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
    var currentUserDetails: User?
    var passwordResetInProgress = false
    var isPasswordResetError = false
    var passwordResetSuccess = false
    var updateInfo: UpdateInfoModel? = nil
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
    var updateComplete = false
    var updateInProgress = false
    var deleteInProgress = false
    var deleteComplete = false
}
