//
//  AuthenticationService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/9/26.
//

import Foundation
import SwiftUI
import TrackerAPI
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

    // The one session-end guard (main-actor isolated). Set by the first endSession call of a
    // session and kept after it completes, so later calls await it (in flight) or return at
    // once (completed). handleAuthSuccess clears it when a new session starts.
    private var sessionEndTask: Task<Void, Never>?

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

            // Compute and apply the biometric offer action before handleAuthSuccess so we
            // evaluate against the enrolled snapshot that existed at the time login completed.
            applyBiometricOffer(session: session)

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

    /// Register a user.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        registrationCode: String
    ) async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.register",
            operation: "service.authentication.register"
        )
        defer { transaction.finish() }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let session = try await authRepository.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                registrationCode: registrationCode
            )

            applyBiometricOffer(session: session)

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

    /// Logout current user. Goes through the single session-end guard; the enrollment is untouched.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func logout(reason: TeardownReason = .userLogout) async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.logout",
            operation: "service.authentication.logout"
        )
        defer { transaction.finish() }
        await endSession(reason: reason)
    }

    /// The single guarded session-end entry point; the only place a teardown happens.
    /// The first call of a session tears down. Calls that arrive while it is in flight await it
    /// and do not tear down or delete again; after it completes, calls are no-ops until a new
    /// session starts (handleAuthSuccess resets the guard). A never-signed-in service can end once.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    internal func endSession(reason: TeardownReason, deletingEnrollmentForCurrentUser: Bool = false) async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.endSession",
            operation: "service.authentication.endSession"
        )
        defer { transaction.finish() }
        if let existing = sessionEndTask {
            await existing.value
            return
        }
        // Created and stored with no suspension in between; main-actor isolation serializes callers.
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performSessionEnd(reason: reason, deletingEnrollment: deletingEnrollmentForCurrentUser)
        }
        sessionEndTask = task
        await task.value
    }

    /// A server-initiated session end (403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND), forwarded by
    /// the SessionEnding seam. Ends only a signed-in session, and only when the failing request
    /// carried the current access token. Never deletes the Face ID enrollment.
    /// Stale responses: a slow 403/404 to a request made by an earlier session (for example,
    /// user A's request answered after user B signed in) carries A's token, not the current one,
    /// so it is ignored. A nil request token is ignored too. Trade-off: a request that used a
    /// token a refresh has since rotated is also ignored; that is acceptable because the next
    /// request carries the new token and gets its own 403/404, which ends the session.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    internal func handleServerSessionEnd(reason: SessionEndReason, requestToken: String?) async {
        let transaction = SentrySDK.startTransaction(
            name: "service.authentication.handleServerSessionEnd",
            operation: "service.authentication.handleServerSessionEnd"
        )
        defer { transaction.finish() }
        guard isAuthenticated else { return }
        guard let requestToken, requestToken == currentAccessToken else {
            // No token values in the log.
            LogInfo("Session end ignored: ignored a stale session-end", category: .auth)
            return
        }
        LogInfo("Session ended by the server: \(reason)", category: .auth)
        await endSession(reason: .sessionExpired)
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
            if isCredentialFailure(authError, context: .refresh) {
                LogError("Token refresh credential failure — session ended", category: .auth)
                await endSessionAfterRefreshCredentialFailure()
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
        // No tokens means no session (for example, after logout): throw without ending anything.
        guard let currentToken = tokens?.refreshToken else {
            throw AuthenticationError.invalidRefreshToken
        }
        let session: AuthSession
        do {
            session = try await singleFlightRefresh(token: currentToken)
        } catch let authError as AuthenticationError {
            if isCredentialFailure(authError, context: .refresh) {
                LogError("Forced refresh credential failure — session ended", category: .auth)
                await endSessionAfterRefreshCredentialFailure()
            }
            // Rethrow the original error so the caller (SessionRefreshSeam) can classify it.
            throw authError
        }
        await updateTokens(session: session)
    }

    /// Record user activity (for session keep-alive)
    func recordActivity() {
        Task {
            await sessionManager.recordActivity()
        }
    }

    // MARK: - Private Helpers

    /// Ends the session after a refresh-context credential failure (D-b), only when signed in:
    /// the guarded end deletes the Face ID enrollment if it belongs to the current user and
    /// this call starts the end.
    private func endSessionAfterRefreshCredentialFailure() async {
        guard isAuthenticated else { return }
        await endSession(reason: .sessionExpired, deletingEnrollmentForCurrentUser: true)
    }

    /// The body of a session end; run only by the task endSession stores as the guard.
    private func performSessionEnd(reason: TeardownReason, deletingEnrollment: Bool) async {
        if deletingEnrollment, let userId = currentUser?.id, credentialStore.enrolledUser()?.userId == userId {
            try? credentialStore.delete()
            // Keep the enrolled-user snapshot in step with the store so the login screen
            // does not offer Face ID for a deleted token.
            refreshBiometricState()
        }

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

    /// Applies the biometric offer logic shared between login() and register().
    /// Computes the offer action, executes any silent enrollment, and sets biometricOfferAction.
    private func applyBiometricOffer(session: AuthSession) {
        let offerAction = computeOfferAction(
            readiness: biometricAuthenticator.readiness,
            signedInUserId: session.user.id,
            pendingRequest: pendingBiometricEnablement
        )
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
        pendingBiometricEnablement = false
        self.biometricOfferAction = offerAction
        if offerAction == .showEnablementScreen {
            enrollmentHistory.markOfferShown(for: session.user.id)
        }
    }

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
        // A new session starts: reset the session-end guard so a later end tears down again.
        sessionEndTask = nil
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
