//
//  PurchaseServiceManagementClearableTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: production wiring of the extended PurchaseService (Gate 1 Story B interface item 6).
//  The service gains management methods but stays ONE session boundary: it is still the 8th and
//  last production clearable, so `makeProductionClearables` still returns 8 and no existing index
//  moves (the pinned count tests in SessionTeardownTests, InactivityLockIntegrationTests,
//  ChildServiceClearableTests and PurchaseServiceClearableTests stay unchanged; a sibling service
//  would have forced a 9th). Clearing the registered service ends an in-flight management call.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService management clearable registration", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceManagementClearableTests {

    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    private struct SUT {
        let clearables: [any SessionClearable]
        let purchaseService: PurchaseService
        let management: GatedPurchaseManager
        let recorder: GatedPurchaseRecorder
    }

    private func makeSUT() -> SUT {
        let recorder = GatedPurchaseRecorder()
        let management = GatedPurchaseManager()
        let purchaseService = PurchaseService(repository: recorder, management: management)
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
        return SUT(clearables: clearables, purchaseService: purchaseService, management: management, recorder: recorder)
    }

    // EDITED (I5a-B): count 8 -> 10 and the name no longer says "last". Reason: two session-safe services
    // were added to the teardown list (StatsService at index 8, BudgetService at index 9); extending the
    // PurchaseService itself still adds no clearable and it keeps index 7.
    @Test("makeProductionClearables returns 10 clearables with the management-capable PurchaseService at index 7")
    func stillEightWithTheServiceLast() {
        let sut = makeSUT()

        #expect(sut.clearables.count == 10, "extending the purchase service must not add a clearable of its own")
        #expect(sut.clearables[7] is PurchaseService)
        #expect(sut.clearables[7] === sut.purchaseService, "the registered clearable is the very instance passed in")
        #expect(sut.clearables[8] is StatsService, "the StatsService clearable follows the PurchaseService")
        #expect(sut.clearables[9] is BudgetService, "the BudgetService clearable is appended last")
    }

    @Test("clearing the registered clearable at index 7 ends an in-flight management call",
          arguments: ManagementOp.allCases)
    func clearingEndsAnInFlightManagementCall(op: ManagementOp) async throws {
        let sut = makeSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.purchaseService, op)
        await sut.management.gate.nextHeldCall()

        try await sut.clearables[7].clearForSession()
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        #expect(result.managementValue == nil)
    }

    @Test("SessionManager.teardown with the production clearables ends an in-flight management call",
          arguments: [TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback])
    func teardownEndsAnInFlightManagementCall(reason: TeardownReason) async {
        let sut = makeSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.purchaseService, .delete)
        await sut.management.gate.nextHeldCall()
        let manager = SessionManager(initialClearables: sut.clearables)

        await manager.teardown(reason: reason)
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        #expect(result.managementValue == nil)
    }

    @Test("after teardown with the production clearables a new management call works")
    func newSessionWorksAfterTeardown() async throws {
        let sut = makeSUT()
        let manager = SessionManager(initialClearables: sut.clearables)
        await manager.teardown(reason: .userLogout)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-new"))

        let purchase = try await sut.purchaseService.fetchPurchase(id: "purchase-new")

        #expect(purchase.id == "purchase-new")
    }
}
