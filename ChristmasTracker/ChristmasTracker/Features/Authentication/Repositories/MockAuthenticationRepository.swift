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
        name: "Test User",
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )
    var mockAccessToken: String = "mock_access_token_\(UUID().uuidString)"
    var mockRefreshToken: String = "mock_refresh_token_\(UUID().uuidString)"


    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        LogDebug("Mock login: \(email)", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.invalidCredentials
        }

        if email == "fail@example.com" {
            throw AuthenticationError.invalidCredentials
        }

        let user = stableUser(for: email)
        let refreshToken = makeRefreshToken(userId: user.id)
        return AuthData(user: user,
                        accessToken: "mock_at_\(UUID().uuidString)",
                        refreshToken: refreshToken,
                        expiresIn: 900)
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        LogDebug("Mock register: \(email)", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.emailAlreadyExists
        }

        // Use a stable userId derived from the email so that offer-action logic
        // (which keys on userId) behaves predictably in multi-step test scenarios.
        let userId = stableUserId(for: email)
        let newUser = User(id: userId,
                           email: email,
                           name: name,
                           role: .user,
                           createdAt: Date(),
                           updatedAt: Date())
        let refreshToken = makeRefreshToken(userId: userId)

        return AuthData(user: newUser,
                        accessToken: mockAccessToken,
                        refreshToken: refreshToken,
                        expiresIn: 900)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        LogDebug("Mock biometric login: \(userId)", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.biometricFailed
        }

        return AuthData(user: mockUser,
                        accessToken: mockAccessToken,
                        refreshToken: mockRefreshToken,
                        expiresIn: 900)

    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        LogDebug("Mock token refresh", category: .auth)

        if shouldFail {
            throw AuthenticationError.invalidRefreshToken
        }

        guard let userId = parseUserId(from: refreshToken) else {
            throw AuthenticationError.invalidRefreshToken
        }

        if userId == "mock-expired" {
            throw AuthenticationError.invalidRefreshToken
        }

        // Reconstruct user from userId (strip "mock-" prefix to recover localPart)
        let localPart = userId.hasPrefix("mock-") ? String(userId.dropFirst(5)) : userId
        let email = "\(localPart)@example.com"
        let user = stableUser(for: email)
        let newRefreshToken = makeRefreshToken(userId: userId)
        return AuthData(user: user,
                        accessToken: "mock_at_\(UUID().uuidString)",
                        refreshToken: newRefreshToken,
                        expiresIn: 900)
    }

    func ping() async throws {
        LogDebug("Mock ping", category: .auth)

        if shouldFail {
            throw AuthenticationError.sessionExpired
        }
    }

    func logout(refreshToken: String) async throws {
        LogDebug("Mock logout", category: .auth)
    }

    func forgotPassword(email: String) async throws {
        LogDebug("Mock forgot password: \(email)", category: .auth)

        try await Task.sleep(for: .seconds(loginDelay))

        if shouldFail {
            throw AuthenticationError.userNotFound
        }
    }

    // MARK: - Private Helpers

    private func stableUserId(for email: String) -> String {
        let localPart = email.components(separatedBy: "@").first ?? email
        return "mock-\(localPart.lowercased())"
    }

    private func stableUser(for email: String) -> User {
        let userId = stableUserId(for: email)
        let localPart = email.components(separatedBy: "@").first ?? email
        let name = localPart.prefix(1).uppercased() + localPart.dropFirst()
        return User(
            id: userId,
            email: email,
            name: String(name),
            role: .user,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
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
enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case userNotFound
    case biometricFailed
    case biometricNotAvailable
    case invalidRefreshToken
    case sessionExpired
    case networkError
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
        }
    }
}
