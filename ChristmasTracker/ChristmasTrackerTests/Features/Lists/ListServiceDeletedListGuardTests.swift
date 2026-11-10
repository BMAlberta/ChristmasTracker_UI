//
//  ListServiceDeletedListGuardTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: ListService keeps a session-local set of deleted (gone) list ids.
//
//  1. A load that was already in flight when a delete completed must not bring the list back
//     (lists, cache and currentListDetail).
//  2. The set is cleared at teardown; a failed delete does not add to it.
//  3. When loadListDetail or updateList fails with notFound or archivedReadOnly, the list is
//     dropped (lists, cache, currentListDetail) and recorded in the set; the error is still set.
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

    /// Loads lists [list-a, list-b] and the detail of list-a so the gone-list drop has something to drop.
    private func loadedSUT() async -> SUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        return sut
    }

    @Test("loadListDetail failing with notFound or archivedReadOnly drops the list everywhere and guards the id", arguments: ListServiceDeletedListGuardTests.goneErrors)
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

        // The guard: a later refresh that still returns the id does not bring it back.
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("updateList failing with notFound or archivedReadOnly drops the list everywhere and guards the id", arguments: ListServiceDeletedListGuardTests.goneErrors)
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

        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        await sut.service.refreshLists()
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("loadListDetail failing with any other error drops nothing and guards nothing", arguments: ListServiceDeletedListGuardTests.otherErrors)
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

    @Test("loadListDetail of an id already in the guard sets notFound, no detail and no busy residue")
    func detailOfGuardedIdIsNotFound() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == .notFound)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.goneListId == "list-a")
    }

    @Test("a cached detail for a guarded id is not served: notFound, no detail, no fetch")
    func cachedDetailOfGuardedIdIsNotFound() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")
        await sut.store.setListDetail(detail("list-a"))       // a stale cached detail appears afterwards

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == .notFound)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.repo.fetchListDetailCount == 0)
        #expect(sut.service.goneListId == "list-a")
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
        sut.repo.enqueueFetchListDetail(.failure(error))
        sut.repo.enqueueUpdateList(.failure(error))

        await sut.service.loadListDetail(id: "list-a")
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
