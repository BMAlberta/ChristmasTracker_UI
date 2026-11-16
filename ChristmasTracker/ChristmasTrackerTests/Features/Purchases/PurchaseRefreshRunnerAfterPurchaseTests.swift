//
//  PurchaseRefreshRunnerAfterPurchaseTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O2: PurchaseRefreshRunner.runAfterPurchase(itemId:listId:) runs the plan
//  PurchaseRefreshPlan.steps(itemId:listId:currentItemsListId: itemService.currentListId) through run(_:).
//
//   - list held by the item service: item detail, items refresh, list detail, spending invalidation, in order;
//   - another list or none held: the items step loads the item's list instead of refreshing;
//   - a failed step never stops the next one;
//   - the spending caches are invalidated last, exactly once.
//
//  REAL ItemService and ListService over gated fake repositories, as in PurchaseRefreshRunnerTests.
//
//  Covers PurchaseRefreshRunner.runAfterPurchase.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase refresh runner after-purchase Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseRefreshRunnerAfterPurchaseTests {

    private struct SUT {
        let runner: PurchaseRefreshRunner
        let invalidator: RecordingSpendingInvalidator
        let itemService: ItemService
        let itemRepo: GatedItemRepository
        let listRepo: GatedListRepository
    }

    private func makeSUT() -> SUT {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let itemService = ItemService(repository: itemRepo, dataStore: ItemDataStore())
        let listService = ListService(repository: listRepo, dataStore: ListDataStore())
        let invalidator = RecordingSpendingInvalidator()
        let runner = PurchaseRefreshRunner(
            itemService: itemService, listService: listService, spendingCaches: invalidator
        )
        return SUT(
            runner: runner,
            invalidator: invalidator,
            itemService: itemService,
            itemRepo: itemRepo,
            listRepo: listRepo
        )
    }

    private let item = ItemServiceFix.item("item-1")

    private func preload(_ sut: SUT, listId: String) async {
        sut.itemRepo.enqueueFetchItems(.success([item]))
        await sut.itemService.loadItems(listId: listId)
    }

    private func scriptSuccess(_ sut: SUT) {
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
    }

    // MARK: Order with the list held

    @Test("With the list held the steps run: item detail, items refresh, list detail, then the invalidation")
    func runsThePlanInOrderWhenListHeld() async {
        let sut = makeSUT()
        await preload(sut, listId: "list-1")
        sut.itemRepo.enqueueFetchItemDetail(.success(item), held: true)
        sut.itemRepo.enqueueFetchItems(.success([item]), held: true)
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()), held: true)
        var marksAtInvalidation = (detail: -1, items: -1, list: -1)
        sut.invalidator.onMark = {
            marksAtInvalidation = (
                sut.itemRepo.fetchItemDetailCount, sut.itemRepo.fetchItemsCount, sut.listRepo.fetchListDetailCount
            )
        }

        let task = Task { @MainActor in await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1") }

        let first = await sut.itemRepo.gate.nextHeldCall()
        #expect(first == .fetchItemDetail("item-1"))
        #expect(sut.itemRepo.fetchItemsCount == 1, "the items step has not started (only the preload)")
        #expect(sut.listRepo.fetchListDetailCount == 0)
        sut.itemRepo.gate.releaseNext()

        let second = await sut.itemRepo.gate.nextHeldCall()
        #expect(second == .fetchItems("list-1"))
        #expect(sut.listRepo.fetchListDetailCount == 0)
        #expect(sut.invalidator.markCount == 0)
        sut.itemRepo.gate.releaseNext()

        let third = await sut.listRepo.nextHeldCall()
        #expect(third == .fetchListDetail("list-1"))
        #expect(sut.invalidator.markCount == 0, "the invalidation comes last")
        sut.listRepo.releaseNext()

        await task.value
        #expect(sut.invalidator.markCount == 1)
        #expect(marksAtInvalidation.detail == 1)
        #expect(marksAtInvalidation.items == 2, "the preload and the refresh")
        #expect(marksAtInvalidation.list == 1)
    }

    // MARK: Load instead of refresh

    @Test("With no list held the items step loads the item's list")
    func loadsWhenNoListHeld() async {
        let sut = makeSUT()
        scriptSuccess(sut)

        await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1")

        #expect(sut.itemRepo.fetchedListIds == ["list-1"])
        #expect(sut.itemService.currentListId == "list-1")
        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.invalidator.markCount == 1)
    }

    @Test("With another list held the items step loads the item's list, not the held one")
    func loadsWhenAnotherListHeld() async {
        let sut = makeSUT()
        await preload(sut, listId: "list-9")
        scriptSuccess(sut)

        await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1")

        #expect(sut.itemRepo.fetchedListIds == ["list-9", "list-1"])
        #expect(sut.itemService.currentListId == "list-1")
        #expect(sut.invalidator.markCount == 1)
    }

    @Test("With the same list held the items step refreshes that list in place")
    func refreshesWhenSameListHeld() async {
        let sut = makeSUT()
        await preload(sut, listId: "list-1")
        scriptSuccess(sut)

        await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1")

        #expect(sut.itemRepo.fetchedListIds == ["list-1", "list-1"])
        #expect(sut.itemService.currentListId == "list-1")
    }

    // MARK: Failures never stop the next step

    @Test("A failed step does not stop the next one and the invalidation still runs last",
          arguments: [ItemError.network, .server, .forbidden, .rateLimited(retryAfter: 3)])
    func failedStepsDoNotStopTheRest(error: ItemError) async {
        let sut = makeSUT()
        await preload(sut, listId: "list-1")
        sut.itemRepo.enqueueFetchItemDetail(.failure(error))
        sut.itemRepo.enqueueFetchItems(.failure(error))
        sut.listRepo.enqueueFetchListDetail(.failure(ListError.server))
        var listCountAtInvalidation = -1
        sut.invalidator.onMark = { listCountAtInvalidation = sut.listRepo.fetchListDetailCount }

        await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1")

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 2, "the items step still ran")
        #expect(sut.listRepo.fetchListDetailCount == 1, "the list detail step still ran")
        #expect(sut.invalidator.markCount == 1)
        #expect(listCountAtInvalidation == 1, "the invalidation came after the list detail step")
    }

    @Test("An item refetch 404 does not stop the later steps or the invalidation")
    func itemGoneDoesNotStopTheRest() async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        sut.itemRepo.enqueueFetchItems(.success([]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.runAfterPurchase(itemId: "item-1", listId: "list-1")

        #expect(sut.itemService.goneItemId == "item-1")
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.invalidator.markCount == 1)
    }
}
