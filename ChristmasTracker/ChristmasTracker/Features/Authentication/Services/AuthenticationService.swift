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
    private let enrollmentHistory: any EnrollmentHistoryStoring

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

    // The offer action computed during the last successful login.
    private(set) var biometricOfferAction: BiometricOfferAction = .none

    // Pending biometric enablement: set by pendBiometricEnablementRequest(),
    // consumed and surfaced as shouldShowBiometricEnablementAfterLogin after a successful login.
    var shouldShowBiometricEnablementAfterLogin: Bool {
        biometricOfferAction == .showEnablementScreen
    }
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
    private var inflightRefreshTasks: [String: Task<AuthSession, Error>] = [:]

    // MARK: - Initialization

    init(
        repository: AuthenticationRepository,
        sessionManager: SessionManager,
        biometricAuthenticator: any BiometricAuthenticating = LocalAuthenticationService(),
        emailStore: any RememberedEmailStoring = RememberedEmailStore(),
        legacyCleanup: any LegacyTokenCleaning = LegacyTokenCleanup(),
        credentialStore: any BiometricCredentialStoring = KeychainBiometricCredentialStore(),
        enrollmentHistory: any EnrollmentHistoryStoring = EphemeralEnrollmentHistory()
    ) {
        self.authRepository = repository
        self.sessionManager = sessionManager
        self.biometricAuthenticator = biometricAuthenticator
        self.emailStore = emailStore
        self.legacyCleanup = legacyCleanup
        self.credentialStore = credentialStore
        self.enrollmentHistory = enrollmentHistory

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
        let firstName = user.firstName
        try credentialStore.enroll(refreshToken: tokens.refreshToken, userId: user.id, firstName: firstName)
        enrollmentHistory.setPreviouslyEnrolledUserId(user.id)
        refreshBiometricState()
        // Enrollment completed: clear the offer action so the UI knows enrollment is done.
        biometricOfferAction = .none
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

    /// Clears the biometric offer action back to .none (call after sheet dismissal).
    func clearBiometricOfferAction() {
        biometricOfferAction = .none
    }

    /// Clears the previously-enrolled user ID from enrollment history
    /// (called by ProfileBiometricToggleModel when revoking enrollment).
    func clearPreviouslyEnrolledUserId() {
        enrollmentHistory.setPreviouslyEnrolledUserId(nil)
    }

    /// Login
    // @MainActor-isolated async — manual SentrySDK span instead of @Instrumented
    func login(email: String, password: String, rememberEmail: Bool = false) async {
        let span = SentrySDK.startTransaction(name: "AuthenticationService.login", operation: "auth")
        defer { span.finish() }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let session = try await authRepository.login(email: email, password: password)

            // Compute the offer action before handleAuthSuccess so we have the pre-login
            // enrolled snapshot. refreshBiometricState() inside handleAuthSuccess will
            // update the snapshot after any silent enroll, but we evaluate against the
            // snapshot that existed at the time login completed.
            let readiness = biometricAuthenticator.readiness
            let offerAction = computeOfferAction(
                readiness: readiness,
                signedInUserId: session.user.id,
                pendingRequest: pendingBiometricEnablement
            )

            // Execute silent actions
            if offerAction == .silentlyReplaceToken {
                let firstName = session.user.firstName
                try? credentialStore.enroll(refreshToken: session.refreshToken, userId: session.user.id, firstName: firstName)
                enrollmentHistory.setPreviouslyEnrolledUserId(session.user.id)
                refreshBiometricState()
            } else if offerAction == .silentlyReenroll {
                let firstName = session.user.firstName
                try? credentialStore.enroll(refreshToken: session.refreshToken, userId: session.user.id, firstName: firstName)
                enrollmentHistory.setPreviouslyEnrolledUserId(session.user.id)
                refreshBiometricState()
            }

            // Always consume the pending flag
            pendingBiometricEnablement = false
            // Set the observable action
            self.biometricOfferAction = offerAction
            // If we are going to show the offer, mark it as shown now so a subsequent
            // login (without a pending request) does not repeat the offer.
            if offerAction == .showEnablementScreen {
                enrollmentHistory.markOfferShown(for: session.user.id)
            }

            await handleAuthSuccess(session: session)

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

        // Read the refresh token — this triggers the biometric prompt via evaluatePolicy
        // inside KeychainBiometricCredentialStore.readRefreshToken (F2 fix).
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
            let session = try await singleFlightRefresh(token: refreshToken)
            // Rotate the stored refresh token before surfacing authenticated state.
            try? credentialStore.updateRefreshToken(session.refreshToken)
            await handleAuthSuccess(session: session)
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

    /// Register a user (legacy service-level signature; name is split into first/last).
    func register(email: String, password: String, name: String) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        // Split name into first/last components for the new repository interface.
        let parts = name.components(separatedBy: " ")
        let firstName = parts.first ?? name
        let lastName = parts.dropFirst().joined(separator: " ")

        do {
            let session = try await authRepository.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName.isEmpty ? " " : lastName,
                registrationCode: ""
            )

            let offerAction = computeOfferAction(
                readiness: biometricAuthenticator.readiness,
                signedInUserId: session.user.id,
                pendingRequest: pendingBiometricEnablement
            )

            if offerAction == .silentlyReplaceToken {
                let fn = session.user.firstName
                try? credentialStore.enroll(refreshToken: session.refreshToken, userId: session.user.id, firstName: fn)
                enrollmentHistory.setPreviouslyEnrolledUserId(session.user.id)
                refreshBiometricState()
            } else if offerAction == .silentlyReenroll {
                let fn = session.user.firstName
                try? credentialStore.enroll(refreshToken: session.refreshToken, userId: session.user.id, firstName: fn)
                enrollmentHistory.setPreviouslyEnrolledUserId(session.user.id)
                refreshBiometricState()
            }

            self.biometricOfferAction = offerAction
            pendingBiometricEnablement = false

            if offerAction == .showEnablementScreen {
                enrollmentHistory.markOfferShown(for: session.user.id)
            }

            await handleAuthSuccess(session: session)

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
                try await repo.logout()
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
            let session = try await singleFlightRefresh(token: tokens.refreshToken)
            await updateTokens(session: session)

            // Rotate the stored credential token only if the enrolled user matches the session user.
            if let enrolled = credentialStore.enrolledUser(),
               enrolled.userId == currentUser?.id {
                try? credentialStore.updateRefreshToken(session.refreshToken)
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

    /// Current access token — used by AccessTokenSeam production closure.
    var currentAccessToken: String? { tokens?.accessToken }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func forceRefresh() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.authentication.forceRefresh",
            operation: "service.authentication.forceRefresh"
        )
        defer { span.finish() }
        guard let currentToken = tokens?.refreshToken else {
            throw AuthenticationError.invalidRefreshToken
        }
        let session = try await singleFlightRefresh(token: currentToken)
        await updateTokens(session: session)
    }

    /// Record user activity (for session keep-alive)
    func recordActivity() {
        Task {
            await sessionManager.recordActivity()
        }
    }

    // MARK: - Private Helpers

    /// Wrapper that delegates to the free function `biometricOfferAction(...)`, avoiding
    /// a naming ambiguity with the stored property `biometricOfferAction: BiometricOfferAction`.
    private func computeOfferAction(
        readiness: BiometricReadiness,
        signedInUserId: String,
        pendingRequest: Bool
    ) -> BiometricOfferAction {
        _computeBiometricOfferAction(
            readiness: readiness,
            enrolledUserId: enrolledUserSnapshot?.userId,
            signedInUserId: signedInUserId,
            previouslyEnrolledUserId: enrollmentHistory.previouslyEnrolledUserId,
            offerShownForUser: enrollmentHistory.hasSeenOffer(for: signedInUserId),
            pendingRequest: pendingRequest
        )
    }

    /// Single-flight refresh: concurrent callers with the same refresh token await
    /// the same in-flight repository call. The task is removed after it completes or fails.
    private func singleFlightRefresh(token: String) async throws -> AuthSession {
        if let existing = inflightRefreshTasks[token] {
            return try await existing.value
        }
        let task = Task<AuthSession, Error> { [authRepository] in
            try await authRepository.refresh(refreshToken: token)
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

    private func handleAuthSuccess(session: AuthSession) async {
        // Update user
        currentUser = session.user
        isAuthenticated = true
        // Store tokens
        let newTokens = AuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(session.expiresIn))
        )
        tokens = newTokens
        // Silent token rotation: if the enrolled user matches the new session user,
        // update the stored refresh token without prompting.
        if credentialStore.enrolledUser()?.userId == session.user.id {
            try? credentialStore.updateRefreshToken(session.refreshToken)
        }
        // Refresh biometric state (availability, type, and enrolled user snapshot).
        refreshBiometricState()
        // Set session ID in cache
        await NetworkCache.shared.setSessionId(session.user.id)
        // Start session keep-alive
        await sessionManager.startSession()
    }

    private func updateTokens(session: AuthSession) async {
        let newTokens = AuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(session.expiresIn))
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

// MARK: - Module-level shim (avoids naming conflict with the BiometricOfferAction stored property)

/// Thin forwarder so AuthenticationService can call the free function without ambiguity.
private nonisolated func _computeBiometricOfferAction(
    readiness: BiometricReadiness,
    enrolledUserId: String?,
    signedInUserId: String,
    previouslyEnrolledUserId: String?,
    offerShownForUser: Bool,
    pendingRequest: Bool
) -> BiometricOfferAction {
    biometricOfferAction(
        readiness: readiness,
        enrolledUserId: enrolledUserId,
        signedInUserId: signedInUserId,
        previouslyEnrolledUserId: previouslyEnrolledUserId,
        offerShownForUser: offerShownForUser,
        pendingRequest: pendingRequest
    )
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
        case .none: return "Face ID or Touch ID"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        }
    }
}
