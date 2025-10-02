//
//  UserActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

enum UserActions: UserAction {
    // Authentication
    case login(email: String, password: String)
    case biometricLogin
    case loginSuccess(String)
    case loginError(String)
    case logout
    case logoutSuccess

    
    // Registration
    
    // Profile Updates
    
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
        }
    }
}
