//
//  TabBarView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

struct TabBarView: View {
    
    @State private var selection: TabSelection = .dashboard
    
    let apiClient: APIClient
    
    var body: some View {
        TabView(selection: $selection) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Label(TabSelection.dashboard.title, systemImage: TabSelection.dashboard.icon)
                }
                .tag(TabSelection.dashboard)
            
            // Stats Tab
            StatsView()
                .tabItem {
                    Label(TabSelection.stats.title, systemImage: TabSelection.stats.icon)
                }
                .tag(TabSelection.stats)
            
            //Profile Tab
            ProfileView()
                .tabItem {
                    Label(TabSelection.profile.title, systemImage: TabSelection.profile.icon)
                }
                .tag(TabSelection.profile)
        }
        .tint(.primaryColor)
    }
}

#Preview {
    TabBarView(apiClient: MockAPIClient.withMockData())
        .environment(\.authenticationService, AuthenticationService(repository: MockAuthenticationRepository(), sessionManager:SessionManager(authRepository:MockAuthenticationRepository())))
}
