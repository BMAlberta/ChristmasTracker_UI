//
//  AuthenticationService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation
import SwiftUI
import TrackerInstrumentation

@MainActor
@Observable
final class AuthenticationService {

    // MARK: - Dependencies
    private let authRepository: AuthenticationRepository
    private let sessionManager: SessionManager
    internal let biometricAuthenticator: any BiometricAuthenticating
    private var emailStore: any RememberedEmailStoring
    private let legacyCleanup: any LegacyTokenCleaning
    private let credentialStore: any BiometricCredentialStoring

    // MARK: - Published State (Observable)
    private(set) var currentUser: User?
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var error: AuthenticationError?

    private(set) var isBiometricAvailable: Bool = false
    private(set) var biometricType: BiometricType = .none

    // Snapshot of the enrolled user; avoids live Keychain reads from view path.
    private(set) var enrolledUserSnapshot: (userId: String, firstName: String)? = nil

    // Biometric sign-in state machine; .idle means no active hint/error.
    private(set) var biometricSignInState: BiometricSignInState = .idle

    // Pending biometric enablement: set by pendBiometricEnablementRequest(),
    // consumed and surfaced as shouldShowBiometricEnablementAfterLogin after a successful login.
    private(set) var shouldShowBiometricEnablementAfterLogin: Bool = false
    private var pendingBiometricEnablement: Bool = false

    // MARK: - Private State
    private var tokens: AuthTokens?
    private let deviceFingerprint: String
    private static let keychainBiometricTokenKey = "auth.biometric_token"
    private static let keychainBiometricUserIdKey = "auth.user_id"
    private static let keychainReasonMessage = "Authenticate to access your Christmas Tracker account"
    private static let keychainAuthTokensKey = "auth.tokens"
    private static let keychainAuthRefreshTokenKey = "auth.refresh_token"

    // Single-flight refresh: keyed by refresh token so concurrent callers share one repo call.
    private var inflightRefreshTasks: [String: Task<AuthData, Error>] = [:]

    // MARK: - Initialization

    init(
        repository: AuthenticationRepository,
        sessionManager: SessionManager,
        biometricAuthenticator: any BiometricAuthenticating = LocalAuthenticationService(),
        emailStore: any RememberedEmailStoring = RememberedEmailStore(),
        legacyCleanup: any LegacyTokenCleaning = LegacyTokenCleanup(),
        credentialStore: any BiometricCredentialStoring = KeychainBiometricCredentialStore()
    ) {
        self.authRepository = repository
        self.sessionManager = sessionManager
        self.biometricAuthenticator = biometricAuthenticator
        self.emailStore = emailStore
        self.legacyCleanup = legacyCleanup
        self.credentialStore = credentialStore

        self.deviceFingerprint = (try? DeviceFingerprintService.getFingerprint()) ?? "unknown"

        refreshBiometricAvailability()
        legacyCleanup.cleanUpLegacyTokens()
    }

    // MARK: - Public Methods

    /// Request that the biometric-enrolment sheet be shown after the next successful login.
    func pendBiometricEnablementRequest() {
        pendingBiometricEnablement = true
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func enrollCurrentSession() async throws {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.enrollCurrentSession",
            operation: "service.authentication.enrollCurrentSession"
        )
        defer { transaction.finish() }
        guard let tokens = self.tokens, let user = self.currentUser else { return }
        let result = await biometricAuthenticator.authenticate(reason: "Enable Face ID for Christmas Tracker")
        switch result {
        case .success:
            let firstName = user.name.components(separatedBy: " ").first ?? ""
            try credentialStore.enroll(refreshToken: tokens.refreshToken, userId: user.id, firstName: firstName)
            refreshBiometricState()
        default:
            throw AuthenticationError.biometricFailed
        }
    }

    func revokeEnrollment() throws {
        try credentialStore.delete()
        refreshBiometricState()
    }

    var enrolledUser: (userId: String, firstName: String)? { enrolledUserSnapshot }

    var enrolledUserMatchesSession: Bool {
        guard let enrolled = enrolledUserSnapshot, let user = currentUser else { return false }
        return enrolled.userId == user.id
    }

    /// Clears the biometricSignInState back to .idle.
    func clearBiometricSignInState() {
        biometricSignInState = .idle
    }

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

            // Consume pending biometric enablement request on successful login.
            // Only offer if the pending flag is set AND the enrolled user does not already
            // match this session (i.e., this is a new user, not an already-enrolled returning user).
            if pendingBiometricEnablement && !enrolledUserMatchesSession {
                pendingBiometricEnablement = false
                shouldShowBiometricEnablementAfterLogin = true
            } else {
                pendingBiometricEnablement = false
                shouldShowBiometricEnablementAfterLogin = false
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

    /// Sign in using the biometric-protected refresh token from the credential store.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func signInWithBiometric() async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.signInWithBiometric",
            operation: "service.authentication.signInWithBiometric"
        )
        defer { transaction.finish() }
        isLoading = true
        defer { isLoading = false }
        biometricSignInState = .idle

        let typeName = biometricType.displayName

        // Read the refresh token — this triggers the biometric prompt.
        let refreshToken: String
        do {
            refreshToken = try await credentialStore.readRefreshToken(
                reason: "Sign in to Christmas Tracker"
            )
        } catch let credError as BiometricCredentialError {
            let outcome = biometricSignInOutcome(for: credError, biometryTypeName: typeName)
            if outcome.deleteEnrollment {
                try? credentialStore.delete()
            }
            if outcome.refreshSnapshot {
                refreshBiometricState()
            }
            biometricSignInState = outcome.state
            LogError("Biometric sign-in: credential error: \(credError)", category: .auth)
            return
        } catch {
            LogError("Biometric sign-in: credential store error: \(error)", category: .auth)
            return
        }

