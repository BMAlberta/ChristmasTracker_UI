//
//  PurchaseServiceClearableTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: PurchaseService is the 8th production clearable, appended AFTER the ChildService
//  (so no existing index moves) and SessionManager.teardown clears it. This is the
//  production-wiring test for the new service.
//
//  The pinned count tests (7 -> 8) live in SessionTeardownTests, InactivityLockIntegrationTests and
//  ChildServiceClearableTests, edited with the stated reason: the PurchaseService clearable is
//  appended last.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService clearable registration", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceClearableTests {

    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    private struct SUT {
        let clearables: [any SessionClearable]
        let purchaseService: PurchaseService
        let repo: GatedPurchaseRecorder
    }

    private func makeSUT() -> SUT {
        let repo = GatedPurchaseRecorder()
        let purchaseService = PurchaseService(repository: repo)
        let listDataStore = ListDataStore()
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: ItemDataStore(),
            listService: ListService(repository: MockListRepository(), dataStore: listDataStore),
            itemService: ItemService(repository: MockItemRepository(), dataStore: ItemDataStore()),
            networkCache: NetworkCache(),
            lockController: InactivityLockController(policy: FakePolicy10()),
            childService: ChildService(repository: GatedChildRepository()),
            purchaseService: purchaseService,
            // EDITED (I5a-B): the two new final parameters of makeProductionClearables.
            statsService: StatsService(repository: GatedStatsLoader()),
            budgetService: BudgetService(repository: GatedBudgetManager())
        )
        return SUT(clearables: clearables, purchaseService: purchaseService, repo: repo)
    }

    // EDITED (I5a-B): count 8 -> 10 and the name no longer says "last". Reason: two session-safe services
    // were added to the teardown list (StatsService at index 8, BudgetService at index 9); the
    // PurchaseService keeps index 7.
    @Test("makeProductionClearables returns 10 clearables with the PurchaseService at index 7")
    func purchaseServiceIsEighthAndLast() {
        let sut = makeSUT()

        #expect(sut.clearables.count == 10)
        #expect(sut.clearables[7] is PurchaseService, "the PurchaseService must come after the ChildService")
        #expect(sut.clearables[7] === sut.purchaseService, "the registered clearable is the very instance passed in")
        #expect(sut.clearables[8] is StatsService, "the StatsService clearable follows the PurchaseService")
        #expect(sut.clearables[9] is BudgetService, "the BudgetService clearable is appended last")
    }

    @Test("the existing seven clearables keep their indices")
    func existingIndicesUnchanged() {
        let sut = makeSUT()

        #expect(sut.clearables[0] is ListDataStore)
        #expect(sut.clearables[1] is ItemDataStore)
        #expect(sut.clearables[2] is ListService)
        #expect(sut.clearables[3] is ItemService)
        #expect(sut.clearables[4] is NetworkCache)
        #expect(sut.clearables[5] is InactivityLockController)
        #expect(sut.clearables[6] is ChildService)
    }

    @Test("clearing the registered clearable at index 7 ends an in-flight call")
    func clearingEndsAnInFlightCall() async throws {
        let sut = makeSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.purchaseService, token: PurchaseWire.token)
        await sut.repo.gate.nextHeldCall()
        #expect(sut.purchaseService.isMutating == true, "precondition")

        try await sut.clearables[7].clearForSession()
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(sut.purchaseService.isMutating == false)
    }

    @Test("SessionManager.teardown with the production clearables ends an in-flight purchase",
          arguments: [TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback])
    func teardownEndsAnInFlightCall(reason: TeardownReason) async {
        let sut = makeSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.purchaseService)
        await sut.repo.gate.nextHeldCall()
        let manager = SessionManager(initialClearables: sut.clearables)

        await manager.teardown(reason: reason)
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(result.outcome == nil)
        #expect(sut.purchaseService.isMutating == false)
    }
}
