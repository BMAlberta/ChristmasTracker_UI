//
//  ItemServiceMutationTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: create, update and delete through ItemService (UI rule 2).
//
//  Rules under test (Gate 1 addendum):
//   - a mutation THROWS the typed ItemError (the initiating view holds it) and never touches
//     `loadError`, `isLoadingItems` or `isLoadingDetail`;
//   - create appends the returned item to `items` when `currentListId` matches, and caches it;
//     update replaces the matching entry in `items`, `currentItem` and the cache; delete removes
//     the item from `items`, `currentItem` and the cache on success;
//   - 404 on update or delete means gone: removed from items / currentItem / cache, `goneItemId`
//     set, `.notFound` thrown; `goneItemId` is cleared only by `clearForSession()`;
//   - `isMutating` is a counter: true while any mutation runs, across overlapping mutations.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService mutations", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceMutationTests {

    private func item(_ id: String, listId: String = "list-1", name: String? = nil) -> ListItem {
        ItemServiceFix.item(id, listId: listId, name: name)
    }

    /// A service that has loaded list-1 with item-1 and item-2 (and the detail of item-1 open).
    private func makeLoadedSUT() async -> ItemServiceSUT {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")))
        await sut.service.loadItemDetail(id: "item-1")
        return sut
    }

    // MARK: - Create

    @Test("createItem returns the created item, appends it to the current list and caches it")
    func createSuccess() async throws {
        let sut = await makeLoadedSUT()
        let created = item("item-new", name: "Brand New")
        sut.repo.enqueueCreateItem(.success(created))

        let returned = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input(name: "Brand New"))

        #expect(returned == created)
        #expect(sut.service.items == [item("item-1"), item("item-2"), created])
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached.contains(created))
        #expect(sut.repo.createdInputs == [ItemServiceFix.input(name: "Brand New")])
        #expect(sut.repo.createdListIds == ["list-1"])
        #expect(sut.service.isMutating == false)
    }

    @Test("createItem for a list that is not the current one does not touch items")
    func createForAnotherList() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueCreateItem(.success(item("item-x", listId: "list-other")))

        _ = try await sut.service.createItem(listId: "list-other", ItemServiceFix.input())

        #expect(sut.service.items == [item("item-1"), item("item-2")])
    }

    @Test("createItem failure throws the exact typed error and changes nothing", arguments: [
        ItemError.forbidden, .invalidPrice, .validation(message: "Name is too long"), .network, .server,
        .rateLimited(retryAfter: 4), .unauthorized, .invalidResponse
    ])
    func createFailure(error: ItemError) async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueCreateItem(.failure(error))

        await #expect(throws: error) {
            _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input())
        }

        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.loadError == nil, "a mutation error is never published")
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneItemId == nil)
    }

    // MARK: - Update

    @Test("updateItem returns the updated item and replaces it in items, currentItem and the cache")
    func updateSuccess() async throws {
        let sut = await makeLoadedSUT()
        let updated = item("item-1", name: "Updated")
        sut.repo.enqueueUpdateItem(.success(updated))

        let returned = try await sut.service.updateItem(id: "item-1", UpdateItemInput(name: "Updated"))

        #expect(returned == updated)
        #expect(sut.service.items == [updated, item("item-2")])
        #expect(sut.service.currentItem == updated)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [updated, item("item-2")])
        #expect(sut.repo.updatedIds == ["item-1"])
        #expect(sut.repo.updatedInputs == [UpdateItemInput(name: "Updated")])
    }

    @Test("updateItem of an item that is not the open detail leaves currentItem alone")
    func updateOtherItemKeepsCurrentItem() async throws {
        let sut = await makeLoadedSUT()
        let updated = item("item-2", name: "Updated Two")
        sut.repo.enqueueUpdateItem(.success(updated))

        _ = try await sut.service.updateItem(id: "item-2", UpdateItemInput(name: "Updated Two"))

        #expect(sut.service.currentItem == item("item-1"))
        #expect(sut.service.items == [item("item-1"), updated])
    }

    @Test("updateItem failure throws the exact typed error and changes nothing", arguments: [
        ItemError.forbidden, .invalidPrice, .validation(message: "Description is required"), .network, .server,
        .rateLimited(retryAfter: 1)
    ])
    func updateFailure(error: ItemError) async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueUpdateItem(.failure(error))

        await #expect(throws: error) {
            _ = try await sut.service.updateItem(id: "item-1", UpdateItemInput(name: "Updated"))
        }

        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.currentItem == item("item-1"))
        #expect(sut.service.loadError == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneItemId == nil)
    }

    @Test("updateItem 404 means gone: dropped everywhere, goneItemId set, notFound thrown, loadError untouched")
    func updateNotFound() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueUpdateItem(.failure(ItemError.notFound))

        await #expect(throws: ItemError.notFound) {
            _ = try await sut.service.updateItem(id: "item-1", UpdateItemInput(name: "Updated"))
        }

        #expect(sut.service.items == [item("item-2")])
        #expect(sut.service.currentItem == nil)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-2")])
        #expect(sut.service.goneItemId == "item-1")
        #expect(sut.service.loadError == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Delete

    @Test("deleteItem removes the item from items, currentItem and the cache")
    func deleteSuccess() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteItem(.success(()))

        try await sut.service.deleteItem(id: "item-1", listId: "list-1")

        #expect(sut.service.items == [item("item-2")])
        #expect(sut.service.currentItem == nil)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-2")])
        #expect(sut.repo.deletedIds == ["item-1"])
        #expect(sut.service.goneItemId == nil, "a delete the user asked for is not a vanished item")
        #expect(sut.service.isMutating == false)
    }

    @Test("deleteItem of an item that is not the open detail leaves currentItem alone")
    func deleteOtherItemKeepsCurrentItem() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteItem(.success(()))

        try await sut.service.deleteItem(id: "item-2", listId: "list-1")

        #expect(sut.service.currentItem == item("item-1"))
        #expect(sut.service.items == [item("item-1")])
    }

    @Test("deleteItem failure throws the exact typed error and changes nothing", arguments: [
        ItemError.cannotDeleteWithPurchases, .forbidden, .network, .server, .rateLimited(retryAfter: 2),
        .validation(message: "Cannot process this request")
    ])
    func deleteFailure(error: ItemError) async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteItem(.failure(error))

        await #expect(throws: error) {
            try await sut.service.deleteItem(id: "item-1", listId: "list-1")
        }

        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.currentItem == item("item-1"))
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-1"), item("item-2")])
        #expect(sut.service.loadError == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneItemId == nil)
    }

    @Test("deleteItem 404 means gone: dropped everywhere, goneItemId set, notFound thrown")
    func deleteNotFound() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteItem(.failure(ItemError.notFound))

        await #expect(throws: ItemError.notFound) {
            try await sut.service.deleteItem(id: "item-1", listId: "list-1")
        }

        #expect(sut.service.items == [item("item-2")])
        #expect(sut.service.currentItem == nil)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-2")])
        #expect(sut.service.goneItemId == "item-1")
        #expect(sut.service.loadError == nil)
    }

    // MARK: - A mutation never touches the load state

    @Test("a mutation error never changes the loadError set by an earlier load", arguments: ItemMutationOp.allCases)
    func mutationErrorLeavesLoadErrorAlone(op: ItemMutationOp) async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.loadError == .network, "precondition")
        op.enqueueFailure(ItemError.server, on: sut.repo)

        await #expect(throws: ItemError.server) { try await op.run(sut.service) }

        #expect(sut.service.loadError == .network, "the load error of the other screen is not overwritten")
    }

    @Test("a successful mutation does not clear a loadError either", arguments: ItemMutationOp.allCases)
    func mutationSuccessLeavesLoadErrorAlone(op: ItemMutationOp) async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        op.enqueueSuccess(on: sut.repo)

        try await op.run(sut.service)

        #expect(sut.service.loadError == .network)
    }

    @Test("a mutation moves only isMutating, never the load flags", arguments: ItemMutationOp.allCases)
    func mutationOnlyMovesIsMutating(op: ItemMutationOp) async throws {
        let sut = await makeLoadedSUT()
        op.enqueueSuccess(on: sut.repo, held: true)
        let task = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isMutating == true)
        #expect(sut.service.isLoadingItems == false)
        #expect(sut.service.isLoadingDetail == false)

        sut.repo.gate.releaseAll()
        let error = await task.value
        #expect(error == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is false again after a failed mutation", arguments: ItemMutationOp.allCases)
    func isMutatingResetsAfterFailure(op: ItemMutationOp) async throws {
        let sut = await makeLoadedSUT()
        op.enqueueFailure(ItemError.network, on: sut.repo, held: true)
        let task = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true)

        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect((error as? ItemError) == .network)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Overlapping mutations

    @Test("isMutating stays true across overlapping mutations until the last one finishes", arguments: [false, true])
    func overlappingMutations(releaseFirstFirst: Bool) async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueUpdateItem(.success(item("item-1", name: "Updated")), held: true)
        sut.repo.enqueueDeleteItem(.success(()), held: true)
        let first = startOutcome { _ = try await sut.service.updateItem(id: "item-1", UpdateItemInput(name: "Updated")) }
        await sut.repo.gate.nextHeldCall()
        let second = startOutcome { try await sut.service.deleteItem(id: "item-2", listId: "list-1") }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true)

        sut.repo.gate.release(at: releaseFirstFirst ? 0 : 1)
        if releaseFirstFirst { _ = await first.value } else { _ = await second.value }
        #expect(sut.service.isMutating == true, "one mutation is still running")

        sut.repo.gate.releaseAll()
        _ = await first.value
        _ = await second.value
        #expect(sut.service.isMutating == false)
    }

    @Test("with one overlapping mutation failing and the other succeeding isMutating still ends false")
    func overlappingMixedOutcomes() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueUpdateItem(.failure(ItemError.server), held: true)
        sut.repo.enqueueDeleteItem(.success(()), held: true)
        let first = startOutcome { _ = try await sut.service.updateItem(id: "item-1", UpdateItemInput(name: "Updated")) }
        await sut.repo.gate.nextHeldCall()
        let second = startOutcome { try await sut.service.deleteItem(id: "item-2", listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        sut.repo.gate.release(at: 0)
        let firstError = await first.value
        #expect((firstError as? ItemError) == .server)
        #expect(sut.service.isMutating == true)
        sut.repo.gate.release(at: 1)
        let secondError = await second.value

        #expect(secondError == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.items == [item("item-1")])
    }

    // MARK: - goneItemId lifecycle

    @Test("goneItemId is cleared only by clearForSession, not by later loads, clearLoadError or clearItemDetail")
    func goneItemIdLifecycle() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueDeleteItem(.failure(ItemError.notFound))
        await #expect(throws: ItemError.notFound) { try await sut.service.deleteItem(id: "item-1", listId: "list-1") }
        #expect(sut.service.goneItemId == "item-1", "precondition")

        sut.repo.enqueueFetchItems(.success([item("item-2")]))
        await sut.service.refreshItems()
        sut.service.clearLoadError()
        sut.service.clearItemDetail()
        sut.service.clearItems()
        #expect(sut.service.goneItemId == "item-1")

        try await sut.service.clearForSession()
        #expect(sut.service.goneItemId == nil)
    }

    @Test("a 404 detail load of a second item sets goneItemId to that item")
    func goneItemIdFollowsTheLastNotFound() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.notFound))

        await sut.service.loadItemDetail(id: "item-2")

        #expect(sut.service.goneItemId == "item-2")
    }
}
