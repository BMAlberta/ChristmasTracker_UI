//
//  ListServiceArchiveSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: archiving (ListService.deleteList) is safe against sign-out, user switching and
//  cancellation, DURING the archive call and DURING the reload that follows it. A result or a
//  failure that arrives after the session ended, or after the caller was cancelled, writes
//  nothing and sets no error.
//
//  Teardown is driven the way the app does it: the service is registered with a SessionManager
//  and `SessionManager.teardown(reason:)` runs.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService archive session safety", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchiveSessionSafetyTests {

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

    private func active(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", flags: ListFixtures.Flags(canCreateItem: true, canDeleteList: true))
    }

    private func archived(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: .archived, flags: ListFixtures.Flags(canCreateItem: true))
    }

    private func expectCleared(_ sut: SUT) async {
        #expect(sut.service.lists.isEmpty, "lists must stay empty")
        #expect(sut.service.currentListDetail == nil, "currentListDetail must stay nil")
        #expect(sut.service.error == nil, "no error may be set after the session ended")
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.isMutating == false)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty, "the cache must not receive a stale result")
        for id in ["list-a", "list-b"] {
            let cachedDetail = await sut.store.getListDetail(id: id)
            #expect(cachedDetail == nil, "the cache must not hold a detail for \(id)")
        }
    }

    // MARK: - Teardown during the archive call

    @Test("an archive that completes after teardown writes nothing, reloads nothing, sets no error", arguments: [false, true])
    func archiveCompletesAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueFetchLists(.success([archived("list-a")]))   // must never be consumed into state
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
        #expect(sut.repo.fetchListsCount == 0, "a stale archive must not even start the reload")
    }

    @Test("an archive that fails after teardown sets no error", arguments: [ListError.server, .network, .forbidden])
    func archiveFailsAfterTeardown(error: ListError) async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.failure(error), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    // MARK: - Teardown during the reload

    @Test("a reload that completes after teardown writes nothing and sets no error", arguments: [false, true])
    func reloadCompletesAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a")]), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a reload that fails after teardown sets no error and removes nothing", arguments: [ListError.server, .network])
    func reloadFailsAfterTeardown(error: ListError) async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(error), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a refetch of the open detail that completes after teardown writes nothing")
    func detailRefetchCompletesAfterTeardown() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a")]))
        sut.repo.enqueueFetchListDetail(
            .success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a", status: .archived)), held: true
        )
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    // MARK: - User switch

    @Test("user switch: A's archive reload, released late, never touches B's lists, cache or error")
    func userSwitchReloadReleasedLate() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a")]), held: true)   // user A's reload
        sut.repo.enqueueFetchLists(.success([active("list-b")]))                 // user B's load
        let archive = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()                                             // user B
        #expect(sut.service.lists.map(\.id) == ["list-b"], "precondition")
        sut.repo.releaseAll()
        await archive.value

        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's data must not replace or join B's")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.error == nil)
        #expect(sut.service.goneListId == nil)
    }

    @Test("user switch: A's archive still in flight when B loads the same id does not alter B's list")
    func userSwitchArchiveInFlight() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))                 // user A
        await sut.service.loadLists()
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))   // user B, same id
        let archive = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()
        sut.repo.releaseAll()
        await archive.value

        #expect(sut.service.lists == [active("list-a"), active("list-b")], "B's lists are untouched")
        let cached = await sut.store.getLists()
        #expect(cached == [active("list-a"), active("list-b")])
        #expect(sut.service.error == nil)
        #expect(sut.repo.fetchListsCount == 2, "A's late archive started no reload of its own")
    }

    // MARK: - Cancellation

    @Test("cancelling the caller during the archive sets no error and leaves the lists alone")
    func cancellationDuringArchive() async {
        let sut = await makeSUT(honorsCancellation: true)
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))
        await sut.service.loadLists()
        sut.repo.enqueueDeleteList(.success(()), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        task.cancel()
        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.error == nil, "cancellation is not shown to the user")
        #expect(sut.service.isMutating == false)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.goneListId == nil)
    }

    @Test("cancelling the caller during the reload sets no error and writes nothing")
    func cancellationDuringReload() async {
        let sut = await makeSUT(honorsCancellation: true)
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))
        await sut.service.loadLists()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        task.cancel()
        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.error == nil, "cancellation is not shown to the user")
        #expect(sut.service.isMutating == false)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "a cancelled reload writes nothing")
        #expect(sut.service.goneListId == nil)
    }

    @Test("a repository that fails the archive with CancellationError sets no error and changes nothing")
    func repositoryCancellationOnArchive() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))
        await sut.service.loadLists()
        sut.repo.enqueueDeleteList(.failure(CancellationError()))

        _ = try? await sut.service.deleteList(id: "list-a")

        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    @Test("a repository that fails the reload with CancellationError sets no error")
    func repositoryCancellationOnReload() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))
        await sut.service.loadLists()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(CancellationError()))

        _ = try? await sut.service.deleteList(id: "list-a")

        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - After teardown the next session starts clean

    @Test("after an archive discarded by teardown, the next load goes to the repository and sees the list as the server says")
    func nextLoadAfterDiscardedArchive() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()), held: true)
        let task = Task { _ = try? await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))

        await sut.service.loadLists()

        #expect(sut.service.activeLists.map(\.id) == ["list-a", "list-b"], "the stale archive left no record")
        #expect(sut.service.error == nil)
    }
}
