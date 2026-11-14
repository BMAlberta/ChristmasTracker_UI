//
//  ListServiceArchiveTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListService.deleteList(id:) ARCHIVES.
//
//  - On success it records NO removal, performs a FRESH repository.fetchLists() (never the cache),
//    writes `lists` and the cache from that result (the list shows under archivedLists with the
//    server's flags) and, when the archived list is the open detail, refetches that detail.
//  - A load, refresh or detail load that STARTED BEFORE the archive completed does not write the
//    lists, the detail or the cache (discarded, no error); one that starts after is applied.
//  - If the archive succeeded but the reload fails, deleteList returns normally, the list is
//    removed from `lists` and the cache until the next successful load, and `error` is set.
//  - If the archive call itself fails, nothing changes and the typed error is thrown.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//  Session safety lives in ListServiceArchiveSessionSafetyTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService archive", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchiveTests {

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

    /// The flags an owner of a child list has before archiving.
    private let ownerFlags = ListFixtures.Flags(
        isRecipient: false, canSeeGiftActivity: true, canPurchase: true, canAddOffList: false,
        canSeeOffList: true, canCreateItem: true, canSeeMembers: true, canEditList: true,
        canDeleteList: true, canManageMembers: true, canSetCoOwner: true, canLeaveList: false
    )

    /// What the server sends after archiving: the four management flags false, the rest unchanged.
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

    /// Lists [list-a, list-b] are loaded.
    private func loadedSUT() async -> SUT {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))
        await sut.service.loadLists()
        return sut
    }

    // MARK: - Success: the lists are reloaded from the server

    @Test("archiving reloads the lists with a fresh fetch and the list shows under archivedLists with the server's flags")
    func archiveReloadsFromServer() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.repo.deleteListCount == 1)
        #expect(sut.repo.fetchListsCount == 2, "a fresh GET /lists, not the cache")
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "the list is not removed")
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        #expect(sut.service.activeLists.map(\.id) == ["list-b"])
        let entry = try #require(sut.service.archivedLists.first)
        #expect(entry == archived("list-a"), "the entry is exactly what the server sent")
        #expect(entry.capabilities.canCreateItem, "item flags survive the archive")
        #expect(!entry.capabilities.canEditList)
        #expect(!entry.capabilities.canDeleteList)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("the reloaded lists are written to the cache")
    func archiveWritesCache() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        let cached = await sut.store.getLists()
        #expect(cached == [archived("list-a"), active("list-b")])
    }

    @Test("archiving does not synthesize the status locally: the list is exactly what the server returned")
    func noLocalStatusSynthesis() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        // A contrived server answer: the list comes back still ACTIVE. The client shows what it got.
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.archivedLists.isEmpty)
        #expect(sut.service.activeLists.map(\.id) == ["list-a", "list-b"])
    }

    @Test("archiving records no removal: it does not mark the list gone and a later load is not filtered")
    func archiveRecordsNoRemoval() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        try await sut.service.deleteList(id: "list-a")
        #expect(sut.service.goneListId == nil)

        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        await sut.service.refreshLists()

        #expect(sut.service.archivedLists.map(\.id) == ["list-a"], "a later refresh shows the archived list")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    @Test("a loadListDetail after the archive shows the archived list's detail")
    func detailLoadAfterArchiveShowsDetail() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(archivedDetail("list-a")))
        try await sut.service.deleteList(id: "list-a")

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail == archivedDetail("list-a"))
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.goneListId == nil)
    }

    // MARK: - The open detail is refetched

    @Test("archiving the open list refetches its detail so the flags refresh, and caches it")
    func archiveRefetchesOpenDetail() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(activeDetail("list-a")))
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.currentListDetail == activeDetail("list-a"), "precondition")
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(archivedDetail("list-a")))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.repo.fetchListDetailCount == 2, "the open detail is refetched once")
        #expect(sut.service.currentListDetail == archivedDetail("list-a"))
        #expect(sut.service.currentListDetail?.status == .archived)
        #expect(sut.service.currentListDetail?.capabilities.canEditList == false)
        #expect(sut.service.currentListDetail?.capabilities.canCreateItem == true)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == archivedDetail("list-a"))
        #expect(sut.service.goneListId == nil, "archiving is not a gone-list drop")
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("archiving a list that is not the open one does not refetch the open detail")
    func archiveOfOtherListKeepsOpenDetail() async throws {
        let sut = await loadedSUT()
        let open = activeDetail("list-b")
        sut.repo.enqueueFetchListDetail(.success(open))
        await sut.service.loadListDetail(id: "list-b")
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.currentListDetail == open)
        #expect(sut.repo.fetchListDetailCount == 1, "no refetch of an unrelated detail")
    }

    @Test("archiving with no open detail refetches no detail")
    func archiveWithoutOpenDetailRefetchesNone() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.repo.fetchListDetailCount == 0)
        #expect(sut.service.currentListDetail == nil)
    }

    // MARK: - Loads that started before the archive completed are discarded

    @Test("a refreshLists in flight when the archive completes cannot show the list as active afterwards")
    func inFlightRefreshIsDiscarded() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]), held: true)   // stale: still active
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))             // the archive reload
        let refresh = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await refresh.value

        #expect(sut.service.archivedLists.map(\.id) == ["list-a"], "the stale refresh must not resurrect the list as active")
        #expect(sut.service.activeLists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached == [archived("list-a"), active("list-b")], "the stale result must not reach the cache")
        #expect(sut.service.anyLoadFailure == nil, "a discarded result records no failure")
        #expect(sut.service.isRefreshing == false)
    }

    @Test("a loadLists in flight when the archive completes cannot show the list as active afterwards")
    func inFlightLoadIsDiscarded() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]), held: true)   // stale: still active
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))             // the archive reload
        let load = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        #expect(sut.service.activeLists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached == [archived("list-a"), active("list-b")])
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a loadListDetail in flight when the archive completes writes no detail and no cache and sets no error")
    func inFlightDetailIsDiscarded() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(activeDetail("list-a")), held: true)   // stale: still active
        sut.repo.enqueueFetchListDetail(.success(archivedDetail("list-a")))             // the refetch for the discarded load
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        let load = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        try await sut.service.deleteList(id: "list-a")
        sut.repo.releaseAll()
        await load.value

        #expect(sut.service.currentListDetail != activeDetail("list-a"), "the stale active detail must not be shown")
        #expect(sut.service.currentListDetail == archivedDetail("list-a"), "the screen gets the refetched detail")
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == archivedDetail("list-a"), "the stale active detail must not be cached")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
    }

    @Test("a load in flight before and a refresh started after the archive completed: only the earlier one is discarded")
    func onlyTheEarlierLoadIsDiscarded() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([active("list-a"), active("list-b")]), held: true)             // started before
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))                       // the archive reload
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b"), active("list-c")]), held: true)   // started after
        let earlier = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        try await sut.service.deleteList(id: "list-a")
        let later = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()

        sut.repo.release(at: 0)
        await earlier.value
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "the earlier result is discarded")
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])

        sut.repo.release(at: 1)
        await later.value
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b", "list-c"], "the later result is applied normally")
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b", "list-c"])
    }

    @Test("a refresh that starts after the archive completed is applied normally")
    func laterRefreshIsApplied() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b"), active("list-c")]))

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b", "list-c"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("a detail load that starts after the archive completed is applied normally")
    func laterDetailLoadIsApplied() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchListDetail(.success(archivedDetail("list-a")))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail == archivedDetail("list-a"))
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == archivedDetail("list-a"))
    }

    // MARK: - The archive succeeded but the reload fails

    // REPLACED (UX1a U2): the old test asserted that the follow-up reload failure was published in the
    // shared `error`. That behavior is removed deliberately: the failure is logged by operation name
    // only, nothing is published, and the mutation returns normally.
    @Test("when the reload fails after a successful archive deleteList returns normally and publishes nothing")
    func reloadFailureAfterArchive() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        try await sut.service.deleteList(id: "list-a")   // must not throw

        #expect(sut.service.lists.map(\.id) == ["list-b"], "removed until the next successful load, no local status synthesis")
        #expect(sut.service.archivedLists.isEmpty)
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.service.listsLoadFailure == nil, "the follow-up reload failure is not published")
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.repo.deleteListCount == 1)
        #expect(sut.repo.fetchListsCount == 2, "the reload was attempted")
        #expect(sut.service.isMutating == false)
    }

    // REPLACED (UX1a U2): was "the reload error is the typed error of the reload" (stored in `error`).
    @Test("a typed reload failure after a successful archive is published nowhere", arguments: [
        ListError.network, .server, .rateLimited(retryAfter: 3), .invalidResponse, .unauthorized
    ])
    func reloadFailureIsNotPublished(error: ListError) async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(error))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
    }

    @Test("after a failed reload the next successful refresh brings the archived list back")
    func nextRefreshRecoversAfterFailedReload() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        try await sut.service.deleteList(id: "list-a")
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        await sut.service.refreshLists()

        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        #expect(sut.service.activeLists.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - The archive call itself fails

    // REWRITTEN (UX1a U2): throws the typed error and publishes nothing (was: also stored in `error`).
    @Test("a failed archive changes nothing, throws the typed error and publishes nothing", arguments: [
        ListError.forbidden, .network, .server, .rateLimited(retryAfter: 3), .unauthorized
    ])
    func failedArchiveChangesNothing(error: ListError) async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueFetchListDetail(.success(activeDetail("list-a")))
        await sut.service.loadListDetail(id: "list-a")
        let listsBefore = sut.service.lists
        let detailBefore = sut.service.currentListDetail
        sut.repo.enqueueDeleteList(.failure(error))

        await #expect(throws: error) {
            try await sut.service.deleteList(id: "list-a")
        }

        #expect(sut.service.lists == listsBefore)
        #expect(sut.service.currentListDetail == detailBefore)
        #expect(sut.repo.fetchListsCount == 1, "no reload after a failed archive")
        #expect(sut.repo.fetchListDetailCount == 1, "no detail refetch after a failed archive")
        let cached = await sut.store.getLists()
        #expect(cached == listsBefore)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.isMutating == false)
    }

    // REWRITTEN (UX1a U2): a failed archive throws and a retry succeeds; neither publishes anything.
    @Test("a failed archive followed by a successful retry publishes nothing at either step")
    func successAfterFailurePublishesNothing() async throws {
        let sut = await loadedSUT()
        sut.repo.enqueueDeleteList(.failure(ListError.network))
        await #expect(throws: ListError.network) {
            try await sut.service.deleteList(id: "list-a")
        }
        #expect(sut.service.anyLoadFailure == nil, "precondition: the failure was only thrown")
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([archived("list-a"), active("list-b")]))

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
    }
}
