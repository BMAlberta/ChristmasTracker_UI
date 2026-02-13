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
    
    // MARK: - Initialization
    init() {
        // Create dependencies
#if DEBUG
        // Use mock in debug
        apiClient = MockAPIClient.withMockData()
#else
        // Use network in production
        apiClient = NetworkAPIClient()
#endif
        // Create repositories
        let authRepository: AuthenticationRepository
#if DEBUG
        authRepository = MockAuthenticationRepository()
#else
        authRepository = NetworkAuthenticationRepository(apiClient: apiClient)
#endif
        // Create session manager
        let sessionManager = SessionManager(authRepository: authRepository)
        
        // Create services
        authService = AuthenticationService(
            repository: authRepository,
            sessionManager: sessionManager
        )
        LogInfo("App initialized", category: .business)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authenticationService, authService)
                .environment(\.apiClient, apiClient)
        }
    }
}
