//
//  AuthenticationService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation
import SwiftUI
import LocalAuthentication

@MainActor
@Observable
final class AuthenticationService {
    
    // MARK: - Dependencies
    private let authRepository: AuthenticationRepository
    private let sessionManager: SessionManager
    
    // MARK: - Published State (Observable)
    private(set) var currentUser: User?
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var error: AuthenticationError?
    
    private(set) var isBiometricAvailable: Bool = false
    private(set) var biometricType: BiometricType = .none
    
    // MARK: - Private State
    private var tokens: AuthTokens?
    private let deviceFingerprint: String
    private static let keychainBiometricTokenKey = "auth.biometric_token"
    private static let keychainBiometricUserIdKey = "auth.user_id"
    private static let keychainReasonMessage = "Authenticate to access your Christmas Tracker account"
    private static let keychainAuthTokensKey = "auth.tokens"
    private static let keychainAuthRefreshTokenKey = "auth.refresh_token"
    
    // MARK: - Initialization
    
    init(repository: AuthenticationRepository, sessionManager: SessionManager) {
        self.authRepository = repository
        self.sessionManager = sessionManager
        
        self.deviceFingerprint = (try? DeviceFingerprintService.getFingerprint()) ?? "unknown"
        
        Task {
            await checkBiometricAvailability()
            await loadStoredSession()
        }
    }
    
