//
//  ListServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/14/26.
//
//  Story I3a-L2 changes (named):
//  - REWRITTEN testRefreshLists: the real 100 ms Task.sleep is gone. It now uses a scripted
//    repository and asserts the second fetch's result and the fetch count (deterministic).
//  - EDITED (ListError old cases removed): FixedListRepository threw .createFailed,
//    .updateFailed and .deleteFailed; each now throws .server (same meaning).
//  - EDITED: every test that uses MockListRepository sets its delay to 0 so no test waits on
//    the mock's built-in sleep.
//  - STRENGTHENED: testErrorHandling and testLoadListsFailureResetsIsLoading also assert the
//    typed error (.server) now that the mock throws it.
//  - ADDED: archived lists dropped on load and refresh (DRAFT kept), delete removes locally and
//    stays hidden after a refresh, create and update take the returned detail (flags) with no
//    refetch, typed repository errors become the service error, cancellation sets no error.
//  Session-safety tests (teardown during in-flight work, user switch) live in
//  ListServiceSessionSafetyTests.swift.
//
//  Story I3c-A changes (named; reason for each: decision "archived lists stay visible and archive
//  reloads from the server", L16): the tests that asserted archived lists are hidden, or that
//  deleteList removes locally / records a removal, now assert the new behavior. Each is marked
//  "CHANGED (I3c-A)" at the test. New archive behavior lives in ListServiceArchiveTests,
//  ListServiceArchivedListsTests, ListServiceArchivedReadOnlyTests and
//  ListServiceArchiveSessionSafetyTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService Tests", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceTests {

    // MARK: - Factory

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

    private func list(
        _ id: String,
        status: ListStatus = .active,
        flags: ListFixtures.Flags = ListFixtures.Flags()
    ) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: status, flags: flags)
    }

    private let editableFlags = ListFixtures.Flags(
        canCreateItem: true, canSeeMembers: true, canEditList: true, canDeleteList: true, canManageMembers: true
    )

    // MARK: - Basic loading (MockListRepository, no delay)

    @Test("Load lists fetches from repository and caches")
    func testLoadLists() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.lists.count == 3)
        #expect(service.isLoadingLists == false)
        #expect(service.listsLoadFailure == nil)
        // Verify cached
        let cached = await dataStore.getLists()
        #expect(cached.count == 3)
    }

    // REWRITTEN (I3a-L2): deterministic. The old version slept 100 ms so the two Date() stamps
    // differed. This one scripts two different results and asserts on those and the fetch count.
    @Test("Refresh lists forces fresh fetch")
    func testRefreshLists() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))

        await sut.service.loadLists()
        let firstLoad = sut.service.lastUpdated
        #expect(sut.service.lists.map(\.id) == ["list-a"])

        await sut.service.refreshLists()

        #expect(sut.repo.fetchListsCount == 2, "refresh must always go to the repository")
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        let secondLoad = sut.service.lastUpdated
        #expect(firstLoad != nil)
        #expect(secondLoad != nil)
        if let firstLoad, let secondLoad {
            #expect(secondLoad >= firstLoad)
        }
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.isRefreshing == false)
    }

    @Test("Create list adds to collection")
    func testCreateList() async throws {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let initialCount = service.lists.count
        let input = CreateListInput(
            recipientId: "test-recipient",
            year: 2024,
            name: "Test List",
            theme: "Test Theme",
            visibility: .private
        )
        try await service.createList(input)
        #expect(service.lists.count == initialCount + 1)
        #expect(service.lists.contains(where: { $0.name == "Test List" }))
    }

    @Test("Update list modifies existing")
    func testUpdateList() async throws {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let listId = try #require(service.lists.first?.id)
        let input = UpdateListInput(
            name: "Updated Name",
            theme: nil,
            visibility: nil
        )
        try await service.updateList(id: listId, input)
        #expect(service.lists.contains(where: { $0.id == listId && $0.name == "Updated Name" }))
    }

    // CHANGED (I3c-A, decision "archive reloads from the server"): was "Delete list removes from
    // collection" (count - 1, gone from lists and cache). The mock now archives, the service
    // reloads, so the list stays and shows as ARCHIVED with the management flags false.
    @Test("Delete list archives: the list stays in the collection and the cache as ARCHIVED")
    func testDeleteList() async throws {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let initialCount = service.lists.count
        let listToDelete = try #require(service.lists.first?.id)
        try await service.deleteList(id: listToDelete)
        #expect(service.lists.count == initialCount)
        let entry = try #require(service.lists.first(where: { $0.id == listToDelete }))
        #expect(entry.status == .archived)
        #expect(!entry.capabilities.canEditList)
        #expect(!entry.capabilities.canDeleteList)
        #expect(service.archivedLists.map(\.id) == [listToDelete])
        let cached = await dataStore.getLists()
        #expect(cached.first(where: { $0.id == listToDelete })?.status == .archived)
    }

    // REWRITTEN (I3a-L1): the owned/shared filter is a display grouping decided by
    // ListPermissions.category (management flags), never by myRole.
    @Test("Filter owned shows only lists whose management flags make them owned")
    func testFilterOwned() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        service.currentFilter = .owned
        #expect(service.filteredLists.allSatisfy {
            ListPermissions($0.capabilities).category == .owned
        })
    }

    // REWRITTEN (I3a-L1): flag-based, see testFilterOwned.
    @Test("Filter shared shows only lists whose management flags do not make them owned")
    func testFilterShared() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        service.currentFilter = .shared
        #expect(service.filteredLists.allSatisfy {
            ListPermissions($0.capabilities).category == .shared
        })
    }

    // ADDED (I3a-L1): deterministic membership with a fixed set of lists, role deliberately
    // contradicting the flags so a role-based filter fails.
    @Test("Filter owned and shared split a known set of lists by flags, not by role")
    func testFilterSplitsByFlagsNotRole() async {
        let managing = ListFixtures.Flags(canEditList: true, canDeleteList: true, canManageMembers: true)
        let deleteOnly = ListFixtures.Flags(canDeleteList: true)
        let none = ListFixtures.Flags()
        let lists = [
            ListFixtures.giftList(id: "a-owner", myRole: .owner, flags: managing),
            ListFixtures.giftList(id: "b-coowner", myRole: .coOwner, flags: managing),
            ListFixtures.giftList(id: "c-viewer-with-delete", myRole: .viewer, flags: deleteOnly),
            ListFixtures.giftList(id: "d-owner-no-flags", myRole: .owner, flags: none),
            ListFixtures.giftList(id: "e-member", myRole: .member, flags: none),
            ListFixtures.giftList(id: "f-viewer", myRole: .viewer, flags: none)
        ]
        let service = ListService(repository: FixedListRepository(lists: lists), dataStore: ListDataStore())
        await service.loadLists()

        service.currentFilter = .all
        #expect(service.filteredLists.map(\.id) == ["a-owner", "b-coowner", "c-viewer-with-delete",
                                                    "d-owner-no-flags", "e-member", "f-viewer"])
        service.currentFilter = .owned
        #expect(service.filteredLists.map(\.id) == ["a-owner", "b-coowner", "c-viewer-with-delete"])
        service.currentFilter = .shared
        #expect(service.filteredLists.map(\.id) == ["d-owner-no-flags", "e-member", "f-viewer"])
    }

    @Test("Load detail fetches and caches")
    func testLoadListDetail() async throws {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let listId = try #require(service.lists.first?.id)
        await service.loadListDetail(id: listId)
        #expect(service.currentListDetail != nil)
        #expect(service.currentListDetail?.id == listId)
        // Verify cached
        let cachedDetail = await dataStore.getListDetail(id: listId)
        #expect(cachedDetail != nil)
    }

    // STRENGTHENED (I3a-L2): also asserts the typed error.
    // REWRITTEN (UX1a U2): the failure of a lists load is the returned value and listsLoadFailure.
    @Test("Error handling sets appropriate error")
    func testErrorHandling() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        let failure = await service.loadLists()
        #expect(failure == .server)
        #expect(service.listsLoadFailure != nil)
        #expect(service.listsLoadFailure == .server)
        #expect(service.detailLoadFailure == nil)
        #expect(service.lists.isEmpty)
    }

    // REWRITTEN (I3b-K0): isLoading is replaced by isLoadingLists.
    @Test("Failed repository fetch resets isLoadingLists and sets the lists load failure")
    func testLoadListsFailureResetsIsLoadingLists() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.isLoadingLists == false)
        #expect(service.listsLoadFailure != nil)
    }

    // MARK: - Cache stale-data: create then loadLists

    @Test("loadLists after createList reflects the new list from cache")
    func testLoadListsAfterCreateReflectsNewList() async throws {
        let mockRepo = MockListRepository(withMockData: true)
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)

        await service.loadLists()
        let initialCount = service.lists.count

        let input = CreateListInput(
            recipientId: "r-test",
            year: 2025,
            name: "Cache Test List",
            theme: nil,
            visibility: .private
        )
        try await service.createList(input)

        // Second service shares same cache — simulates another view reloading
        let service2 = ListService(repository: mockRepo, dataStore: dataStore)
        await service2.loadLists()

        #expect(service2.lists.count == initialCount + 1)
        #expect(service2.lists.contains(where: { $0.name == "Cache Test List" }))
    }

    // MARK: - Cache stale-data: delete then loadLists

    // CHANGED (I3c-A, decision "archive reloads from the server"): was "loadLists after deleteList
    // does not serve the deleted list from cache" (absent). The cache now holds the reloaded list as
    // ARCHIVED, so a second service sees it as archived and never as active.
    @Test("loadLists after deleteList serves the list from cache as ARCHIVED, never as active")
    func testLoadListsAfterDeleteServesArchivedList() async throws {
        let mockRepo = MockListRepository(withMockData: true)
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)

        await service.loadLists()
        let listToDelete = try #require(service.lists.first?.id)

        try await service.deleteList(id: listToDelete)

        // Second service shares same cache
        let service2 = ListService(repository: mockRepo, dataStore: dataStore)
        await service2.loadLists()

        let seen = try #require(service2.lists.first(where: { $0.id == listToDelete }))
        #expect(seen.status == .archived)
        #expect(!service2.activeLists.contains(where: { $0.id == listToDelete }))
    }

    // MARK: - Cache stale-data: logout then loadLists for another user

    @Test("loadLists after logout does not serve previous user's cached lists")
    func testLoadListsAfterLogoutFetchesFreshData() async {
        let dataStore = ListDataStore()

        // Session 1: populate cache with 3 lists
        let repo1 = MockListRepository(withMockData: true)
        await repo1.setDelay(0)
        let service1 = ListService(repository: repo1, dataStore: dataStore)
        await service1.loadLists()
        #expect(service1.lists.count == 3)

        // Logout must clear the cache so the next user gets a fresh fetch
        await service1.clearCache()

        // Session 2: different user with no lists
        let repo2 = MockListRepository(withMockData: false)
        await repo2.setDelay(0)
        let service2 = ListService(repository: repo2, dataStore: dataStore)
        await service2.loadLists()

        // Without clearCache() the stale 3 lists would be served from cache
        #expect(service2.lists.isEmpty)
    }

    // MARK: - ADDED (I3a-L2): archived lists are hidden, DRAFT is kept

    // CHANGED (I3c-A, decision "archived lists stay visible"): was "loadLists drops ARCHIVED lists
    // and keeps ACTIVE and DRAFT ones". Now every list is kept, in `lists` and in the cache.
    @Test("loadLists keeps ARCHIVED lists together with ACTIVE and DRAFT ones")
    func loadKeepsArchivedAndDraft() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([
            list("list-active"), list("list-draft", status: .draft), list("list-archived", status: .archived)
        ]))

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-draft", "list-archived"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-active", "list-draft", "list-archived"], "archived lists are cached too")
        #expect(sut.service.listsLoadFailure == nil)
    }

    // CHANGED (I3c-A): was "refreshLists drops ARCHIVED lists and keeps ACTIVE and DRAFT ones".
    @Test("refreshLists keeps ARCHIVED lists together with ACTIVE and DRAFT ones")
    func refreshKeepsArchivedAndDraft() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-active")]))
        sut.repo.enqueueFetchLists(.success([
            list("list-active"), list("list-draft", status: .draft), list("list-archived", status: .archived)
        ]))
        await sut.service.loadLists()

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-draft", "list-archived"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-active", "list-draft", "list-archived"])
    }

    // CHANGED (I3c-A): was "a response with only ARCHIVED lists leaves the list empty without an error".
    @Test("a response with only ARCHIVED lists keeps them, without an error")
    func onlyArchivedKeepsThem() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-archived", status: .archived)]))

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-archived"])
        #expect(sut.service.listsLoadFailure == nil)
    }

    // MARK: - ADDED (I3a-L2 fix round): the cached branch hides ARCHIVED too

    // CHANGED (I3c-A, decision "archived lists stay visible"): was "loadLists on the cached branch
    // does not expose an ARCHIVED summary already in the cache". The cached branch keeps it.
    @Test("loadLists on the cached branch exposes an ARCHIVED summary already in the cache")
    func cachedBranchKeepsArchivedOnly() async {
        let sut = makeSUT()
        await sut.store.setLists([list("list-archived", status: .archived)])

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-archived"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-archived"])
        #expect(sut.service.listsLoadFailure == nil)
    }

    // CHANGED (I3c-A): was "... shows only the non-archived part of a mixed cache, without fetching".
    @Test("loadLists on the cached branch shows all of a mixed cache, without fetching")
    func cachedBranchKeepsArchivedInMixedCache() async {
        let sut = makeSUT()
        await sut.store.setLists([
            list("list-active"), list("list-archived", status: .archived), list("list-draft", status: .draft)
        ])

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-archived", "list-draft"])
        #expect(sut.repo.fetchListsCount == 0, "a fresh non-empty cache is served without a fetch")
        #expect(sut.service.listsLoadFailure == nil)
    }

    // MARK: - ADDED (I3a-L2): delete removes locally and stays hidden

    // CHANGED (I3c-A, decision "archive reloads from the server"): was "deleteList removes the list
    // from lists and the cache without refetching". Archiving now reloads with a fresh fetch and the
    // list stays, as ARCHIVED, with the server's flags.
    @Test("deleteList archives: it reloads the lists with a fresh fetch and keeps the list as ARCHIVED")
    func deleteArchivesAndReloads() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        await sut.service.loadLists()

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
        #expect(cached.first?.status == .archived)
        #expect(sut.repo.deleteListCount == 1)
        #expect(sut.repo.fetchListsCount == 2, "archive reloads from the server")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // CHANGED (I3c-A): was "deleteList clears currentListDetail and the cached detail when it is that
    // list". The open detail is now refetched (flags refresh) instead of cleared.
    @Test("deleteList refetches currentListDetail and the cached detail when it is that list")
    func deleteRefetchesCurrentDetail() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a")))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        let archivedDetail = ListFixtures.listDetail(id: "list-a", name: "Name of list-a", status: .archived)
        sut.repo.enqueueFetchListDetail(.success(archivedDetail))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.currentListDetail?.id == "list-a")

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.currentListDetail == archivedDetail)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == archivedDetail)
        #expect(sut.repo.fetchListDetailCount == 2)
    }

    // CHANGED (I3c-A): the list set after the archive is the reloaded one (was: list-a only).
    @Test("deleteList of another list keeps currentListDetail")
    func deleteOfOtherListKeepsCurrentDetail() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a")))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b", status: .archived)]))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")

        try await sut.service.deleteList(id: "list-b")

        #expect(sut.service.currentListDetail?.id == "list-a")
        #expect(sut.service.activeLists.map(\.id) == ["list-a"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-b"])
        #expect(sut.repo.fetchListDetailCount == 1, "the open detail of another list is not refetched")
    }

    // CHANGED (I3c-A): was "a later refresh that still returns the deleted list as ARCHIVED keeps it
    // hidden". Archived lists stay visible, so a later refresh shows it under archivedLists.
    @Test("a later refresh that returns the archived list keeps it, as ARCHIVED")
    func archivedListStaysVisibleAfterRefresh() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a", "list-b"])
    }

    // REWRITTEN (UX1a U2): the typed error is thrown and nothing is published.
    @Test("a failed deleteList keeps the list, throws the typed error and publishes nothing")
    func failedDeleteKeepsList() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueDeleteList(.failure(ListError.forbidden))
        await sut.service.loadLists()

        await #expect(throws: ListError.forbidden) {
            try await sut.service.deleteList(id: "list-a")
        }

        #expect(sut.service.lists.map(\.id) == ["list-a"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a"])
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - ADDED (I3a-L2): create and update use the returned detail

    @Test("createList uses the returned detail and its flags for lists and the cache, without refetching")
    func createUsesReturnedDetail() async throws {
        let sut = makeSUT()
        let created = ListFixtures.listDetail(
            id: "list-new", name: "Brand New", flags: editableFlags, memberCount: 1
        )
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueCreateList(.success(created))
        await sut.service.loadLists()
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "Brand New", theme: nil, visibility: .private)

        try await sut.service.createList(input)

        #expect(sut.repo.createdInputs == [input])
        #expect(sut.repo.fetchListsCount == 1, "create must not refetch the lists")
        #expect(sut.repo.fetchListDetailCount == 0, "create must not refetch the detail")
        let entry = try #require(sut.service.lists.first { $0.id == "list-new" })
        #expect(entry == created.asGiftList())
        #expect(entry.capabilities.canEditList, "flags come from the returned detail")
        #expect(sut.service.lists.map(\.id).contains("list-a"))
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.contains(created.asGiftList()))
        let cachedDetail = await sut.store.getListDetail(id: "list-new")
        #expect(cachedDetail == created)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // REWRITTEN (UX1a U2): throws the typed error, publishes nothing.
    @Test("a failed createList leaves lists unchanged, throws the typed error and publishes nothing")
    func failedCreateKeepsLists() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueCreateList(.failure(ListError.duplicateRecipientYear))
        await sut.service.loadLists()
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "Dup", theme: nil, visibility: .private)

        await #expect(throws: ListError.duplicateRecipientYear) {
            try await sut.service.createList(input)
        }

        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("updateList uses the returned detail: fresh flags in lists, currentListDetail and the cache, no refetch")
    func updateUsesReturnedDetail() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a", flags: editableFlags), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(
            ListFixtures.listDetail(id: "list-a", name: "Name of list-a", flags: editableFlags)
        ))
        // The returned detail has different flags than before: they must win.
        let updated = ListFixtures.listDetail(id: "list-a", name: "Renamed", flags: ListFixtures.Flags(canLeaveList: true))
        sut.repo.enqueueUpdateList(.success(updated))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        let input = UpdateListInput(name: "Renamed", theme: nil, visibility: nil)

        try await sut.service.updateList(id: "list-a", input)

        #expect(sut.repo.updatedInputs == [input])
        #expect(sut.repo.fetchListsCount == 1, "update must not refetch the lists")
        #expect(sut.repo.fetchListDetailCount == 1, "update must not refetch the detail")
        let entry = try #require(sut.service.lists.first { $0.id == "list-a" })
        #expect(entry == updated.asGiftList())
        #expect(entry.capabilities.canEditList == false)
        #expect(entry.capabilities.canLeaveList)
        #expect(sut.service.lists.map(\.id) == ["list-a", "list-b"], "order is kept")
        #expect(sut.service.currentListDetail == updated)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == updated)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.first { $0.id == "list-a" } == updated.asGiftList())
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("updateList of a list that is not the current detail leaves currentListDetail alone")
    func updateOfOtherListKeepsCurrentDetail() async throws {
        let sut = makeSUT()
        let currentDetail = ListFixtures.listDetail(id: "list-a", name: "Name of list-a")
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(currentDetail))
        sut.repo.enqueueUpdateList(.success(ListFixtures.listDetail(id: "list-b", name: "B Renamed")))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")

        try await sut.service.updateList(id: "list-b", UpdateListInput(name: "B Renamed", theme: nil, visibility: nil))

        #expect(sut.service.currentListDetail == currentDetail)
        #expect(sut.service.lists.first { $0.id == "list-b" }?.name == "B Renamed")
    }

    // REWRITTEN (UX1a U2): throws the typed error, publishes nothing.
    @Test("a failed updateList leaves lists and currentListDetail unchanged, throws the typed error and publishes nothing")
    func failedUpdateKeepsState() async {
        let sut = makeSUT()
        let currentDetail = ListFixtures.listDetail(id: "list-a", name: "Name of list-a")
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchListDetail(.success(currentDetail))
        // I3b-K0: archivedReadOnly is now a gone-list error (list dropped); forbidden keeps state.
        sut.repo.enqueueUpdateList(.failure(ListError.forbidden))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")

        await #expect(throws: ListError.forbidden) {
            try await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }

        #expect(sut.service.currentListDetail == currentDetail)
        #expect(sut.service.lists.map(\.name) == ["Name of list-a"])
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    // MARK: - ADDED (I3a-L2): typed errors become the service error

    nonisolated static let typedErrors: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Name must be between 1 and 200 characters"),
        .rateLimited(retryAfter: 3), .unauthorized, .network, .invalidResponse, .server
    ]

    // REWRITTEN (UX1a U2): the typed error is the returned failure and listsLoadFailure (was `error`).
    @Test("a typed repository error on loadLists becomes the returned failure and listsLoadFailure with its userMessage", arguments: ListServiceTests.typedErrors)
    func loadListsTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(error))

        let failure = await sut.service.loadLists()

        #expect(failure == error)
        #expect(sut.service.listsLoadFailure == error)
        #expect(sut.service.listsLoadFailure?.userMessage == error.userMessage)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.isLoadingLists == false)
    }

    // REWRITTEN (UX1a U2): see loadListsTypedError.
    @Test("a typed repository error on refreshLists becomes the returned failure and listsLoadFailure and keeps the lists", arguments: ListServiceTests.typedErrors)
    func refreshListsTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchLists(.failure(error))
        await sut.service.loadLists()

        let failure = await sut.service.refreshLists()

        #expect(failure == error)
        #expect(sut.service.listsLoadFailure == error)
        #expect(sut.service.listsLoadFailure?.userMessage == error.userMessage)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.isRefreshing == false)
    }

    // REWRITTEN (UX1a U2): a detail load failure is recorded in detailLoadFailure only.
    @Test("a typed repository error on loadListDetail becomes detailLoadFailure", arguments: ListServiceTests.typedErrors)
    func loadListDetailTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.detailLoadFailure == error)
        #expect(sut.service.detailLoadFailure?.userMessage == error.userMessage)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    // CHANGED (I3c-A, decision "a 422 CANNOT_EDIT_ARCHIVED_LIST is NOT list gone"): archivedReadOnly
    // from updateList now refetches the detail, so a refetch result is queued for that case. Without
    // it the refetch would fail with the repository default and the outcome would depend on how a
    // failed refetch is recorded, which this test is not about (see ListServiceArchivedReadOnlyTests).
    // REWRITTEN (UX1a U2): the typed error is thrown and nothing is published (was: stored in `error`).
    @Test("a typed repository error on createList, updateList and deleteList is thrown and publishes nothing", arguments: ListServiceTests.typedErrors)
    func writeTypedErrors(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueCreateList(.failure(error))
        sut.repo.enqueueUpdateList(.failure(error))
        sut.repo.enqueueDeleteList(.failure(error))
        if error == .archivedReadOnly {
            sut.repo.enqueueFetchListDetail(.success(
                ListFixtures.listDetail(id: "list-a", name: "Name of list-a", status: .archived)
            ))
        }
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)

        await #expect(throws: error) { try await sut.service.createList(input) }
        #expect(sut.service.anyLoadFailure == nil)

        await #expect(throws: error) {
            try await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }
        #expect(sut.service.anyLoadFailure == nil)

        await #expect(throws: error) { try await sut.service.deleteList(id: "list-a") }
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // REWRITTEN (UX1a U2): "error cleared at the start of the next operation" becomes "the lists
    // load failure is cleared when the next lists load starts / when it succeeds".
    @Test("a successful refresh clears the previous lists load failure")
    func successClearsError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.loadLists()
        #expect(sut.service.listsLoadFailure == .network)

        let failure = await sut.service.refreshLists()

        #expect(failure == nil)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    // MARK: - ADDED (I3a-L2): cancellation is not an error

    @Test("a CancellationError from the repository sets no error on loadLists")
    func cancellationOnLoadSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(CancellationError()))

        let failure = await sut.service.loadLists()

        #expect(failure == nil)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a CancellationError from the repository sets no error on refreshLists")
    func cancellationOnRefreshSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(CancellationError()))

        let failure = await sut.service.refreshLists()

        #expect(failure == nil)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isRefreshing == false)
    }

    @Test("a CancellationError from the repository sets no error on loadListDetail")
    func cancellationOnDetailSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(CancellationError()))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a CancellationError from the repository sets no error on create, update and delete")
    func cancellationOnWritesSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueCreateList(.failure(CancellationError()))
        sut.repo.enqueueUpdateList(.failure(CancellationError()))
        sut.repo.enqueueDeleteList(.failure(CancellationError()))
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)

        _ = try? await sut.service.createList(input)
        _ = try? await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        _ = try? await sut.service.deleteList(id: "list-a")

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }
}

/// Returns a fixed set of lists (ADDED I3a-L1, used by the flag-based filter test).
/// Writes are not exercised by the tests that use it.
/// EDITED (I3a-L2): the old ListError cases createFailed, updateFailed and deleteFailed are
/// gone; each throw below is now `.server` (same meaning).
@MainActor private final class FixedListRepository: ListRepository {
    private let lists: [GiftList]
    init(lists: [GiftList]) { self.lists = lists }
    func fetchLists() async throws -> [GiftList] { lists }
    func fetchListDetail(id: String) async throws -> ListDetail { throw ListError.notFound }
    func createList(_ input: CreateListInput) async throws -> ListDetail { throw ListError.server }
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail { throw ListError.server }
    func deleteList(id: String) async throws { throw ListError.server }
    func removeCoOwner(listId: String) async throws -> ListDetail { throw ListError.server }
}
