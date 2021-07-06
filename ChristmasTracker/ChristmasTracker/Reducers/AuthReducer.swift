//
//  AuthReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation


func authReducer(state: inout AuthState, action: AuthAction) -> Void {
    
    switch action {
    case .doLogin(_):
        state.isAuthError = false
        state.authInProgress = true
        
    case .loginComplete(let res):
        state.token = res.token
        state.authInProgress = false
        state.isLoggedIn = true
        state.isAuthError = false
        
    case .loginError(_):
        state.authInProgress = false
        state.isAuthError = true
    }
}
