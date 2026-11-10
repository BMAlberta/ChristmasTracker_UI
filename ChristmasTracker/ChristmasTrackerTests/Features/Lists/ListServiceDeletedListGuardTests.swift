//
//  ListServiceDeletedListGuardTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0 / I3b-6 (F1): the deleted-list guard blocks only operations that STARTED BEFORE the
//  removal completed (an in-flight guard, not a session-long one).
//
//  1. A load that was already in flight when a delete completed must not bring the list back
//     (lists, cache and currentListDetail). A load that starts AFTER the removal is not filtered
//     (a server response that returns the list ARCHIVED is still hidden by the archived filter).
//  2. The guard records are cleared at teardown; a failed delete does not add to them.
//  3. When loadListDetail or updateList fails with notFound or archivedReadOnly, the list is
//     dropped (lists, cache, currentListDetail) and recorded as a removal; the error is still set.
//     Any other error drops nothing.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService deleted-list guard", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceDeletedListGuardTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
        let manager: SessionManager
    }

    private func makeSUT() async -> SUT {
        let repo = GatedListRepository()
        let store = ListDataStore()
        let service = ListService(repository: repo, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, store: store, manager: manager)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    private func archivedList(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: .archived)
    }

    private func detail(_ id: String) -> ListDetail {
        ListFixtures.listDetail(id: id, name: "Name of \(id)")
    }

    // MARK: - In-flight loads racing a delete

    @Test("a loadLists in flight when the delete completes does not bring the deleted list back")
    func inFlightLoadListsDoesNotResurrect() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        let load = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.currentListDetail == nil)
    }

    @Test("a refreshLists in flight when the delete completes does not bring the deleted list back")
    func inFlightRefreshDoesNotResurrect() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let refresh = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await refresh.value

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.currentListDetail == nil)
    }

    @Test("a loadListDetail of the deleted id in flight when the delete completes sets no currentListDetail")
    func inFlightDetailDoesNotResurrect() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let load = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.isLoadingDetail == false)
    }

    // MARK: - Guard lifetime

    @Test("after teardown the guard is cleared: a new session that sees the same id shows it")
    func guardClearedAtTeardown() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))   // a different user

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("a failed delete does not add the id to the guard")
    func failedDeleteDoesNotGuard() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueDeleteList(.failure(ListError.forbidden))
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.loadLists()
        _ = try? await sut.service.deleteList(id: "list-a")

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-a"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a"])
    }

    // MARK: - Gone lists (loadListDetail and updateList)

    nonisolated static let goneErrors: [ListError] = [.notFound, .archivedReadOnly]
    nonisolated static let otherErrors: [ListError] = [
        .forbidden, .recipientNotFound, .duplicateRecipientYear,
        .validation(message: "Name must be between 1 and 200 characters"),
        .rateLimited(retryAfter: 3), .unauthorized, .network, .invalidResponse, .server
    ]
    /// I3b-6: forbidden is not here. A forbidden revalidation of a CACHED detail now drops the list
    /// (see ListServiceRevalidationTests); forbidden stays in `otherErrors` for the updateList variants.
    nonisolated static let detailOtherErrors: [ListError] = otherErrors.filter { $0 != .forbidden }

    /// Loads lists [list-a, list-b] and the detail of list-a so the gone-list drop has something to drop.
    private func loadedSUT() async -> SUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        return sut
    }

    @Test("loadListDetail failing with notFound or archivedReadOnly drops the list everywhere (a later refresh may show it again)", arguments: ListServiceDeletedListGuardTests.goneErrors)
    func detailGoneDropsList(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == error)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.currentListDetail == nil)

        // I3b-6: the guard is in-flight only. A later refresh that starts after the drop and returns
        // the (non-archived) list shows it again.
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let recached = await sut.store.getLists()
        #expect(recached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("updateList failing with notFound or archivedReadOnly drops the list everywhere (a later refresh may show it again)", arguments: ListServiceDeletedListGuardTests.goneErrors)
    func updateGoneDropsList(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueUpdateList(.failure(error))

        await #expect(throws: error) {
            try await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }

        #expect(sut.service.error == error)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.currentListDetail == nil)

        // I3b-6: a later refresh that starts after the drop and returns the (non-archived) list shows it.
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let recached = await sut.store.getLists()
        #expect(recached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("loadListDetail failing with any other error drops nothing and guards nothing", arguments: ListServiceDeletedListGuardTests.detailOtherErrors)
    func detailOtherErrorDropsNothing(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == error)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])

        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
    }

    @Test("updateList failing with any other error drops nothing and guards nothing", arguments: ListServiceDeletedListGuardTests.otherErrors)
    func updateOtherErrorDropsNothing(error: ListError) async {
        let sut = await loadedSUT()
        let before = sut.service.currentListDetail
        sut.repo.enqueueUpdateList(.failure(error))

        await #expect(throws: error) {
            try await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }

        #expect(sut.service.error == error)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.currentListDetail == before)
        #expect(sut.service.currentListDetail?.id == "list-a")

        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
    }

    // MARK: - F4: loadListDetail for a guarded id reports notFound (all three guard points)

    // I3b-6 replaces detailOfGuardedIdIsNotFound: the product decision changes the guard from
    // session-long to in-flight only.
    @Test("a loadListDetail that starts after the delete completed is not filtered and shows the detail")
    func laterDetailLoadAfterDeleteShowsDetail() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail?.id == "list-a")
        #expect(sut.service.error == nil)
        #expect(sut.service.isLoadingDetail == false)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail?.id == "list-a")
        #expect(sut.repo.fetchListDetailCount == 1)
    }

    // I3b-6 replaces cachedDetailOfGuardedIdIsNotFound: the product decision changes the guard from
    // session-long to in-flight only.
    @Test("a cached detail that appears after the delete is shown and revalidated by a later loadListDetail")
    func cachedDetailAfterDeleteIsShownAndRevalidated() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        await sut.store.setListDetail(detail("list-a"))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail?.id == "list-a")
        #expect(sut.service.error == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.repo.fetchListDetailCount == 1, "the cached detail is revalidated, not trusted")
    }

    @Test("a fresh detail result that arrives after the id became guarded reports notFound and sets no detail")
    func freshDetailResultForNewlyGuardedIdIsNotFound() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let load = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.error == .notFound)
        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.goneListId == "list-a")
    }

    // MARK: - I3b-6 (F1): the guard covers only operations that started before the removal

    @Test("a loadLists that starts after the delete completed and returns the list ARCHIVED still hides it")
    func laterLoadListsReturningArchivedStaysHidden() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))   // the only list, so the delete empties the cache and loadLists must fetch
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchLists(.success([archivedList("list-a"), list("list-b")]))

        await sut.service.loadLists()

        #expect(sut.repo.fetchListsCount == 2, "the second load really fetched")
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
    }

    @Test("a refreshLists that starts after the delete completed and returns the list ARCHIVED still hides it")
    func laterRefreshReturningArchivedStaysHidden() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchLists(.success([archivedList("list-a"), list("list-b")]))

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
    }

    @Test("a loadLists that starts after the delete completed and returns the list non-archived shows it")
    func laterLoadListsAfterDeleteShowsList() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))   // the only list, so the delete empties the cache and loadLists must fetch
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("two loads in flight, one started before and one after the delete completed: only the earlier one is filtered")
    func onlyTheLoadStartedBeforeTheRemovalIsFiltered() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))   // the only list, so the delete leaves none
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)   // started before
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)   // started after
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let earlier = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()
        try await sut.service.deleteList(id: "list-a")
        let later = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        sut.repo.release(at: 0)
        await earlier.value
        #expect(sut.service.lists.map(\.id) == ["list-b"], "the load that started before the removal is filtered")

        sut.repo.release(at: 1)
        await later.value
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "the load that started after the removal is not")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("the guard records are cleared at teardown: a new session starts with none")
    func recordsClearedAtTeardownNewSessionStartsEmpty() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        await sut.manager.teardown(reason: .userLogout)

        // New session, another user who also sees list-a. Their load starts at the beginning of the
        // session and must not be filtered by the previous session's record.
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)
        let load = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("in a new session the in-flight guard works from a clean slate")
    func newSessionInFlightGuardStillWorks() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        await sut.manager.teardown(reason: .userLogout)

        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let refresh = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()
        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await refresh.value

        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    // MARK: - F3: an update in flight when the delete completes

    @Test("an updateList in flight when the same list is deleted does not write the list back")
    func inFlightUpdateDoesNotResurrect() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueUpdateList(.success(detail("list-a")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        let update = Task {
            _ = try? await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await update.value

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - F5: goneListId

    @Test("loadListDetail failing with a gone error sets goneListId to that id", arguments: ListServiceDeletedListGuardTests.goneErrors)
    func detailGoneSetsGoneListId(error: ListError) async {
        let sut = await loadedSUT()
        #expect(sut.service.goneListId == nil, "precondition")
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.goneListId == "list-a")
    }

    @Test("updateList failing with a gone error sets goneListId to that id", arguments: ListServiceDeletedListGuardTests.goneErrors)
    func updateGoneSetsGoneListId(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueUpdateList(.failure(error))

        _ = try? await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))

        #expect(sut.service.goneListId == "list-a")
    }

    @Test("any other error leaves goneListId nil", arguments: ListServiceDeletedListGuardTests.otherErrors)
    func otherErrorsLeaveGoneListIdNil(error: ListError) async {
        let sut = await loadedSUT()
        sut.repo.enqueueUpdateList(.failure(error))

        // I3b-6: forbidden on a detail load WITH a cached detail drops the list, so it is not in this loop.
        if error != .forbidden {
            sut.repo.enqueueFetchListDetail(.failure(error))
            await sut.service.loadListDetail(id: "list-a")
        }
        _ = try? await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))

        #expect(sut.service.goneListId == nil)
    }

    @Test("a gone error for list-b sets goneListId to list-b only, never list-a")
    func goneErrorOfOtherListIsNotMistaken() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.notFound))

        await sut.service.loadListDetail(id: "list-b")

        #expect(sut.service.goneListId == "list-b")
        #expect(sut.service.goneListId != "list-a")
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    @Test("teardown clears goneListId")
    func teardownClearsGoneListId() async {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.notFound))
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.goneListId == "list-a", "precondition")

        await sut.manager.teardown(reason: .userLogout)

        #expect(sut.service.goneListId == nil)
    }
}
