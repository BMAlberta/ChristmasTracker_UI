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
        
    case .logout:
        state.authInProgress = false
        state.isAuthError = false
        state.isLoggedIn = false
        state.token  = ""
        
    case .fetchCurrenUser(_):
        state.isAuthError = false
        state.authInProgress = false
        
    case .fetchCurrentUserComplete(let res):
        state.currentUserDetails = res.user
        
    case .resetPassword(_,_):
        state.passwordResetInProgress = true
        state.isPasswordResetError = false
        state.passwordResetSuccess = false
        
    case .resetPasswordComplete:
        state.passwordResetInProgress = false
        state.isPasswordResetError = false
        state.passwordResetSuccess = true
        
    case .passwordResetError(_):
        state.isPasswordResetError = true
        state.passwordResetInProgress = false
        state.passwordResetSuccess = false
    }
}
