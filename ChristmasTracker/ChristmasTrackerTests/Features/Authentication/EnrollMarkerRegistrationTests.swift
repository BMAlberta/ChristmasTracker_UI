//
//  EnrollMarkerRegistrationTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a F1: defect fixes E1, E2, and E4.
//
//  E1 — enrollCurrentSession() must set enrollmentHistory.previouslyEnrolledUserId
//       to the enrolled user's id AFTER completing, and must NOT call
//       biometricAuthenticator.authenticate() (evaluationCount stays 0 inside the method).
//
//  E2 — register() gains offer logic: biometricOfferAction is .showEnablementScreen
//       after a first-time registration when biometrics are available and no prior
//       enrollment exists.
//
//  E4 — ProfileBiometricToggleModel.toggle(to: true) must authenticate exactly ONCE
//       (in the toggle model, before calling enrollCurrentSession). enrollCurrentSession
//       itself must NOT authenticate again. Total evaluationCount == 1 on success and
//       == 1 on failure (not 2).
//
//  RED-phase: these tests will FAIL on the current production code and must PASS after
//  the implementation fixes E1, E2, and E4.
//
//  Concurrency: suite is @MainActor because AuthenticationService and
//  ProfileBiometricToggleModel are both @MainActor @Observable.
//  No real Keychain, no real LocalAuthentication, no real network.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - InMemoryEnrollmentHistory (local to this file)

/// Minimal in-memory EnrollmentHistoryStoring double. Isolated per test via
/// a fresh instance from makeSUT(). Not shared with other test files.
private final class InMemoryEnrollmentHistory: EnrollmentHistoryStoring, @unchecked Sendable {
    nonisolated(unsafe) private var _previouslyEnrolledUserId: String?
    nonisolated(unsafe) private var offerShownSet: Set<String> = []
    private let lock = NSLock()

    nonisolated var previouslyEnrolledUserId: String? {
        lock.withLock { _previouslyEnrolledUserId }
    }

    nonisolated func setPreviouslyEnrolledUserId(_ userId: String?) {
        lock.withLock { _previouslyEnrolledUserId = userId }
    }

    nonisolated func hasSeenOffer(for userId: String) -> Bool {
        lock.withLock { offerShownSet.contains(userId) }
    }

    nonisolated func markOfferShown(for userId: String) {
        lock.withLock { offerShownSet.insert(userId) }
    }
}

// MARK: - SUT factory

@MainActor
private func makeSUT(
    authenticatorResult: BiometricResult = .success,
    biometricsAvailable: Bool = true,
    enrollmentHistory: InMemoryEnrollmentHistory = InMemoryEnrollmentHistory()
) -> (
    service: AuthenticationService,
    repo: MockAuthenticationRepository,
    store: InMemoryBiometricCredentialStore,
    authenticator: FakeBiometricAuthenticator,
    history: InMemoryEnrollmentHistory
) {
    let repo = MockAuthenticationRepository()
    let sessionManager = SessionManager(authRepository: repo)
    let store = InMemoryBiometricCredentialStore()
    let auth = FakeBiometricAuthenticator()
    auth.stubbedResult = authenticatorResult
    auth.stubbedIsAvailable = biometricsAvailable
    auth.stubbedReadiness = biometricsAvailable ? .ready : .noHardware
    let service = AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: auth,
        credentialStore: store,
        enrollmentHistory: enrollmentHistory
    )
    return (service, repo, store, auth, enrollmentHistory)
}

// MARK: - Suite

@Suite("EnrollMarker and Registration Tests (F1 defects E1, E2, E4)")
@MainActor
struct EnrollMarkerRegistrationTests {

    // =========================================================================
    // MARK: - E1: enrollCurrentSession() sets the previouslyEnrolledUserId marker
    // =========================================================================

