//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

struct AppState: Equatable {
    var user: UserState
    var ui: UIState
    var list: ListState
    var activity: ActivityState
    var stats: StatsState
    
    static let initialState = AppState(
        user: .initialState,
        ui: .initialState,
        list: .initialState,
        activity: .initialState,
        stats: .initialState
    )
}
