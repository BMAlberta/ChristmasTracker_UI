//
//  UserActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

/// Enumeration representing "user" actions including, authentication, session management, registration, and profile management.
enum UserActions: UserAction {
    // Authentication
    case login(email: String, password: String)
    case biometricLogin
    case loginSuccess(String)
    case loginError(String)
    case logout
    case logoutSuccess

    
    // Registration
//    case requestEnrollmentCode
//    case enrollmentCodeReturned
//
    
    // Profile Updates
    case submitPasswordChange(currentPassword: String, newPassword: String)
    case passwordChangeSuccess
    case passwordChangeError(String)
    
    case enableBiometrics
    case enableBiometricSuccess
    case enableBiometricError(String)
    
    case resetLogonInfo
    case resetSuccess
    
    // Session
    case refreshSession
    case sessionExpired
    
        var type: String {
        switch self {
        case .login: return "USER_LOGIN"
        case .biometricLogin: return "USER_BIOMETRIC_LOGIN"
        case .loginSuccess: return "USER_LOGIN_SUCCESS"
        case .loginError: return "USER_LOGIN_ERROR"
        case .logout: return "USER_LOGOUT"
        case .logoutSuccess: return "USER_LOGOUT_SUCCESS"
        case .refreshSession: return "USER_REFRESH_SESSION"
        case .sessionExpired: return "USER_SESSION_EXPIRED"
        case .submitPasswordChange: return "USER_SUBMIT_PASSWORD_CHANGE"
        case .passwordChangeSuccess: return "USER_PASSWORD_CHANGE_SUCCESS"
        case .passwordChangeError: return "USER_PASSWORD_CHANGE_ERROR"
        case .enableBiometrics: return "USER_ENABLE_BIOMETRICS"
        case .enableBiometricSuccess: return "USER_ENABLE_BIOMETRIC_SUCCESS"
        case .enableBiometricError: return "USER_ENABLE_BIOMETRICS_ERROR"
        case . resetSuccess: return "USER_RESET_SUCCESS"
        case .resetLogonInfo: return "USER_RESET_LOGON_INFO"

        }
    }
}

