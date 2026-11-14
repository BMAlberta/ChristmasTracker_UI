//
//  ListServiceArchiveBatchTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-D2: ListService.freshLists() and ListService.archiveLists(ids:).
//
//  freshLists always fetches (never the cache), is session-safe, writes `lists` and the cache,
//  publishes no shared error and throws the typed ListError on failure.
//  archiveLists is sequential, stops at the first failure, counts a 404 as archived, reloads the
//  lists exactly once at the end (also after a failure, not for empty input or an ended session),
//  and publishes no shared error.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService freshLists and archiveLists", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchiveBatchTests {

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

    // MARK: - freshLists

    @Test("freshLists fetches from the repository even when the cache is filled, and returns the lists")
    func freshListsIgnoresCache() async throws {
        let sut = await makeSUT()
        await sut.store.setLists([active("cached")])
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))

        let fetched = try await sut.service.freshLists()

        #expect(fetched.map(\.id) == ["list-a", "list-b"])
        #expect(sut.repo.fetchListsCount == 1)
    }

    @Test("freshLists writes the result to lists and the cache and publishes no error")
    func freshListsWritesStateAndCache() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))

        _ = try await sut.service.freshLists()

        #expect(sut.service.lists.map(\.id) == ["list-a"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("every freshLists call fetches again")
    func freshListsFetchesEveryTime() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))

        _ = try await sut.service.freshLists()
        let second = try await sut.service.freshLists()

        #expect(sut.repo.fetchListsCount == 2)
        #expect(second.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
    }

    @Test(
        "a failed freshLists throws the typed ListError and leaves lists and error untouched",
        arguments: [ListError.network, .server, .forbidden, .unauthorized]
    )
    func freshListsFailure(error: ListError) async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a")]))
        await sut.service.refreshLists()
        sut.repo.enqueueFetchLists(.failure(error))

        await #expect(throws: error) {
            _ = try await sut.service.freshLists()
        }

        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("freshLists after the session was cleared mid-fetch throws CancellationError and writes nothing", arguments: [false, true])
    func freshListsSessionCleared(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchLists(.success([active("list-a")]), held: true)
        let task = Task { () -> Bool in
            do {
                _ = try await sut.service.freshLists()
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        let threwCancellation = await task.value

        #expect(threwCancellation)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.anyLoadFailure == nil)
        let cached = await sut.store.getLists()
        #expect(cached.isEmpty)
    }

    // MARK: - archiveLists: success

    @Test("archiveLists archives every id, reloads once and reports the full count")
    func archiveAll() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-b"), archived("list-c")]))

        let result = await sut.service.archiveLists(ids: ["list-a", "list-b", "list-c"])

        #expect(result == ArchiveBatchResult(archivedCount: 3, totalCount: 3, failedId: nil, failure: nil))
        #expect(sut.repo.deleteListCount == 3)
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.archivedLists.map(\.id) == ["list-a", "list-b", "list-c"])
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("archiveLists goes through the ids sequentially, in order")
    func archiveInOrder() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueFetchLists(.success([]))
        let task = Task { await sut.service.archiveLists(ids: ["list-c", "list-a", "list-b"]) }

        let first = await sut.repo.nextHeldCall()
        #expect(first == .deleteList("list-c"))
        #expect(sut.repo.deleteListCount == 1, "the second archive must not start before the first finished")
        sut.repo.releaseNext()
        let second = await sut.repo.nextHeldCall()
        #expect(second == .deleteList("list-a"))
        #expect(sut.repo.deleteListCount == 2)
        sut.repo.releaseNext()
        let third = await sut.repo.nextHeldCall()
        #expect(third == .deleteList("list-b"))
        #expect(sut.repo.fetchListsCount == 0, "the reload comes only after the last archive")
        sut.repo.releaseNext()
        let result = await task.value

        #expect(result.archivedCount == 3)
        #expect(sut.repo.fetchListsCount == 1)
    }

    @Test("a 404 on an archive counts as archived and the batch continues")
    func notFoundCountsAsArchived() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.failure(ListError.notFound))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-c")]))

        let result = await sut.service.archiveLists(ids: ["list-a", "list-b", "list-c"])

        #expect(result == ArchiveBatchResult(archivedCount: 3, totalCount: 3, failedId: nil, failure: nil))
        #expect(sut.repo.deleteListCount == 3)
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - archiveLists: empty input

    @Test("archiveLists with no ids does nothing: no archive, no reload")
    func archiveNothing() async {
        let sut = await makeSUT()

        let result = await sut.service.archiveLists(ids: [])

        #expect(result == ArchiveBatchResult(archivedCount: 0, totalCount: 0, failedId: nil, failure: nil))
        #expect(sut.repo.deleteListCount == 0)
        #expect(sut.repo.fetchListsCount == 0)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - archiveLists: failures

    @Test("a failure on the second of three stops the batch, reloads once and names the failed id")
    func stopsAtFirstFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.failure(ListError.forbidden))
        sut.repo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b"), active("list-c")]))

        let result = await sut.service.archiveLists(ids: ["list-a", "list-b", "list-c"])

        #expect(result == ArchiveBatchResult(archivedCount: 1, totalCount: 3, failedId: "list-b", failure: .forbidden))
        #expect(sut.repo.deleteListCount == 2, "the third id must stay untouched")
        #expect(sut.repo.fetchListsCount == 1, "one reload at the end, also after a failure")
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        #expect(sut.service.anyLoadFailure == nil, "the batch publishes nothing")
        #expect(sut.service.isMutating == false)
    }

    @Test("a failure on the first id (zero progress) still reloads once")
    func failureWithZeroProgressReloads() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.failure(ListError.network))
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))

        let result = await sut.service.archiveLists(ids: ["list-a", "list-b"])

        #expect(result == ArchiveBatchResult(archivedCount: 0, totalCount: 2, failedId: "list-a", failure: .network))
        #expect(sut.repo.deleteListCount == 1)
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test(
        "every failure kind is reported in the result and never published as a load failure",
        arguments: [ListError.forbidden, .unauthorized, .rateLimited(retryAfter: 5), .network, .invalidResponse, .server]
    )
    func failureKinds(error: ListError) async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.failure(error))
        sut.repo.enqueueFetchLists(.success([]))

        let result = await sut.service.archiveLists(ids: ["list-a"])

        #expect(result.failure == error)
        #expect(result.failedId == "list-a")
        #expect(result.archivedCount == 0)
        #expect(result.totalCount == 1)
        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - archiveLists: session safety

    @Test("a session cleared during the first archive reloads nothing, writes nothing, reports nothing done", arguments: [false, true])
    func sessionClearedDuringFirstArchive(honorsCancellation: Bool) async {
        let sut = await makeSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.repo.enqueueFetchLists(.success([archived("list-a")]))   // must never be consumed
        let task = Task { await sut.service.archiveLists(ids: ["list-a", "list-b"]) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result.archivedCount == 0)
        #expect(result.totalCount == 2)
        #expect(sut.repo.deleteListCount == 1, "a cleared session must not start the next archive")
        #expect(sut.repo.fetchListsCount == 0, "a cleared session must not reload")
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
        let cached = await sut.store.getLists()
        #expect(cached.isEmpty)
    }

    @Test("a session cleared after the first archive stops the batch and reports what had completed")
    func sessionClearedBetweenArchives() async {
        let sut = await makeSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.success(()), held: true)
        sut.repo.enqueueDeleteList(.success(()))   // must never be consumed
        sut.repo.enqueueFetchLists(.success([archived("list-a")]))   // must never be consumed
        let task = Task { await sut.service.archiveLists(ids: ["list-a", "list-b", "list-c"]) }
        let held = await sut.repo.nextHeldCall()
        #expect(held == .deleteList("list-b"))

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        let result = await task.value

        #expect(result.archivedCount == 1, "list-a had completed before the session ended")
        #expect(result.totalCount == 3)
        #expect(sut.repo.deleteListCount == 2)
        #expect(sut.repo.fetchListsCount == 0)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.anyLoadFailure == nil)
        let cached = await sut.store.getLists()
        #expect(cached.isEmpty)
    }
}
