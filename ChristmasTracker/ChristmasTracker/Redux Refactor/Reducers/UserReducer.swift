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
        case .login(email: _, password: _, enableBiometrics: _):
            newState.isLoading = true
            newState.error = nil
            
        case .biometricLogin:
            newState.isLoading = true
            newState.error = nil
            
        case .loginSuccess(let user):
            newState.currentUser = LWUserModel(id: user.userId, firstName: user.firstName, lastName: user.lastName)
            newState.isLoading = false
            newState.isLoggedIn = true
            newState.teaser = Teaser(type: .greeting, name: user.firstName, message: "Welcome to the 2025 Christmas Tracker!")
            
        case .loginError(_):
            newState.isLoading = false
            newState.isLoggedIn = false
            newState.error = .authenticationFailed
            newState.currentUser = nil
            
        case .logout:
            newState.isLoading = true
            newState.error = nil
            
        case .logoutSuccess:
            newState.isLoading = false
            newState.isLoggedIn = false
            newState.currentUser = nil
            newState.error = nil
            
        case .loginErrorsCleared:
            newState.isLoading = false
            newState.isLoggedIn = false
            newState.currentUser = nil
            newState.error = nil
        
        case .submitPasswordChange(currentPassword: _, newPassword: _):
            newState.isLoading = true
            newState.error = nil
            newState.changePasswordSuccess = false
            
        case .passwordChangeSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.changePasswordSuccess = true
            
        case .passwordChangeError(let error):
            newState.isLoading = false
            newState.changePasswordSuccess = false
            newState.error = error
            
        case .passwordChangeFlowComplete:
            newState.isLoading = false
            newState.changePasswordSuccess = false
            newState.error = nil

        case .updateProfileName(userId: _, firstName: _, lastName: _):
            newState.isLoading = true
            newState.error = nil
            
        case .updateProfileNameSuccess:
            newState.isLoading = false
            newState.updateNameSuccess = true
            newState.error = nil
            
        case .updateProfileNameError(let error):
            newState.isLoading = false
            newState.updateNameSuccess = false
            newState.error = error
            
        case .updateProfileFlowComplete:
            newState.isLoading = false
            newState.updateNameSuccess = false
            newState.error = nil
            
        case .checkForBiometrics:
            newState.biometricsState = .unavailable
            
        case .checkforBiometricsSuccess(let state):
            newState.biometricsState = state
            
        case .enableBiometrics:
            newState.isLoading = true
            newState.error = nil
            
        case .enableBiometricSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.biometricsState = BiometricUtility.biometricStatus
            
        case .enableBiometricError(let error):
            newState.isLoading = false
            newState.error = error
            newState.biometricsState = BiometricUtility.biometricStatus
            
        case .disableBiometrics:
            newState.isLoading = true
            newState.error = nil
            
        case .disableBiometricsSuccess:
            newState.isLoading = false
            newState.error = nil
            
        case .disableBiometricsError(let error):
            newState.isLoading = false
            newState.error = error
            
        case .homeFeedLoaded(let data):
            newState.metadata = data.userMetadata
    
        case .refreshMetadata:
            newState.isLoading = true
            newState.error = nil
            
        case .metadataRefreshed(let metadata):
            newState.isLoading = false
            newState.error = nil
            newState.metadata = metadata
            
        case .refreshMetadataError(let error):
            newState.error = error
            newState.isLoading = false
        }
    default:
        break
    }
    
    return newState
}
