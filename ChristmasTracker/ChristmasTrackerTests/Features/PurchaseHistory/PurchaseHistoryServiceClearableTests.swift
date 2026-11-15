//
//  PurchaseHistoryServiceClearableTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC9: PurchaseHistoryService is the 11th production clearable, appended AFTER the
//  BudgetService (so no existing index moves), and SessionManager.teardown clears it. This is the
//  production-wiring test for the new service.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryService clearable registration", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseHistoryServiceClearableTests {

    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    private struct SUT {
        let clearables: [any SessionClearable]
        let historyService: PurchaseHistoryService
        let loader: GatedPurchaseHistoryLoader
    }

    private func makeSUT() -> SUT {
        let loader = GatedPurchaseHistoryLoader()
        let historyService = PurchaseHistoryService(repository: loader)
        let listDataStore = ListDataStore()
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: ItemDataStore(),
            listService: ListService(repository: MockListRepository(), dataStore: listDataStore),
            itemService: ItemService(repository: MockItemRepository(), dataStore: ItemDataStore()),
            networkCache: NetworkCache(),
            lockController: InactivityLockController(policy: FakePolicy10()),
            childService: ChildService(repository: GatedChildRepository()),
            purchaseService: PurchaseService(repository: GatedPurchaseRecorder()),
            statsService: StatsService(repository: GatedStatsLoader()),
            budgetService: BudgetService(repository: GatedBudgetManager()),
            purchaseHistoryService: historyService
        )
        return SUT(clearables: clearables, historyService: historyService, loader: loader)
    }

    @Test("makeProductionClearables returns 11 clearables with the PurchaseHistoryService at index 10")
    func historyServiceIsEleventh() {
        let sut = makeSUT()

        #expect(sut.clearables.count == 11)
        #expect(sut.clearables[10] is PurchaseHistoryService)
        #expect(sut.clearables[10] === sut.historyService, "the registered clearable is the very instance passed in")
    }

    @Test("the existing ten clearables keep their indices")
    func existingIndicesUnchanged() {
        let sut = makeSUT()

        #expect(sut.clearables[0] is ListDataStore)
        #expect(sut.clearables[1] is ItemDataStore)
        #expect(sut.clearables[2] is ListService)
        #expect(sut.clearables[3] is ItemService)
        #expect(sut.clearables[4] is NetworkCache)
        #expect(sut.clearables[5] is InactivityLockController)
        #expect(sut.clearables[6] is ChildService)
        #expect(sut.clearables[7] is PurchaseService)
        #expect(sut.clearables[8] is StatsService)
        #expect(sut.clearables[9] is BudgetService)
    }

    @Test("clearing the registered clearable at index 10 ends an in-flight call")
    func clearingEndsAnInFlightCall() async throws {
        let sut = makeSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(sut.historyService)
        await sut.loader.gate.nextHeldCall()
        let before = sut.historyService.sessionGeneration

        try await sut.clearables[10].clearForSession()
        sut.loader.gate.releaseAll()

        expectCancellation(await task.result)
        #expect(sut.historyService.sessionGeneration == before + 1)
    }

    @Test("SessionManager.teardown with the production clearables ends an in-flight history call",
          arguments: [TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback])
    func teardownEndsAnInFlightCall(reason: TeardownReason) async {
        let sut = makeSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(sut.historyService)
        await sut.loader.gate.nextHeldCall()
        let manager = SessionManager(initialClearables: sut.clearables)

        await manager.teardown(reason: reason)
        sut.loader.gate.releaseAll()

        expectCancellation(await task.result)
    }

    @Test("after teardown with the production clearables a new call works")
    func newSessionWorksAfterTeardown() async throws {
        let sut = makeSUT()
        let manager = SessionManager(initialClearables: sut.clearables)
        await manager.teardown(reason: .userLogout)
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "after")]))

        let page = try await sut.historyService.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(page.rows.map(\.id) == ["after"])
    }
}
