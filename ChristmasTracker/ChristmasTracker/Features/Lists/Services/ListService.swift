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
    private(set) var error: ListError?
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

    // MARK: - Initialization
    init(
        repository: any ListRepository,
        memberRepository: any MemberRepository = InertMemberRepository(),
        dataStore: ListDataStore
    ) {
        self.repository = repository
        self.memberRepository = memberRepository
        self.dataStore = dataStore
    }

    // MARK: - Public Methods

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No list data goes into the span.
    func loadLists() async {
        guard !isLoadingLists else { return }
        let span = SentrySDK.startTransaction(name: "service.lists.loadLists", operation: "service.lists.loadLists")
        defer { span.finish() }

        let gen = generation
        let start = operationSequence
        isLoadingLists = true
        defer { if gen == generation { isLoadingLists = false } }
        error = nil

        do {
            // Check cache
            let cached = await dataStore.getLists()
            guard gen == generation else { return }
            if !cached.isEmpty {
                lists = visibleLists(cached, since: start)

                // Background refresh
                if await dataStore.shouldRefresh(), gen == generation {
                    await refreshLists()
                }
                return
            }

            // Fetch from repository
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
            guard gen == generation else { return }

            // Update cache
            await dataStore.setLists(fetched)
            guard gen == generation else { return }
            lists = visibleLists(fetched, since: start)
            lastUpdated = Date()

            LogInfo("Loaded \(fetched.count) lists", category: .business)
        } catch {
            _ = record(error, generation: gen, operation: "load lists")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadLists.
    func refreshLists() async {
        guard !isRefreshing else { return }
        let span = SentrySDK.startTransaction(
            name: "service.lists.refreshLists",
            operation: "service.lists.refreshLists"
        )
        defer { span.finish() }

        let gen = generation
        let start = operationSequence
        isRefreshing = true
        defer { if gen == generation { isRefreshing = false } }
        error = nil

        do {
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() }, since: start)
            guard gen == generation else { return }
            await dataStore.setLists(fetched)
            guard gen == generation else { return }
            lists = visibleLists(fetched, since: start)
            lastUpdated = Date()

            LogInfo("Refreshed \(fetched.count) lists", category: .business)
        } catch {
            _ = record(error, generation: gen, operation: "refresh lists")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadLists.
    func loadListDetail(id: String) async {
        let span = SentrySDK.startTransaction(
            name: "service.lists.loadListDetail",
            operation: "service.lists.loadListDetail"
        )
        defer { span.finish() }

        let gen = generation
        let start = operationSequence
        isLoadingDetail = true
        defer { if gen == generation { isLoadingDetail = false } }
        error = nil
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
            guard gen == generation else { return }
            guard await !reportGuarded(id, since: start, generation: gen) else { return }
            if let cached {
                currentListDetail = cached
                shownCached = true
            }

            let repository = self.repository
            let detail = try await perform { try await repository.fetchListDetail(id: id) }
            guard gen == generation else { return }
            guard await !reportGuarded(id, since: start, generation: gen) else { return }

            await dataStore.setListDetail(detail)
            guard gen == generation else { return }
            guard await !reportGuarded(id, since: start, generation: gen) else { return }
            currentListDetail = detail

            LogInfo("Loaded list detail", category: .business)
        } catch {
            if shownCached, (error as? ListError) == .forbidden {
                // Revalidating a cached detail: access is gone, so the cached copy must go too.
                if gen == generation { await dropList(id: id) }
            } else {
                await dropListIfGone(error, id: id, generation: gen)
            }
            _ = record(error, generation: gen, operation: "load list details")
        }
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No list data goes into the span.
    func createList(_ input: CreateListInput) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.createList",
            operation: "service.lists.createList"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

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
        } catch {
            throw failure(error, generation: gen, operation: "create list")
        }
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No list data goes into the span.
    func updateList(id: String, _ input: UpdateListInput) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.updateList",
            operation: "service.lists.updateList"
        )
        defer { span.finish() }

        let gen = generation
        let start = operationSequence
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

        do {
            let repository = self.repository
            let updated = try await perform { try await repository.updateList(id: id, input) }
            try ensureCurrent(gen)

            // The returned detail carries fresh flags: use it, do not refetch.
            // The list was removed while the update was in flight: write nothing back.
            guard !isRemoved(id, since: start) else { return }
            let summary = updated.asGiftList()
            await dataStore.setListDetail(updated)
            try ensureCurrent(gen)
            guard !isRemoved(id, since: start) else {
                await dataStore.removeList(id: id)
                return
            }

            if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                lists[index] = summary
            }
            if currentListDetail?.id == updated.id {
                currentListDetail = updated
            }

            LogInfo("Updated list", category: .business)
        } catch {
            await dropListIfGone(error, id: id, generation: gen)
            throw failure(error, generation: gen, operation: "update list")
        }
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No list data goes into the span.
    func deleteList(id: String) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.deleteList",
            operation: "service.lists.deleteList"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

        do {
            let repository = self.repository
            try await perform { try await repository.deleteList(id: id) }
            try ensureCurrent(gen)
            recordRemoval(id)

            // The server archives the list; remove it locally without refetching. Later
            // loads drop it because it comes back ARCHIVED.
            await dataStore.removeList(id: id)
            try ensureCurrent(gen)

            lists.removeAll { $0.id == id }
            if currentListDetail?.id == id {
                currentListDetail = nil
            }

            LogInfo("Deleted list", category: .business)
        } catch {
            throw failure(error, generation: gen, operation: "delete list")
        }
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No member data goes into the span.
    /// Adds a member, then refetches the detail: the roster is never built from the add response.
    /// If the add succeeded but the refetch fails, returns normally with `error` set to the
    /// refetch error.
    func addMember(listId: String, _ input: AddMemberInput) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.addMember",
            operation: "service.lists.addMember"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

        do {
            let members = self.memberRepository
            _ = try await perform { try await members.addMember(listId: listId, input) }
            try ensureCurrent(gen)
            try await refetchDetailAfterMemberChange(listId: listId, generation: gen)
            LogInfo("Added list member", category: .business)
        } catch {
            await dropListIfGone(error, id: listId, generation: gen)
            throw failure(error, generation: gen, operation: "add member")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see addMember.
    /// Removes another member, then refetches the detail. A `membershipNotFound` failure
    /// (already gone) refetches best-effort so the roster catches up, then rethrows.
    func removeMember(listId: String, userId: String) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.removeMember",
            operation: "service.lists.removeMember"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

        do {
            let members = self.memberRepository
            try await perform { try await members.removeMember(listId: listId, userId: userId) }
            try ensureCurrent(gen)
            try await refetchDetailAfterMemberChange(listId: listId, generation: gen)
            LogInfo("Removed list member", category: .business)
        } catch {
            await dropListIfGone(error, id: listId, generation: gen)
            if gen == generation, (error as? ListError) == .membershipNotFound {
                try? await refetchDetailAfterMemberChange(listId: listId, generation: gen)
            }
            throw failure(error, generation: gen, operation: "remove member")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see addMember.
    /// Leaves a list: removes the caller (`userId`) as a member, then drops the list from the
    /// service and the cache. `membershipNotFound` (already not a member) drops it too.
    func leaveList(id: String, userId: String) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.leaveList",
            operation: "service.lists.leaveList"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }
        error = nil

        do {
            let members = self.memberRepository
            try await perform { try await members.removeMember(listId: id, userId: userId) }
            try ensureCurrent(gen)
            await dropList(id: id)
            LogInfo("Left list", category: .business)
        } catch {
            if gen == generation, (error as? ListError) == .membershipNotFound {
                await dropList(id: id)
            } else {
                await dropListIfGone(error, id: id, generation: gen)
            }
            throw failure(error, generation: gen, operation: "leave list")
        }
    }

    /// Sets the co-owner by email through the update-list operation and uses the returned detail
    /// (flags included), exactly like updateList. Clearing the co-owner is not offered: the
    /// generated client cannot send it.
    // Covered by the manual span of updateList, which does all the work.
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
    // so a manual span is used. No data goes into the span.
    func clearCache() async {
        let span = SentrySDK.startTransaction(name: "service.lists.clearCache", operation: "service.lists.clearCache")
        defer { span.finish() }
        await resetSession()
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight work, bumps the generation so late results
    /// are discarded, and empties the published state and the cache.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual span is used. No data goes into the span.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.lists.clearForSession",
            operation: "service.lists.clearForSession"
        )
        defer { span.finish() }
        await resetSession()
    }

    // MARK: - Private Functions

    // Covered by the manual spans of its public callers (clearForSession, clearCache).
    private func resetSession() async {
        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        lists = []
        currentListDetail = nil
        error = nil
        operationSequence = 0
        removalSequence = [:]
        goneListId = nil
        isLoadingLists = false
        isLoadingDetail = false
        isMutating = false
        isRefreshing = false
        lastUpdated = nil
        currentFilter = .all

        // The service clears the cache itself, so it does not depend on the store also being
        // registered with the session manager.
        await dataStore.clear()
    }

    /// ARCHIVED lists are hidden everywhere; DRAFT behaves like ACTIVE. Lists removed after the
    /// operation started (`start`) are hidden too, even when that load still returns them.
    private func visibleLists(_ fetched: [GiftList], since start: Int) -> [GiftList] {
        fetched.filter { $0.status != .archived && !isRemoved($0.id, since: start) }
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

    /// When a call failed because the list is gone (not found) or read-only (archived), removes
    /// it from the lists, the cache and the open detail and records the removal for this session.
    /// Does nothing for any other error or after the session ended.
    // Covered by the manual spans of its public callers (loadListDetail, updateList).
    private func dropListIfGone(_ error: any Error, id: String, generation gen: Int) async {
        guard gen == generation, let listError = error as? ListError else { return }
        switch listError {
        case .notFound, .archivedReadOnly:
            break
        case .forbidden, .recipientNotFound, .duplicateRecipientYear, .validation, .rateLimited,
             .unauthorized, .sessionEnded, .network, .invalidResponse, .server, .memberEmailNotFound,
             .alreadyMember, .membershipNotFound:
            return
        }
        await dropList(id: id)
    }

    /// Removes a list that is gone for this user (left, not found, read-only) from the lists, the
    /// cache and the open detail, and records the removal for this session. Callers check the
    /// generation first.
    // Covered by the manual spans of its public callers.
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
    // Covered by the manual spans of its public callers (addMember, removeMember).
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
        } catch {
            await dropListIfGone(error, id: listId, generation: gen)
            if record(error, generation: gen, operation: "refresh list after member change") == nil {
                throw CancellationError()
            }
        }
    }

    /// For a list removed after the load started (`start`): drops any cached or open copy,
    /// records notFound through the normal error path, marks the list gone and returns true.
    /// Returns false when the list was not removed after the load started.
    // Covered by the manual span of its public caller (loadListDetail).
    private func reportGuarded(_ id: String, since start: Int, generation gen: Int) async -> Bool {
        guard isRemoved(id, since: start) else { return false }
        goneListId = id
        if currentListDetail?.id == id {
            currentListDetail = nil
        }
        _ = record(ListError.notFound, generation: gen, operation: "load list details")
        await dataStore.removeList(id: id)
        return true
    }

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Covered by the manual spans of its public callers (the load, create, update and delete functions).
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

    /// Records the error of a failed call and returns it. Returns nil for cancellation and for a
    /// call that belongs to a session that has ended: neither is shown to the user.
    private func record(_ error: any Error, generation gen: Int, operation: String) -> ListError? {
        if error is CancellationError || gen != generation { return nil }
        let listError = (error as? ListError) ?? .server
        // Only the operation name is logged: no ids, names, emails or server text.
        LogError("\(operation) failed", category: .business)
        self.error = listError
        return listError
    }

    /// The error a throwing operation rethrows: the typed ListError, or CancellationError when the
    /// call was cancelled or its session ended.
    private func failure(_ error: any Error, generation gen: Int, operation: String) -> any Error {
        if let listError = record(error, generation: gen, operation: operation) {
            return listError
        }
        return CancellationError()
    }
}

// MARK: - SessionClearable

extension ListService: SessionClearable {}
