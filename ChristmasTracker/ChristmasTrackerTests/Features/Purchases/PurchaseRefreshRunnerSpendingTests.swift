//
//  PurchaseRefreshRunnerSpendingTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: the cache hook. The runner handles the plan's final `.invalidateSpending` step by
//  calling `spendingCaches?.markSpendingStale()` on the injected invalidator:
//
//   - exactly once for a plan that ends with the step, and only after the three refresh steps;
//   - NOT when the continue-check says stop before that step (the session ended);
//   - a failing earlier step never stops it;
//   - a nil invalidator (the defaulted init) makes the step a no-op, and the old initializer still works;
//   - an explicit plan runs the step exactly as many times as it appears.
//
//  REAL ItemService and ListService over gated fake repositories, as in PurchaseRefreshRunnerTests.
//  The check is a counter, so no handshake or sleep is needed.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase refresh runner spending hook Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseRefreshRunnerSpendingTests {

    private struct SUT {
        let runner: PurchaseRefreshRunner
        let invalidator: RecordingSpendingInvalidator
        let itemService: ItemService
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

    private func makeSUT(withInvalidator: Bool = true) -> SUT {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let itemService = ItemService(repository: itemRepo, dataStore: ItemDataStore())
        let listService = ListService(repository: listRepo, dataStore: ListDataStore())
        let invalidator = RecordingSpendingInvalidator()
        let runner = PurchaseRefreshRunner(
            itemService: itemService, listService: listService, spendingCaches: withInvalidator ? invalidator : nil
        )
        return SUT(runner: runner, invalidator: invalidator, itemService: itemService, itemRepo: itemRepo, listRepo: listRepo)
    }

    private let item = ItemServiceFix.item("item-1")

    private func script(_ sut: SUT) {
        sut.itemRepo.enqueueFetchItemDetail(.success(item))
        sut.itemRepo.enqueueFetchItems(.success([item]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))
    }

    private func plan(_ sut: SUT) -> [PurchaseRefreshStep] {
        PurchaseRefreshPlan.steps(itemId: "item-1", listId: "list-1", currentItemsListId: sut.itemService.currentListId)
    }

    // MARK: The step itself

    @Test("the invalidation step marks the spending caches stale exactly once")
    func stepCallsTheInvalidator() async {
        let sut = makeSUT()

        await sut.runner.run([.invalidateSpending])

        #expect(sut.invalidator.markCount == 1)
        #expect(sut.itemRepo.fetchItemDetailCount == 0, "the step refreshes nothing else")
        #expect(sut.itemRepo.fetchItemsCount == 0)
        #expect(sut.listRepo.fetchListDetailCount == 0)
    }

    @Test("an explicit plan runs the step as often as it appears")
    func explicitStepsRunAsGiven() async {
        let sut = makeSUT()

        await sut.runner.run([.invalidateSpending, .invalidateSpending])

        #expect(sut.invalidator.markCount == 2)
    }

    @Test("the other steps never mark the spending caches stale")
    func otherStepsDoNotInvalidate() async {
        let sut = makeSUT()
        script(sut)

        await sut.runner.run([.itemDetail(id: "item-1"), .itemsLoad(listId: "list-1"), .listDetail(id: "list-1")])

        #expect(sut.invalidator.markCount == 0)
    }

    // MARK: A whole plan

    @Test("a full plan marks the caches stale exactly once, after the three refresh steps")
    func fullPlanInvalidatesOnceAfterTheRefreshes() async {
        let sut = makeSUT()
        script(sut)
        var itemDetailAtMark = -1
        var itemsAtMark = -1
        var listDetailAtMark = -1
        sut.invalidator.onMark = {
            itemDetailAtMark = sut.itemRepo.fetchItemDetailCount
            itemsAtMark = sut.itemRepo.fetchItemsCount
            listDetailAtMark = sut.listRepo.fetchListDetailCount
        }

        await sut.runner.run(plan(sut))

        #expect(sut.invalidator.markCount == 1)
        #expect(itemDetailAtMark == 1, "the item detail step ran before the invalidation")
        #expect(itemsAtMark == 1, "the items step ran before the invalidation")
        #expect(listDetailAtMark == 1, "the list detail step ran before the invalidation")
    }

    @Test("the delete plan marks the caches stale exactly once too")
    func deletePlanInvalidatesOnce() async {
        let sut = makeSUT()
        script(sut)
        let steps = PurchaseRefreshPlan.stepsAfterDelete(
            itemId: "item-1", listId: "list-1", currentItemsListId: sut.itemService.currentListId
        )

        await sut.runner.run(steps)

        #expect(sut.invalidator.markCount == 1)
    }

    // MARK: The guard

    @Test("the guarded run does not invalidate when the check says stop before the step")
    func guardStopsBeforeTheInvalidation() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 3)

        await sut.runner.run(plan(sut), while: { check() })

        #expect(sut.listRepo.fetchListDetailCount == 1, "the three refresh steps ran")
        #expect(check.asked == 4, "asked before each of the four steps, then stopped")
        #expect(sut.invalidator.markCount == 0, "a session that ended must not mark caches")
    }

    @Test("the guarded run does not invalidate when the check says stop earlier", arguments: [0, 1, 2])
    func guardStopsEarlier(allowed: Int) async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: allowed)

        await sut.runner.run(plan(sut), while: { check() })

        #expect(sut.invalidator.markCount == 0)
    }

    @Test("the guarded run invalidates once when the check stays true, asked once before each step")
    func guardStaysTrue() async {
        let sut = makeSUT()
        script(sut)
        let check = Check(allowing: 4)

        await sut.runner.run(plan(sut), while: { check() })

        #expect(sut.invalidator.markCount == 1)
        #expect(check.asked == 4)
    }

    @Test("the guarded run asks the check before the invalidation step on its own")
    func guardIsAskedForTheStepAlone() async {
        let sut = makeSUT()
        let allowed = Check(allowing: 1)
        let denied = Check(allowing: 0)

        await sut.runner.run([.invalidateSpending], while: { allowed() })
        await sut.runner.run([.invalidateSpending], while: { denied() })

        #expect(sut.invalidator.markCount == 1)
        #expect(allowed.asked == 1)
        #expect(denied.asked == 1)
    }

    // MARK: Failures never stop it

    @Test("failing earlier steps never stop the invalidation",
          arguments: [ItemError.network, .server, .forbidden, .rateLimited(retryAfter: 3)])
    func failingStepsDoNotStopIt(error: ItemError) async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItemDetail(.failure(error))
        sut.itemRepo.enqueueFetchItems(.failure(error))
        sut.listRepo.enqueueFetchListDetail(.failure(ListError.server))

        await sut.runner.run(plan(sut))

        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
        #expect(sut.invalidator.markCount == 1)
    }

    @Test("an item refetch 404 does not stop the invalidation")
    func itemGoneDoesNotStopIt() async {
        let sut = makeSUT()
        sut.itemRepo.enqueueFetchItemDetail(.failure(ItemError.notFound))
        sut.itemRepo.enqueueFetchItems(.success([]))
        sut.listRepo.enqueueFetchListDetail(.success(ListFixtures.listDetail()))

        await sut.runner.run(plan(sut))

        #expect(sut.invalidator.markCount == 1)
    }

    // MARK: No invalidator

    @Test("a runner without an invalidator treats the step as a no-op and still runs the other steps")
    func nilInvalidatorIsANoOp() async {
        let sut = makeSUT(withInvalidator: false)
        script(sut)

        await sut.runner.run(plan(sut))

        #expect(sut.invalidator.markCount == 0)
        #expect(sut.itemRepo.fetchItemDetailCount == 1)
        #expect(sut.itemRepo.fetchItemsCount == 1)
        #expect(sut.listRepo.fetchListDetailCount == 1)
    }

    @Test("the existing two-argument initializer still works and ignores the step")
    func oldInitializerStillWorks() async {
        let itemRepo = GatedItemRepository()
        let listRepo = GatedListRepository()
        let runner = PurchaseRefreshRunner(
            itemService: ItemService(repository: itemRepo, dataStore: ItemDataStore()),
            listService: ListService(repository: listRepo, dataStore: ListDataStore())
        )

        await runner.run([.invalidateSpending])
        await runner.run([.invalidateSpending], while: { true })

        #expect(itemRepo.fetchItemDetailCount == 0)
        #expect(listRepo.fetchListDetailCount == 0)
    }
}
