//
//  AuthenticationService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AuthenticationService {
    
    // MARK: - Dependencies
    private let authRepository: AuthenticationRepository
    private let sessionManager: SessionManager
    internal let biometricAuthenticator: any BiometricAuthenticating
    private var emailStore: any RememberedEmailStoring
    private let legacyCleanup: any LegacyTokenCleaning
    
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
    
    init(
        repository: AuthenticationRepository,
        sessionManager: SessionManager,
        biometricAuthenticator: any BiometricAuthenticating = LocalAuthenticationService(),
        emailStore: any RememberedEmailStoring = RememberedEmailStore(),
        legacyCleanup: any LegacyTokenCleaning = LegacyTokenCleanup()
    ) {
        self.authRepository = repository
        self.sessionManager = sessionManager
        self.biometricAuthenticator = biometricAuthenticator
        self.emailStore = emailStore
        self.legacyCleanup = legacyCleanup

        self.deviceFingerprint = (try? DeviceFingerprintService.getFingerprint()) ?? "unknown"

        refreshBiometricAvailability()
        legacyCleanup.cleanUpLegacyTokens()
    }

    // MARK: - Public Methods
    /// Login
    func login(email: String, password: String, rememberEmail: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let authData = try await authRepository.login(email: email,
                                                          password: password,
                                                          rememberMe: true)

            await handleAuthSuccess(authData: authData)

            if rememberEmail {
                emailStore.rememberedEmail = email
            } else {
                emailStore.rememberedEmail = nil
            }

            LogInfo("User logged in", category: .auth)
        } catch let authError as AuthenticationError {
            error = authError
            LogError("Login failed: \(authError)", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Login failed: \(error)", category: .auth)
        }
    }

    /// Clear current error
    func clearError() {
        error = nil
    }
    
    
    /// Register a user
    func register(email: String, password: String, name: String) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let authData = try await authRepository.register(email: email,
                                                   password: password,
                                                   name: name)

            await handleAuthSuccess(authData: authData)

            LogInfo("User registered", category: .auth)
        } catch let authError as AuthenticationError {
            error = authError
            LogError("Registration failed: \(authError)", category: .auth)
        } catch {
            self.error = .networkError
            LogError("Registration failed: \(error)", category: .auth)
        }
    }
    
    /// Login with biometric auth
    func loginWithBiometric() async {
        guard isBiometricAvailable else {
            error = .biometricNotAvailable
            return
        }
        
        isLoading = true
        defer { isLoading = false }
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
            
            await handleAuthSuccess(authData: authData)

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
    func logout(reason: TeardownReason = .userLogout) async {
        isLoading = true
        defer { isLoading = false }

        if let refreshToken = tokens?.refreshToken {
            do {
                try await authRepository.logout(refreshToken: refreshToken)
            } catch {
                LogError("Logout API failed: \(error)", category: .auth)
            }
        }

        // Route through teardown — clears all registered clearables
        await sessionManager.teardown(reason: reason)
        // AuthenticationService is not a registered clearable: SessionManager must exist before
        // AuthenticationService can be constructed (circular dependency), so it clears its own state here.
        clearAuthState()
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
            
            await logout(reason: .sessionExpired)
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
        defer { isLoading = false }
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

    private func handleAuthSuccess(authData: AuthData) async {
        refreshBiometricAvailability()
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
    
    internal func refreshBiometricAvailability() {
        isBiometricAvailable = biometricAuthenticator.isAvailable
        switch biometricAuthenticator.biometryType {
        case .faceID:
            biometricType = .faceID
        case .touchID:
            biometricType = .touchID
        case .none:
            biometricType = .none
        }
    }
}

// MARK: - SessionClearable

extension AuthenticationService: SessionClearable {
    // Actor-isolated (@MainActor): manual instrumentation only — @Instrumented not yet available (I6a)
    func clearForSession() async throws {
        clearAuthState()
        clearStoredTokens()
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

