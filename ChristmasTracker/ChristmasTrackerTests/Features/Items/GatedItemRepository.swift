//
//  GatedItemRepository.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: a scripted, optionally gated ItemRepository fake for the ItemService tests.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step. A step marked `held`
//  suspends the call on a gate until the test releases it, and announces itself through
//  `gate.nextHeldCall()` (a continuation handshake, see HeldCallGate), so a test can wait until
//  the service has really entered the repository, act (for example tear the session down), and
//  then release.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its
//  task is cancelled; otherwise it keeps waiting until released (the stale-result case).
//
//  A @MainActor final class, never an actor, because it conforms to the nonisolated
//  ItemRepository protocol the same way GatedListRepository does.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class GatedItemRepository: ItemRepository {

    enum Call: Equatable, Sendable {
        case fetchItems(String)
        case fetchItemDetail(String)
        case createItem(String)
        case updateItem(String)
        case deleteItem(String)
    }

    struct Step<Value: Sendable>: Sendable {
        var outcome: Result<Value, any Error>
        var held: Bool
    }

    // MARK: Handshake (shared implementation)

    let gate = HeldCallGate<Call>()

    // MARK: Recorded calls

    private(set) var fetchItemsCount = 0
    private(set) var fetchItemDetailCount = 0
    private(set) var createItemCount = 0
    private(set) var updateItemCount = 0
    private(set) var deleteItemCount = 0
    private(set) var fetchedListIds: [String] = []
    private(set) var detailIds: [String] = []
    private(set) var createdInputs: [CreateItemInput] = []
    private(set) var createdListIds: [String] = []
    private(set) var updatedInputs: [UpdateItemInput] = []
    private(set) var updatedIds: [String] = []
    private(set) var deletedIds: [String] = []

    // MARK: Scripts

    private var listSteps: [Step<[ListItem]>] = []
    private var detailSteps: [Step<ListItem>] = []
    private var createSteps: [Step<ListItem>] = []
    private var updateSteps: [Step<ListItem>] = []
    private var deleteSteps: [Step<Void>] = []

    func enqueueFetchItems(_ outcome: Result<[ListItem], any Error>, held: Bool = false) {
        listSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueFetchItemDetail(_ outcome: Result<ListItem, any Error>, held: Bool = false) {
        detailSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueCreateItem(_ outcome: Result<ListItem, any Error>, held: Bool = false) {
        createSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueUpdateItem(_ outcome: Result<ListItem, any Error>, held: Bool = false) {
        updateSteps.append(Step(outcome: outcome, held: held))
    }

    func enqueueDeleteItem(_ outcome: Result<Void, any Error>, held: Bool = false) {
        deleteSteps.append(Step(outcome: outcome, held: held))
    }

    // MARK: ItemRepository

    @MainActor func fetchItems(listId: String) async throws -> [ListItem] {
        fetchItemsCount += 1
        fetchedListIds.append(listId)
        let step = listSteps.isEmpty ? Step(outcome: .success([ListItem]()), held: false) : listSteps.removeFirst()
        if step.held { try await gate.hold(.fetchItems(listId)) }
        return try step.outcome.get()
    }

    @MainActor func fetchItemDetail(id: String) async throws -> ListItem {
        fetchItemDetailCount += 1
        detailIds.append(id)
        let step = detailSteps.isEmpty
            ? Step<ListItem>(outcome: .failure(ItemError.server), held: false)
            : detailSteps.removeFirst()
        if step.held { try await gate.hold(.fetchItemDetail(id)) }
        return try step.outcome.get()
    }

    @MainActor func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem {
        createItemCount += 1
        createdInputs.append(input)
        createdListIds.append(listId)
        let step = createSteps.isEmpty
            ? Step<ListItem>(outcome: .failure(ItemError.server), held: false)
            : createSteps.removeFirst()
        if step.held { try await gate.hold(.createItem(listId)) }
        return try step.outcome.get()
    }

    @MainActor func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem {
        updateItemCount += 1
        updatedInputs.append(input)
        updatedIds.append(id)
        let step = updateSteps.isEmpty
            ? Step<ListItem>(outcome: .failure(ItemError.server), held: false)
            : updateSteps.removeFirst()
        if step.held { try await gate.hold(.updateItem(id)) }
        return try step.outcome.get()
    }

    @MainActor func deleteItem(id: String) async throws {
        deleteItemCount += 1
        deletedIds.append(id)
        let step = deleteSteps.isEmpty
            ? Step<Void>(outcome: .failure(ItemError.server), held: false)
            : deleteSteps.removeFirst()
        if step.held { try await gate.hold(.deleteItem(id)) }
        try step.outcome.get()
    }
}
