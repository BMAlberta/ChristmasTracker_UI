//
//  InactivityLockIntegrationTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 (Story 2): integration between
//  makeProductionClearables(lockController:) and InactivityLockController.
//
//  R1 rework: lockControllerConformsToSessionClearable rewritten to use FakeClock +
//  FakeSleeper instead of tracker.enteredBackground(at:), which is removed in R1.
//
//  Will fail (pre-R1) because:
//    - makeProductionClearables has no lockController: parameter yet
//  Will fail (R1) because:
//    - InactivityLockController gains clockNow: and sleepUntil: params (compile error
//      until implemented)
//
//  Concurrency: @MainActor throughout (controller is @MainActor).
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("InactivityLock Integration Tests")
@MainActor
struct InactivityLockIntegrationTests {

    // MARK: - Helpers

    /// Minimal fake policy for controller construction.
    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    // MARK: - Factory

    private func makeSUT() -> (
        listDataStore: ListDataStore,
        itemDataStore: ItemDataStore,
        listService: ListService,
        itemService: ItemService,
        networkCache: NetworkCache,
        lockController: InactivityLockController
    ) {
        let listDataStore = ListDataStore()
        let itemDataStore = ItemDataStore()
        let listService = ListService(repository: MockListRepository(), dataStore: listDataStore)
        let itemService = ItemService(repository: MockItemRepository(), dataStore: itemDataStore)
        let networkCache = NetworkCache()
        let lockController = InactivityLockController(policy: FakePolicy10())
        return (listDataStore, itemDataStore, listService, itemService, networkCache, lockController)
    }

    // MARK: - Tests

    @Test("makeProductionClearables(lockController:) returns exactly 6 clearables")
    func productionClearablesReturnsSixItems() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables.count == 6,
                "makeProductionClearables(lockController:) must return exactly 6 clearables")
    }

    @Test("makeProductionClearables(lockController:) — clearables[0] is ListDataStore")
    func clearablesIndexZeroIsListDataStore() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[0] is ListDataStore, "clearables[0] must be ListDataStore")
    }

    @Test("makeProductionClearables(lockController:) — clearables[1] is ItemDataStore")
    func clearablesIndexOneIsItemDataStore() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[1] is ItemDataStore, "clearables[1] must be ItemDataStore")
    }

    @Test("makeProductionClearables(lockController:) — clearables[2] is ListService")
    func clearablesIndexTwoIsListService() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[2] is ListService, "clearables[2] must be ListService")
    }

    @Test("makeProductionClearables(lockController:) — clearables[3] is ItemService")
    func clearablesIndexThreeIsItemService() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[3] is ItemService, "clearables[3] must be ItemService")
    }

    @Test("makeProductionClearables(lockController:) — clearables[4] is NetworkCache")
    func clearablesIndexFourIsNetworkCache() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[4] is NetworkCache, "clearables[4] must be NetworkCache")
    }

    @Test("makeProductionClearables(lockController:) — clearables[5] is InactivityLockController")
    func clearablesIndexFiveIsInactivityLockController() {
        let (listDataStore, itemDataStore, listService, itemService, networkCache, lockController) = makeSUT()

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: networkCache,
            lockController: lockController
        )

        #expect(clearables[5] is InactivityLockController,
                "clearables[5] must be InactivityLockController")
    }

    // R1 rework: drive to locked via fake clock + sceneDidBecomeActive(),
    // replacing tracker.enteredBackground(at:) which is removed in R1.
    // Will fail to compile until InactivityLockController gains clockNow: and sleepUntil: params.
    @Test("lockController clearForSession() resets lockState to .unlocked and is SessionClearable")
    func lockControllerConformsToSessionClearable() async throws {
        let (_, _, _, _, _, lockController) = makeSUT()

        // Drive to .locked via fake clock + scene event (R1 rework).
        let clock = FakeClock()
        let sleeper = FakeSleeper()
        let lockedController = InactivityLockController(
            policy: FakePolicy10(),
            clockNow: { clock.now },
            sleepUntil: { deadline in try await sleeper.sleep(until: deadline) }
        )
        lockedController.start()
        await Task.yield()
        clock.advance(by: .seconds(10 * 60 + 1))
        lockedController.sceneDidBecomeActive()
        try #require(lockedController.lockState == .locked,
                     "Precondition: controller must be locked before clearForSession()")

        // clearForSession() satisfies the SessionClearable contract.
        try await lockedController.clearForSession()

        #expect(lockedController.lockState == .unlocked,
                "clearForSession() must reset lockState to .unlocked")

        // Keep original makeSUT controller reference alive to avoid deallocation warning.
        _ = lockController
    }

    // MARK: - Lock-only-when-started integration test

    @Test("lockState only changes when start() was called — stop() without start() is safe")
    func lockStateOnlyChangesWhenStartWasCalled() {
        let (_, _, _, _, _, lockController) = makeSUT()

        // Never call start(). Call stop() — must be safe.
        lockController.stop()

        // No background/foreground events should lock without start().
        lockController.sceneWillResignActive()
        lockController.sceneDidBecomeActive()

        #expect(lockController.lockState == .unlocked,
                "lockState must remain .unlocked when start() was never called")
    }

    @Test("lockState remains .unlocked after stop() even with scene events")
    func lockStateRemainsUnlockedAfterStop() {
        let (_, _, _, _, _, lockController) = makeSUT()

        lockController.start()
        lockController.stop()

        // After stop(), no further lock transitions should occur via scene events
        // (the timer is cancelled and no new deadline is set).
        lockController.sceneWillResignActive()
        // After stop(), isRunning == false, so sceneDidBecomeActive is a no-op.
        lockController.stop() // idempotent — second call must not crash
        #expect(lockController.lockState == .unlocked)
    }
}
