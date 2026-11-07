//
//  BiometricFaceIDGapTests.swift
//  ChristmasTrackerTests
//
//  Story I2b-2b C3: failing tests for the four Face ID gaps.
//
//  RED-phase: will fail to compile/run until:
//    Gap 2 — KeychainBiometricCredentialStore gains a `policyEvaluator` injectable closure
//             and the LAError catch block is expanded with .authenticationFailed,
//             .systemCancel, .appCancel mappings.
//    Gap 3 — LoginBiometricModel.autoAttemptIfNeeded gains an `appIsActive` parameter
//             and returns WITHOUT consuming the flag when appIsActive() returns false.
//
//  Gap 1 (clearBiometricOfferAction) tests exercise an interface that already exists;
//  they serve as a regression guard for Criterion 1.
//

import Testing
import Foundation
import LocalAuthentication
@testable import ChristmasTracker

// MARK: - Shared SUT factories

@MainActor
private func makeAuthSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore(),
    biometricAuthenticator: FakeBiometricAuthenticator = FakeBiometricAuthenticator()
) -> (sut: AuthenticationService, store: InMemoryBiometricCredentialStore, authenticator: FakeBiometricAuthenticator) {
    let sessionManager = SessionManager(initialClearables: [])
    let sut = AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: biometricAuthenticator,
        legacyCleanup: FakeLegacyTokenCleanup(),
        credentialStore: credentialStore
    )
    return (sut, credentialStore, biometricAuthenticator)
}

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
        legacyCleanup: FakeLegacyTokenCleanup(),
        credentialStore: credentialStore
    )
    let model = LoginBiometricModel(authService: service)
    return (model, service, biometricAuthenticator)
}

// MARK: - LAError stub helper

/// Returns a closure that throws the given LAError code when called as a policyEvaluator.
private func makeThrowingEvaluator(_ code: LAError.Code) -> (LAPolicy, String) async throws -> Void {
    return { _, _ in throw LAError(code) }
}

// MARK: - Suite 1: clearBiometricOfferAction (Gap 1 / Criterion 1 service layer)

@Suite("clearBiometricOfferAction — Criterion 1 service-layer validation")
@MainActor
struct ClearBiometricOfferActionTests {

    // MARK: - C1-S1: clearBiometricOfferAction sets biometricOfferAction to .none on a fresh service

    @Test("clearBiometricOfferAction sets biometricOfferAction to .none")
    func clearBiometricOfferActionSetsNone() {
        let (sut, _, _) = makeAuthSUT()

        sut.clearBiometricOfferAction()

        #expect(sut.biometricOfferAction == .none)
    }

    // MARK: - C1-S2: clearBiometricOfferAction removes a pending offer set by pendBiometricEnablementRequest + login

    @Test("clearBiometricOfferAction removes pending offer after pendBiometricEnablementRequest and login")
    func clearBiometricOfferActionClearsPendingOffer() async throws {
        let (sut, _, authenticator) = makeAuthSUT()
        authenticator.stubbedReadiness = .ready

        // Fire a pending request and log in so biometricOfferAction becomes .showEnablementScreen.
        sut.pendBiometricEnablementRequest()
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)

        // Pre-condition: the offer action is non-.none (it must be .showEnablementScreen given
        // pending request + no prior enrollment + ready biometrics).
        #expect(sut.biometricOfferAction != .none,
                "Precondition: biometricOfferAction must be non-.none after pendBiometricEnablementRequest + login")

        sut.clearBiometricOfferAction()

        #expect(sut.biometricOfferAction == .none,
                "clearBiometricOfferAction must set biometricOfferAction back to .none")
    }
}

// MARK: - Suite 2: LAError mapping on KeychainBiometricCredentialStore (Gap 2 / Criterion 2)

// These tests will FAIL TO COMPILE until the implementer adds `policyEvaluator` to
// KeychainBiometricCredentialStore.
//
// Adapter-test exception (I2b-2d D2(c)): this suite builds the real
// KeychainBiometricCredentialStore on purpose to exercise its LAError mapping, so it reaches
// the system Keychain adapter. Every other unit test uses an in-memory credential store.

@Suite("KeychainBiometricCredentialStore LAError mapping — Criterion 2")
struct KeychainLAErrorMappingTests {

    private func makeSUT() -> KeychainBiometricCredentialStore {
        KeychainBiometricCredentialStore()
    }

    // MARK: - C2-M1: authenticationFailed → .biometricFailed

