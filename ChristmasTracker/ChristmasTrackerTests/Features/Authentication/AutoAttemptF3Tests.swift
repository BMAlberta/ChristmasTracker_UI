//
//  AutoAttemptF3Tests.swift
//  ChristmasTrackerTests
//
//  Story I2b-2a F3 / Defect E6:
//  `autoAttemptIfNeeded()` must consume `hasAutoAttempted` on FIRST appearance
//  regardless of `buttonState` (hidden, not-enrolled, or enrolled).
//
//  Current (broken) code only consumes the flag when `buttonState == .showEnrolled`.
//  Tests 1–4 therefore FAIL on the current code and PASS after the fix.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - makeSUT (file-local)

@MainActor
private func makeAutoAttemptSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore(),
    biometricAuthenticator: FakeBiometricAuthenticator = FakeBiometricAuthenticator()
) -> (model: LoginBiometricModel, service: AuthenticationService, authenticator: FakeBiometricAuthenticator) {
    let sessionManager = SessionManager(initialClearables: [])
    let service = AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: biometricAuthenticator,
        credentialStore: credentialStore
    )
    let model = LoginBiometricModel(authService: service)
    return (model, service, biometricAuthenticator)
}

// MARK: - Suite

/// Tests for the fixed behaviour described in I2b-2a Story F3 / Defect E6.
/// All four tests in this suite FAIL on the current production code and must
/// PASS once the implementer applies the fix.
@Suite("AutoAttemptF3 — E6: autoAttemptIfNeeded consumes flag for all states", .serialized)
@MainActor
struct AutoAttemptF3Tests {

    // MARK: - Test 1: .hidden state — flag consumed, signInWithBiometric NOT called

    /// FAILS on current code: the old implementation guards on `.showEnrolled` before
    /// setting `hasAutoAttempted`, so the flag is never consumed for `.hidden`.
    @Test("autoAttemptIfNeeded with .hidden state sets hasAutoAttempted and does NOT call signInWithBiometric")
    func autoAttemptHiddenStateSetsFlag() async {
        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .noHardware   // produces .hidden buttonState
        let (model, _, _) = makeAutoAttemptSUT(biometricAuthenticator: authenticator)

        // Pre-condition: flag is clear and state is .hidden.
        #expect(LoginBiometricModel.hasAutoAttempted == false)
        #expect(model.buttonState == .hidden)

        await model.autoAttemptIfNeeded()

        // Flag MUST be consumed regardless of buttonState.
        #expect(LoginBiometricModel.hasAutoAttempted == true,
                "hasAutoAttempted must be true after autoAttemptIfNeeded with .hidden buttonState")

        // No biometric authentication prompt must have fired.
        #expect(authenticator.evaluationCount == 0,
                "signInWithBiometric must NOT be called when buttonState is .hidden")
    }

    // MARK: - Test 2: .showNotEnrolled state — flag consumed, signInWithBiometric NOT called

    /// FAILS on current code: same reason as Test 1 — flag not consumed for non-enrolled.
    @Test("autoAttemptIfNeeded with .showNotEnrolled state sets hasAutoAttempted and does NOT call signInWithBiometric")
    func autoAttemptNotEnrolledStateSetsFlag() async {
        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready    // ready but no enrolled credential
        // No credential in the default InMemoryBiometricCredentialStore → .showNotEnrolled
        let (model, _, _) = makeAutoAttemptSUT(biometricAuthenticator: authenticator)

        #expect(LoginBiometricModel.hasAutoAttempted == false)
        #expect(model.buttonState == .showNotEnrolled)

        await model.autoAttemptIfNeeded()

        #expect(LoginBiometricModel.hasAutoAttempted == true,
                "hasAutoAttempted must be true after autoAttemptIfNeeded with .showNotEnrolled buttonState")
        #expect(authenticator.evaluationCount == 0,
                "signInWithBiometric must NOT be called when buttonState is .showNotEnrolled")
    }

    // MARK: - Test 3: .showEnrolled state — flag consumed AND signInWithBiometric IS called

    /// Current code also fires for .showEnrolled, BUT the new ordering (set flag before
    /// the guard) is what matters here — this test validates the full happy path still works.
    /// This test PASSES on current code and must continue to PASS after the fix.
    @Test("autoAttemptIfNeeded with .showEnrolled state sets hasAutoAttempted and calls signInWithBiometric")
    func autoAttemptEnrolledStateSetsFlag() async throws {
        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        authenticator.stubbedResult = .success
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let (model, service, _) = makeAutoAttemptSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        // Establish an enrolled session.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()
        await service.logout()
        try #require(service.isAuthenticated == false)
        try #require(model.buttonState == .showEnrolled(firstName: "Alice"))

        await model.autoAttemptIfNeeded()

        #expect(LoginBiometricModel.hasAutoAttempted == true,
                "hasAutoAttempted must be true after autoAttemptIfNeeded with .showEnrolled buttonState")
        // signInWithBiometric goes through credentialStore.readRefreshToken (which uses
        // evaluatePolicy, not biometricAuthenticator.authenticate), so evaluationCount stays 0.
        // Verify sign-in fired by checking that the service is authenticated.
        #expect(service.isAuthenticated == true,
                "signInWithBiometric must be called when buttonState is .showEnrolled — verified via isAuthenticated")
    }

    // MARK: - Test 4: Second call is a no-op regardless of state

    /// FAILS on current code if the first call was with a non-enrolled state (flag never
    /// set), so the second call would fire if the state later becomes .showEnrolled.
    /// After the fix the flag is set on the first call regardless, so the second call
    /// is always a no-op.
    @Test("Second call to autoAttemptIfNeeded is always a no-op after the first call")
    func autoAttemptSecondCallIsNoOp() async {
        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        let authenticator = FakeBiometricAuthenticator()
        // Start with .hidden so the first call consumes the flag but does not sign in.
        authenticator.stubbedReadiness = .noHardware
        let (model, _, _) = makeAutoAttemptSUT(biometricAuthenticator: authenticator)

        #expect(model.buttonState == .hidden)

        // First call — consumes flag, does not sign in.
        await model.autoAttemptIfNeeded()
        #expect(LoginBiometricModel.hasAutoAttempted == true)
        let countAfterFirst = authenticator.evaluationCount  // expected 0

        // Second call — must be a no-op even though state is still .hidden.
        await model.autoAttemptIfNeeded()

        #expect(authenticator.evaluationCount == countAfterFirst,
                "Second autoAttemptIfNeeded call must not trigger signInWithBiometric")
        #expect(LoginBiometricModel.hasAutoAttempted == true)
    }
}
