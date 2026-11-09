//
//  BiometricOfferIntegrationTests.swift
//  ChristmasTrackerTests
//
//  Service-level integration tests for the BiometricOfferAction flow in AuthenticationService.
//  RED-phase: will fail to compile/run until:
//    - BiometricOfferAction enum exists
//    - biometricOfferAction(...) pure function exists
//    - EnrollmentHistoryStoring protocol exists
//    - AuthenticationService gains:
//        private(set) var biometricOfferAction: BiometricOfferAction
//        init parameter: enrollmentHistory: any EnrollmentHistoryStoring
//    - ProfileBiometricToggleModel.toggle(to: false) calls enrollmentHistory.setPreviouslyEnrolledUserId(nil)
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - InMemoryEnrollmentHistory

private final class InMemoryEnrollmentHistory: EnrollmentHistoryStoring {
    var previouslyEnrolledUserId: String?
    private var offerShownSet: Set<String> = []

    func setPreviouslyEnrolledUserId(_ userId: String?) {
        previouslyEnrolledUserId = userId
    }

    func hasSeenOffer(for userId: String) -> Bool {
        offerShownSet.contains(userId)
    }

    func markOfferShown(for userId: String) {
        offerShownSet.insert(userId)
    }
}

// MARK: - Factory

@MainActor
private func makeSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore(),
    biometricAuthenticator: FakeBiometricAuthenticator = FakeBiometricAuthenticator(),
    enrollmentHistory enrollmentHistoryOverride: InMemoryEnrollmentHistory? = nil
) -> (
    sut: AuthenticationService,
    store: InMemoryBiometricCredentialStore,
    authenticator: FakeBiometricAuthenticator,
    history: InMemoryEnrollmentHistory
) {
    // Built here, not as a default argument: default arguments are evaluated nonisolated.
    let enrollmentHistory = enrollmentHistoryOverride ?? InMemoryEnrollmentHistory()
    let sessionManager = SessionManager(initialClearables: [])
    let sut = AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: biometricAuthenticator,
        legacyCleanup: FakeLegacyTokenCleanup(),
        credentialStore: credentialStore,
        enrollmentHistory: enrollmentHistory
    )
    return (sut, credentialStore, biometricAuthenticator, enrollmentHistory)
}

// MARK: - Suite

@Suite("BiometricOffer Integration Tests")
@MainActor
struct BiometricOfferIntegrationTests {

    // MARK: - I1: no enrollment, offer not shown → .showEnablementScreen

