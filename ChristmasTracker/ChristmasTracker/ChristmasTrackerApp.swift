//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    // MARK: - State
    @State private var authService: AuthenticationService
    @State private var apiClient: APIClient
    @State private var listService: ListService
    @State private var itemService: ItemService
    private let sessionManager: SessionManager

    private struct AppDependencies {
        let apiClient: APIClient
        let authRepository: AuthenticationRepository
        let listRepository: ListRepository
        let itemRepository: ItemRepository

        static func make() -> AppDependencies {
#if DEBUG
            // Use mocks in debug
            let apiClient = MockAPIClient.withMockData()
            let authRepository: AuthenticationRepository = MockAuthenticationRepository()
            let listRepository: ListRepository = MockListRepository()
            let itemRepository: ItemRepository = MockItemRepository()
#else
            // Use network in production
            let apiClient = NetworkAPIClient()
            let authRepository: AuthenticationRepository = NetworkAuthenticationRepository(apiClient: apiClient)
            let listRepository: ListRepository = NetworkListRepository(apiClient: apiClient)
            let itemRepository: ItemRepository = NetworkItemRepository(apiClient: apiClient)
#endif

            return AppDependencies(
                apiClient: apiClient,
                authRepository: authRepository,
                listRepository: listRepository,
                itemRepository: itemRepository
            )
        }
    }
    
    // MARK: - Initialization
    init() {
        // Wipe 4.4 legacy credentials/data on first launch — must run before store reads
        FirstLaunchWipe().performIfNeeded()

        let dependencies = AppDependencies.make()
        apiClient = dependencies.apiClient

        // List Service
        let listDataStore = ListDataStore()
        listService = ListService(
            repository: dependencies.listRepository,
            dataStore: listDataStore
        )

        let itemDataStore = ItemDataStore()
        itemService = ItemService(
            repository: dependencies.itemRepository,
            dataStore: itemDataStore
        )

        // Create session manager
        let sm = SessionManager(authRepository: dependencies.authRepository)
        sessionManager = sm

        // Create services
        let auth = AuthenticationService(
            repository: dependencies.authRepository,
            sessionManager: sm
        )
        authService = auth

        // Register clearables with the session manager
        let lds = listDataStore
        let ids = itemDataStore
        let ls = listService
        let is_ = itemService
        Task {
            await sm.register(lds)
            await sm.register(ids)
            await sm.register(ls)
            await sm.register(is_)
            await sm.register(auth)
            await sm.register(NetworkCache.shared)
        }

        LogInfo("App initialized", category: .business)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authenticationService, authService)
                .environment(\.apiClient, apiClient)
                .environment(\.listService, listService)
                .environment(\.itemService, itemService)
        }
    }
}
