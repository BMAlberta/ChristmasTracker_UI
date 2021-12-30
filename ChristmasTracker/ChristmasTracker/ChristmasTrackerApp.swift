//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    let sessionManager = UserSession()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .onAppear {
                    let appearance = UITabBarAppearance()
                    appearance.configureWithDefaultBackground()
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
        }
    }
}
