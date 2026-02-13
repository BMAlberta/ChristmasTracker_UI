//
//  MockAuthenticationRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/8/26.
//

import Foundation

actor MockAuthenticationRepository: AuthenticationRepository {
    
    // MARK: - Mock Configuration
    var shouldFail: Bool = false
    var loginDelay: TimeInterval = 0.5
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
        
        return AuthData(user: mockUser,
                        accessToken: mockAccessToken,
                        refreshToken: mockRefreshToken,
                        expiresIn: 900)
        
        
    }
    
    func register(email: String, password: String, name: String) async throws -> AuthData {
        LogDebug("Mock register: \(email)", category: .auth)
        
        try await Task.sleep(for: .seconds(loginDelay))
        
        if shouldFail {
            throw AuthenticationError.emailAlreadyExists
        }
        
        let newUser = User(id: UUID().uuidString,
                           email: email,
                           name: name,
                           role: .user,
                           createdAt: Date(),
                           updatedAt: Date())
        
        return AuthData(user: newUser,
                        accessToken: mockAccessToken,
                        refreshToken: mockRefreshToken,
                        expiresIn: 900)
    }
    
    func biometricLogin(userId: String,biometricToken: String) async throws -> AuthData {
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
        
        return AuthData(user: mockUser,
                        accessToken: mockAccessToken,
                        refreshToken: mockRefreshToken,
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
