//
//  ListServiceRevalidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-6 (F1): loadListDetail shows a cached detail first and revalidates it.
//
//  - A revalidation that fails with notFound, archivedReadOnly or forbidden removes the cached
//    detail, the summary and the open detail, sets goneListId and reports the error.
//  - forbidden with NO cached detail keeps the old behavior: nothing is dropped, goneListId stays nil.
//  - A cached detail never survives teardown or a user switch.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//
//  Story I3c-A changes (named; reason: decision "archived lists stay visible and archive reloads
//  from the server" and "a 422 CANNOT_EDIT_ARCHIVED_LIST is NOT list gone"):
//  - revalidationErrors no longer contains archivedReadOnly (notFound and forbidden-with-cache
//    still mean gone).
//  - cachedDetailRevalidationRacingDeleteReportsNotFound now races a LEAVE (a removal) instead of
//    an archive, because an archive records no removal.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService cached-detail revalidation", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceRevalidationTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
        let manager: SessionManager
        let members: GatedMemberRepository
    }

    private func makeSUT() async -> SUT {
        let repo = GatedListRepository()
        let members = GatedMemberRepository()
        let store = ListDataStore()
        let service = ListService(repository: repo, memberRepository: members, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, store: store, manager: manager, members: members)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    private func detail(_ id: String, name: String? = nil) -> ListDetail {
        ListFixtures.listDetail(id: id, name: name ?? "Name of \(id)")
    }

    /// Lists [list-a, list-b] are loaded and the detail of list-a is cached and open.
    private func loadedSUT() async -> SUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        return sut
    }

    /// CHANGED (I3c-A): archivedReadOnly removed; a 422 is not "list gone".
    nonisolated static let revalidationErrors: [ListError] = [.notFound, .forbidden]

    // MARK: - (f) revalidation failure with a cached detail

    @Test("a cached detail whose revalidation fails with notFound or forbidden is removed and reported",
          arguments: ListServiceRevalidationTests.revalidationErrors)
    func revalidationFailureRemovesCachedDetail(error: ListError) async {
        let sut = await loadedSUT()
        let cachedBefore = await sut.store.getListDetail(id: "list-a")
        #expect(cachedBefore != nil, "precondition")
        sut.repo.enqueueFetchListDetail(.failure(error), held: true)
        let reopen = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()
        #expect(sut.service.currentListDetail?.id == "list-a", "the cached detail is shown while it revalidates")

        sut.repo.releaseAll()
        await reopen.value

        let cachedAfter = await sut.store.getListDetail(id: "list-a")
        #expect(cachedAfter == nil)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == "list-a")
        #expect(sut.service.detailLoadFailure == error, "a revalidation failure with cached data is recorded")
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.map(\.id) == ["list-b"])
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a cached detail of another list is left alone when list-a's revalidation fails")
    func revalidationFailureKeepsOtherCachedDetails() async {
        let sut = await loadedSUT()
        await sut.store.setListDetail(detail("list-b"))
        sut.repo.enqueueFetchListDetail(.failure(ListError.forbidden))

        await sut.service.loadListDetail(id: "list-a")

        let other = await sut.store.getListDetail(id: "list-b")
        #expect(other?.id == "list-b")
        #expect(sut.service.goneListId == "list-a")
    }

    @Test("forbidden with no cached detail keeps the old behavior: nothing dropped, goneListId nil")
    func forbiddenWithoutCacheDropsNothing() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.failure(ListError.forbidden))
        await sut.service.loadLists()

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.detailLoadFailure == .forbidden)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    // CHANGED (I3c-A): the removal is a leave (was a delete); an archive records no removal.
    @Test("a cached detail whose list is left while it revalidates is removed and reported as notFound")
    func cachedDetailRevalidationRacingLeaveReportsNotFound() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Fresh")), held: true)
        sut.members.enqueueRemoveMember(.success(()))
        let reopen = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.leaveList(id: "list-a", userId: "user-me")
        sut.repo.releaseAll()
        await reopen.value

        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == "list-a")
        #expect(sut.service.detailLoadFailure == .notFound)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.isLoadingDetail == false)
    }

    // MARK: - (g) a cached detail does not survive teardown or a user switch

    @Test("teardown empties the store and the open detail")
    func teardownDropsCachedDetail() async {
        let sut = await loadedSUT()
        #expect(sut.service.currentListDetail?.id == "list-a", "precondition")

        await sut.manager.teardown(reason: .userLogout)

        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.lists.isEmpty)
    }

    @Test("a new session's loadListDetail for the same id starts without the previous user's detail")
    func newSessionStartsWithoutPreviousUsersDetail() async {
        let sut = await loadedSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchListDetail(.success(detail("list-a", name: "Second user's view")), held: true)

        let load = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        #expect(sut.service.currentListDetail == nil, "no cached detail of the previous user is shown")
        let cachedWhileLoading = await sut.store.getListDetail(id: "list-a")
        #expect(cachedWhileLoading == nil)

        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.currentListDetail?.name == "Second user's view")
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a new session whose first fetch of the same id fails shows no detail from the previous user")
    func newSessionFailureShowsNoPreviousDetail() async {
        let sut = await loadedSUT()
        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.enqueueFetchListDetail(.failure(ListError.network))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.detailLoadFailure == .network)
    }
}
