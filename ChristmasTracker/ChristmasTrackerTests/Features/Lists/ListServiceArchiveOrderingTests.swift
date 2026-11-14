//
//  ListServiceArchiveOrderingTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A fix pass:
//  - two archives in flight: a reload that belongs to an earlier archive never overwrites the
//    lists or the cache with a result that may predate a later archive, and isMutating stays true
//    until the last overlapping mutation finishes;
//  - an archive of list X discards only the in-flight detail loads of X, never those of another
//    list, and an open (or loading) X ends up with a refreshed detail.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService archive ordering", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchiveOrderingTests {

    // MARK: - Factory and fixtures

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
    }

    private func makeSUT() -> SUT {
        let repo = GatedListRepository()
        let store = ListDataStore()
        return SUT(service: ListService(repository: repo, dataStore: store), repo: repo, store: store)
    }

    private let ownerFlags = ListFixtures.Flags(
        isRecipient: false, canSeeGiftActivity: true, canPurchase: true, canAddOffList: false,
        canSeeOffList: true, canCreateItem: true, canSeeMembers: true, canEditList: true,
        canDeleteList: true, canManageMembers: true, canSetCoOwner: true, canLeaveList: false
    )

    private var archivedFlags: ListFixtures.Flags {
        var flags = ownerFlags
        flags.canEditList = false
        flags.canDeleteList = false
        flags.canManageMembers = false
        flags.canSetCoOwner = false
        return flags
    }

    private func active(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", flags: ownerFlags)
    }

    private func archived(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: .archived, flags: archivedFlags)
    }

    private func activeDetail(_ id: String) -> ListDetail {
        ListFixtures.listDetail(id: id, name: "Name of \(id)", flags: ownerFlags)
    }

    private func archivedDetail(_ id: String) -> ListDetail {
        ListFixtures.listDetail(id: id, name: "Name of \(id)", status: .archived, flags: archivedFlags)
    }

    private func loadedSUT() async -> SUT {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))
        await sut.service.loadLists()
        return sut
    }

    // MARK: - Two archives in flight

    @Test("two overlapping archives: the earlier archive's reload, answered last, does not overwrite the later result")
    func earlierReloadAnsweredLastIsDiscarded() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))   // archive A
        sut.repo.enqueueDeleteList(.success(()))   // archive B
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]), held: true)   // A's reload (predates B)
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-b")]))             // B's reload
        let archiveA = Task { try await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-b")
        #expect(sut.service.archivedLists.map(\.id) == ["list-a", "list-b"], "precondition: B's reload applied")
        #expect(sut.service.isMutating, "archive A is still running")

        sut.repo.releaseAll()
        try await archiveA.value

        #expect(sut.service.archivedLists.map(\.id) == ["list-a", "list-b"], "A's older reload must not bring list-b back")
        #expect(sut.service.activeLists.isEmpty)
        let cached = await sut.store.getLists()
        #expect(cached == [archived("list-a"), archived("list-b")], "the older result must not reach the cache")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false, "false once the last mutation finished")
    }

    @Test("two overlapping archives: the earlier archive's reload FAILING late sets no error and removes nothing")
    func earlierReloadFailingLateIsSilent() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)                        // A's reload
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-b")]))             // B's reload
        let archiveA = Task { try await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()
        try await sut.service.deleteList(id: "list-b")

        sut.repo.releaseAll()
        try await archiveA.value

        #expect(sut.service.archivedLists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.anyLoadFailure == nil, "a superseded reload reports nothing")
        let cached = await sut.store.getLists()
        #expect(cached == [archived("list-a"), archived("list-b")])
    }

    @Test("isMutating stays true while another mutation runs, then clears")
    func isMutatingCountsOverlap() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()), held: true)   // A held at the archive call
        sut.repo.enqueueDeleteList(.success(()))               // B
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-b")]))   // B's reload
        sut.repo.enqueueFetchLists(.success([archived("list-a"), archived("list-b")]))   // A's reload
        let archiveA = Task { try await sut.service.deleteList(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-b")
        #expect(sut.service.isMutating, "the first finisher must not clear the flag while A runs")

        sut.repo.releaseAll()
        try await archiveA.value
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Detail loads are discarded per list

    @Test("archiving list X applies an in-flight detail load of another list")
    func unrelatedDetailLoadIsApplied() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(activeDetail("list-b")), held: true)
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        let load = Task { await sut.service.loadListDetail(id: "list-b") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.currentListDetail == activeDetail("list-b"), "must not strand the screen on Loading")
        let cachedDetail = await sut.store.getListDetail(id: "list-b")
        #expect(cachedDetail == activeDetail("list-b"))
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
    }

    @Test("a discarded in-flight detail load of the archived list leaves the screen with a refreshed detail")
    func discardedDetailLoadOfArchivedListIsRefetched() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(activeDetail("list-a")), held: true)   // stale: still active
        sut.repo.enqueueFetchListDetail(.success(archivedDetail("list-a")))             // the refetch
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        let load = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.currentListDetail == archivedDetail("list-a"), "refreshed, never the stale active detail")
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == archivedDetail("list-a"))
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.repo.fetchListDetailCount == 2)
    }
}
