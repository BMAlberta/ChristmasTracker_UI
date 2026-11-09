//
//  SessionTeardownTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2a: session teardown and clearable stores.
//
//  All tests intentionally fail before the implementation is written:
//  - SessionClearable protocol does not exist yet.
//  - SessionManager.register(_:) does not exist yet.
//  - SessionManager.teardown(reason:) does not exist yet.
//  - The clearForSession() conformances on stores/services do not exist yet.
//
//  Compile-time failures ARE the expected "failing for the right reason".
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Helpers

/// A fast MockListRepository that doesn't sleep — avoids slow test suite.
@MainActor private final class FastMockListRepository: ListRepository {
    // I3a-L1: three fixed lists built from fixtures (no dependency on MockListData's shape).
    func fetchLists() async throws -> [GiftList] {
        [
            ListFixtures.giftList(id: "t-1", name: "Teardown One"),
            ListFixtures.giftList(id: "t-2", name: "Teardown Two"),
            ListFixtures.giftList(id: "t-3", name: "Teardown Three")
        ]
    }
    func fetchListDetail(id: String) async throws -> ListDetail { throw ListError.notFound }
    func createList(_ input: CreateListInput) async throws -> ListDetail { throw ListError.createFailed }
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail { throw ListError.updateFailed }
    func deleteList(id: String) async throws {}
}

/// A fast MockItemRepository that doesn't sleep.
@MainActor private final class FastMockItemRepository: ItemRepository {
    func fetchItems(listId: String) async throws -> [GiftItem] { MockItemData.allItems.filter { $0.listId == listId } }
    func fetchItemDetail(id: String) async throws -> GiftItem { throw ItemError.notFound }
    func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem { throw ItemError.createFailed }
    func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem { throw ItemError.updateFailed }
    func deleteItem(id: String) async throws {}
}

// MARK: - Suite

@Suite("Session Teardown Tests")
struct SessionTeardownTests {

    // MARK: - Factory

    /// Creates a fresh SessionManager with no registered clearables.
    @MainActor
    private func makeSUT() async -> SessionManager {
        let mockRepo = await MockAuthenticationRepository()
        return SessionManager(initialClearables: [])
    }

    // MARK: - Test 1: ListDataStore cleared after teardown

    @Test("ListDataStore is empty after teardown")
    func listDataStoreIsEmptyAfterTeardown() async throws {
        let sessionManager = await makeSUT()
        let dataStore = ListDataStore()

        // Seed the store with data
        // I3a-L1: a fixture list replaces the MockListData-derived one (same meaning: one seeded list).
        let sampleList = ListFixtures.giftList(id: "t-1", name: "Teardown One")
        await dataStore.setLists([sampleList])

        let before = await dataStore.getLists()
        #expect(!before.isEmpty, "Precondition: store must have data before teardown")

        // Register and tear down
        await sessionManager.register(dataStore)
        await sessionManager.teardown(reason: .userLogout)

        let after = await dataStore.getLists()
        #expect(after.isEmpty, "ListDataStore must be empty after teardown")
    }

    // MARK: - Test 2: ItemDataStore cleared after teardown

    @Test("ItemDataStore is empty after teardown")
    func itemDataStoreIsEmptyAfterTeardown() async throws {
        let sessionManager = await makeSUT()
        let dataStore = ItemDataStore()
        let listId = "1"

        // Seed items for list "1"
        let items = MockItemData.allItems.filter { $0.listId == listId }
        await dataStore.setItems(items, listId: listId)

        let before = await dataStore.getItems(listId: listId)
        #expect(!before.isEmpty, "Precondition: store must have items before teardown")

        await sessionManager.register(dataStore)
        await sessionManager.teardown(reason: .sessionExpired)

        let after = await dataStore.getItems(listId: listId)
        #expect(after.isEmpty, "ItemDataStore must be empty after teardown")
    }

    // MARK: - Test 3: ListService state cleared after teardown