    @Test("I1: login with no enrollment and offerShownForUser false → biometricOfferAction == .showEnablementScreen")
    func i1_noEnrollment_offerNotShown_showsEnablementScreen() async {
        let history = InMemoryEnrollmentHistory()
        let (sut, _, _, _) = makeSUT(enrollmentHistory: history)
        // history.hasSeenOffer("mock-alice") == false (fresh)

        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .showEnablementScreen)
    }

    // MARK: - I2: same user enrolled → .silentlyReplaceToken, credential store updated

    @Test("I2: login with same user already enrolled → biometricOfferAction == .silentlyReplaceToken and token updated")
    func i2_sameUserEnrolled_silentlyReplaceToken() async throws {
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let history = InMemoryEnrollmentHistory()
        let (sut, _, _, _) = makeSUT(
            repo: repo,
            credentialStore: store,
            enrollmentHistory: history
        )
        // Log in once to discover the userId
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated, "Precondition: must be authenticated")
        let userId = try #require(sut.currentUser?.id)

        // Pre-enroll that user
        try store.enroll(refreshToken: "mock_rt_\(userId)_seed", userId: userId, firstName: "Alice")
        await sut.refreshBiometricState()

        // Log in again (simulating a second login for the same user)
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .silentlyReplaceToken)
        // Token should have been silently rotated
        let enrolled = store.enrolledUser()
        #expect(enrolled != nil, "Credential store must still have the enrolled user after silent replace")
    }

    // MARK: - I3: different user enrolled → .none

    @Test("I3: login with another user enrolled → biometricOfferAction == .none")
    func i3_differentUserEnrolled_returnsNone() async throws {
        let store = InMemoryBiometricCredentialStore()
        let history = InMemoryEnrollmentHistory()
        // Pre-enroll a different user
        try store.enroll(refreshToken: "mock_rt_mock-bob_seed", userId: "mock-bob", firstName: "Bob")
        let (sut, _, _, _) = makeSUT(
            credentialStore: store,
            enrollmentHistory: history
        )

        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .none)
    }

    // MARK: - I4: biometricOfferAction is set BEFORE isAuthenticated changes

    @Test("I4: biometricOfferAction is non-default immediately after login() returns (set within login, not deferred)")
    func i4_biometricOfferActionSetBeforeIsAuthenticated() async {
        let history = InMemoryEnrollmentHistory()
        let (sut, _, _, _) = makeSUT(enrollmentHistory: history)

        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        // Both are set within the same @MainActor login() function:
        // isAuthenticated must be true and biometricOfferAction must already be set.
        #expect(sut.isAuthenticated == true)
        // The action must not be .none if the offer has not been shown and no enrollment exists;
        // this proves it was computed inside login(), not in a later onChange callback.
        #expect(sut.biometricOfferAction != .none,
                "biometricOfferAction must be set within login() — it is .none, suggesting it was deferred")
    }

    // MARK: - I5: after revoke + re-login → .none (previouslyEnrolledUserId cleared)

    @Test("I5: after toggle OFF (revokeEnrollment + clear previouslyEnrolledUserId) and re-login → biometricOfferAction == .none")
    func i5_afterRevokeAndRelogin_returnsNone() async throws {
        let store = InMemoryBiometricCredentialStore()
        let history = InMemoryEnrollmentHistory()
        let repo = MockAuthenticationRepository()
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = .success
        let (sut, _, _, _) = makeSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: auth,
            enrollmentHistory: history
        )

        // Login and enroll
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated)
        try await sut.enrollCurrentSession()

        // Simulate toggle OFF via ProfileBiometricToggleModel
        let toggleModel = ProfileBiometricToggleModel(authService: sut)
        await toggleModel.toggle(to: false)

        // history.previouslyEnrolledUserId must be nil after revoke
        #expect(history.previouslyEnrolledUserId == nil,
                "setPreviouslyEnrolledUserId(nil) must be called by toggle(to: false)")

        // Also mark the offer as shown so the only possible non-.none would be .silentlyReenroll
        // (which requires previouslyEnrolledUserId). Since it was cleared, we expect .none.
        history.markOfferShown(for: sut.currentUser?.id ?? "")

        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        #expect(sut.biometricOfferAction == .none)
    }

    // MARK: - I6: previouslyEnrolledUserId matches signed-in user, no enrollment → .silentlyReenroll

    @Test("I6: previouslyEnrolledUserId matches signed-in user with no current enrollment → .silentlyReenroll and re-enrolled")
    func i6_previouslyEnrolledMatchesCurrent_silentlyReenroll() async throws {
        let store = InMemoryBiometricCredentialStore()
        let history = InMemoryEnrollmentHistory()
        let repo = MockAuthenticationRepository()
        let (sut, _, _, _) = makeSUT(
            repo: repo,
            credentialStore: store,
            enrollmentHistory: history
        )

        // Login once to discover userId, then set previouslyEnrolledUserId
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        let userId = try #require(sut.currentUser?.id)
        // Mark offer as shown so .showEnablementScreen is suppressed
        history.markOfferShown(for: userId)
        // Set previouslyEnrolledUserId but no current enrollment
        history.setPreviouslyEnrolledUserId(userId)
        // No store enrollment present

        // Log in again
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .silentlyReenroll)
        // Credential store should now have the re-enrolled entry
        let enrolled = store.enrolledUser()
        #expect(enrolled?.userId == userId, "Silent re-enroll must write credentials to the store")
    }

    // MARK: - I7: second login, offer already shown, no pending, no enrollment → .none

    @Test("I7: second login with offerShownForUser true and no enrollment → biometricOfferAction == .none")
    func i7_secondLogin_offerAlreadyShown_returnsNone() async throws {
        let history = InMemoryEnrollmentHistory()
        let (sut, _, _, _) = makeSUT(enrollmentHistory: history)

        // First login — sets up userId
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        let userId = try #require(sut.currentUser?.id)
        // Simulate that the offer was already shown
        history.markOfferShown(for: userId)

        // Second login
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .none)
    }

    // MARK: - I8: pendingRequest overrides offer-shown suppression

    @Test("I8: pendingRequest == true gives .showEnablementScreen even if hasSeenOffer is true")
    func i8_pendingRequestOverridesOfferShownSuppression() async throws {
        let history = InMemoryEnrollmentHistory()
        let (sut, _, _, _) = makeSUT(enrollmentHistory: history)

        // First login — sets up userId and marks offer as shown
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        let userId = try #require(sut.currentUser?.id)
        history.markOfferShown(for: userId)

        // Fire a pending request
        sut.pendBiometricEnablementRequest()

        // Login again — pending should force .showEnablementScreen despite offerShown
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        #expect(sut.biometricOfferAction == .showEnablementScreen,
                "pendingRequest must override offerShown suppression and return .showEnablementScreen")
    }
}
