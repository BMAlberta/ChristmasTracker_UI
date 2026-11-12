//
//  ItemService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation
import Sentry
import SwiftUI

/// Session-safe item service. Mutations throw their typed `ItemError` to the initiating view and
/// publish nothing. Load failures are kept per screen: `listLoadError` is set only by the list
/// loads and `detailLoadError` only by the detail load, so one screen never clears or shows the
/// other's error. No item id, name, url, price or raw error value is ever logged.
@MainActor
@Observable
final class ItemService {

    // MARK: - Dependencies

    private nonisolated let itemRepository: any ItemRepository
    private nonisolated let dataStore: ItemDataStore

    // MARK: - Published State

    private(set) var items: [ListItem] = []
    private(set) var currentListId: String?
    private(set) var currentItem: ListItem?
    /// True only while loadItems or refreshItems runs.
    private(set) var isLoadingItems: Bool = false
    /// True only while loadItemDetail runs.
    private(set) var isLoadingDetail: Bool = false
    /// True while any create, update or delete runs.
    private(set) var isMutating: Bool = false
    /// Set only by a failed loadItems or refreshItems; cleared at the start of each, by
    /// `clearListLoadError()` and at session end.
    private(set) var listLoadError: ItemError?
    /// Set only by a failed loadItemDetail; cleared at the start of each, by
    /// `clearDetailLoadError()` and at session end.
    private(set) var detailLoadError: ItemError?
    /// The id of the item the server reported gone. Only the session reset clears it.
    private(set) var goneItemId: String?

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every operation captures it before its
    /// first await and drops its result (and any error) if it changed.
    private var generation = 0

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    /// Identifies the newest list load or refresh (see `beginListLoad`).
    private var listLoadToken = 0

    /// Identifies the newest item detail load.
    private var detailLoadToken = 0

    /// Number of mutations in flight; isMutating is true while it is above zero.
    private var mutationCount = 0

    // MARK: - Initialization

    init(repository: any ItemRepository, dataStore: ItemDataStore) {
        self.itemRepository = repository
        self.dataStore = dataStore
    }

