//
//  ListServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: ListService is safe against sign-out and user switching.
//
//  Teardown is driven the way the app does it: the service (and, in some tests, the data store)
//  is registered with a SessionManager and `SessionManager.teardown(reason:)` runs, which calls
//  `ListService.clearForSession()`. No other entry point is assumed.
//
//  Determinism: every in-flight call is held by a gated GatedListRepository. A test waits for
//  `nextHeldCall()` (a continuation handshake), so it knows the service is inside the
//  repository before it tears the session down, and it releases the held call explicitly. There
//  are no sleeps and no yield loops. A suite time limit turns a hang into a failure.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The six service operations that talk to the repository.
nonisolated enum ListServiceOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case loadLists, refreshLists, loadListDetail, createList, updateList, deleteList

    var testDescription: String {
        switch self {
        case .loadLists: "loadLists"
        case .refreshLists: "refreshLists"
        case .loadListDetail: "loadListDetail"
        case .createList: "createList"
        case .updateList: "updateList"
        case .deleteList: "deleteList"
        }
    }

    /// Queues ONE held step for this operation: success (fake data) or the given failure.
    @MainActor
    func script(_ repo: GatedListRepository, failing error: ListError?) {
        func outcome<T>(_ value: T) -> Result<T, any Error> {
            if let error { return .failure(error) }
            return .success(value)
        }
        switch self {
        case .loadLists, .refreshLists:
            repo.enqueueFetchLists(outcome([ListFixtures.giftList(id: "list-a", name: "Alpha")]), held: true)
        case .loadListDetail:
            repo.enqueueFetchListDetail(outcome(ListFixtures.listDetail(id: "list-a", name: "Alpha")), held: true)
        case .createList:
            repo.enqueueCreateList(outcome(ListFixtures.listDetail(id: "list-new", name: "Brand New")), held: true)
        case .updateList:
            repo.enqueueUpdateList(outcome(ListFixtures.listDetail(id: "list-a", name: "Renamed")), held: true)
        case .deleteList:
            repo.enqueueDeleteList(outcome(()), held: true)
        }
    }

    /// Runs the operation; a thrown error is swallowed (the tests assert on service state).
    @MainActor
    func run(_ service: ListService) async {
        switch self {
        case .loadLists:
            await service.loadLists()
        case .refreshLists:
            await service.refreshLists()
        case .loadListDetail:
            await service.loadListDetail(id: "list-a")
        case .createList:
            _ = try? await service.createList(
                CreateListInput(recipientId: "user-1", year: 2026, name: "Brand New", theme: nil, visibility: .private)
            )
        case .updateList:
            _ = try? await service.updateList(id: "list-a", UpdateListInput(name: "Renamed", theme: nil, visibility: nil))
        case .deleteList:
            _ = try? await service.deleteList(id: "list-a")
        }
    }
}

