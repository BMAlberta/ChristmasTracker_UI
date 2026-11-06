//
//  AuthenicationRespository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

/// Protocol for authentication access.
protocol AuthenticationRepository: AnyObject, Sendable {

    /// Traditional login.
    func login(email: String, password: String) async throws -> AuthSession

    /// New user registration.
    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession

    /// Rotate refresh token.
    func refresh(refreshToken: String) async throws -> AuthSession

    /// Logout (best-effort server-side invalidation).
    func logout() async throws
}