    // MARK: - Loads

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No item data goes into the span.
    func loadItems(listId: String) async {
        let span = SentrySDK.startTransaction(name: "service.items.loadItems", operation: "service.items.loadItems")
        defer { span.finish() }

        let gen = generation
        let token = beginListLoad()
        if currentListId != listId {
            items = []
        }
        currentListId = listId
        listLoadError = nil
        isLoadingItems = true
        defer { endListLoad(token: token, generation: gen) }

        do {
            let cached = await dataStore.getItems(listId: listId)
            try ensureCurrent(gen)
            if !cached.isEmpty {
                if currentListId == listId { items = cached }
                if await dataStore.shouldRefresh(listId: listId), gen == generation {
                    try await fetchAndStore(listId: listId, generation: gen)
                }
                return
            }
            try await fetchAndStore(listId: listId, generation: gen)
        } catch {
            recordLoadError(error, generation: gen, token: token, operation: "load items")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    func refreshItems() async {
        guard let listId = currentListId else { return }
        let span = SentrySDK.startTransaction(
            name: "service.items.refreshItems",
            operation: "service.items.refreshItems"
        )
        defer { span.finish() }

        let gen = generation
        let token = beginListLoad()
        listLoadError = nil
        isLoadingItems = true
        defer { endListLoad(token: token, generation: gen) }

        do {
            try await fetchAndStore(listId: listId, generation: gen)
        } catch {
            recordLoadError(error, generation: gen, token: token, operation: "refresh items")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    func loadItemDetail(id: String) async {
        let span = SentrySDK.startTransaction(
            name: "service.items.loadItemDetail",
            operation: "service.items.loadItemDetail"
        )
        defer { span.finish() }

        let gen = generation
        detailLoadToken += 1
        let token = detailLoadToken
        detailLoadError = nil
        isLoadingDetail = true
        defer { if gen == generation, token == detailLoadToken { isLoadingDetail = false } }
        // Another item's detail is never shown while this one loads.
        if currentItem?.id != id {
            currentItem = nil
        }

        do {
            let repository = self.itemRepository
            let detail = try await perform { try await repository.fetchItemDetail(id: id) }
            try ensureCurrent(gen)
            // A newer detail load owns currentItem now.
            guard token == detailLoadToken else { return }
            currentItem = detail
        } catch {
            await dropIfGone(error, id: id, generation: gen)
            recordDetailLoadError(error, generation: gen, token: token)
        }
    }

    func clearListLoadError() {
        listLoadError = nil
    }

    func clearDetailLoadError() {
        detailLoadError = nil
    }

    func clearItemDetail() {
        currentItem = nil
    }

    func clearItems() {
        items = []
        currentListId = nil
    }

    // MARK: - Mutations

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    @discardableResult
    func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem {
        let span = SentrySDK.startTransaction(
            name: "service.items.createItem",
            operation: "service.items.createItem"
        )
        defer { span.finish() }

        let gen = generation
        beginMutation()
        defer { endMutation(generation: gen) }

        do {
            let repository = self.itemRepository
            let created = try await perform { try await repository.createItem(listId: listId, input) }
            try ensureCurrent(gen)
            await dataStore.addItem(created)
            try ensureCurrent(gen)
            if currentListId == listId, !items.contains(where: { $0.id == created.id }) {
                items.append(created)
            }
            LogInfo("Created item", category: .business)
            return created
        } catch {
            await dropIfGone(error, id: nil, generation: gen)
            throw failure(error, generation: gen, operation: "create item")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    @discardableResult
    func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem {
        let span = SentrySDK.startTransaction(
            name: "service.items.updateItem",
            operation: "service.items.updateItem"
        )
        defer { span.finish() }

        let gen = generation
        beginMutation()
        defer { endMutation(generation: gen) }

        do {
            let repository = self.itemRepository
            let updated = try await perform { try await repository.updateItem(id: id, input) }
            try ensureCurrent(gen)
            await dataStore.updateItem(updated)
            try ensureCurrent(gen)
            if let index = items.firstIndex(where: { $0.id == updated.id }) {
                items[index] = updated
            }
            if currentItem?.id == updated.id {
                currentItem = updated
            }
            LogInfo("Updated item", category: .business)
            return updated
        } catch {
            await dropIfGone(error, id: id, generation: gen)
            throw failure(error, generation: gen, operation: "update item")
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    func deleteItem(id: String, listId: String) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.items.deleteItem",
            operation: "service.items.deleteItem"
        )
        defer { span.finish() }

        let gen = generation
        beginMutation()
        defer { endMutation(generation: gen) }

        do {
            let repository = self.itemRepository
            try await perform { try await repository.deleteItem(id: id) }
            try ensureCurrent(gen)
            await dataStore.removeItem(id: id, listId: listId)
            try ensureCurrent(gen)
            items.removeAll { $0.id == id }
            if currentItem?.id == id {
                currentItem = nil
            }
            LogInfo("Deleted item", category: .business)
        } catch {
            await dropIfGone(error, id: id, generation: gen)
            throw failure(error, generation: gen, operation: "delete item")
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight work, bumps the generation so late results
    /// are discarded, and empties the published state and the cache.
    // Actor-isolated (@MainActor): manual SentrySDK span, see loadItems.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.items.clearForSession",
            operation: "service.items.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        items = []
        currentItem = nil
        currentListId = nil
        listLoadError = nil
        detailLoadError = nil
        goneItemId = nil
        isLoadingItems = false
        isLoadingDetail = false
        isMutating = false
        mutationCount = 0

        await dataStore.clearAll()
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

    /// Fetches a list's items and writes the cache and (for the current list) `items`.
    // Covered by the manual spans of its public callers (loadItems, refreshItems).
    private func fetchAndStore(listId: String, generation gen: Int) async throws {
        let repository = self.itemRepository
        let fetched = try await perform { try await repository.fetchItems(listId: listId) }
        try ensureCurrent(gen)
        await dataStore.setItems(fetched, listId: listId)
        try ensureCurrent(gen)
        if currentListId == listId {
            items = fetched
        }
        LogInfo("Loaded \(fetched.count) items", category: .business)
    }

    /// A 404 means the item is gone: removes it from the items, the open detail and the cache and
    /// marks it gone. Does nothing for another error, a nil id, or after the session ended.
    // Covered by the manual spans of its public callers.
    private func dropIfGone(_ error: any Error, id: String?, generation gen: Int) async {
        guard gen == generation, let id, (error as? ItemError) == .notFound else { return }
        goneItemId = id
        items.removeAll { $0.id == id }
        if currentItem?.id == id {
            currentItem = nil
        }
        await dataStore.removeItem(id: id)
    }

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Covered by the manual spans of its public callers.
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

    /// Starts a list load or refresh and returns its token. Only the newest list load may set
    /// `listLoadError` or clear `isLoadingItems`, so a load of list A that ends after list B started
    /// (same session) never touches B's state.
    private func beginListLoad() -> Int {
        listLoadToken += 1
        return listLoadToken
    }

    private func endListLoad(token: Int, generation gen: Int) {
        if gen == generation, token == listLoadToken { isLoadingItems = false }
    }

    /// Records a list load failure. Nothing for cancellation, a session that has ended, or a load
    /// that a newer list load has replaced.
    private func recordLoadError(_ error: any Error, generation gen: Int, token: Int, operation: String) {
        if error is CancellationError || gen != generation { return }
        if token != listLoadToken { return }
        // Only the operation name is logged: no ids, names or server text.
        LogError("\(operation) failed", category: .business)
        listLoadError = (error as? ItemError) ?? .server
    }

    /// Records a detail load failure. Nothing for cancellation, a session that has ended, or a
    /// load that a newer detail load has replaced.
    private func recordDetailLoadError(_ error: any Error, generation gen: Int, token: Int) {
        if error is CancellationError || gen != generation { return }
        if token != detailLoadToken { return }
        LogError("load item detail failed", category: .business)
        detailLoadError = (error as? ItemError) ?? .server
    }

    /// The error a mutation rethrows: the typed ItemError, or CancellationError when the call was
    /// cancelled or its session ended. Never stored in the service.
    private func failure(_ error: any Error, generation gen: Int, operation: String) -> any Error {
        if error is CancellationError || gen != generation { return CancellationError() }
        LogError("\(operation) failed", category: .business)
        return (error as? ItemError) ?? ItemError.server
    }
}

// MARK: - SessionClearable

extension ItemService: SessionClearable {}
