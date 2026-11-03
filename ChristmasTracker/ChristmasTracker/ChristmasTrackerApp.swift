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
            switch AppConfiguration.apiMode {
            case .mock:
                let apiClient = MockAPIClient.withMockData()
                return AppDependencies(
                    apiClient: apiClient,
                    authRepository: MockAuthenticationRepository(),
                    listRepository: MockListRepository(),
                    itemRepository: MockItemRepository()
                )
            case .real:
                let apiClient = NetworkAPIClient()
                return AppDependencies(
                    apiClient: apiClient,
                    authRepository: NetworkAuthenticationRepository(apiClient: apiClient),
                    listRepository: NetworkListRepository(apiClient: apiClient),
                    itemRepository: NetworkItemRepository(apiClient: apiClient)
                )
            }
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
        let ls = ListService(
            repository: dependencies.listRepository,
            dataStore: listDataStore
        )
        listService = ls

        let itemDataStore = ItemDataStore()
        let is_ = ItemService(
            repository: dependencies.itemRepository,
            dataStore: itemDataStore
        )
        itemService = is_

        // Create session manager with production clearables
        let clearables = makeProductionClearables(
            listDataStore: listDataStore,
            itemDataStore: itemDataStore,
            listService: ls,
            itemService: is_,
            networkCache: NetworkCache.shared
        )
        let sm = SessionManager(authRepository: dependencies.authRepository,
                                initialClearables: clearables)
        sessionManager = sm

        // Create services
        let auth = AuthenticationService(
            repository: dependencies.authRepository,
            sessionManager: sm
        )
        authService = auth

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
