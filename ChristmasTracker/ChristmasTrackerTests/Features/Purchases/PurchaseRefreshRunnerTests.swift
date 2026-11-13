//
//  PurchaseRefreshRunnerTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: PurchaseRefreshRunner executes the steps of PurchaseRefreshPlan against the REAL
//  ItemService and ListService over gated fake repositories.
//
//   - the three steps run in plan order (item detail, then items, then list detail);
//   - items refresh when the item service holds the list, load otherwise (decided by the plan);
//   - a failed step never throws and never stops the next step;
//   - an item refetch 404 drops the item from the caches and sets goneItemId (existing ItemService
//     behavior), and the later steps still run.
//
//  Determinism: held steps and the nextHeldCall() handshake; no sleeps, no yield loops.
//
//  Fails today because PurchaseRefreshRunner does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase refresh runner Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseRefreshRunnerTests {

    private struct SUT {
        let runner: PurchaseRefreshRunner
        let itemService: ItemService
        let listService: ListService
        let itemRepo: GatedItemRepository
        let listRepo: GatedListRepository
    }

    private func makeSUT() -> SUT {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let itemService = ItemService(repository: itemRepo, dataStore: ItemDataStore())
        let listService = ListService(repository: listRepo, dataStore: ListDataStore())
        return SUT(
            runner: PurchaseRefreshRunner(itemService: itemService, listService: listService),
            itemService: itemService, listService: listService, itemRepo: itemRepo, listRepo: listRepo
        )
    }

    private let item = ItemServiceFix.item("item-1")
    private let otherItem = ItemServiceFix.item("item-2")

    /// Loads the items of list-1 so the item service holds that list (the plan then chooses a refresh).
    private func preloadItems(_ sut: SUT, _ items: [ListItem]) async {
        sut.itemRepo.enqueueFetchItems(.success(items))
        await sut.itemService.loadItems(listId: "list-1")
    }

    private func steps(_ sut: SUT) -> [PurchaseRefreshStep] {
        PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-1", listId: "list-1", currentItemsListId: sut.itemService.currentListId)
    }

    // MARK: Order

    @Test("The three steps run in plan order: item detail, then items, then list detail")
    func runsInPlanOrder() async {
        let sut = makeSUT()
        await preloadItems(sut, [item, otherItem])
        sut.itemRepo.enqueueFetchItemDetail(.success(item), held: true)
        sut.itemRepo.enqueueFetchItems(.success([item, otherItem]), held: true)
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()), held: true)
        let plan = steps(sut)
        #expect(plan == [.itemDetail(id: "item-1"), .itemsRefresh, .listDetail(id: "list-1")])

        let task = Task { @MainActor in await sut.runner.run(plan) }

        let first = await sut.itemRepo.gate.nextHeldCall()
        #expect(first == .fetchItemDetail("item-1"))
        #expect(sut.itemRepo.fetchItemsCount == 1, "the items step has not started (only the preload)")
        #expect(sut.listRepo.fetchListDetailCount == 0, "the list detail step has not started")
        sut.itemRepo.gate.releaseNext()

        let second = await sut.itemRepo.gate.nextHeldCall()
        #expect(second == .fetchItems("list-1"))
        #expect(sut.listRepo.fetchListDetailCount == 0, "the list detail step has not started")
        sut.itemRepo.gate.releaseNext()

        let third = await sut.listRepo.nextHeldCall()
        #expect(third == .fetchListDetail("list-1"))
        sut.listRepo.releaseNext()

        await task.value
        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 2)
        #expect(sut.listRepo.fetchListDetailCount == 1)
    }

    @Test("A plan with no steps does nothing")
    func emptyPlan() async {
        let sut = makeSUT()

        await sut.runner.run([])

        #expect(sut.itemRepo.fetchItemDetailCount == 0)
        #expect(sut.itemRepo.fetchItemsCount == 0)
        #expect(sut.listRepo.fetchListDetailCount == 0)
    }

    // MARK: Items refresh vs load

    @Test("When the item service already holds the list the items step refreshes in place")
    func itemsRefreshWhenListHeld() async {
        let sut = makeSUT()
        await preloadItems(sut, [item])
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item, otherItem]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(steps(sut))

        #expect(sut.itemRepo.fetchedListIds == ["list-1", "list-1"])
        #expect(sut.itemService.currentListId == "list-1")
        #expect(sut.itemService.items.map(\.id) == ["item-1", "item-2"])
        #expect(sut.itemService.currentItem?.id == "item-1")
    }

    @Test("When the item service holds another list or none the items step loads the item's list")
    func itemsLoadWhenListNotHeld() async {
        let sut = makeSUT()
        let plan = steps(sut)
        #expect(plan == [.itemDetail(id: "item-1"), .itemsLoad(listId: "list-1"), .listDetail(id: "list-1")])
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(plan)

        #expect(sut.itemRepo.fetchedListIds == ["list-1"])
        #expect(sut.itemService.currentListId == "list-1")
        #expect(sut.itemService.items.map(\.id) == ["item-1"])
        #expect(sut.listService.currentListDetail?.id == "list-1")
    }

    @Test("Explicit steps run exactly as given")
    func explicitSteps() async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItems(.success([otherItem]))

        await sut.runner.run([.itemsLoad(listId: "list-9")])

        #expect(sut.itemRepo.fetchedListIds == ["list-9"])
        #expect(sut.itemRepo.fetchItemDetailCount == 0)
        #expect(sut.listRepo.fetchListDetailCount == 0)
    }

    // MARK: Failures never throw and never stop the next step

    @Test("A failed item detail step does not stop the items and list detail steps",
          arguments: [ItemError.network, .server, .forbidden, .rateLimited(retryAfter: 3)])
    func failedStepDoesNotStopTheNext(error: ItemError) async {
        let sut = makeSUT()
        await preloadItems(sut, [item])
        sut.itemRepo.enqueueFetchItemDetail(.failure(error))
        sut.itemRepo.enqueueFetchItems(.success([item]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(steps(sut))

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 2, "the items step still ran")
        #expect(sut.listRepo.fetchListDetailCount == 1, "the list detail step still ran")
    }

    @Test("A failed items step does not stop the list detail step")
    func failedItemsStepDoesNotStopListDetail() async {
        let sut = makeSUT()
        await preloadItems(sut, [item])
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.failure(ItemError.server))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(steps(sut))

        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.listService.currentListDetail?.id == "list-1")
    }

    @Test("A failed list detail step is the last step and ends the run quietly")
    func failedListDetailStep() async {
        let sut = makeSUT()
        await preloadItems(sut, [item])
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item]))
        sut.listRepo.enqueueFetchListDetail(.failure(ListError.server))

        await sut.runner.run(steps(sut))

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.itemService.currentItem?.id == "item-1", "the earlier successful steps stay applied")
    }

    // MARK: Item gone

    @Test("An item refetch 404 drops the item from the caches, sets goneItemId and the later steps still run")
    func itemRefetchNotFoundDropsItem() async {
        let sut = makeSUT()
        await preloadItems(sut, [item, otherItem])
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        sut.itemRepo.enqueueFetchItems(.success([otherItem]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(steps(sut))

        #expect(sut.itemService.goneItemId == "item-1")
        #expect(sut.itemService.items.map(\.id) == ["item-2"])
        #expect(sut.itemService.currentItem == nil)
        #expect(sut.itemRepo.fetchItemsCount == 2, "the items step still ran")
        #expect(sut.listRepo.fetchListDetailCount == 1, "the list detail step still ran")
    }

    @Test("A refetch 404 of the item does not mark the other item gone")
    func otherItemNotGone() async {
        let sut = makeSUT()
        await preloadItems(sut, [item, otherItem])
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        sut.itemRepo.enqueueFetchItems(.success([otherItem]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(steps(sut))

        #expect(sut.itemService.goneItemId != "item-2")
        #expect(sut.itemService.items.contains { $0.id == "item-2" })
    }
}