@Suite("ListService session safety", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceSessionSafetyTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
        let manager: SessionManager
    }

    /// `registerStore` also registers the ListDataStore with the manager (as the app does);
    /// by default only the service is registered, so a cleared cache proves the SERVICE clears it.
    private func makeSUT(honorsCancellation: Bool = false, registerStore: Bool = false) async -> SUT {
        let repo = GatedListRepository()
        repo.honorsCancellation = honorsCancellation
        let store = ListDataStore()
        let service = ListService(repository: repo, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        if registerStore { await manager.register(store) }
        await manager.register(service)
        return SUT(service: service, repo: repo, store: store, manager: manager)
    }

    private func expectCleared(_ sut: SUT) async {
        #expect(sut.service.lists.isEmpty, "lists must stay empty")
        #expect(sut.service.currentListDetail == nil, "currentListDetail must stay nil")
        #expect(sut.service.listsLoadFailure == nil, "no lists load failure may be set after the session ended")
        #expect(sut.service.detailLoadFailure == nil, "no detail load failure may be set after the session ended")
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty, "the cache must not receive a stale result")
        for id in ["list-a", "list-b", "list-new"] {
            let cachedDetail = await sut.store.getListDetail(id: id)
            #expect(cachedDetail == nil, "the cache must not hold a detail for \(id)")
        }
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    // MARK: - Teardown during an in-flight operation

    @Test("a held operation that completes after teardown leaves everything empty", arguments: ListServiceOp.allCases)
    func inFlightSuccessAfterTeardownIsDiscarded(op: ListServiceOp) async {
        let sut = await makeSUT()
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.isRefreshing == false)
    }

    @Test("a held operation that FAILS after teardown does not set an error", arguments: ListServiceOp.allCases)
    func inFlightFailureAfterTeardownSetsNoError(op: ListServiceOp) async {
        let sut = await makeSUT()
        op.script(sut.repo, failing: .server)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a held operation that fails with a typed network error after teardown sets no error", arguments: ListServiceOp.allCases)
    func inFlightNetworkFailureAfterTeardownSetsNoError(op: ListServiceOp) async {
        let sut = await makeSUT()
        op.script(sut.repo, failing: .network)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test(
        "cancellation during teardown does not set an error, whether or not the repository honors it",
        arguments: ListServiceOp.allCases, [false, true]
    )
    func cancellationDuringTeardownSetsNoError(op: ListServiceOp, honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        // If teardown cancelled the in-flight work and the repository honors it, the call has
        // already ended with CancellationError; releasing again is a no-op. Otherwise this is
        // the stale-result path.
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("after a create held across teardown completes, the store holds no summary or detail and the next load fetches")
    func createHeldAcrossTeardownLeavesStoreEmpty() async {
        let sut = await makeSUT()
        sut.repo.enqueueCreateList(.success(ListFixtures.listDetail(id: "list-new", name: "Brand New")), held: true)
        sut.repo.enqueueFetchLists(.success([list("list-b")]))
        let task = Task { await ListServiceOp.createList.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        let cachedLists = await sut.store.getLists()
        let cachedDetail = await sut.store.getListDetail(id: "list-new")
        #expect(cachedLists.isEmpty, "no summary of the old user's list may remain")
        #expect(cachedDetail == nil)
        let shouldRefresh = await sut.store.shouldRefresh()
        #expect(shouldRefresh, "an empty, cleared cache must not look fresh")

        await sut.service.loadLists()                                        // next session

        #expect(sut.repo.fetchListsCount == 1, "the next load must go to the repository, not the cache")
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("after any operation discarded by teardown, the next load goes to the repository", arguments: ListServiceOp.allCases)
    func nextLoadAfterDiscardedOperationFetches(op: ListServiceOp) async {
        let sut = await makeSUT()
        op.script(sut.repo, failing: nil)
        sut.repo.enqueueFetchLists(.success([list("list-b")]))
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value
        let before = sut.repo.fetchListsCount

        await sut.service.loadLists()

        #expect(sut.repo.fetchListsCount == before + 1)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("teardown with the data store also registered leaves service and cache empty after a late result")
    func teardownWithStoreRegistered() async {
        let sut = await makeSUT(registerStore: true)
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let task = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    // MARK: - Teardown clears loaded state

    @Test("teardown empties lists, currentListDetail, the cache and the error of a loaded service")
    func teardownClearsLoadedState() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Alpha")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        #expect(!sut.service.lists.isEmpty, "precondition")
        #expect(sut.service.currentListDetail != nil, "precondition")

        await sut.manager.teardown(reason: .userLogout)

        await expectCleared(sut)
        let shouldRefresh = await sut.store.shouldRefresh()
        #expect(shouldRefresh, "a cleared cache must not look fresh")
    }

    // REWRITTEN (UX1a U2): both load failures are cleared at teardown (was: the shared `error`).
    @Test("teardown clears the load failures left by failed loads")
    func teardownClearsError() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        #expect(sut.service.detailLoadFailure == .server, "precondition")

        await sut.manager.teardown(reason: .sessionExpired)

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("after teardown the next load goes to the repository, not to the old cache")
    func loadAfterTeardownFetchesFresh() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchLists(.success([list("list-b")]))
        await sut.service.loadLists()
        await sut.manager.teardown(reason: .userLogout)

        await sut.service.loadLists()

        #expect(sut.repo.fetchListsCount == 2)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
    }

    @Test("a second teardown with nothing loaded is harmless")
    func repeatedTeardownIsHarmless() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.loadLists()

        await sut.manager.teardown(reason: .userLogout)
        await sut.manager.teardown(reason: .userLogout)

        await expectCleared(sut)
    }

    // MARK: - User switch

    @Test("user switch: B loads while A's load is held; A's late result never shows")
    func userSwitchBLoadsFirst() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)   // user A
        sut.repo.enqueueFetchLists(.success([list("list-b")]))               // user B
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()                                        // user B
        #expect(sut.service.lists.map(\.id) == ["list-b"])

        sut.repo.releaseAll()
        await loadA.value

        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's data must not replace or join B's")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.repo.fetchListsCount == 2)
    }

    @Test("user switch: A's late result is discarded while B's load is still in flight")
    func userSwitchAReleasedBeforeB() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)   // user A
        sut.repo.enqueueFetchLists(.success([list("list-b")]), held: true)   // user B
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let loadB = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        #expect(sut.repo.fetchListsCount == 2, "B's load must reach the repository even though A's is still held")

        sut.repo.releaseNext()                                               // release A
        await loadA.value
        #expect(sut.service.lists.isEmpty, "A's data must never show")
        let cachedAfterA = await sut.store.getLists()
        #expect(cachedAfterA.isEmpty)

        sut.repo.releaseNext()                                               // release B
        await loadB.value
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cachedAfterB = await sut.store.getLists()
        #expect(cachedAfterB.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("user switch: B finishes first, then A's late result arrives and is discarded")
    func userSwitchBReleasedBeforeA() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)   // user A
        sut.repo.enqueueFetchLists(.success([list("list-b")]), held: true)   // user B
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let loadB = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        sut.repo.release(at: 1)                                              // release B first
        await loadB.value
        #expect(sut.service.lists.map(\.id) == ["list-b"])

        sut.repo.release(at: 0)                                              // then A, late
        await loadA.value

        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's late result must not overwrite B's")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("user switch: A's late failure does not put a load failure on B's session")
    func userSwitchLateFailureDoesNotLeak() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)  // user A fails late
        sut.repo.enqueueFetchLists(.success([list("list-b")]))               // user B succeeds
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()

        sut.repo.releaseAll()
        await loadA.value

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("user switch: A's held detail load never becomes B's currentListDetail")
    func userSwitchDetail() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Alpha")), held: true)
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-b", name: "Beta")))
        let loadA = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadListDetail(id: "list-b")
        sut.repo.releaseAll()
        await loadA.value

        #expect(sut.service.currentListDetail?.id == "list-b")
        let staleDetail = await sut.store.getListDetail(id: "list-a")
        #expect(staleDetail == nil)
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("user switch: a delete still in flight for A does not remove or alter B's lists")
    func userSwitchDeleteInFlight() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))   // B happens to see the same id
        await sut.service.loadLists()
        let deleteTask = Task { await ListServiceOp.deleteList.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()
        sut.repo.releaseAll()
        await deleteTask.value

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "A's late delete must not touch B's lists")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }
}
