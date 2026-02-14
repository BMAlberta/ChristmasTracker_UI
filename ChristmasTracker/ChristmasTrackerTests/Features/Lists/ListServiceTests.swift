//
//  ListServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/14/26.
//

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
}
extension MockListRepository {
    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }
}

