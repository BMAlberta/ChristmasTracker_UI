//
//  AuthTypes.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

// MARK: - Domain Session Type (C1)

/// Returned by all AuthenticationRepository methods in the new generated-client path.
nonisolated struct AuthSession: Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
    /// Seconds until the access token expires. 900 for login/register (not in those responses);
    /// taken from the body for refresh responses.
    let expiresIn: Int
}

// MARK: - Token Storage

nonisolated struct AuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    nonisolated var isExpired: Bool {
        Date() >= expiresAt
    }
    nonisolated var needsRefresh: Bool {
        // Refresh 5 minutes before expiry
        Date().addingTimeInterval(5 * 60) >= expiresAt
    }
}
