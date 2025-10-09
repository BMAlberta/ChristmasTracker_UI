//
//  Error.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

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
