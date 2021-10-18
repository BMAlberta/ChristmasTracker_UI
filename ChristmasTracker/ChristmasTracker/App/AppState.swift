//
//  AppState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation


class AppState {
    var auth: AuthState
    var ownedList: ListState
    
    init(authState: AuthState, listState: ListState) {
        self.auth = authState
        self.ownedList = listState
    }
}

class AuthState {
    var token = ""
    var authInProgress = false
    var isAuthError = false
    var isLoggedIn = false
}

class ListState {
    var items: [Item] = []
    var userItems: [Item] = []
    var userIdContext: String = ""
    var overviews: [ListOverview] = []
    var fetchInProgess = false
    var isFetchError = false
    var createInProgrees = false
    var isCreateError = false
    var purchaseComplete = false
}