    @Test("ListService is empty after teardown")
    @MainActor
    func listServiceIsEmptyAfterTeardown() async throws {
        let sessionManager = await makeSUT()
        let repo = FastMockListRepository()
        let dataStore = ListDataStore()
        let service = ListService(repository: repo, dataStore: dataStore)

        // Load lists so service has state
        await service.loadLists()
        #expect(!service.lists.isEmpty, "Precondition: lists must be loaded before teardown")

        await sessionManager.register(service)
        await sessionManager.teardown(reason: .userLogout)

        #expect(service.lists.isEmpty, "ListService.lists must be empty after teardown")
        #expect(service.currentListDetail == nil, "ListService.currentListDetail must be nil after teardown")
    }

    // MARK: - Test 4: ItemService state cleared after teardown

    @Test("ItemService is empty after teardown")
    @MainActor
    func itemServiceIsEmptyAfterTeardown() async throws {
        let sessionManager = await makeSUT()
        let repo = FastMockItemRepository()
        let dataStore = ItemDataStore()
        let service = ItemService(repository: repo, dataStore: dataStore)
        let listId = "1"

        await service.loadItems(listId: listId)
        #expect(!service.items.isEmpty, "Precondition: items must be loaded before teardown")

        await sessionManager.register(service)
        await sessionManager.teardown(reason: .userLogout)

        #expect(service.items.isEmpty, "ItemService.items must be empty after teardown")
        #expect(service.currentListId == nil, "ItemService.currentListId must be nil after teardown")
    }

    // MARK: - Test 5: AuthenticationService is signed out after teardown

    @Test("AuthenticationService is signed out after teardown")
    @MainActor
    func authServiceIsSignedOutAfterTeardown() async throws {
        let mockRepo = MockAuthenticationRepository()
        let innerSessionManager = SessionManager(initialClearables: [])
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: innerSessionManager,
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: InMemoryBiometricCredentialStore()
        )

        // Login first
        await authService.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated before teardown")

        // Use a fresh SessionManager as the teardown driver
        let teardownManager = await makeSUT()
        await teardownManager.register(authService)
        await teardownManager.teardown(reason: .userLogout)

