//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation


struct AppState {
    var auth: AuthState
    var ownedList: ListState
}

struct AuthState {
    var token = ""
    var authInProgress = false
    var isAuthError = false
    var isLoggedIn = false
}

struct ListState {
    var items: [Item] = []
    var userItems: [Item] = []
    var overviews: [ListOverview] = []
    var fetchInProgess = false
    var isFetchError = false
    var createInProgrees = false
    var isCreateError = false
}
