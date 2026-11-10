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
    private nonisolated let dataStore: ListDataStore

    // MARK: - Published State
    private(set) var lists: [GiftList] = []
    private(set) var currentListDetail: ListDetail?
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: ListError?
    private(set) var lastUpdated: Date?

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every operation captures it before its
    /// first await and drops its result (and any error) if it changed, so a sign-out or a user
    /// switch never leaves the previous user's data in the service or the cache.
    private var generation = 0

    /// Cancel handles of the repository calls that are in flight, keyed by call.
    private var inFlight: [UUID: () -> Void] = [:]

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
    init(repository: any ListRepository, dataStore: ListDataStore) {
        self.repository = repository
        self.dataStore = dataStore
    }

    // MARK: - Public Methods

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No list data goes into the span.
    func loadLists() async {
        guard !isLoading else { return }
        let span = SentrySDK.startTransaction(name: "service.lists.loadLists", operation: "service.lists.loadLists")
        defer { span.finish() }

        let gen = generation
        isLoading = true
        defer { if gen == generation { isLoading = false } }
        error = nil

        do {
            // Check cache
            let cached = await dataStore.getLists()
            guard gen == generation else { return }
            if !cached.isEmpty {
                lists = visibleLists(cached)

                // Background refresh
                if await dataStore.shouldRefresh(), gen == generation {
                    await refreshLists()
                }
                return
            }

            // Fetch from repository
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() })
            guard gen == generation else { return }

            // Update cache
            await dataStore.setLists(fetched)
            guard gen == generation else { return }
            lists = fetched
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
        isRefreshing = true
        defer { if gen == generation { isRefreshing = false } }
        error = nil

        do {
            let repository = self.repository
            let fetched = visibleLists(try await perform { try await repository.fetchLists() })
            guard gen == generation else { return }
            await dataStore.setLists(fetched)
            guard gen == generation else { return }
            lists = fetched
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
        isLoading = true
        defer { if gen == generation { isLoading = false } }
        error = nil
        currentListDetail = nil

        do {
            if let cached = await dataStore.getListDetail(id: id) {
                guard gen == generation else { return }
                currentListDetail = cached
                return
            }
            guard gen == generation else { return }

            let repository = self.repository
            let detail = try await perform { try await repository.fetchListDetail(id: id) }
            guard gen == generation else { return }

            await dataStore.setListDetail(detail)
            guard gen == generation else { return }
            currentListDetail = detail

            LogInfo("Loaded list detail", category: .business)
        } catch {
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
        isLoading = true
        defer { if gen == generation { isLoading = false } }
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
        isLoading = true
        defer { if gen == generation { isLoading = false } }
        error = nil

        do {
            let repository = self.repository
            let updated = try await perform { try await repository.updateList(id: id, input) }
            try ensureCurrent(gen)

            // The returned detail carries fresh flags: use it, do not refetch.
            let summary = updated.asGiftList()
            await dataStore.setListDetail(updated)
            try ensureCurrent(gen)

            if let index = lists.firstIndex(where: { $0.id == summary.id }) {
                lists[index] = summary
            }
            if currentListDetail?.id == updated.id {
                currentListDetail = updated
            }

            LogInfo("Updated list", category: .business)
        } catch {
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
        isLoading = true
        defer { if gen == generation { isLoading = false } }
        error = nil

        do {
            let repository = self.repository
            try await perform { try await repository.deleteList(id: id) }
            try ensureCurrent(gen)

            // The server archives the list; remove it locally without refetching. Later
            // refreshes drop it because it comes back ARCHIVED.
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
        isLoading = false
        isRefreshing = false
        lastUpdated = nil
        currentFilter = .all

        // The service clears the cache itself, so it does not depend on the store also being
        // registered with the session manager.
        await dataStore.clear()
    }

    /// ARCHIVED lists are hidden everywhere; DRAFT behaves like ACTIVE.
    private func visibleLists(_ fetched: [GiftList]) -> [GiftList] {
        fetched.filter { $0.status != .archived }
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
