//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    
    let store = AppStore(initialState: .init(
        authState: AuthState(),
        listState: ListState()
    ),
    reducer: appReducer,
    middlewares: [
        authMiddleware(service: AuthService()),
        logMiddleware(),
        listMiddleware(service: ListService())
    ])
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    let appearance = UITabBarAppearance()
                    appearance.configureWithDefaultBackground()
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
        }
    }
}