    @Test("LAError.authenticationFailed maps to BiometricCredentialError.biometricFailed")
    func authenticationFailedMappedToBiometricFailed() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.authenticationFailed)

        await #expect(throws: BiometricCredentialError.biometricFailed) {
            _ = try await sut.readRefreshToken(reason: "Test")
        }
    }

    // MARK: - C2-M2: systemCancel → .userCancelled

    @Test("LAError.systemCancel maps to BiometricCredentialError.userCancelled")
    func systemCancelMappedToUserCancelled() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.systemCancel)

        await #expect(throws: BiometricCredentialError.userCancelled) {
            _ = try await sut.readRefreshToken(reason: "Test")
        }
    }

    // MARK: - C2-M3: appCancel → .userCancelled

    @Test("LAError.appCancel maps to BiometricCredentialError.userCancelled")
    func appCancelMappedToUserCancelled() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.appCancel)

        await #expect(throws: BiometricCredentialError.userCancelled) {
            _ = try await sut.readRefreshToken(reason: "Test")
        }
    }

    // MARK: - C2-M4: userCancel → .lockedOut

    @Test("LAError.userCancel maps to BiometricCredentialError.lockedOut")
    func userCancelMappedToLockedOut() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.userCancel)

        await #expect(throws: BiometricCredentialError.lockedOut) {
            _ = try await sut.readRefreshToken(reason: "Test")
        }
    }

    // MARK: - C2-M5: biometryLockout → .lockedOut

    @Test("LAError.biometryLockout maps to BiometricCredentialError.lockedOut")
    func biometryLockoutMappedToLockedOut() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.biometryLockout)

        await #expect(throws: BiometricCredentialError.lockedOut) {
            _ = try await sut.readRefreshToken(reason: "Test")
        }
    }

    // MARK: - C2-M6: policyEvaluator throwing yields a BiometricCredentialError (not a Keychain OSStatus error)

    @Test("When policyEvaluator throws, the thrown error is a BiometricCredentialError — not a Keychain error")
    func policyEvaluatorThrowingYieldsBiometricCredentialError() async throws {
        var sut = makeSUT()
        sut.policyEvaluator = makeThrowingEvaluator(.authenticationFailed)

        do {
            _ = try await sut.readRefreshToken(reason: "Test")
            Issue.record("readRefreshToken must throw when policyEvaluator throws — it returned a value instead")
        } catch let error as BiometricCredentialError {
            // The thrown error is a BiometricCredentialError — Keychain was not reached.
            #expect(error == .biometricFailed)
        } catch {
            Issue.record("Expected BiometricCredentialError but got \(error) — Keychain code may have been reached")
        }
    }
}

// MARK: - Suite 3: autoAttemptIfNeeded appIsActive guard (Gap 3 / Criterion 3)

// These tests will FAIL TO COMPILE until the implementer adds the `appIsActive` parameter
// to LoginBiometricModel.autoAttemptIfNeeded.

@Suite("autoAttemptIfNeeded appIsActive guard — Criterion 3", .serialized)
@MainActor
struct AutoAttemptAppIsActiveTests {

    // MARK: - C3-A1: inactive app — flag NOT consumed, function returns early

    @Test("autoAttemptIfNeeded with appIsActive returning false does not consume hasAutoAttempted")
    func inactiveAppDoesNotConsumeFlag() async {
        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        let (model, _, _) = makeAutoAttemptSUT(biometricAuthenticator: authenticator)

        #expect(LoginBiometricModel.hasAutoAttempted == false, "Precondition: flag must be clear")

        await model.autoAttemptIfNeeded(appIsActive: { false })

        #expect(LoginBiometricModel.hasAutoAttempted == false,
                "Flag must NOT be consumed when appIsActive returns false")
        #expect(authenticator.evaluationCount == 0,
                "signInWithBiometric must NOT be called when app is inactive")
    }

    // MARK: - C3-A2: inactive then active — second call fires after first inactive call

    @Test("After an inactive call that did not consume the flag, a subsequent active call fires the attempt")
    func inactiveThenActiveCallFiresAttempt() async throws {
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

        // Establish an enrolled session so buttonState == .showEnrolled.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()
        await service.logout()
        try #require(service.isAuthenticated == false)
        try #require(model.buttonState == .showEnrolled(firstName: "Alice"))

        // First call — inactive; flag must NOT be consumed.
        await model.autoAttemptIfNeeded(appIsActive: { false })
        #expect(LoginBiometricModel.hasAutoAttempted == false,
                "Flag must remain false after inactive call")

        // Second call — active; flag IS consumed and sign-in fires.
        await model.autoAttemptIfNeeded(appIsActive: { true })
        #expect(LoginBiometricModel.hasAutoAttempted == true,
                "Flag must be consumed on the subsequent active call")
        #expect(service.isAuthenticated == true,
                "signInWithBiometric must be called on the active call after an inactive call")
    }

    // MARK: - C3-A3: active app with enrolled user — flag consumed and sign-in called

    @Test("autoAttemptIfNeeded with appIsActive true and enrolled user consumes flag and calls sign-in")
    func activeAppEnrolledUserConsumesFlag() async throws {
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

        // Establish enrolled session.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()
        await service.logout()
        try #require(service.isAuthenticated == false)
        try #require(model.buttonState == .showEnrolled(firstName: "Alice"))

        await model.autoAttemptIfNeeded(appIsActive: { true })

        #expect(LoginBiometricModel.hasAutoAttempted == true,
                "Flag must be consumed when appIsActive returns true")
        #expect(service.isAuthenticated == true,
                "signInWithBiometric must be called when appIsActive returns true and user is enrolled")
    }
}
