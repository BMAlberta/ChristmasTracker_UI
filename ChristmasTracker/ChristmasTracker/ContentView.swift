//
//  ContentView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct ContentView: View {
    @Environment(\.authenticationService) private var authService
    @Environment(\.apiClient) private var apiClient
    var body: some View {
        rootView
    }

    private var rootView: some View {
        Group {
            if authService.isAuthenticated {
                TabBarView(apiClient: apiClient)
            } else {
                LoginView()
            }
        }
    }
}
#Preview("Authenticated") {
    ContentViewAuthenticatedPreview()
}
#Preview("Not Authenticated") {
    ContentView()
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
private struct ContentViewAuthenticatedPreview: View {
//    @State private var authService = AuthenticationService(
//        repository: MockAuthenticationRepository(),
//        sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
//    )
    
    @State private var apiClient = MockAPIClient.withMockData()
    @State private var authService = AuthenticationService(repository: MockAuthenticationRepository(), sessionManager: SessionManager(authRepository: MockAuthenticationRepository()))
    
    var body: some View {
        ContentView()
            .environment(\.authenticationService, authService)
            .environment(\.apiClient, apiClient)
            .task {
                await authService.login(email: "test@example.com", password: "password", rememberMe: false)
            }
    }
}

