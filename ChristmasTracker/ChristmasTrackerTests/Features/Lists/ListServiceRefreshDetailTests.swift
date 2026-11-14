//
//  ListServiceRefreshDetailTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-F2: ListService.refreshListDetail(id:) always fetches (even with a fresh cache),
//  returns a failure instead of storing it, and obeys the same session, archive and ordering
//  guards as loadListDetail.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService refreshListDetail", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceRefreshDetailTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
        let manager: SessionManager
    }

    private func makeSUT(honorsCancellation: Bool = false) async -> SUT {
        let repo = GatedListRepository()
        repo.honorsCancellation = honorsCancellation
        let store = ListDataStore()
        let service = ListService(repository: repo, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, store: store, manager: manager)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    private func detail(_ id: String, name: String? = nil, status: ListStatus = .active) -> ListDetail {
        ListFixtures.listDetail(id: id, name: name ?? "Name of \(id)", status: status)
    }

    /// Lists [list-a, list-b] are loaded; the detail of list-a is cached and open (one detail fetch used).
    private func loadedSUT(honorsCancellation: Bool = false) async -> SUT {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        return sut
    }

    private func expectUntouched(_ sut: SUT) async {
        #expect(sut.service.currentListDetail == nil, "currentListDetail must stay nil")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.goneListId == nil)
        for id in ["list-a", "list-b"] {
            let cached = await sut.store.getListDetail(id: id)
            #expect(cached == nil, "the cache must not hold a detail for \(id)")
        }
    }

    nonisolated static let failures: [ListError] = [.network, .server, .rateLimited(retryAfter: 5)]

    // MARK: - Always fetches

    @Test("it calls the repository even when the detail is cached and fresh")
    func fetchesWithFreshCache() async {
        let sut = await loadedSUT()
        let cachedBefore = await sut.store.getListDetail(id: "list-a")
        #expect(cachedBefore != nil, "precondition: the cache is fresh")
        #expect(sut.repo.fetchListDetailCount == 1, "precondition")
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")))

        await sut.service.refreshListDetail(id: "list-a")

        #expect(sut.repo.fetchListDetailCount == 2)
    }

    @Test("it calls the repository when nothing is cached")
    func fetchesWithoutCache() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.repo.fetchListDetailCount == 1)
    }

    // MARK: - Success

    @Test("success returns nil and updates the open detail and the cache")
    func successUpdatesDetailAndCache() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.service.currentListDetail?.name == "Fresh")
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached?.name == "Fresh")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("success for a list that is not the open one updates the cache but not the open detail")
    func successForOtherListKeepsOpenDetail() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-b")))
        await sut.service.loadListDetail(id: "list-b")
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.service.currentListDetail?.id == "list-b", "the open detail is another list and stays")
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached?.name == "Fresh")
    }

    @Test("a success after a failure returns nil: the failure is not remembered by the service")
    func secondSuccessAfterFailure() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.network))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")))

        let first = await sut.service.refreshListDetail(id: "list-a")
        let second = await sut.service.refreshListDetail(id: "list-a")

        #expect(first == .network)
        #expect(second == nil)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.currentListDetail?.name == "Fresh")
    }

    // MARK: - Failure

    @Test("a failure keeps the cached and open detail and returns the typed error", arguments: ListServiceRefreshDetailTests.failures)
    func failureKeepsDetailAndReturnsError(error: ListError) async {
        let sut = await loadedSUT()
        let before = sut.service.currentListDetail
        sut.repo.enqueueFetchListDetail(.failure(error))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == error)
        #expect(sut.service.currentListDetail == before)
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached == before)
        #expect(sut.service.goneListId == nil)
    }

    // REWRITTEN (UX1a U2): the refresh stores neither load failure (it only returns its failure).
    @Test("a failure stores neither listsLoadFailure nor detailLoadFailure", arguments: ListServiceRefreshDetailTests.failures)
    func failureDoesNotSetServiceError(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.refreshListDetail(id: "list-a")

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a failure with nothing open or cached returns the error and stores no load failure")
    func failureWithoutDetail() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == .server)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.currentListDetail == nil)
    }

    @Test("the refresh does not touch isLoadingDetail while it runs or after it fails")
    func doesNotTouchIsLoadingDetail() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.network), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isLoadingDetail == false, "a pull to refresh must not flip the screen to Loading")
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == .network)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a successful refresh does not touch isLoadingDetail while it runs")
    func doesNotTouchIsLoadingDetailOnSuccess() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isLoadingDetail == false)
        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isLoadingDetail == false)
    }

    // MARK: - Gone

    @Test("404 drops the list, sets goneListId and returns nil")
    func notFoundSetsGone() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.notFound))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.service.goneListId == "list-a")
        #expect(sut.service.currentListDetail == nil)
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("403 on a shown detail drops it like loadListDetail and returns nil")
    func forbiddenOnShownDetailDrops() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.forbidden))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.service.goneListId == "list-a")
        #expect(sut.service.currentListDetail == nil)
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    // MARK: - Ordering

    @Test("a newer refresh wins over an older one that finishes later")
    func newerRefreshWins() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Older")), held: true)
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Newer")), held: true)
        let older = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()
        let newer = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        sut.repo.release(at: 1)
        _ = await newer.value
        #expect(sut.service.currentListDetail?.name == "Newer", "precondition")
        sut.repo.release(at: 0)
        _ = await older.value

        #expect(sut.service.currentListDetail?.name == "Newer", "the older result must not overwrite")
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached?.name == "Newer")
    }

    @Test("an older refresh that fails after a newer one succeeded does not change the detail")
    func olderFailureAfterNewerSuccess() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.network), held: true)
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Newer")), held: true)
        let older = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()
        let newer = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        sut.repo.release(at: 1)
        _ = await newer.value
        sut.repo.release(at: 0)
        _ = await older.value

        #expect(sut.service.currentListDetail?.name == "Newer")
        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - Session safety

    @Test("a result that arrives after teardown writes nothing and returns nil", arguments: [false, true])
    func staleSuccessAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        await expectUntouched(sut)
    }

    @Test("a failure that arrives after teardown returns nil and sets nothing", arguments: ListServiceRefreshDetailTests.failures)
    func staleFailureAfterTeardown(error: ListError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(error), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        await expectUntouched(sut)
    }

    @Test("a gone result that arrives after teardown sets no goneListId and returns nil")
    func staleGoneAfterTeardown() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.notFound), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        await expectUntouched(sut)
    }

    @Test("user switch: user A's late refresh never replaces user B's detail or cache")
    func userSwitchLateRefresh() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "User A late")), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "User B")))
        await sut.service.loadListDetail(id: "list-a")
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.service.currentListDetail?.name == "User B")
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached?.name == "User B")
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("cancelling the caller returns nil and writes nothing")
    func cancellationWritesNothing() async {
        let sut = await loadedSUT(honorsCancellation: true)
        let before = sut.service.currentListDetail
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")), held: true)
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        task.cancel()
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.service.currentListDetail == before)
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached == before)
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("a repository that fails with CancellationError returns nil and sets no error")
    func repositoryCancellationReturnsNil() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(CancellationError()))

        let result = await sut.service.refreshListDetail(id: "list-a")

        #expect(result == nil)
        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - Archive epoch

    @Test("an archive of the same list between start and finish discards the refresh result")
    func archiveOfSameListDiscardsResult() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Stale active")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([
            ListFixtures.giftList(id: "list-a", name: "Name of list-a", status: .archived),
            list("list-b")
        ]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", status: .archived)))
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.service.currentListDetail?.name != "Stale active", "the stale active detail must not be shown")
        let cached = await sut.store.getListDetail(id: "list-a")
        #expect(cached?.name != "Stale active", "the stale active detail must not be cached")
    }

    @Test("an archive of another list does not discard the refresh result")
    func archiveOfOtherListKeepsResult() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([
            list("list-a"),
            ListFixtures.giftList(id: "list-b", name: "Name of list-b", status: .archived)
        ]))
        let task = Task { await sut.service.refreshListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-b")
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result == nil)
        #expect(sut.service.currentListDetail?.name == "Fresh")
    }
}
