//
//  ListService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation
import Sentry
import SwiftUI

@MainActor
@Observable
final class ListService {
    // MARK: - Dependencies
    private nonisolated let repository: any ListRepository
    private nonisolated let memberRepository: any MemberRepository
    private nonisolated let dataStore: ListDataStore
    private nonisolated let log: ServiceLog

    // MARK: - Published State
    private(set) var lists: [GiftList] = []
    private(set) var currentListDetail: ListDetail?
    /// True only while loadLists runs.
    private(set) var isLoadingLists: Bool = false
    /// True only while loadListDetail runs.
    private(set) var isLoadingDetail: Bool = false
    /// True only while createList, updateList or deleteList runs.
    private(set) var isMutating: Bool = false
    private(set) var isRefreshing: Bool = false
    /// The failure of the last lists load or refresh that reported it (the dashboard's load failure).
    /// Set only by loadLists and refreshLists; cleared when one starts, by clearListsLoadFailure()
    /// and at teardown. A mutation never touches it.
    private(set) var listsLoadFailure: ListError?
    /// The last detail failure per list id (a revalidation failure while cached data is shown
    /// included). Set by loadListDetail and by a failed detail refetch after a successful member
    /// change or archive; the entry of one id is cleared when a load of that id starts, when a
    /// refetch of that id succeeds, by clearDetailLoadFailure(forListId:), and every entry by
    /// clearDetailLoadFailure() and at teardown. A failure of one list is never read for another.
    private(set) var detailLoadFailures: [String: ListError] = [:]

    /// The detail failure stored for this list id only, or nil.
    func detailLoadFailure(forListId id: String) -> ListError? {
        detailLoadFailures[id]
    }
    /// The id of the list the server reported gone (not found or read-only), or that a guarded
    /// load found gone. Screens compare it with their own list id to leave. Only the session
    /// reset clears it.
    private(set) var goneListId: String?
    private(set) var lastUpdated: Date?

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every operation captures it before its
    /// first await and drops its result (and any error) if it changed, so a sign-out or a user
    /// switch never leaves the previous user's data in the service or the cache.
    private var generation = 0

    /// Read-only view of the session generation, so a coordinator can tell that the session was
    /// cleared between its steps.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight, keyed by call.
    private var inFlight: [UUID: () -> Void] = [:]

    /// Session-local, monotonic counter of list removals. Every load, refresh, detail load,
    /// update and member refetch captures it at its start.
    private var operationSequence = 0

    /// For each list removed in this session (deleted, left, or reported not found or read-only
    /// by the server), the counter value recorded when the removal completed. A result is
    /// filtered only when its list was removed after the operation started, so a load that
    /// starts after the removal (for example after the member was re-added) is never filtered.
    /// Reset with the rest of the session state.
    private var removalSequence: [String: Int] = [:]

    /// Incremented when an archive completes. A list load, refresh or detail load that captured an
    /// older value started before the archive finished, so its result may show the list as active
    /// and is discarded without an error.
    private var archiveEpoch = 0

    /// For each list archived in this session, the number of archives that completed for it. A
    /// detail load captures its own list's value, so an archive of one list never discards the
    /// in-flight detail load of another.
    private var archivedListEpoch: [String: Int] = [:]

    /// Number of loadListDetail calls in flight per list id.
    private var detailLoadsInFlight: [String: Int] = [:]

    /// Monotonic token handed to each refreshListDetail; only the newest one applies.
    private var detailRefreshToken = 0

    /// Number of mutations in flight; isMutating is true while it is above zero.
    private var mutationCount = 0

    /// Monotonic token handed to each archive's reload; only the latest token's result is applied.
    private var reloadTokenCounter = 0

    /// Callers of loadLists that arrived while a lists load was in flight. They are resumed with
    /// that load's outcome when it ends, and with a finished-without-failure outcome at teardown.
    private var listsLoadWaiters: [CheckedContinuation<ListsLoadOutcome, Never>] = []

    /// What a waiting loadLists caller learns when the load it waited for ends.
    private enum ListsLoadOutcome {
        /// The load ended with this result (nil: success, or a session that ended).
        case finished(ListError?)
        /// The load was cancelled before it finished, so it says nothing about the lists.
        case cancelled
    }

    // MARK: - Filtering

    enum FilterType {
        case all
        case owned
        case shared
    }

    var currentFilter: FilterType = .all

    var filteredLists: [GiftList] {
        switch currentFilter {
        case .all:
            return lists
        case .owned:
            return lists.filter { ListPermissions($0.capabilities).category == .owned }
        case .shared:
            return lists.filter { ListPermissions($0.capabilities).category == .shared }
        }
    }

    /// Lists with status ACTIVE or DRAFT, in the order of `lists`.
    var activeLists: [GiftList] {
        lists.filter { ListSegment.active.includes($0.status) }
    }

    /// Lists with status ARCHIVED, in the order of `lists`.
    var archivedLists: [GiftList] {
        lists.filter { ListSegment.archived.includes($0.status) }
    }