        #expect(authService.isAuthenticated == false, "AuthenticationService must not be authenticated after teardown")
        #expect(authService.currentUser == nil, "AuthenticationService.currentUser must be nil after teardown")
    }

    // MARK: - Test 6: NetworkCache is empty after teardown

    @Test("NetworkCache is empty after teardown")
    func networkCacheIsEmptyAfterTeardown() async throws {
        let sessionManager = await makeSUT()
        let cache = NetworkCache()

        // Seed with a value
        await cache.setSessionId("test-session-teardown")
        await cache.set("teardownKey", value: "sampleValue")

        let before: String? = await cache.get("teardownKey")
        #expect(before != nil, "Precondition: cache must contain the key before teardown")

        await sessionManager.register(cache)
        await sessionManager.teardown(reason: .userLogout)

        let after: String? = await cache.get("teardownKey")
        #expect(after == nil, "NetworkCache must not return cached values after teardown")
    }

    // MARK: - Test 7: A failing clearable does not block subsequent clearables

    @Test("Failing clearable does not block others")
    func failingClearableDoesNotBlockOthers() async throws {
        let sessionManager = await makeSUT()

        let failingClearable = MockSessionClearable()
        failingClearable.configureToThrow(true)

        let successClearable = MockSessionClearable()

        await sessionManager.register(failingClearable)
        await sessionManager.register(successClearable)
        await sessionManager.teardown(reason: .userLogout)

        #expect(failingClearable.wasClearCalled, "The failing clearable must still have been called")
        #expect(successClearable.wasClearCalled, "The succeeding clearable must have been called despite earlier failure")
    }

    // MARK: - Test 8: Teardown is idempotent

    @Test("Teardown is idempotent — calling twice does not crash")
    @MainActor
    func teardownIsIdempotent() async throws {
        let mockRepo = MockAuthenticationRepository()
        let innerSessionManager = SessionManager(initialClearables: [])
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: innerSessionManager,
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: InMemoryBiometricCredentialStore()
        )

        await authService.login(email: "test@example.com", password: "password", rememberEmail: false)

        let teardownManager = await makeSUT()
        await teardownManager.register(authService)

        // First teardown
        await teardownManager.teardown(reason: .userLogout)
        // Second teardown — must not crash or change already-cleared state
        await teardownManager.teardown(reason: .userLogout)

        #expect(authService.isAuthenticated == false, "isAuthenticated must remain false after second teardown")
    }

    // MARK: - Test 9: Signed-out state reached even when clearable throws

    @Test("Signed-out state reached even when a clearable throws")
    func signedOutStateReachedEvenWhenClearableThrows() async throws {
        let sessionManager = await makeSUT()

        // Register a throwing clearable first so AuthenticationService teardown
        // still runs even after the failure.
        let throwingClearable = MockSessionClearable()
        throwingClearable.configureToThrow(true)

        let mockRepo = await MockAuthenticationRepository()
        let innerSessionManager = await SessionManager(initialClearables: [])
        let authService = await AuthenticationService(
            repository: mockRepo,
            sessionManager: innerSessionManager,
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: InMemoryBiometricCredentialStore()
        )

        await authService.login(email: "test@example.com", password: "password", rememberEmail: false)
        let authenticated = await authService.isAuthenticated
        #expect(authenticated == true, "Precondition: must be authenticated")

        await sessionManager.register(throwingClearable)
        await sessionManager.register(authService)
        await sessionManager.teardown(reason: .sessionExpired)

        let afterAuth = await authService.isAuthenticated
        #expect(afterAuth == false, "AuthenticationService must be signed out even when a preceding clearable throws")
    }

    // MARK: - Test 11: Production clearable set contains expected clearables (R2 → updated for I2b-1 Story 2)

    @Test("Production clearable set contains expected clearables")
    @MainActor
    func productionClearableSetContainsExpectedClearables() async throws {
        let listDataStore = ListDataStore()
        let itemDataStore = ItemDataStore()
        let listService = ListService(repository: MockListRepository(), dataStore: listDataStore)
        let itemService = ItemService(repository: MockItemRepository(), dataStore: itemDataStore)
        let lockController = InactivityLockController(policy: LockPolicy())

        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: listService,
            itemService: itemService,
            networkCache: NetworkCache.shared,
            lockController: lockController
        )

        // Updated from 5 → 6 for I2b-1 Story 2 (InactivityLockController added as clearable)
        #expect(clearables.count == 6, "Factory must return exactly 6 clearables")
        #expect(clearables[0] is ListDataStore, "clearables[0] must be ListDataStore")
        #expect(clearables[1] is ItemDataStore, "clearables[1] must be ItemDataStore")
        #expect(clearables[2] is ListService, "clearables[2] must be ListService")
        #expect(clearables[3] is ItemService, "clearables[3] must be ItemService")
        #expect(clearables[4] is NetworkCache, "clearables[4] must be NetworkCache")
        #expect(clearables[5] is InactivityLockController, "clearables[5] must be InactivityLockController")
    }

    // MARK: - Test 10: Device-level UserDefaults survive teardown

    @Test("Device-level UserDefaults key survives teardown")
    func deviceLevelDefaultsSurviveTeardown() async throws {
        let sessionManager = await makeSUT()

        // Use an isolated suite so we don't pollute the real UserDefaults
        let suite = "com.christmastracker.tests.teardown.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let deviceKey = "deviceSetting.notificationsEnabled"
        defaults.set(true, forKey: deviceKey)

        #expect(defaults.object(forKey: deviceKey) != nil, "Precondition: device key must exist before teardown")

        // Register a clearable that doesn't know about UserDefaults
        let clearable = MockSessionClearable()
        await sessionManager.register(clearable)
        await sessionManager.teardown(reason: .userLogout)

        // Device-level key must still be present
        #expect(defaults.bool(forKey: deviceKey) == true,
                "Device-level UserDefaults key must survive session teardown")

        // Clean up the isolated suite
        defaults.removePersistentDomain(forName: suite)
    }
}
