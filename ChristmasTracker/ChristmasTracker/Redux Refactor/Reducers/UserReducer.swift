//
//  UserReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

func userReducer(state: UserState, action: any Action) -> UserState {
    var newState = state
    
    switch action {
    case let userAction as UserActions:
        switch userAction {
        case .login(email: _, password: _):
            newState.isloading = true
            newState.error = nil
            break
        case .biometricLogin:
            break
        case .loginSuccess(let user):
            newState.currentUser = user
            newState.isloading = false
            newState.isLoggedIn = true
            break
        case .loginError(_):
            fatalError("userReducer: \(userAction) not implemented")
        case .logout:
            fatalError("userReducer: \(userAction) not implemented")
        case .logoutSuccess:
            fatalError("userReducer: \(userAction) not implemented")
        case .refreshSession:
            fatalError("userReducer: \(userAction) not implemented")
        case .sessionExpired:
            fatalError("userReducer: \(userAction) not implemented")
        case .submitPasswordChange(currentPassword: let currentPassword, newPassword: let newPassword):
            fatalError("userReducer: \(userAction) not implemented")
        case .passwordChangeSuccess:
            fatalError("userReducer: \(userAction) not implemented")
        case .passwordChangeError(_):
            fatalError("userReducer: \(userAction) not implemented")
        case .enableBiometrics:
            fatalError("userReducer: \(userAction) not implemented")
        case .enableBiometricSuccess:
            fatalError("userReducer: \(userAction) not implemented")
        case .enableBiometricError(_):
            fatalError("userReducer: \(userAction) not implemented")
        case .resetLogonInfo:
            fatalError("userReducer: \(userAction) not implemented")
        case .resetSuccess:
            fatalError("userReducer: \(userAction) not implemented")
        }
    default:
        break
    }
    
    return newState
}
