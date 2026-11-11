//
//  ItemServiceHarness.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: shared construction and helpers for the ItemService tests.
//
//  Teardown is driven the way the app does it: the service is registered with a SessionManager
//  and `SessionManager.teardown(reason:)` runs (which calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct ItemServiceSUT {
    let service: ItemService
    let repo: GatedItemRepository
    let store: ItemDataStore
    let manager: SessionManager
}

func makeItemServiceSUT(honorsCancellation: Bool = false) async -> ItemServiceSUT {
    let repo = GatedItemRepository()
    repo.gate.honorsCancellation = honorsCancellation
    let store = ItemDataStore()
    let service = ItemService(repository: repo, dataStore: store)
    let manager = SessionManager(initialClearables: [])
    await manager.register(service)
    return ItemServiceSUT(service: service, repo: repo, store: store, manager: manager)
}

/// Starts the body in a task and hands back the error it threw (nil when it threw nothing).
func startOutcome(_ body: @escaping @MainActor () async throws -> Void) -> Task<(any Error)?, Never> {
    Task { @MainActor in
        do {
            try await body()
            return nil
        } catch {
            return error
        }
    }
}

/// Cheap constructors for service tests (ids are fake; the list is always "list-1" unless said).
enum ItemServiceFix {
    static func item(_ id: String, listId: String = "list-1", name: String? = nil) -> ListItem {
        ItemFixtures.item(id: id, listId: listId, name: name ?? "Name of \(id)")
    }

    static func input(name: String = "New Item") -> CreateItemInput {
        CreateItemInput(
            name: name, description: "A fake description", url: nil, imageUrl: nil,
            expectedUnitPrice: nil, quantityRequested: 1, priority: 5
        )
    }
}

/// The three mutations, so cross-cutting tests run once per operation.
enum ItemMutationOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case create, update, delete

    var testDescription: String {
        switch self {
        case .create: "createItem"
        case .update: "updateItem"
        case .delete: "deleteItem"
        }
    }

    /// The call that is held when this operation is scripted with `held: true`.
    var heldCall: GatedItemRepository.Call {
        switch self {
        case .create: .createItem("list-1")
        case .update: .updateItem("item-1")
        case .delete: .deleteItem("item-1")
        }
    }

    @MainActor
    func enqueueSuccess(on repo: GatedItemRepository, held: Bool = false) {
        switch self {
        case .create: repo.enqueueCreateItem(.success(ItemServiceFix.item("item-new")), held: held)
        case .update: repo.enqueueUpdateItem(.success(ItemServiceFix.item("item-1", name: "Updated")), held: held)
        case .delete: repo.enqueueDeleteItem(.success(()), held: held)
        }
    }

    @MainActor
    func enqueueFailure(_ error: any Error, on repo: GatedItemRepository, held: Bool = false) {
        switch self {
        case .create: repo.enqueueCreateItem(.failure(error), held: held)
        case .update: repo.enqueueUpdateItem(.failure(error), held: held)
        case .delete: repo.enqueueDeleteItem(.failure(error), held: held)
        }
    }

    @MainActor
    func run(_ service: ItemService) async throws {
        switch self {
        case .create: _ = try await service.createItem(listId: "list-1", ItemServiceFix.input())
        case .update: _ = try await service.updateItem(id: "item-1", UpdateItemInput(name: "Updated"))
        case .delete: try await service.deleteItem(id: "item-1", listId: "list-1")
        }
    }
}
