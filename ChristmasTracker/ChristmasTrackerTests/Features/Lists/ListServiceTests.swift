//
//  ListServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/14/26.
//

import Foundation
import Testing
@testable import ChristmasTracker
@Suite("ListService Tests")
@MainActor
struct ListServiceTests {
    @Test("Load lists fetches from repository and caches")
    func testLoadLists() async {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.lists.count == 3)
        #expect(service.isLoading == false)
        #expect(service.error == nil)
        // Verify cached
        let cached = await dataStore.getLists()
        #expect(cached.count == 3)
    }
    @Test("Refresh lists forces fresh fetch")
    func testRefreshLists() async {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let firstLoad = service.lastUpdated
        try? await Task.sleep(for: .milliseconds(100))
        await service.refreshLists()
        let secondLoad = service.lastUpdated
        #expect(secondLoad != firstLoad)
    }
    @Test("Create list adds to collection")
    func testCreateList() async throws {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let initialCount = service.lists.count
        let request = CreateListRequest(
            name: "Test List",
            theme: "Test Theme",
            year: 2024,
            recipientId: "test-recipient",
            description: "Test description",
            visibility: .private,
            coOwnerId: nil
        )
        try await service.createList(request)
        #expect(service.lists.count == initialCount + 1)
        #expect(service.lists.contains(where: { $0.name == "Test List" }))
    }
    @Test("Update list modifies existing")
    func testUpdateList() async throws {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let listId = service.lists.first!.id
        let request = UpdateListRequest(
            name: "Updated Name",
            theme: nil,
            description: nil,
            visibility: nil
        )
        try await service.updateList(id: listId, request)
        #expect(service.lists.contains(where: { $0.id == listId && $0.name == "Updated Name" }))
    }
    @Test("Delete list removes from collection")
    func testDeleteList() async throws {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let initialCount = service.lists.count
        let listToDelete = service.lists.first!.id
        try await service.deleteList(id: listToDelete)
        #expect(service.lists.count == initialCount - 1)
        #expect(!service.lists.contains(where: { $0.id == listToDelete }))
        // Verify removed from cache
        let cached = await dataStore.getLists()
        #expect(!cached.contains(where: { $0.id == listToDelete }))
    }
    @Test("Filter owned shows only owner/co-owner lists")
    func testFilterOwned() async {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        service.currentFilter = .owned
        #expect(service.filteredLists.allSatisfy {
            $0.myRole == .owner || $0.myRole == .coOwner
        })
    }
    @Test("Filter shared shows only member/viewer lists")
    func testFilterShared() async {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        service.currentFilter = .shared
        #expect(service.filteredLists.allSatisfy {
            $0.myRole == .member || $0.myRole == .viewer
        })
    }
    @Test("Load detail fetches and caches")
    func testLoadListDetail() async {
        let mockRepo = MockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        let listId = service.lists.first!.id
        await service.loadListDetail(id: listId)
        #expect(service.currentListDetail != nil)
        #expect(service.currentListDetail?.id == listId)
        // Verify cached
        let cachedDetail = await dataStore.getListDetail(id: listId)
        #expect(cachedDetail != nil)
    }
    @Test("Error handling sets appropriate error")
    func testErrorHandling() async {
        let mockRepo = MockListRepository()
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.error != nil)
        #expect(service.lists.isEmpty)
    }
    @Test("Failed repository fetch resets isLoading and sets error")
    func testLoadListsFailureResetsIsLoading() async {
        let mockRepo = MockListRepository()
        await mockRepo.setShouldFail(true)
        let dataStore = ListDataStore()
        let service = ListService(repository: mockRepo, dataStore: dataStore)
        await service.loadLists()
        #expect(service.isLoading == false)
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

        let request = CreateListRequest(
            name: "Cache Test List",
            theme: nil,
            year: 2025,
            recipientId: "r-test",
            description: nil,
            visibility: .private,
            coOwnerId: nil
        )
        try await service.createList(request)

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
        let listToDelete = service.lists.first!.id

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
}
extension MockListRepository {
    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }

    func setDelay(_ value: TimeInterval) {
        delay = value
    }
}
