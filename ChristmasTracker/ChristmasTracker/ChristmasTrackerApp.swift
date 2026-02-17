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
        let sessionManager = SessionManager(authRepository: dependencies.authRepository)

        // Create services
        authService = AuthenticationService(
            repository: dependencies.authRepository,
            sessionManager: sessionManager
        )
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
