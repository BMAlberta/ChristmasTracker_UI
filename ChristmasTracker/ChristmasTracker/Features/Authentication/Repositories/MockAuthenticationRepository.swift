//
//  MockAuthenticationRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

// MockAuthenticationRepository is a final class (not actor) so that tests can create
// instances from synchronous nonisolated contexts. Protocol methods are async so callers
// can still use `await` as before. The NSLock guards the mutable properties.
nonisolated final class MockAuthenticationRepository: AuthenticationRepository, @unchecked Sendable {

    // MARK: - Mock Configuration
    var shouldFail: Bool = false
    var loginDelay: TimeInterval = 0
    var mockUser: User = User(
        id: "mock-user-123",
        email: "test@example.com",
        firstName: "Test",
        lastName: "User",
        displayName: "Test User",
        role: .user,
        isActive: true,
        createdAt: Date(),
        updatedAt: Date(),
        lastLoginAt: nil
    )
    var mockAccessToken: String = "mock_access_token_\(UUID().uuidString)"
    var mockRefreshToken: String = "mock_refresh_token_\(UUID().uuidString)"

    // MARK: - C1 Primary Interface

    func login(email: String, password: String) async throws -> AuthSession {
        LogDebug("Mock login", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.invalidCredentials
        }

        if email == "fail@example.com" || email == "fail@test.invalid" {
            throw AuthenticationError.invalidCredentials
        }

        if email == "expired@test.invalid" {
            throw AuthenticationError.credentialExpired
        }

        let user = stableUser(for: email)
        let refreshToken = makeRefreshToken(userId: user.id)
        return AuthSession(
            user: user,
            accessToken: "mock_at_\(UUID().uuidString)",
            refreshToken: refreshToken,
            expiresIn: 900
        )
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        LogDebug("Mock register", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.emailAlreadyExists
        }

        if registrationCode == "CODE-INVALID-FAKE" {
            throw AuthenticationError.invalidRegistrationCode
        }

        let userId = stableUserId(for: email)
        let displayName = "\(firstName) \(lastName)"
        let newUser = User(
            id: userId,
            email: email,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            role: .user,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date(),
            lastLoginAt: nil
        )
        let refreshToken = makeRefreshToken(userId: userId)
        return AuthSession(
            user: newUser,
            accessToken: mockAccessToken,
            refreshToken: refreshToken,
            expiresIn: 900
        )
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        LogDebug("Mock token refresh (C1)", category: .auth)

        if shouldFail {
            throw AuthenticationError.invalidRefreshToken
        }

        guard let userId = parseUserId(from: refreshToken) else {
            throw AuthenticationError.invalidRefreshToken
        }

        if userId == "mock-expired" {
            throw AuthenticationError.credentialExpired
        }

        let localPart = userId.hasPrefix("mock-") ? String(userId.dropFirst(5)) : userId
        let email = "\(localPart)@example.com"
        let user = stableUser(for: email)
        let newRefreshToken = makeRefreshToken(userId: userId)
        return AuthSession(
            user: user,
            accessToken: "mock_at_\(UUID().uuidString)",
            refreshToken: newRefreshToken,
            expiresIn: 900
        )
    }

    func logout() async throws {
        LogDebug("Mock logout (C1)", category: .auth)
    }

    // MARK: - Private Helpers

    private func stableUserId(for email: String) -> String {
        let localPart = email.components(separatedBy: "@").first ?? email
        return "mock-\(localPart.lowercased())"
    }

    private func stableUser(for email: String) -> User {
        let userId = stableUserId(for: email)
        let localPart = email.components(separatedBy: "@").first ?? email
        let firstName = String(localPart.prefix(1).uppercased() + localPart.dropFirst())
        return User(
            id: userId,
            email: email,
            firstName: firstName,
            lastName: String(firstName.first ?? "U"),
            displayName: firstName,
            role: .user,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            lastLoginAt: nil
        )
    }

    private func makeRefreshToken(userId: String) -> String {
        "mock_rt_\(userId)_\(UUID().uuidString)"
    }

    private func parseUserId(from refreshToken: String) -> String? {
        guard refreshToken.hasPrefix("mock_rt_") else { return nil }
        // Format: "mock_rt_{userId}_{uuid}"
        // The UUID uses "-" not "_", so splitting on "_" yields exactly:
        // ["mock", "rt", userId, uuidString] where uuidString still contains "-".
        let components = refreshToken.components(separatedBy: "_")
        guard components.count >= 4 else { return nil }
        return components[2]
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyExists
    case userNotFound
    case biometricFailed
    case biometricNotAvailable
    case invalidRefreshToken
    case sessionExpired
    case networkError
    // C1: new cases
    case invalidResponse         // undecodable or malformed response
    case accountDisabled         // 1008 ACCOUNT_DISABLED
    case updateRequired          // 426 VERSION_OUTDATED
    case rateLimited(retryAfter: TimeInterval) // 429 with optional retry-after
    case serverError             // 500 or other internal error
    case invalidRegistrationCode // 1017 REGISTRATION_CODE_INVALID
    case validation(message: String) // 400 validation
    case credentialExpired       // 1005/1006 refresh token expired/invalid (token-rotation-specific)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .userNotFound:
            return "No account found with this email"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .invalidRefreshToken:
            return "Your session has expired. Please login again"
        case .sessionExpired:
            return "Your session has expired. Please login again"
        case .networkError:
            return "Network error. Please check your connection"
        case .invalidResponse:
            return "An unexpected response was received from the server"
        case .accountDisabled:
            // D-d: AuthErrorMessages.swift is the single source of the administrator text.
            return userMessage(for: .accountDisabled)
        case .updateRequired:
            return "A newer version of the app is required. Please update"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .serverError:
            return "A server error occurred. Please try again later"
        case .invalidRegistrationCode:
            return "The registration code is invalid or has expired"
        case .validation(let message):
            return message
        case .credentialExpired:
            return "Your session credentials have expired. Please login again"
        }
    }
}