    // MARK: - Initialization
    init(
        repository: any ListRepository,
        memberRepository: any MemberRepository = InertMemberRepository(),
        dataStore: ListDataStore,
        log: ServiceLog = ServiceLog()
    ) {
        self.repository = repository
        self.memberRepository = memberRepository
        self.dataStore = dataStore
        self.log = log
    }

    // MARK: - Public Methods
    //
    // Every repository-calling method runs inside InstrumentedOperation.run (the same span names as the
    // old hand spans; the helper works on the main actor, where @Instrumented cannot be applied) and
    // writes its step lines through ServiceLog: started after the guards, processed after the result is
    // applied, cancelled for a cancellation, and exactly one failed line per failure. Only the operation
    // name, the refresh reason and a count with a literal noun go into a line: no list data.

    /// Loads the lists cache-first and revalidates a stale cache. When a lists load is already in
    /// flight, waits for that load and returns its result without a second fetch. Returns the failure
    /// of the fetch this call performed or waited for (nil on success, cancellation or an ended
    /// session). With `reportingFailure` true the failure is also stored in `listsLoadFailure`
    /// (which is cleared when the load starts); with false it is stored nowhere and an existing
    /// `listsLoadFailure` is left alone. `reason` is only logged.
    @discardableResult
    func loadLists(reportingFailure: Bool = true, reason: RefreshReason = .unspecified) async -> ListError? {
        await loadLists(reportingFailure: reportingFailure, reason: reason, mayRetryAfterCancelledLoad: true)
    }

    // The waiting path does no work of its own (and logs nothing); the span covers the load.
    private func loadLists(
        reportingFailure: Bool,
        reason: RefreshReason,
        mayRetryAfterCancelledLoad: Bool
    ) async -> ListError? {
        let op = "load lists"
        if isLoadingLists {
            let gen = generation
            let outcome = await withCheckedContinuation { (waiter: CheckedContinuation<ListsLoadOutcome, Never>) in
                listsLoadWaiters.append(waiter)
            }
            switch outcome {
            case .finished(let failure):
                return failure
            case .cancelled:
                // The load we waited for was cancelled, not failed: with nothing loaded, this
                // session still alive and this caller not cancelled, load once ourselves.
                guard mayRetryAfterCancelledLoad, gen == generation, !Task.isCancelled, lists.isEmpty else {
                    return nil
                }
                return await loadLists(
                    reportingFailure: reportingFailure, reason: reason, mayRetryAfterCancelledLoad: false
                )
            }
        }
        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        return try? await InstrumentedOperation.run("service.lists.loadLists") { () async -> ListError? in
            log.started(op, reason: reason)
            let gen = generation
            isLoadingLists = true
            if reportingFailure { listsLoadFailure = nil }

            var wasCancelled = false
            let result = await performLoadLists(
                generation: gen, reportingFailure: reportingFailure, reason: reason, cancelled: &wasCancelled
            )
            guard gen == generation else { return nil }
            isLoadingLists = false
            let waiters = listsLoadWaiters
            listsLoadWaiters = []
            let outcome: ListsLoadOutcome = wasCancelled ? .cancelled : .finished(result)
            for waiter in waiters { waiter.resume(returning: outcome) }
            return result
        }
    }

    // Covered by the span of its public caller (loadLists). Writes the one terminal line of the load:
    // processed once the lists are applied, cancelled when the result is dropped, failed once on a failure.
    private func performLoadLists(
        generation gen: Int,
        reportingFailure: Bool,
        reason: RefreshReason,
        cancelled: inout Bool
    ) async -> ListError? {
        let op = "load lists"
        let start = operationSequence
        let epoch = archiveEpoch

        do {
            // Check cache
            let cached = await dataStore.getLists()
            guard gen == generation, epoch == archiveEpoch else { log.cancelled(op); return nil }
            if !cached.isEmpty {
                lists = visibleLists(cached, since: start)
                log.processed(op, count: lists.count, noun: "lists")

                // Background refresh
                if await dataStore.shouldRefresh(), gen == generation {
                    return await performRefreshLists(reportingFailure: reportingFailure, reason: reason)
                }
                return nil
            }

            // Fetch from repository
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
            guard gen == generation, epoch == archiveEpoch else { log.cancelled(op); return nil }

            // Update cache
            await dataStore.setLists(fetched)
            guard gen == generation, epoch == archiveEpoch else { log.cancelled(op); return nil }
            lists = visibleLists(fetched, since: start)
            lastUpdated = Date()

            LogInfo("Loaded \(fetched.count) lists", category: .business)
            log.processed(op, count: lists.count, noun: "lists")
            return nil
        } catch {
            guard epoch == archiveEpoch else { log.cancelled(op); return nil }
            if error is CancellationError, gen == generation { cancelled = true }
            let failure = record(error, generation: gen, op: op)
            if failure == nil { log.cancelled(op) }
            if reportingFailure, let failure { listsLoadFailure = failure }
            return failure
        }
    }

