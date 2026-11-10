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
        #expect(service.error == nil)
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

    @Test("Delete list removes from collection")
    func testDeleteList() async throws {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let initialCount = service.lists.count
        let listToDelete = try #require(service.lists.first?.id)
        try await service.deleteList(id: listToDelete)
        #expect(service.lists.count == initialCount - 1)
        #expect(!service.lists.contains(where: { $0.id == listToDelete }))
        // Verify removed from cache
        let cached = await dataStore.getLists()
        #expect(!cached.contains(where: { $0.id == listToDelete }))
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
    @Test("Error handling sets appropriate error")
    func testErrorHandling() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.error != nil)
        #expect(service.error == .server)
        #expect(service.lists.isEmpty)
    }

    // REWRITTEN (I3b-K0): isLoading is replaced by isLoadingLists.
    @Test("Failed repository fetch resets isLoadingLists and sets error")
    func testLoadListsFailureResetsIsLoadingLists() async {
        let mockRepo = MockListRepository()
        await mockRepo.setDelay(0)
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.isLoadingLists == false)
        #expect(service.error != nil)
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

    @Test("loadLists after deleteList does not serve the deleted list from cache")
    func testLoadListsAfterDeleteDoesNotServeDeletedList() async throws {
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

        #expect(!service2.lists.contains(where: { $0.id == listToDelete }))
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

    @Test("loadLists drops ARCHIVED lists and keeps ACTIVE and DRAFT ones")
    func loadDropsArchivedKeepsDraft() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([
            list("list-active"), list("list-draft", status: .draft), list("list-archived", status: .archived)
        ]))

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-draft"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-active", "list-draft"], "archived lists must not be cached either")
        #expect(sut.service.error == nil)
    }

    @Test("refreshLists drops ARCHIVED lists and keeps ACTIVE and DRAFT ones")
    func refreshDropsArchivedKeepsDraft() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-active")]))
        sut.repo.enqueueFetchLists(.success([
            list("list-active"), list("list-draft", status: .draft), list("list-archived", status: .archived)
        ]))
        await sut.service.loadLists()

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-draft"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-active", "list-draft"])
    }

    @Test("a response with only ARCHIVED lists leaves the list empty without an error")
    func onlyArchivedLeavesEmpty() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-archived", status: .archived)]))

        await sut.service.loadLists()

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.error == nil)
    }

    // MARK: - ADDED (I3a-L2 fix round): the cached branch hides ARCHIVED too

    @Test("loadLists on the cached branch does not expose an ARCHIVED summary already in the cache")
    func cachedBranchHidesArchivedOnly() async {
        let sut = makeSUT()
        await sut.store.setLists([list("list-archived", status: .archived)])

        await sut.service.loadLists()

        #expect(!sut.service.lists.contains { $0.id == "list-archived" })
        #expect(!sut.service.lists.contains { $0.status == .archived })
        #expect(sut.service.error == nil)
    }

    @Test("loadLists on the cached branch shows only the non-archived part of a mixed cache, without fetching")
    func cachedBranchHidesArchivedInMixedCache() async {
        let sut = makeSUT()
        await sut.store.setLists([
            list("list-active"), list("list-archived", status: .archived), list("list-draft", status: .draft)
        ])

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-active", "list-draft"])
        #expect(sut.repo.fetchListsCount == 0, "a fresh non-empty cache is served without a fetch")
        #expect(sut.service.error == nil)
    }

    // MARK: - ADDED (I3a-L2): delete removes locally and stays hidden

    @Test("deleteList removes the list from lists and the cache without refetching")
    func deleteRemovesLocallyWithoutRefetch() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        #expect(sut.repo.deleteListCount == 1)
        #expect(sut.repo.fetchListsCount == 1, "delete must not refetch")
        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("deleteList clears currentListDetail and the cached detail when it is that list")
    func deleteClearsCurrentDetail() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a")))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.currentListDetail?.id == "list-a")

        try await sut.service.deleteList(id: "list-a")

        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == nil)
        #expect(sut.repo.fetchListDetailCount == 1)
    }

    @Test("deleteList of another list keeps currentListDetail")
    func deleteOfOtherListKeepsCurrentDetail() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: "list-a", name: "Name of list-a")))
        sut.repo.enqueueDeleteList(.success(()))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")

        try await sut.service.deleteList(id: "list-b")

        #expect(sut.service.currentListDetail?.id == "list-a")
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    @Test("a later refresh that still returns the deleted list as ARCHIVED keeps it hidden")
    func deletedListStaysHiddenAfterRefresh() async throws {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueDeleteList(.success(()))
        // The server archives instead of removing, so the list comes back with status ARCHIVED.
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        await sut.service.loadLists()
        try await sut.service.deleteList(id: "list-a")

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == ["list-b"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
    }

    @Test("a failed deleteList keeps the list, sets the typed error and rethrows")
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
        #expect(sut.service.error == .forbidden)
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
        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("a failed createList leaves lists unchanged, sets the typed error and rethrows")
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
        #expect(sut.service.error == .duplicateRecipientYear)
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
        #expect(sut.service.error == nil)
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

    @Test("a failed updateList leaves lists and currentListDetail unchanged, sets the typed error and rethrows")
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
        #expect(sut.service.error == .forbidden)
    }

    // MARK: - ADDED (I3a-L2): typed errors become the service error

    nonisolated static let typedErrors: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Name must be between 1 and 200 characters"),
        .rateLimited(retryAfter: 3), .unauthorized, .network, .invalidResponse, .server
    ]

    @Test("a typed repository error on loadLists becomes the service error with its userMessage", arguments: ListServiceTests.typedErrors)
    func loadListsTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(error))

        await sut.service.loadLists()

        #expect(sut.service.error == error)
        #expect(sut.service.error?.userMessage == error.userMessage)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a typed repository error on refreshLists becomes the service error and keeps the lists", arguments: ListServiceTests.typedErrors)
    func refreshListsTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        sut.repo.enqueueFetchLists(.failure(error))
        await sut.service.loadLists()

        await sut.service.refreshLists()

        #expect(sut.service.error == error)
        #expect(sut.service.error?.userMessage == error.userMessage)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.isRefreshing == false)
    }

    @Test("a typed repository error on loadListDetail becomes the service error", arguments: ListServiceTests.typedErrors)
    func loadListDetailTypedError(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == error)
        #expect(sut.service.error?.userMessage == error.userMessage)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a typed repository error on createList, updateList and deleteList becomes the service error", arguments: ListServiceTests.typedErrors)
    func writeTypedErrors(error: ListError) async {
        let sut = makeSUT()
        sut.repo.enqueueCreateList(.failure(error))
        sut.repo.enqueueUpdateList(.failure(error))
        sut.repo.enqueueDeleteList(.failure(error))
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)

        await #expect(throws: error) { try await sut.service.createList(input) }
        #expect(sut.service.error == error)
        #expect(sut.service.error?.userMessage == error.userMessage)

        await #expect(throws: error) {
            try await sut.service.updateList(id: "list-a", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }
        #expect(sut.service.error == error)

        await #expect(throws: error) { try await sut.service.deleteList(id: "list-a") }
        #expect(sut.service.error == error)
        #expect(sut.service.isMutating == false)
    }

    @Test("a successful call clears a previous error")
    func successClearsError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.loadLists()
        #expect(sut.service.error == .network)

        await sut.service.refreshLists()

        #expect(sut.service.error == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    // MARK: - ADDED (I3a-L2): cancellation is not an error

    @Test("a CancellationError from the repository sets no error on loadLists")
    func cancellationOnLoadSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(CancellationError()))

        await sut.service.loadLists()

        #expect(sut.service.error == nil)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a CancellationError from the repository sets no error on refreshLists")
    func cancellationOnRefreshSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(CancellationError()))

        await sut.service.refreshLists()

        #expect(sut.service.error == nil)
        #expect(sut.service.isRefreshing == false)
    }

    @Test("a CancellationError from the repository sets no error on loadListDetail")
    func cancellationOnDetailSetsNoError() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(CancellationError()))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.error == nil)
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

        #expect(sut.service.error == nil)
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