    // MARK: - Public Methods
    /// Login
    func login(email: String, password: String, rememberMe: Bool = false) async {
        isLoading = true
        error = nil
        
        do {
            let authData = try await authRepository.login(email: email,
                                                          password: password,
                                                          rememberMe: rememberMe)
            
            await handleAuthSuccess(authData: authData, rememberMe: rememberMe)
            
            LogInfo("User logged in: \(email)", category: .auth)
        } catch let authError as AuthenticationError {
            error = authError
            LogError("Login failed: \(authError)", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Login failed: \(error)", category: .auth)
        }
    }
    
    
    /// Register a user
    func register(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        
        do {
            let authData = try await authRepository.register(email: email,
                                                   password: password,
                                                   name: name)
            
            await handleAuthSuccess(authData: authData,
                                    rememberMe: true)
            
            LogInfo("User registered: \(email)", category: .auth)
        } catch let authError as AuthenticationError {
            error = authError
            LogError("Registration failed: \(authError)", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Registration failed: \(error)", category: .auth)
        }
        
        isLoading = false
    }
    
    /// Login with biometric auth
    func loginWithBiometric() async {
        guard isBiometricAvailable else {
            error = .biometricNotAvailable
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Get token from keychain
            let biometricToken = try await KeychainService.getWithBiometric(Self.keychainBiometricTokenKey,
                                                                            reason: Self.keychainReasonMessage)
            
            // Get user id
            let userId = try KeychainService.get(Self.keychainBiometricUserIdKey)
        
            // Call auth
            let authData = try await authRepository.biometricLogin(userId: userId,
                                                                   biometricToken: biometricToken)
            
            await handleAuthSuccess(authData: authData,
                                    rememberMe: true)
            
            LogInfo("Biometric authentication successful", category: .auth)
            
            
        } catch KeychainService.KeychainError.biometricFailed {
            error = .biometricFailed
            LogError("Biometric authentication failed", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Biometric login failed: \(error)", category: .auth)
        }
        
    }
    
    /// Logout current user
    func logout() async {
        isLoading = true
        
        defer {
            clearAuthState()
            isLoading = false
        }
        
        await sessionManager.stopSession()
        await NetworkCache.shared.clear()
        
        if let refreshToken = tokens?.refreshToken {
            do {
                try await authRepository.logout(refreshToken: refreshToken)
            } catch {
                LogError("Logout API failed: \(error)", category: .auth)
            }
        }
        clearStoredTokens()
    }
    
    /// Refresh access token
    func refreshTokenIfNeeded() async {
        guard let tokens = self.tokens, tokens.needsRefresh else {
            return
        }
        
        LogDebug("Refreshing access token", category: .auth)
        
        do {
            let authData = try await authRepository.refreshToken(tokens.refreshToken)
            await updateTokens(authData: authData)
            
            LogInfo("Token refreshed successfully", category: .auth)
            
        } catch {
            LogError("Token refresh failed: \(error)", category: .auth)
            
            await logout()
        }
        
    }
    
    /// Setup biometric auth
    func setupBiometrics(biometricToken: String) async throws {
        guard isBiometricAvailable else {
            throw AuthenticationError.biometricNotAvailable
        }
        
        guard let userId = currentUser?.id else {
            throw AuthenticationError.networkError
        }
        
        try KeychainService.set(biometricToken,
                                for: Self.keychainBiometricTokenKey,
                                accessControl: .biometry)
        
        try KeychainService.set(userId, for: Self.keychainBiometricUserIdKey)
        
        LogInfo("Biometric authentication enabled", category: .auth)
    }
    
    /// Forgot password flow
    func forgotPassword(email: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authRepository.forgotPassword(email: email)
            LogInfo("Password reset email sent", category: .auth)
        } catch let authError as AuthenticationError {
            error = authError
            LogError("Forgot password failed: \(authError)", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Forgot password failed: \(error)", category: .auth)
        }
    }
    
    /// Record user activity (for session keep-alive)
    func recordActivity() {
        Task {
            await sessionManager.recordActivity()
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleAuthSuccess(authData: AuthData, rememberMe: Bool) async {
        // Update user
        currentUser = authData.user
        isAuthenticated = true
        // Store tokens
        let newTokens = AuthTokens(
            accessToken: authData.accessToken,
            refreshToken: authData.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(authData.expiresIn))
        )
        tokens = newTokens
        // Store tokens if remember me
        if rememberMe {
            storeTokens(newTokens)
        }
        // Set session ID in cache
        await NetworkCache.shared.setSessionId(authData.user.id)
        // Start session keep-alive
        await sessionManager.startSession()
    }
    
    private func updateTokens(authData: AuthData) async {
        let newTokens = AuthTokens(
            accessToken: authData.accessToken,
            refreshToken: authData.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(authData.expiresIn))
        )
        tokens = newTokens
        // Update stored tokens if they exist
        if (try? KeychainService.get(Self.keychainAuthRefreshTokenKey)) != nil {
            storeTokens(newTokens)
        }
    }
    
    private func storeTokens(_ tokens: AuthTokens) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(tokens)
            let string = String(data: data, encoding: .utf8)!
            try KeychainService.set(string, for: Self.keychainAuthTokensKey)
            try KeychainService.set(tokens.refreshToken, for: Self.keychainAuthRefreshTokenKey)
            LogDebug("Tokens stored in keychain", category: .auth)
        } catch {
            LogError("Failed to store tokens: \(error)", category: .auth)
        }
    }
    
    private func loadStoredSession() async {
        do {
            // Try to load stored tokens
            let tokenString = try KeychainService.get(Self.keychainAuthTokensKey)
            guard let data = tokenString.data(using: .utf8) else { return }
            let decoder = JSONDecoder()
            let storedTokens = try decoder.decode(AuthTokens.self, from: data)
            // Check if tokens expired
            guard !storedTokens.isExpired else {
                LogDebug("Stored tokens expired", category: .auth)
                clearStoredTokens()
                return
            }
            // Try to refresh token
            LogDebug("Found stored session, attempting refresh", category: .auth)
            let authData = try await authRepository.refreshToken(
                storedTokens.refreshToken)
            await handleAuthSuccess(authData: authData, rememberMe: true)
            LogInfo("Session restored from stored tokens", category: .auth)
        } catch KeychainService.KeychainError.itemNotFound {
            // No stored session - expected
            LogDebug("No stored session found", category: .auth)
        } catch {
            LogError("Failed to restore session: \(error)", category: .auth)
            clearStoredTokens()
        }
    }
    
    private func clearAuthState() {
        currentUser = nil
        isAuthenticated = false
        tokens = nil
        error = nil
    }
    private func clearStoredTokens() {
        do {
            try KeychainService.delete(Self.keychainAuthTokensKey)
            try KeychainService.delete(Self.keychainAuthRefreshTokenKey)
            try KeychainService.delete(Self.keychainBiometricUserIdKey)
            try KeychainService.delete(Self.keychainBiometricTokenKey)
            LogDebug("Stored tokens cleared", category: .auth)
        } catch {
            LogError("Failed to clear tokens: \(error)", category: .auth)
        }
    }
    
    private func checkBiometricAvailability() async {
        // Check if device supports biometric authentication
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType == .faceID ? .faceID : .touchID
            LogDebug("Biometric available: \(biometricType)", category: .auth)
        } else {
            isBiometricAvailable = false
            biometricType = .none
            LogDebug("Biometric not available", category: .auth)
        }
    }
}

// MARK: - Supporting Types
enum BiometricType {
    case none
    case touchID
    case faceID
    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
}
//// MARK: - Environment Key
//private struct AuthenticationServiceKey: EnvironmentKey {
//    static let defaultValue: AuthenticationService = AuthenticationService(
//        repository: MockAuthenticationRepository(),
//        sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
//    )
//}
//
//extension EnvironmentValues {
//    var authenticationService: AuthenticationService {
//        get { self[AuthenticationServiceKey.self] }
//        set { self[AuthenticationServiceKey.self] = newValue }
//    }
//}