        // Perform single-flight token refresh.
        do {
            let authData = try await singleFlightRefresh(token: refreshToken)
            // Rotate the stored refresh token before surfacing authenticated state.
            try? credentialStore.updateRefreshToken(authData.refreshToken)
            await handleAuthSuccess(authData: authData)
            LogInfo("Biometric sign-in succeeded", category: .auth)
        } catch let authError as AuthenticationError {
            let outcome = biometricSignInOutcome(for: authError, biometryTypeName: typeName)
            if outcome.deleteEnrollment {
                try? credentialStore.delete()
            }
            if outcome.refreshSnapshot {
                refreshBiometricState()
            }
            biometricSignInState = outcome.state
            LogError("Biometric sign-in: auth error: \(authError)", category: .auth)
        } catch {
            LogError("Biometric sign-in: network or unknown error: \(error)", category: .auth)
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
    
    /// Logout current user
    func logout(reason: TeardownReason = .userLogout) async {
        // Capture repo reference before clearing state.
        let repo = authRepository

        // Local teardown FIRST — the user is signed out immediately regardless of network.
        // SessionClearable path clears all registered clearables.
        await sessionManager.teardown(reason: reason)
        // AuthenticationService is not a registered clearable: SessionManager must exist before
        // AuthenticationService can be constructed (circular dependency), so it clears its own state here.
        clearAuthState()
        clearStoredTokens()
        isLoading = false

        // Best-effort non-awaited server logout — enrollment is never touched here.
        Task {
            do {
                try await repo.logout(refreshToken: "")
            } catch {
                LogError("Logout API failed (best-effort): \(error)", category: .auth)
            }
        }
    }
    
    /// Refresh access token
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func refreshTokenIfNeeded() async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.refreshTokenIfNeeded",
            operation: "service.authentication.refreshTokenIfNeeded"
        )
        defer { transaction.finish() }
        guard let tokens = self.tokens, tokens.needsRefresh else {
            return
        }

        LogDebug("Refreshing access token", category: .auth)

        do {
            let authData = try await singleFlightRefresh(token: tokens.refreshToken)
            await updateTokens(authData: authData)

            // Rotate the stored credential token only if the enrolled user matches the session user.
            if let enrolled = credentialStore.enrolledUser(),
               enrolled.userId == currentUser?.id {
                try? credentialStore.updateRefreshToken(authData.refreshToken)
            }

            LogInfo("Token refreshed successfully", category: .auth)

        } catch let authError as AuthenticationError {
            if isCredentialFailure(authError) {
                // Delete enrollment only when it belongs to the current session user.
                if let enrolled = credentialStore.enrolledUser(),
                   enrolled.userId == currentUser?.id {
                    try? credentialStore.delete()
                }
                LogError("Token refresh credential failure — session ended", category: .auth)
                await logout(reason: .sessionExpired)
            } else {
                // Non-credential failure (network, etc.) — keep session and enrollment alive.
                LogError("Token refresh failed (non-credential): \(authError)", category: .auth)
            }
        } catch {
            // Unknown failure — keep session and enrollment alive.
            LogError("Token refresh failed: \(error)", category: .auth)
        }
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

    /// Single-flight refresh: concurrent callers with the same refresh token await
    /// the same in-flight repository call. The task is removed after it completes or fails.
    private func singleFlightRefresh(token: String) async throws -> AuthData {
        if let existing = inflightRefreshTasks[token] {
            return try await existing.value
        }
        let task = Task<AuthData, Error> { [authRepository] in
            try await authRepository.refreshToken(token)
        }
        inflightRefreshTasks[token] = task
        do {
            let result = try await task.value
            inflightRefreshTasks.removeValue(forKey: token)
            return result
        } catch {
            inflightRefreshTasks.removeValue(forKey: token)
            throw error
        }
    }

    private func handleAuthSuccess(authData: AuthData) async {
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
        // Silent token rotation: if the enrolled user matches the new session user,
        // update the stored refresh token without prompting.
        if credentialStore.enrolledUser()?.userId == authData.user.id {
            try? credentialStore.updateRefreshToken(authData.refreshToken)
        }
        // Refresh biometric state (availability, type, and enrolled user snapshot).
        refreshBiometricState()
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
            LogDebug("Stored tokens cleared", category: .auth)
        } catch {
            LogError("Failed to clear tokens: \(error)", category: .auth)
        }
    }
    
    /// Full biometric state refresh: availability, type, and enrolled user snapshot.
    func refreshBiometricState() {
        isBiometricAvailable = biometricAuthenticator.isAvailable
        switch biometricAuthenticator.biometryType {
        case .faceID:
            biometricType = .faceID
        case .touchID:
            biometricType = .touchID
        case .none:
            biometricType = .none
        }
        enrolledUserSnapshot = credentialStore.enrolledUser()
    }

    internal func refreshBiometricAvailability() {
        refreshBiometricState()
    }
}

// MARK: - SessionClearable

extension AuthenticationService: SessionClearable {
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func clearForSession() async throws {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.clearForSession",
            operation: "service.authentication.clearForSession"
        )
        defer { transaction.finish() }
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

