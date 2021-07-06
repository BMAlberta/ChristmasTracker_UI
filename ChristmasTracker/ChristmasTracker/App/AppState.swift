//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation


struct AppState {
    var auth: AuthState
    var ownedList: OwnedListState
}

struct AuthState {
    var token = ""
    var authInProgress = false
    var isAuthError = false
    var isLoggedIn = false
}

struct OwnedListState {
    var items: [Item] = []
    var fetchInProgess = false
    var isFetchError = false
    var createInProgrees = false
    var isCreateError = false
}
