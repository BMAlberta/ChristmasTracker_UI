//
//  ChildServiceClearableTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: ChildService is registered as the 7th production clearable (appended AFTER the
//  lock controller, so no existing index moves) and SessionManager.teardown clears it. This is
//  the production-wiring test for the new store.
//
//  The pinned count test itself (6 -> 7) lives in InactivityLockIntegrationTests and
//  SessionTeardownTests, edited with the stated reason.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildService clearable registration", .timeLimit(.minutes(1)))
@MainActor
struct ChildServiceClearableTests {

    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    private struct SUT {
        let clearables: [any SessionClearable]
        let childService: ChildService
        let repo: GatedChildRepository
        let listService: ListService
        let lockController: InactivityLockController
    }

    private func makeSUT() -> SUT {
        let repo = GatedChildRepository()
        let childService = ChildService(repository: repo)
        let listDataStore = ListDataStore()
        let listService = ListService(repository: MockListRepository(), dataStore: listDataStore)
        let lockController = InactivityLockController(policy: FakePolicy10())
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: ItemDataStore(),
            listService: listService,
            itemService: ItemService(repository: MockItemRepository(), dataStore: ItemDataStore()),
            networkCache: NetworkCache(),
            lockController: lockController,
            childService: childService,
            // EDITED (I4a-B): the new final parameter of makeProductionClearables.
            purchaseService: PurchaseService(repository: MockPurchaseRecorder(access: { _ in .unknown }))
        )
        return SUT(
            clearables: clearables, childService: childService, repo: repo,
            listService: listService, lockController: lockController
        )
    }

    // EDITED (I4a-B): count 7 -> 8 and the name no longer says "last". Reason: the PurchaseService
    // clearable is appended last (index 7); the ChildService keeps index 6.
    @Test("makeProductionClearables(childService:) returns 8 clearables and the ChildService keeps index 6")
    func childServiceKeepsIndexSix() {
        let sut = makeSUT()

        #expect(sut.clearables.count == 8)
        #expect(sut.clearables[6] is ChildService, "the ChildService must come after the lock controller")
        #expect(sut.clearables[6] === sut.childService, "the registered clearable is the very instance passed in")
        #expect(sut.clearables[7] is PurchaseService, "the PurchaseService clearable is appended last")
    }

    // EDITED (I4a-B): the title said "the existing six"; the ChildService (index 6) is now also pinned
    // here because the PurchaseService clearable is appended after it.
    @Test("the existing seven clearables keep their indices")
    func existingIndicesUnchanged() {
        let sut = makeSUT()
        #expect(sut.clearables[6] is ChildService)
        #expect(sut.clearables[6] === sut.childService)

        #expect(sut.clearables[0] is ListDataStore)
        #expect(sut.clearables[1] is ItemDataStore)
        #expect(sut.clearables[2] is ListService)
        #expect(sut.clearables[3] is ItemService)
        #expect(sut.clearables[4] is NetworkCache)
        #expect(sut.clearables[5] is InactivityLockController)
        #expect(sut.clearables[5] === sut.lockController)
        #expect(sut.clearables[2] === sut.listService)
    }

    @Test("SessionManager.teardown with the production clearables empties a populated ChildService")
    func teardownClearsPopulatedChildService() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.childService.loadChildren()
        #expect(sut.childService.children.count == 2, "precondition")
        #expect(sut.childService.phase == .loaded, "precondition")
        let manager = SessionManager(initialClearables: sut.clearables)

        await manager.teardown(reason: .userLogout)

        #expect(sut.childService.children.isEmpty)
        #expect(sut.childService.phase == .idle)
        #expect(sut.childService.error == nil)
        #expect(sut.childService.isMutating == false)
    }

    @Test("teardown also clears a ChildService that holds an error", arguments: [TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback])
    func teardownClearsErrorForEveryReason(reason: TeardownReason) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchChildren(.success(ChildFixtures.twoChildren()))
        await sut.childService.loadChildren()
        sut.repo.enqueueDeleteChild(.failure(ChildError.childHasLists))
        _ = try? await sut.childService.deleteChild(id: "child-1")
        #expect(sut.childService.error != nil, "precondition")
        let manager = SessionManager(initialClearables: sut.clearables)

        await manager.teardown(reason: reason)

        #expect(sut.childService.children.isEmpty)
        #expect(sut.childService.error == nil)
        #expect(sut.childService.phase == .idle)
    }
}
