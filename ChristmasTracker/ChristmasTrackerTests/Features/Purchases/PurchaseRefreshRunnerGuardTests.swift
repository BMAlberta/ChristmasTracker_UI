//
//  PurchaseRefreshRunnerGuardTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-C: PurchaseRefreshRunner.run(_:while:) asks a continue-check before EACH step and stops
//  (no further step) when it answers false. The unguarded run(_:) is unchanged (an always-true check).
//  A failed step never stops the next one; an item refetch 404 still drops the item and sets goneItemId.
//
//  REAL ItemService and ListService over gated fake repositories, as in PurchaseRefreshRunnerTests.
//  The check is a counter, so no handshake or sleep is needed.
//
//  These tests pin the guarded run(_:while:).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase refresh runner guard Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseRefreshRunnerGuardTests {

    private struct SUT {
        let runner: PurchaseRefreshRunner
        let itemService: ItemService
        let listService: ListService
        let itemRepo: GatedItemRepository
        let listRepo: GatedListRepository
    }

    /// Answers true for the first `allowed` questions and false afterwards; counts the questions.
    private final class Check {
        private(set) var asked = 0
        private let allowed: Int
        init(allowing allowed: Int) { self.allowed = allowed }
        func callAsFunction() -> Bool {
            asked += 1
            return asked <= allowed
        }
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

    private let plan: [PurchaseRefreshStep] = [.itemDetail(id: "item-1"), .itemsLoad(listId: "list-1"), .listDetail(id: "list-1")]

    private func script(_ sut: SUT) {
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item, otherItem]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
    }

    // MARK: Guarded run

    @Test("The guarded run stops when the check turns false before step 2")
    func stopsBeforeSecondStep() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 1)

        await sut.runner.run(plan, while: { check() })

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 0, "the items step must not run")
        #expect(sut.listRepo.fetchListDetailCount == 0, "the list detail step must not run")
        #expect(check.asked == 2, "asked before step 1 and before step 2, then stopped")
    }

    @Test("The guarded run stops when the check turns false before step 3")
    func stopsBeforeThirdStep() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 2)

        await sut.runner.run(plan, while: { check() })

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 0)
        #expect(check.asked == 3)
    }

    @Test("A check that is false before step 1 runs nothing")
    func stopsBeforeFirstStep() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 0)

        await sut.runner.run(plan, while: { check() })

        #expect(sut.itemRepo.fetchItemDetailCount == 0)
        #expect(sut.itemRepo.fetchItemsCount == 0)
        #expect(sut.listRepo.fetchListDetailCount == 0)
        #expect(check.asked == 1)
    }

    @Test("A check that stays true runs every step, asked once before each")
    func alwaysTrueRunsEverything() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 3)

        await sut.runner.run(plan, while: { check() })

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(check.asked == 3)
    }

    @Test("An empty plan asks nothing and does nothing")
    func emptyPlanGuarded() async {
        let sut = makeSUT()
        let check = Check(allowing: 5)

        await sut.runner.run([], while: { check() })

        #expect(check.asked == 0)
        #expect(sut.itemRepo.fetchItemDetailCount == 0)
    }

    // MARK: Unguarded run is unchanged

    @Test("The unguarded run(_:) still runs all steps in order")
    func unguardedRunsEverything() async {
        let sut = makeSUT()
        script(sut)

        await sut.runner.run(plan)

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.itemService.items.map(\.id) == ["item-1", "item-2"])
        #expect(sut.listService.currentListDetail?.id == "list-1")
    }

    // MARK: Failures and 404 under the guard

    @Test("A failed step does not stop the next one under the guarded run")
    func failedStepDoesNotStopNextGuarded() async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.server))
        sut.itemRepo.enqueueFetchItems(.failure(ItemError.network))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
        let check = Check(allowing: 3)

        await sut.runner.run(plan, while: { check() })

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 1, "the items step still ran")
        #expect(sut.listRepo.fetchListDetailCount == 1, "the list detail step still ran")
        #expect(check.asked == 3)
    }

    @Test("An item refetch 404 under the guarded run drops the item, sets goneItemId and the later steps still run")
    func itemRefetchNotFoundGuarded() async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItems(.success([item, otherItem]))
        await sut.itemService.loadItems(listId: "list-1")
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        sut.itemRepo.enqueueFetchItems(.success([otherItem]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
        let steps = PurchaseRefreshPlan.stepsAfterDelete(itemId: "item-1", listId: "list-1", currentItemsListId: sut.itemService.currentListId)
        let check = Check(allowing: 3)

        await sut.runner.run(steps, while: { check() })

        #expect(sut.itemService.goneItemId == "item-1")
        #expect(sut.itemService.items.map(\.id) == ["item-2"])
        #expect(sut.itemService.currentItem == nil)
        #expect(sut.listRepo.fetchListDetailCount == 1, "the list detail step still ran")
    }
}
