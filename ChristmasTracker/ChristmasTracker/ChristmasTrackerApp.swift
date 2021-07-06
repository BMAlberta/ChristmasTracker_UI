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
        auth: AuthState(),
        ownedList: OwnedListState()
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
        }
    }
}
