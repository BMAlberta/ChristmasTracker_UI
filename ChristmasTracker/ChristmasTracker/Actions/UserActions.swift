//
//  UserActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

/// Enumeration representing "user" actions including, authentication, session management, registration, and profile management.
enum UserActions: UserAction {
    // Authentication
    case login(email: String, password: String, enableBiometrics: Bool)
    case biometricLogin
    case loginSuccess(AuthModel)
    case loginError(UserError)
    case logout
    case logoutSuccess
    case loginErrorsCleared

    
    // Registration
//    case requestEnrollmentCode
//    case enrollmentCodeReturned
//
    
    // Profile Updates
    case submitPasswordChange(currentPassword: String, newPassword: String)
    case passwordChangeSuccess
    case passwordChangeError(UserError)
    case passwordChangeFlowComplete
    
    case updateProfileName(userId: String, firstName: String, lastName: String)
    case updateProfileNameSuccess
    case updateProfileNameError(UserError)
    case updateProfileFlowComplete
    
    case checkForBiometrics
    case checkforBiometricsSuccess(BiometricUtility.BiometricState)
    case enableBiometrics(confirmedPassword: String)
    case enableBiometricSuccess
    case enableBiometricError(UserError)
    case disableBiometrics
    case disableBiometricsSuccess
    case disableBiometricsError(UserError)
    
    case refreshMetadata
    case metadataRefreshed(UserMetadata)
    case refreshMetadataError(UserError)
    
    // Home Feed
    case homeFeedLoaded(AppData)
    
        var type: String {
        switch self {
        case .login: return "USER_LOGIN"
        case .biometricLogin: return "USER_BIOMETRIC_LOGIN"
        case .loginSuccess: return "USER_LOGIN_SUCCESS"
        case .loginError: return "USER_LOGIN_ERROR"
        case .logout: return "USER_LOGOUT"
        case .logoutSuccess: return "USER_LOGOUT_SUCCESS"
        case .loginErrorsCleared: return "USER_LOGIN_ERRORS_CLEARED"
        case .submitPasswordChange: return "USER_SUBMIT_PASSWORD_CHANGE"
        case .passwordChangeSuccess: return "USER_PASSWORD_CHANGE_SUCCESS"
        case .passwordChangeError: return "USER_PASSWORD_CHANGE_ERROR"
        case .passwordChangeFlowComplete: return "USER_PASSWORD_CHANGE_FLOW_COMPLETE"
        case .updateProfileName: return "USER_UPDATE_PROFILE_NAME"
        case .updateProfileNameSuccess: return "USER_UPDATE_PROFILE_NAME_SUCCESS"
        case .updateProfileNameError: return "USER_UPDATE_PROFILE_NAME_ERROR"
        case .updateProfileFlowComplete: return "USER_UPDATE_PROFILE_FLOW_COMPLETE"
        case .checkForBiometrics: return "USER_CHECK_FOR_BIOMETRICS"
        case .checkforBiometricsSuccess: return "USER_CHECK_FOR_BIOMETRICS_SUCCESS"
        case .enableBiometrics: return "USER_ENABLE_BIOMETRICS"
        case .enableBiometricSuccess: return "USER_ENABLE_BIOMETRIC_SUCCESS"
        case .enableBiometricError: return "USER_ENABLE_BIOMETRICS_ERROR"
        case .disableBiometrics: return "USER_DISABLE_BIOMETRICS"
        case .disableBiometricsSuccess: return "USER_DISABLE_BIOMETRICS_SUCCESS"
        case .disableBiometricsError: return "USER_DISABLE_BIOMETRICS_ERROR"
        case .homeFeedLoaded: return "USER_HOME_FEED_LOADED"
        case .refreshMetadata: return "USER_REFRESH_METADATA"
        case .metadataRefreshed: return "USER_METADATA_REFRESHED"
        case .refreshMetadataError: return "USER_REFRESH_METADATA_ERROR"
        }
    }
}


