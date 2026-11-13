//
//  ContentView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct ContentView: View {
    @Environment(\.authenticationService) private var authService
    var body: some View {
        rootView
    }

    private var rootView: some View {
        Group {
            if authService.isAuthenticated {
                TabBarView()
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
            sessionManager: SessionManager(initialClearables: [])
        ))
}
private struct ContentViewAuthenticatedPreview: View {
//    @State private var authService = AuthenticationService(
//        repository: MockAuthenticationRepository(),
//        sessionManager: SessionManager(initialClearables: [])
//    )
    
    @State private var authService = AuthenticationService(repository: MockAuthenticationRepository(), sessionManager: SessionManager(initialClearables: []))
    
    var body: some View {
        ContentView()
            .environment(\.authenticationService, authService)
            .task {
                await authService.login(email: "test@example.com", password: "password", rememberEmail: false)
            }
    }
}

