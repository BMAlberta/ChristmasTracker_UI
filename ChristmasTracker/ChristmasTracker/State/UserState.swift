//
//  UserState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

struct UserState: Codable, Equatable {
    var currentUser: LWUserModel?
    var savdUserId: String
    var isLoading: Bool = false
    var error: UserError? // TODO: Change type
    var isLoggedIn: Bool = false
    var authToken: String?
    var biometricsState: BiometricUtility.BiometricState
    var teaser: Teaser
    var metadata: UserMetadata
    var updateNameSuccess: Bool
    var changePasswordSuccess: Bool
    var passwordChangeRequired: Bool
    
    
    
    static let initialState = UserState(
        currentUser: nil,
        savdUserId: "",
        isLoading: false,
        error: nil,
        isLoggedIn: false,
        authToken: nil,
        biometricsState: .unavailable,
        teaser: Teaser(type: .greeting, name: "<name>", message: "Sample teaser message here"),
        metadata: UserMetadata.defaultMetadata(),
        updateNameSuccess: false,
        changePasswordSuccess: false,
        passwordChangeRequired: false
    )
    
    var userName: String {
//        currentUser?.name ?? "Guest"
        "Guest"
    }
    
    var userEmail: String {
//        currentUser?.email ?? ""
        ""
    }
}

enum UserError: Error, Equatable, LocalizedError, Codable {
    case authenticationFailed
    case networkError(String)
    case invalidCredentials
    case accountLocked
    case emailNotVerified
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked:
            return "Your account has been temporarily locked"
        case .emailNotVerified:
            return "Please verify your email address before logging in"
        }
    }
}
