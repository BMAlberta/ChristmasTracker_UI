//
//  AuthTypes.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation
// MARK: - Request Types
nonisolated struct LoginRequest: Codable, Sendable {
    let email: String
    let password: String
    let rememberMe: Bool
}

nonisolated struct RegisterRequest: Codable, Sendable {
    let email: String
    let password: String
    let name: String
}

nonisolated struct BiometricLoginRequest: Codable, Sendable {
    let userId: String
    let biometricToken: String // Keychain-protected token
}

nonisolated struct RefreshTokenRequest: Codable, Sendable {
    let refreshToken: String
    struct ForgotPasswordRequest: Codable, Sendable {
        let email: String
    }
}

nonisolated struct ForgotPasswordRequest: Codable, Sendable {
    let email: String
}

// MARK: - Response Types
nonisolated struct AuthResponse: Codable, Sendable {
    let success: Bool
    let data: AuthData
    let meta: ResponseMeta
}

struct AuthData: Codable, Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds
}

struct ResponseMeta: Codable, Sendable {
    let timestamp: String
    let requestId: String
    let sessionId: String
}

// MARK: - Token Storage
struct AuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    var isExpired: Bool {
        Date() >= expiresAt
    }
    var needsRefresh: Bool {
        // Refresh 5 minutes before expiry
        Date().addingTimeInterval(5 * 60) >= expiresAt
    }
}