    /// Always fetches (unless a refresh is already in flight). Returns the failure. With `reportingFailure`
    /// true the failure is also stored in `listsLoadFailure` (cleared when the refresh starts); with
    /// false it is stored nowhere and an existing `listsLoadFailure` is left alone. `reason` (pull to
    /// refresh passes `.pull`) is only logged.
    @discardableResult
    func refreshLists(reportingFailure: Bool = true, reason: RefreshReason = .unspecified) async -> ListError? {
        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        try? await InstrumentedOperation.run("service.lists.refreshLists") { () async -> ListError? in
            await performRefreshLists(reportingFailure: reportingFailure, reason: reason)
        }
    }

    func clearListsLoadFailure() {
        listsLoadFailure = nil
    }

    /// Removes every stored detail failure.
    func clearDetailLoadFailure() {
        detailLoadFailures = [:]
    }

    /// Removes the detail failure stored for this list id only.
    func clearDetailLoadFailure(forListId id: String) {
        detailLoadFailures[id] = nil
    }

    // Covered by the spans of its public callers (loadLists, refreshLists). Logs "skipped" when a refresh
    // is already running (no call is made), then started, and one terminal line.
    private func performRefreshLists(reportingFailure: Bool, reason: RefreshReason) async -> ListError? {
        let op = "refresh lists"
        guard !isRefreshing else { log.skipped(op); return nil }
        log.started(op, reason: reason)
        let gen = generation
        let start = operationSequence
        let epoch = archiveEpoch
        isRefreshing = true
        defer { if gen == generation { isRefreshing = false } }
        if reportingFailure { listsLoadFailure = nil }

        do {
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
            guard gen == generation, epoch == archiveEpoch else { log.cancelled(op); return nil }
            await dataStore.setLists(fetched)
            guard gen == generation, epoch == archiveEpoch else { log.cancelled(op); return nil }
            lists = visibleLists(fetched, since: start)
            lastUpdated = Date()

            LogInfo("Refreshed \(fetched.count) lists", category: .business)
            log.processed(op, count: lists.count, noun: "lists")
            return nil
        } catch {
            guard epoch == archiveEpoch else { log.cancelled(op); return nil }
            let failure = record(error, generation: gen, op: op)
            if failure == nil { log.cancelled(op) }
            if reportingFailure, let failure { listsLoadFailure = failure }
            return failure
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    func loadListDetail(id: String, reason: RefreshReason = .unspecified) async {
        let op = "load list details"
        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        _ = try? await InstrumentedOperation.run("service.lists.loadListDetail") {
            log.started(op, reason: reason)
            let gen = generation
            let start = operationSequence
            // Only an archive of this very list can make the result stale.
            let epoch = archivedListEpoch[id, default: 0]
            isLoadingDetail = true
            detailLoadsInFlight[id, default: 0] += 1
            defer {
                if gen == generation {
                    isLoadingDetail = false
                    detailLoadsInFlight[id, default: 1] -= 1
                }
            }
            detailLoadFailures[id] = nil
            // A reload of the list that is already open keeps showing it; another list's detail is
            // never shown while this one loads.
            if currentListDetail?.id != id {
                currentListDetail = nil
            }
            var shownCached = false

            do {
                // Show the cached detail right away, then always revalidate with the server: the
                // flags and the roster must be fresh, and a gone list must be noticed.
                let cached = await dataStore.getListDetail(id: id)
                guard gen == generation else { log.cancelled(op); return }
                // A list gone since the load started logs its own failure line (reportGuarded).
                guard await !reportGuarded(id, since: start, generation: gen, storingFailure: true) else { return }
                if let cached {
                    currentListDetail = cached
                    shownCached = true
                }

                let repository = self.repository
                let detail = try await perform { try await repository.fetchListDetail(id: id) }
                guard gen == generation, epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return }
                guard await !reportGuarded(id, since: start, generation: gen, storingFailure: true) else { return }

                await dataStore.setListDetail(detail)
                guard gen == generation, epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return }
                guard await !reportGuarded(id, since: start, generation: gen, storingFailure: true) else { return }
                currentListDetail = detail

                LogInfo("Loaded list detail", category: .business)
                log.processed(op)
            } catch {
                guard epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return }
                if shownCached, (error as? ListError) == .forbidden {
                    // Revalidating a cached detail: access is gone, so the cached copy must go too.
                    if gen == generation { await dropList(id: id) }
                } else {
                    await dropListIfGone(error, id: id, generation: gen)
                }
                if let failure = record(error, generation: gen, op: op) {
                    detailLoadFailures[id] = failure
                } else {
                    log.cancelled(op)
                }
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    /// Always fetches. Returns the failure (it is not stored); nil on success, when the list is
    /// gone (goneListId is set), when superseded by a newer refresh, or when the session ended.
    /// `reason` (pull to refresh passes `.pull`) is only logged.
    @discardableResult
    func refreshListDetail(id: String, reason: RefreshReason = .unspecified) async -> ListError? {
        let op = "refresh list details"
        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        return try? await InstrumentedOperation.run("service.lists.refreshListDetail") { () async -> ListError? in
            log.started(op, reason: reason)
            let gen = generation
            let start = operationSequence
            let epoch = archivedListEpoch[id, default: 0]
            detailRefreshToken += 1
            let token = detailRefreshToken

            do {
                let repository = self.repository
                let detail = try await perform { try await repository.fetchListDetail(id: id) }
                guard gen == generation, token == detailRefreshToken,
                      epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return nil }
                // A list gone since the refresh started logs its own failure line (reportGuarded).
                guard await !reportGuarded(id, since: start, generation: gen) else { return nil }
                await dataStore.setListDetail(detail)
                guard gen == generation, token == detailRefreshToken,
                      epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return nil }
                guard await !reportGuarded(id, since: start, generation: gen) else { return nil }
                if currentListDetail == nil || currentListDetail?.id == id {
                    currentListDetail = detail
                }
                LogInfo("Refreshed list detail", category: .business)
                log.processed(op)
                return nil
            } catch {
                guard gen == generation, token == detailRefreshToken, !(error is CancellationError),
                      epoch == archivedListEpoch[id, default: 0] else { log.cancelled(op); return nil }
                let listError = (error as? ListError) ?? .server
                if listError == .notFound {
                    await dropListIfGone(error, id: id, generation: gen)
                    log.processed(op)
                    return nil
                }
                if listError == .forbidden, currentListDetail?.id == id {
                    await dropList(id: id)
                    log.processed(op)
                    return nil
                }
                // Only the operation name is logged: no ids, names, emails or server text.
                log.failed(op)
                return listError
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    func createList(_ input: CreateListInput) async throws {
        let op = "create list"
        try await InstrumentedOperation.run("service.lists.createList") {
            log.started(op)
            let gen = generation
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let repository = self.repository
                let created = try await perform { try await repository.createList(input) }
                try ensureCurrent(gen)

                // The returned detail carries fresh flags: use it, do not refetch.
                let summary = created.asGiftList()
                try ensureCurrent(gen)
                await dataStore.storeCreated(created)
                try ensureCurrent(gen)

                if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                    lists[index] = summary
                } else {
                    lists.append(summary)
                }

                LogInfo("Created list", category: .business)
                log.processed(op)
            } catch {
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    func updateList(id: String, _ input: UpdateListInput) async throws {
        let op = "update list"
        try await InstrumentedOperation.run("service.lists.updateList") {
            log.started(op)
            let gen = generation
            let start = operationSequence
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let repository = self.repository
                let updated = try await perform { try await repository.updateList(id: id, input) }
                try ensureCurrent(gen)

                // The returned detail carries fresh flags: use it, do not refetch.
                // The list was removed while the update was in flight: write nothing back.
                guard !isRemoved(id, since: start) else { log.cancelled(op); return }
                let summary = updated.asGiftList()
                await dataStore.setListDetail(updated)
                try ensureCurrent(gen)
                guard !isRemoved(id, since: start) else {
                    await dataStore.removeList(id: id)
                    log.cancelled(op)
                    return
                }

                if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                    lists[index] = summary
                }
                if currentListDetail?.id == updated.id {
                    currentListDetail = updated
                }

                LogInfo("Updated list", category: .business)
                log.processed(op)
            } catch {
                await dropListIfGone(error, id: id, generation: gen)
                await refetchAfterArchivedReadOnly(error, id: id, generation: gen)
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    func removeCoOwner(listId: String) async throws {
        let op = "remove co-owner"
        try await InstrumentedOperation.run("service.lists.removeCoOwner") {
            log.started(op)
            let gen = generation
            let start = operationSequence
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let repository = self.repository
                let updated = try await perform { try await repository.removeCoOwner(listId: listId) }
                try ensureCurrent(gen)

                // The returned detail carries fresh flags: use it, do not refetch.
                // The list was removed while the call was in flight: write nothing back.
                guard !isRemoved(listId, since: start) else { log.cancelled(op); return }
                let summary = updated.asGiftList()
                await dataStore.setListDetail(updated)
                try ensureCurrent(gen)
                guard !isRemoved(listId, since: start) else {
                    await dataStore.removeList(id: listId)
                    log.cancelled(op)
                    return
                }

                if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                    lists[index] = summary
                }
                if currentListDetail?.id == updated.id {
                    currentListDetail = updated
                }

                LogInfo("Removed co-owner", category: .business)
                log.processed(op)
            } catch {
                await dropListIfGone(error, id: listId, generation: gen)
                await refetchAfterArchivedReadOnly(error, id: listId, generation: gen)
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    /// Archives a list (the server's delete), then reloads the lists with a fresh fetch so the list
    /// shows under Archived with the server's flags. No removal is recorded and no status is
    /// synthesized locally. If the archive succeeded but the reload fails, returns normally: the
    /// failure is logged by operation name only and left to the next load.
    func deleteList(id: String) async throws {
        let op = "archive list"
        try await InstrumentedOperation.run("service.lists.deleteList") {
            log.started(op)
            let gen = generation
            let start = operationSequence
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let repository = self.repository
                try await perform { try await repository.deleteList(id: id) }
                try ensureCurrent(gen)
                // Loads that started before this point may still carry the list as active.
                archiveEpoch += 1
                archivedListEpoch[id, default: 0] += 1
                // A detail load of this list that is in flight now is discarded: refetch for it.
                let discardedDetailLoad = detailLoadsInFlight[id, default: 0] > 0
                reloadTokenCounter += 1

                try await reloadAfterArchive(
                    id: id,
                    since: start,
                    generation: gen,
                    reloadToken: reloadTokenCounter,
                    refetchDetailAnyway: discardedDetailLoad
                )
                LogInfo("Archived list", category: .business)
                log.processed(op)
            } catch {
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    /// Always fetches from the repository (never the cache), writes the result to `lists` and the
    /// cache like `refreshLists`, and returns it. Publishes no shared `error`: a failure is thrown
    /// as the typed ListError (anything else as `.server`); a cancelled call or an ended session
    /// throws CancellationError and writes nothing.
    func freshLists() async throws -> [GiftList] {
        let op = "fresh lists"
        return try await InstrumentedOperation.run("service.lists.freshLists") { () async throws -> [GiftList] in
            log.started(op)
            let gen = generation
            let start = operationSequence
            let epoch = archiveEpoch

            do {
                let repository = self.repository
                let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
                try ensureCurrent(gen)
                try Task.checkCancellation()
                // An archive that finished meanwhile makes this result stale for the cache and `lists`.
                guard epoch == archiveEpoch else {
                    log.processed(op, count: fetched.count, noun: "lists")
                    return fetched
                }
                await dataStore.setLists(fetched)
                try ensureCurrent(gen)
                guard epoch == archiveEpoch else {
                    log.processed(op, count: fetched.count, noun: "lists")
                    return fetched
                }
                lists = visibleLists(fetched, since: start)
                lastUpdated = Date()
                log.processed(op, count: fetched.count, noun: "lists")
                return fetched
            } catch {
                if error is CancellationError || Task.isCancelled || gen != generation {
                    log.cancelled(op)
                    throw CancellationError()
                }
                // Only the operation name is logged: no ids, names, emails or server text.
                log.failed(op)
                throw (error as? ListError) ?? ListError.server
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists.
    /// Archives the lists one after the other and stops at the first failure (a not-found counts as
    /// archived). Reloads the lists exactly once at the end, also after a failure or zero progress,
    /// but not for empty input and not when the session ended or the caller was cancelled. Publishes
    /// no shared `error`: the failure is in the result. One line per operation, nothing per list: a
    /// single processed line with the count, and one failed line when an archive failed. Counts only.
    func archiveLists(ids: [String]) async -> ArchiveBatchResult {
        guard !ids.isEmpty else {
            return ArchiveBatchResult(archivedCount: 0, totalCount: 0, failedId: nil, failure: nil)
        }
        let op = "archive list in batch"
        // The closure throws nothing, so `run` rethrows nothing; the fallback below is never used.
        typealias Batch = ArchiveBatchResult
        let result = try? await InstrumentedOperation.run("service.lists.archiveLists") { () async -> Batch in
            log.started(op)
            let gen = generation
            let start = operationSequence
            beginMutation()
            defer { endMutation(generation: gen) }

            var archivedCount = 0
            var failedId: String?
            var failure: ListError?
            let repository = self.repository

            for id in ids {
                if Task.isCancelled || gen != generation {
                    log.cancelled(op)
                    return ArchiveBatchResult(
                        archivedCount: archivedCount, totalCount: ids.count, failedId: nil, failure: nil
                    )
                }
                do {
                    try await perform { try await repository.deleteList(id: id) }
                    try ensureCurrent(gen)
                } catch {
                    if error is CancellationError || Task.isCancelled || gen != generation {
                        log.cancelled(op)
                        return ArchiveBatchResult(
                            archivedCount: archivedCount, totalCount: ids.count, failedId: nil, failure: nil
                        )
                    }
                    let listError = (error as? ListError) ?? ListError.server
                    if listError != .notFound {
                        // Nothing is logged per list: the one failed line is written after the loop.
                        failedId = id
                        failure = listError
                        break
                    }
                }
                archivedCount += 1
                // Loads that started before this point may still carry the list as active.
                archiveEpoch += 1
                archivedListEpoch[id, default: 0] += 1
            }

            reloadTokenCounter += 1
            let token = reloadTokenCounter
            do {
                let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
                try ensureCurrent(gen)
                try Task.checkCancellation()
                if token == reloadTokenCounter {
                    await dataStore.setLists(fetched)
                    try ensureCurrent(gen)
                    if token == reloadTokenCounter {
                        lists = fetched
                        lastUpdated = Date()
                    }
                }
            } catch {
                // A failed reload is left to the next load; nothing is published. A cancelled reload is not
                // an error.
                if !(error is CancellationError), !Task.isCancelled, gen == generation {
                    log.failed("reload lists after archive batch")
                }
            }

            LogInfo("Archived \(archivedCount) of \(ids.count) lists", category: .business)
            log.processed(op, count: archivedCount, noun: "lists")
            if failure != nil { log.failed(op) }
            return ArchiveBatchResult(
                archivedCount: archivedCount, totalCount: ids.count, failedId: failedId, failure: failure
            )
        }
        return result ?? ArchiveBatchResult(archivedCount: 0, totalCount: ids.count, failedId: nil, failure: nil)
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see loadLists. No member data goes into
    // the span or a line.
    /// Adds a member, then refetches the detail: the roster is never built from the add response.
    /// If the add succeeded but the refetch fails, returns normally: the failure is logged by
    /// operation name only and left to the next load.
    func addMember(listId: String, _ input: AddMemberInput) async throws {
        let op = "add member"
        try await InstrumentedOperation.run("service.lists.addMember") {
            log.started(op)
            let gen = generation
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let members = self.memberRepository
                _ = try await perform { try await members.addMember(listId: listId, input) }
                try ensureCurrent(gen)
                try await refetchDetailAfterMemberChange(listId: listId, generation: gen)
                LogInfo("Added list member", category: .business)
                log.processed(op)
            } catch {
                await dropListIfGone(error, id: listId, generation: gen)
                await refetchAfterArchivedReadOnly(error, id: listId, generation: gen)
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see addMember.
    /// Removes another member, then refetches the detail. A `membershipNotFound` failure
    /// (already gone) refetches best-effort so the roster catches up, then rethrows.
    func removeMember(listId: String, userId: String) async throws {
        let op = "remove member"
        try await InstrumentedOperation.run("service.lists.removeMember") {
            log.started(op)
            let gen = generation
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let members = self.memberRepository
                try await perform { try await members.removeMember(listId: listId, userId: userId) }
                try ensureCurrent(gen)
                try await refetchDetailAfterMemberChange(listId: listId, generation: gen)
                LogInfo("Removed list member", category: .business)
                log.processed(op)
            } catch {
                await dropListIfGone(error, id: listId, generation: gen)
                await refetchAfterArchivedReadOnly(error, id: listId, generation: gen)
                if gen == generation, (error as? ListError) == .membershipNotFound {
                    try? await refetchDetailAfterMemberChange(listId: listId, generation: gen)
                }
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    // Actor-isolated (@MainActor): InstrumentedOperation span, see addMember.
    /// Leaves a list: removes the caller (`userId`) as a member, then drops the list from the
    /// service and the cache. `membershipNotFound` (already not a member) drops it too.
    func leaveList(id: String, userId: String) async throws {
        let op = "leave list"
        try await InstrumentedOperation.run("service.lists.leaveList") {
            log.started(op)
            let gen = generation
            beginMutation()
            defer { endMutation(generation: gen) }

            do {
                let members = self.memberRepository
                try await perform { try await members.removeMember(listId: id, userId: userId) }
                try ensureCurrent(gen)
                await dropList(id: id)
                LogInfo("Left list", category: .business)
                log.processed(op)
            } catch {
                if gen == generation, (error as? ListError) == .membershipNotFound {
                    await dropList(id: id)
                } else {
                    await dropListIfGone(error, id: id, generation: gen)
                }
                throw failure(error, generation: gen, op: op)
            }
        }
    }

    /// Sets the co-owner by email through the update-list operation and uses the returned detail
    /// (flags included), exactly like updateList. Clearing the co-owner is a
    /// separate operation: see removeCoOwner(listId:).
    // Covered by the span (and the step lines) of updateList, which does all the work.
    func setCoOwner(listId: String, email: String) async throws {
        try await updateList(
            id: listId,
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: email))
        )
    }

    func clearCurrentDetail() {
        currentListDetail = nil
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual span is used (no repository call, so no step lines). No data goes into the span.
    func clearCache() async {
        let span = SentrySDK.startTransaction(name: "service.lists.clearCache", operation: "service.lists.clearCache")
        defer { span.finish() }
        await resetSession()
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight work, bumps the generation so late results
    /// are discarded, and empties the published state and the cache.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual span is used (no repository call, so no step lines). No data goes into the span.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.clearForSession",
            operation: "service.lists.clearForSession"
        )
        defer { span.finish() }
        await resetSession()
    }

    // MARK: - Private Functions

    private func beginMutation() {
        mutationCount += 1
        isMutating = true
    }

    /// Clears isMutating only when no other mutation is running. Ignores a session that ended.
    private func endMutation(generation gen: Int) {
        guard gen == generation else { return }
        mutationCount = max(0, mutationCount - 1)
        isMutating = mutationCount > 0
    }

    // Covered by the manual spans of its public callers (clearForSession, clearCache).
    private func resetSession() async {
        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        lists = []
        currentListDetail = nil
        listsLoadFailure = nil
        detailLoadFailures = [:]
        let waiters = listsLoadWaiters
        listsLoadWaiters = []
        for waiter in waiters { waiter.resume(returning: .finished(nil)) }
        operationSequence = 0
        removalSequence = [:]
        goneListId = nil
        isLoadingLists = false
        isLoadingDetail = false
        isMutating = false
        mutationCount = 0
        archivedListEpoch = [:]
        detailLoadsInFlight = [:]
        detailRefreshToken = 0
        isRefreshing = false
        lastUpdated = nil
        currentFilter = .all

        // The service clears the cache itself, so it does not depend on the store also being
        // registered with the session manager.
        await dataStore.clear()
    }

    /// Every list stays, ARCHIVED included. Lists removed after the operation started (`start`)
    /// are hidden, even when that load still returns them.
    private func visibleLists(_ fetched: [GiftList], since start: Int) -> [GiftList] {
        fetched.filter { !isRemoved($0.id, since: start) }
    }

    /// True when the list was removed after an operation that captured `start` began.
    private func isRemoved(_ id: String, since start: Int) -> Bool {
        guard let recorded = removalSequence[id] else { return false }
        return recorded > start
    }

    /// Records a completed removal: bumps the counter and stores the new value for the id.
    private func recordRemoval(_ id: String) {
        operationSequence += 1
        removalSequence[id] = operationSequence
    }

    /// When a call failed because the list is gone (not found), removes it from the lists, the
    /// cache and the open detail and records the removal for this session. An archived list (422)
    /// is not gone. Does nothing for any other error or after the session ended.
    // Covered by the spans of its public callers (loadListDetail, updateList).
    private func dropListIfGone(_ error: any Error, id: String, generation gen: Int) async {
        guard gen == generation, let listError = error as? ListError else { return }
        switch listError {
        case .notFound:
            break
        case .forbidden, .archivedReadOnly, .recipientNotFound, .duplicateRecipientYear, .validation, .rateLimited,
             .unauthorized, .sessionEnded, .network, .invalidResponse, .server, .memberEmailNotFound,
             .alreadyMember, .membershipNotFound:
            return
        }
        await dropList(id: id)
    }

    /// Removes a list that is gone for this user (left, not found) from the lists, the
    /// cache and the open detail, and records the removal for this session. Callers check the
    /// generation first.
    // Covered by the spans of its public callers.
    private func dropList(id: String) async {
        recordRemoval(id)
        goneListId = id
        lists.removeAll { $0.id == id }
        if currentListDetail?.id == id {
            currentListDetail = nil
        }
        await dataStore.removeList(id: id)
    }

    /// Refetches one list's detail after a member change and writes it to the cache, the open
    /// detail and the lists entry (member count). A failed refetch records its error and returns;
    /// only cancellation or an ended session throws.
    // Covered by the spans of its public callers (addMember, removeMember).
    private func refetchDetailAfterMemberChange(listId: String, generation gen: Int) async throws {
        let start = operationSequence
        do {
            let repository = self.repository
            let detail = try await perform { try await repository.fetchListDetail(id: listId) }
            try ensureCurrent(gen)
            guard !isRemoved(listId, since: start) else { return }
            await dataStore.setListDetail(detail)
            try ensureCurrent(gen)
            guard !isRemoved(listId, since: start) else {
                await dataStore.removeList(id: listId)
                return
            }
            let summary = detail.asGiftList()
            if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                lists[index] = summary
            }
            if currentListDetail?.id == detail.id {
                currentListDetail = detail
            }
            detailLoadFailures[listId] = nil
        } catch {
            await dropListIfGone(error, id: listId, generation: gen)
            guard let failure = record(error, generation: gen, op: "refresh list after member change") else {
                throw CancellationError()
            }
            // The mutation succeeded: the failed refetch is recorded for the screen, never thrown.
            // A list that turned out to be gone is left to the gone-list handling.
            if goneListId != listId { detailLoadFailures[listId] = failure }
        }
    }

    /// After a successful archive: a fresh fetch of the lists (never the cache) written to `lists`
    /// and the cache, then a refetch of the open detail when it is the archived list. Calls the
    /// repository directly, so an in-flight refresh and its guard are not involved. A failed fetch
    /// removes the list until the next successful load and records the error; only cancellation
    /// or an ended session throws.
    // Covered by the span of its public caller (deleteList).
    private func reloadAfterArchive(
        id: String,
        since start: Int,
        generation gen: Int,
        reloadToken: Int,
        refetchDetailAnyway: Bool
    ) async throws {
        let repository = self.repository
        do {
            let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
            try ensureCurrent(gen)
            try Task.checkCancellation()
            // A later archive started its own reload: this result may predate it, so drop it.
            if reloadToken == reloadTokenCounter {
                await dataStore.setLists(fetched)
                try ensureCurrent(gen)
                if reloadToken == reloadTokenCounter {
                    lists = fetched
                    lastUpdated = Date()
                }
            }
        } catch {
            if error is CancellationError || gen != generation { throw CancellationError() }
            // A superseded reload reports nothing and removes nothing: the later one decides.
            if reloadToken == reloadTokenCounter {
                if let failure = record(error, generation: gen, op: "reload lists after archive") {
                    listsLoadFailure = failure
                }
                lists.removeAll { $0.id == id }
                await dataStore.removeList(id: id)
                try ensureCurrent(gen)
            }
        }

        guard currentListDetail?.id == id || refetchDetailAnyway else { return }
        do {
            let detail = try await perform { try await repository.fetchListDetail(id: id) }
            try ensureCurrent(gen)
            try Task.checkCancellation()
            await dataStore.setListDetail(detail)
            try ensureCurrent(gen)
            currentListDetail = detail
            detailLoadFailures[id] = nil
        } catch {
            if error is CancellationError || gen != generation { throw CancellationError() }
            if let failure = record(error, generation: gen, op: "refresh list after archive") {
                detailLoadFailures[id] = failure
            }
        }
    }

    /// After a 422 (the list is archived): refetches the list detail and writes it to the open
    /// detail (when it is that list), the cache and the lists entry, so the flags refresh. Best
    /// effort: a failed refetch changes nothing (a not-found refetch drops the list) and the caller
    /// still throws the original error. Does nothing for any other error.
    // Covered by the spans of its public callers (updateList, removeCoOwner, addMember, removeMember).
    private func refetchAfterArchivedReadOnly(_ error: any Error, id: String, generation gen: Int) async {
        guard gen == generation, (error as? ListError) == .archivedReadOnly else { return }
        let start = operationSequence
        do {
            let repository = self.repository
            let detail = try await perform { try await repository.fetchListDetail(id: id) }
            try ensureCurrent(gen)
            guard !isRemoved(id, since: start) else { return }
            await dataStore.setListDetail(detail)
            try ensureCurrent(gen)
            guard !isRemoved(id, since: start) else {
                await dataStore.removeList(id: id)
                return
            }
            let summary = detail.asGiftList()
            if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                lists[index] = summary
            }
            if currentListDetail?.id == detail.id {
                currentListDetail = detail
            }
        } catch {
            await dropListIfGone(error, id: id, generation: gen)
        }
    }

    /// For a list removed after the load started (`start`): drops any cached or open copy,
    /// logs notFound, marks the list gone and returns true. With `storingFailure` (the detail
    /// load) the notFound also goes into the keyed `detailLoadFailures` entry of that id. Returns false when the list was not
    /// removed after the load started.
    // Covered by the spans of its public callers (loadListDetail, refreshListDetail).
    private func reportGuarded(
        _ id: String,
        since start: Int,
        generation gen: Int,
        storingFailure: Bool = false
    ) async -> Bool {
        guard isRemoved(id, since: start) else { return false }
        goneListId = id
        if currentListDetail?.id == id {
            currentListDetail = nil
        }
        let failure = record(ListError.notFound, generation: gen, op: "load list details")
        if storingFailure, let failure { detailLoadFailures[id] = failure }
        await dataStore.removeList(id: id)
        return true
    }

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Covered by the spans of its public callers (the load, create, update and delete functions).
    private func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task { try await work() }
        let token = UUID()
        inFlight[token] = { task.cancel() }
        defer { inFlight[token] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Stops a write that finished after the session was cleared.
    private func ensureCurrent(_ gen: Int) throws {
        if gen != generation { throw CancellationError() }
    }

    /// Classifies the error of a failed call, writes the one failed line (the operation name only)
    /// and returns the typed error. Stores nothing. Returns nil, with no line, for cancellation and
    /// for a call that belongs to a session that has ended: neither is shown to the user, and the
    /// caller logs `cancelled`.
    private func record(_ error: any Error, generation gen: Int, op: String) -> ListError? {
        if error is CancellationError || gen != generation { return nil }
        let listError = (error as? ListError) ?? .server
        // Only the operation name is logged: no ids, names, emails or server text.
        log.failed(op)
        return listError
    }

    /// The error a throwing operation rethrows: the typed ListError (one failed line), or
    /// CancellationError (one cancelled line) when the call was cancelled or its session ended.
    private func failure(_ error: any Error, generation gen: Int, op: String) -> any Error {
        if let listError = record(error, generation: gen, op: op) {
            return listError
        }
        log.cancelled(op)
        return CancellationError()
    }
}

/// The outcome of `ListService.archiveLists(ids:)`. `failedId` and `failure` are set only when an
/// archive failed (kept in memory only; never logged). A result with fewer archived than total and
/// no failure means the batch stopped because the session ended or the caller was cancelled.
nonisolated struct ArchiveBatchResult: Equatable, Sendable {
    let archivedCount: Int
    let totalCount: Int
    let failedId: String?
    let failure: ListError?
}

// MARK: - SessionClearable

extension ListService: SessionClearable {}