    /// After a successful enrollCurrentSession(), the enrollment history must record
    /// the enrolled user's id so that future logins can silently re-enroll.
    @Test("E1a: enrollCurrentSession sets previouslyEnrolledUserId to the enrolled user's id")
    func enrollCurrentSessionSetsPreviouslyEnrolledUserId() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated before enrolling")
        let userId = try #require(service.currentUser?.id,
                                  "Precondition: currentUser must be set after login")

        try await service.enrollCurrentSession()

        // E1 fix: the marker must be set.
        #expect(history.previouslyEnrolledUserId == userId,
                "enrollCurrentSession() must call setPreviouslyEnrolledUserId(userId) so future logins can silently re-enroll")
    }

    /// After the E4 fix, enrollCurrentSession() does NOT authenticate — the caller does.
    /// Calling enrollCurrentSession() directly always sets the marker when a session exists,
    /// regardless of the auth stub (the stub is irrelevant since auth was removed).
    @Test("E1b: enrollCurrentSession always sets previouslyEnrolledUserId when called after login (auth stub irrelevant after E4)")
    func enrollCurrentSessionAlwaysSetsMarkerWhenCalledAfterLogin() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .userCancelled,  // irrelevant after E4 — no auth inside enrollCurrentSession
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")

        // After E4, enrollCurrentSession() does not call biometricAuthenticator.
        // It always enrolls and sets the marker when a session exists.
        try await service.enrollCurrentSession()

        #expect(history.previouslyEnrolledUserId != nil,
                "enrollCurrentSession() must set previouslyEnrolledUserId — authentication was moved to the caller so enrollment always succeeds when a session exists")
    }

    // =========================================================================
    // MARK: - E1 / E4: enrollCurrentSession() must NOT call biometricAuthenticator.authenticate()
    // =========================================================================

    /// The E4 fix moves authentication OUT of enrollCurrentSession() and INTO the
    /// caller (ProfileBiometricToggleModel.toggle). Therefore evaluationCount must be
    /// 0 after calling enrollCurrentSession() directly — the method no longer prompts.
    @Test("E1/E4: enrollCurrentSession does not call biometricAuthenticator.authenticate (evaluationCount == 0)")
    func enrollCurrentSessionDoesNotCallAuthenticate() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, auth, _) = makeSUT(
            authenticatorResult: .success,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")

        // Reset count in case login itself triggered anything.
        auth.resetEvaluationCount()

        try await service.enrollCurrentSession()

        // E4 fix: authentication must NOT happen inside enrollCurrentSession().
        #expect(auth.evaluationCount == 0,
                "enrollCurrentSession() must not call biometricAuthenticator.authenticate() — authentication was moved to the caller (toggle model)")
    }

    // =========================================================================
    // MARK: - E2: register() gains offer logic
    // =========================================================================

    /// A first-time registration for a user who has never enrolled and has biometrics
    /// available must result in biometricOfferAction == .showEnablementScreen.
    @Test("E2a: register for new user with biometrics available and no prior enrollment sets biometricOfferAction to .showEnablementScreen")
    func registerNewUserWithBiometricsAvailableSetsShowEnablementScreen() async {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        // No prior enrollment; offer not shown; no pendingBiometricEnablement flag.

        await service.register(email: "bob@example.com", password: "pass", name: "Bob")

        #expect(service.isAuthenticated == true,
                "Precondition: register must succeed")
        #expect(service.biometricOfferAction == .showEnablementScreen,
                "register() must compute the offer action and set biometricOfferAction to .showEnablementScreen for a first-time user with biometrics available")
    }

    /// A registration with pendingBiometricEnablement == true must also yield
    /// .showEnablementScreen (the pending flag is consumed during register just as
    /// it is during login).
    @Test("E2b: register with pendingBiometricEnablement set yields .showEnablementScreen")
    func registerWithPendingBiometricEnablementSetsShowEnablementScreen() async {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        // Mark offer as already shown — without pendingRequest, this would suppress the offer.
        // We will pend a request so it overrides the suppression.
        service.pendBiometricEnablementRequest()

        await service.register(email: "carol@example.com", password: "pass", name: "Carol")

        #expect(service.isAuthenticated == true,
                "Precondition: register must succeed")
        #expect(service.biometricOfferAction == .showEnablementScreen,
                "register() must honour pendingBiometricEnablement and set .showEnablementScreen even when the offer was already shown")
    }

    /// When biometrics are unavailable, register must NOT set .showEnablementScreen.
    @Test("E2c: register with biometrics unavailable does not set .showEnablementScreen")
    func registerWithBiometricsUnavailableDoesNotSetShowEnablementScreen() async {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: false,
            enrollmentHistory: history
        )

        await service.register(email: "dave@example.com", password: "pass", name: "Dave")

        #expect(service.isAuthenticated == true, "Precondition: register must succeed")
        #expect(service.biometricOfferAction != .showEnablementScreen,
                "register() must not offer enablement when biometrics are unavailable")
    }

    /// The silentlyReenroll case: if the user previously enrolled and their credential
    /// was lost, registration for that same user should silently re-enroll and NOT show
    /// the enablement screen.
    @Test("E2d: register for silentlyReenroll case (previouslyEnrolledUserId matches) does not set .showEnablementScreen")
    func registerSilentlyReenrollCaseDoesNotSetShowEnablementScreen() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )

        // First registration to discover userId.
        await service.register(email: "erin@example.com", password: "pass", name: "Erin")
        let userId = try #require(service.currentUser?.id,
                                  "Precondition: currentUser must be set after register")

        // Simulate that the user previously enrolled (credential was then lost/deleted).
        history.setPreviouslyEnrolledUserId(userId)
        // Also mark offer as shown so .showEnablementScreen is suppressed for the normal path.
        history.markOfferShown(for: userId)

        // Register again (second account creation is unusual but tests the logic path in isolation).
        await service.register(email: "erin@example.com", password: "pass", name: "Erin")

        // The silentlyReenroll path must have fired — not the showEnablementScreen path.
        #expect(service.biometricOfferAction != .showEnablementScreen,
                "register() must silently re-enroll when previouslyEnrolledUserId matches and must not show the enablement screen")
    }

    // =========================================================================
    // MARK: - E4: ProfileBiometricToggleModel.toggle authenticates before enrolling
    // =========================================================================

    /// toggle(to: true) with a succeeding authenticator must result in evaluationCount == 1
    /// and isEnabled == true. If evaluationCount were 2 it would indicate both the toggle
    /// and enrollCurrentSession called authenticate — the double-prompt bug (E4).
    @Test("E4a: toggle(to: true) with success: evaluationCount == 1, isEnabled == true")
    func toggleToTrueWithSuccessCallsAuthenticateExactlyOnce() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, auth, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")

        // Reset count after login so we isolate only the toggle call.
        auth.resetEvaluationCount()

        let toggleModel = ProfileBiometricToggleModel(authService: service)

        await toggleModel.toggle(to: true)

        #expect(auth.evaluationCount == 1,
                "toggle(to: true) must trigger exactly one biometric prompt (evaluationCount must be 1, not 2 or 0)")
        #expect(toggleModel.isEnabled == true,
                "isEnabled must be true after a successful toggle(to: true)")
    }

    /// toggle(to: true) with a failing authenticator must result in evaluationCount == 1,
    /// isEnabled == false, and a non-nil errorMessage. If the double-prompt bug (E4) is
    /// present, enrollCurrentSession would add a second authenticate call before throwing,
    /// making the count 2.
    @Test("E4b: toggle(to: true) with failing authenticator: evaluationCount == 1, isEnabled == false, errorMessage set")
    func toggleToTrueWithFailingAuthCallsAuthenticateExactlyOnce() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, auth, _) = makeSUT(
            authenticatorResult: .failed,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")

        auth.resetEvaluationCount()

        let toggleModel = ProfileBiometricToggleModel(authService: service)

        await toggleModel.toggle(to: true)

        #expect(auth.evaluationCount == 1,
                "toggle(to: true) with a failing authenticator must still trigger exactly one prompt (evaluationCount must be 1)")
        #expect(toggleModel.isEnabled == false,
                "isEnabled must remain false when biometric authentication fails during toggle")
        #expect(toggleModel.errorMessage != nil,
                "errorMessage must be set when toggle(to: true) fails due to biometric rejection")
    }

    /// With a failing authenticator, enrollCurrentSession must NOT be reached.
    /// This is proven indirectly: evaluationCount == 1 (not 2) means only the toggle
    /// model's pre-check ran; enrollCurrentSession's authenticate would be the 2nd call.
    @Test("E4c: toggle(to: true) with failing authenticator does not reach enrollCurrentSession (total evaluationCount == 1 not 2)")
    func toggleWithFailingAuthDoesNotCallEnrollCurrentSession() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, store, auth, _) = makeSUT(
            authenticatorResult: .failed,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")

        auth.resetEvaluationCount()

        let toggleModel = ProfileBiometricToggleModel(authService: service)
        await toggleModel.toggle(to: true)

        // enrollCurrentSession stores credentials; if it ran, store would be non-nil.
        #expect(store.enrolledUser() == nil,
                "enrollCurrentSession must not have been called when biometric authentication fails in the toggle model")
        // Confirm count is 1, not 2 (double-prompt was the bug).
        #expect(auth.evaluationCount == 1,
                "Only the toggle model's pre-authentication must have fired — not a second call inside enrollCurrentSession")
    }

    // =========================================================================
    // MARK: - E4 / E1 combined: full enable-in-Profile end-to-end
    // =========================================================================

    /// End-to-end flow: login → toggle on. Total evaluationCount across both operations
    /// must be 1 (the toggle's gate prompt) and previouslyEnrolledUserId must be set.
    @Test("E4/E1 end-to-end: login then toggle ON yields evaluationCount == 1 and previouslyEnrolledUserId set")
    func endToEndLoginThenToggleOnYieldsSinglePromptAndSetsMarker() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, auth, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be authenticated")
        let userId = try #require(service.currentUser?.id)

        // Reset to count only the toggle flow.
        auth.resetEvaluationCount()

        let toggleModel = ProfileBiometricToggleModel(authService: service)
        await toggleModel.toggle(to: true)

        // E4: exactly one prompt across the entire enable flow.
        #expect(auth.evaluationCount == 1,
                "The full enable-in-Profile flow must trigger exactly one biometric prompt (evaluationCount == 1)")
        // E1: the marker must be set after the toggle completes.
        #expect(history.previouslyEnrolledUserId == userId,
                "previouslyEnrolledUserId must equal the enrolled user's id after the full enable flow")
        // Basic sanity: enrollment is live.
        #expect(toggleModel.isEnabled == true,
                "isEnabled must be true after the full enable flow succeeds")
    }

    // =========================================================================
    // MARK: - E1: login() silent paths set previouslyEnrolledUserId
    // =========================================================================

    /// silentlyReplaceToken path: when the same user logs in again after enrolling,
    /// the marker must be (re-)set to that user's id. This covers the case where the
    /// service calls setPreviouslyEnrolledUserId inside the silentlyReplaceToken branch.
    @Test("E1 login silentlyReplaceToken: previouslyEnrolledUserId is set to the signed-in user's id")
    func loginSilentlyReplaceTokenSetsPreviouslyEnrolledUserId() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, store, auth, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )

        // First login and enroll (through toggle to avoid E4 — the toggle authenticates,
        // then enrollCurrentSession runs without an extra prompt).
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: first login succeeded")
        let userId = try #require(service.currentUser?.id)

        // Directly enroll via the credential store (no toggle, to keep the test focused).
        try store.enroll(refreshToken: "seeded-rt", userId: userId, firstName: "Alice")
        await service.refreshBiometricState()

        // Reset the marker to verify login re-sets it.
        history.setPreviouslyEnrolledUserId(nil)

        // Second login — hits the silentlyReplaceToken branch.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.biometricOfferAction == .silentlyReplaceToken,
                     "Precondition: must be on the silentlyReplaceToken path")

        // E1 fix: the marker must be set by the silent path.
        #expect(history.previouslyEnrolledUserId == userId,
                "login() silentlyReplaceToken path must call setPreviouslyEnrolledUserId(userId)")
    }

    /// silentlyReenroll path: when previouslyEnrolledUserId matches the signing-in user,
    /// the login silently re-enrolls and must again call setPreviouslyEnrolledUserId(userId).
    @Test("E1 login silentlyReenroll: previouslyEnrolledUserId is set to the signed-in user's id")
    func loginSilentlyReenrollSetsPreviouslyEnrolledUserId() async throws {
        let history = InMemoryEnrollmentHistory()
        let (service, _, _, _, _) = makeSUT(
            authenticatorResult: .success,
            biometricsAvailable: true,
            enrollmentHistory: history
        )

        // First login to discover the userId.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: first login succeeded")
        let userId = try #require(service.currentUser?.id)

        // Set up conditions for silentlyReenroll: prior marker, offer shown, no current enrollment.
        history.setPreviouslyEnrolledUserId(userId)
        history.markOfferShown(for: userId)
        // (No credential in store — store starts empty.)

        // Second login — hits the silentlyReenroll branch.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.biometricOfferAction == .silentlyReenroll,
                     "Precondition: must be on the silentlyReenroll path")

        // E1 fix: the marker must still be set (re-set) on the silentlyReenroll path.
        #expect(history.previouslyEnrolledUserId == userId,
                "login() silentlyReenroll path must call setPreviouslyEnrolledUserId(userId)")
    }
}
