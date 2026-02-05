//
//  ChristmasTrackerApp.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import SwiftUI

@main
struct ChristmasTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView(lists: MockData.allLists)
        }
    }
}
