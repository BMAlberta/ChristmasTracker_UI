//
//  LoginBiometricModelTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (R3): LoginBiometricModel view model.
//
//  Will fail to compile until the implementer adds LoginBiometricModel to the
//  production module.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - makeSUT factory

@MainActor
private func makeSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore(),
    biometricAuthenticator: FakeBiometricAuthenticator = FakeBiometricAuthenticator()
) -> (model: LoginBiometricModel, service: AuthenticationService) {
    let sessionManager = SessionManager(authRepository: repo)
    let service = AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: biometricAuthenticator,
        credentialStore: credentialStore
    )
    let model = LoginBiometricModel(authService: service)
    return (model, service)
}

// MARK: - Suite

@Suite("LoginBiometricModel Tests")
@MainActor
struct LoginBiometricModelTests {

    // MARK: - 1. buttonStateIsHiddenWhenNoHardware

    @Test("buttonState is .hidden when readiness is .noHardware")
    func buttonStateIsHiddenWhenNoHardware() {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .noHardware
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)
        #expect(model.buttonState == .hidden)
    }

    // MARK: - 2. buttonStateIsShowNotEnrolledWhenReadyAndNoSnapshot

    @Test("buttonState is .showNotEnrolled when ready and no enrolled user snapshot")
    func buttonStateIsShowNotEnrolledWhenReadyAndNoSnapshot() {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        // No enrollment in the credential store
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)
        #expect(model.buttonState == .showNotEnrolled)
    }

    // MARK: - 3. buttonStateIsShowEnrolledWhenReadyAndSnapshotPresent

    @Test("buttonState is .showEnrolled with correct firstName after enrollCurrentSession")
    func buttonStateIsShowEnrolledWhenReadyAndSnapshotPresent() async throws {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        authenticator.stubbedResult = .success
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let (model, service) = makeSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        // Log in to establish a session so enrollCurrentSession has a user and tokens.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true, "Precondition: must be authenticated before enrollment")

        // Enroll the current session — this stores the credential and refreshes the snapshot.
        try await service.enrollCurrentSession()

        // The snapshot should now be populated; derive expected firstName from the login email.
        // MockAuthenticationRepository produces name "Alice" for "alice@example.com".
        if case .showEnrolled(let firstName) = model.buttonState {
            #expect(firstName == "Alice")
        } else {
            Issue.record("Expected .showEnrolled but got \(model.buttonState)")
        }
    }

    // MARK: - 4. tapWhenHiddenIsNoOp

    @Test("tap when buttonState is .hidden does not show any alert")
    func tapWhenHiddenIsNoOp() async {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .noHardware
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)
        #expect(model.buttonState == .hidden)

        await model.tap()

        #expect(model.showSetupAlert == false)
        #expect(model.showNotEnrolledAlert == false)
        #expect(model.biometricSignInState == .idle)
    }

    // MARK: - 5. tapWhenShowNotEnrolledSetsNotEnrolledAlert

    @Test("tap when buttonState is .showNotEnrolled sets showNotEnrolledAlert")
    func tapWhenShowNotEnrolledSetsNotEnrolledAlert() async {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        // No enrollment means .showNotEnrolled
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)
        #expect(model.buttonState == .showNotEnrolled)

        await model.tap()

        #expect(model.showNotEnrolledAlert == true)
        #expect(model.showSetupAlert == false)
    }

    // MARK: - 6. tapWhenShowNeedsSetupSetsSetupAlert

    @Test("tap when buttonState is .showNeedsSetup sets showSetupAlert")
    func tapWhenShowNeedsSetupSetsSetupAlert() async {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .needsSetup(reason: .notEnrolled)
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)

        await model.tap()

        #expect(model.showSetupAlert == true)
        #expect(model.showNotEnrolledAlert == false)
        #expect(model.setupMessage != nil)
    }

    // MARK: - 7. tapWhenShowEnrolledCallsSignInWithBiometric

    @Test("tap when buttonState is .showEnrolled calls signInWithBiometric and shows no alerts on success")
    func tapWhenShowEnrolledCallsSignInWithBiometric() async throws {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        authenticator.stubbedResult = .success
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let (model, service) = makeSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        // Establish session and enroll so buttonState is .showEnrolled.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()

        // Logout so the sign-in via tap can be tested from unauthenticated state.
        await service.logout()
        try #require(service.isAuthenticated == false)

        // The credential store still has the enrolled user; buttonState should be .showEnrolled.
        guard case .showEnrolled = model.buttonState else {
            Issue.record("Precondition: expected .showEnrolled but got \(model.buttonState)")
            return
        }

        await model.tap()

        // signInWithBiometric refreshes the token — the mock repo accepts it and sets authenticated.
        #expect(model.showSetupAlert == false)
        #expect(model.showNotEnrolledAlert == false)
    }

    // MARK: - 8. biometricSignInStateReflectsServiceState

    @Test("biometricSignInState mirrors service state after a failed signInWithBiometric")
    func biometricSignInStateReflectsServiceState() async throws {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        let store = InMemoryBiometricCredentialStore()
        // Stub a biometric credential read error so signInWithBiometric returns a retryHint.
        store.stubbedReadError = .biometricFailed

        let (model, service) = makeSUT(
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        await service.signInWithBiometric()

        // The service's biometricSignInState should be a retryHint; the model must mirror it.
        if case .retryHint = service.biometricSignInState {
            if case .retryHint = model.biometricSignInState {
                // expected
            } else {
                Issue.record("Model biometricSignInState \(model.biometricSignInState) does not mirror service state \(service.biometricSignInState)")
            }
        } else {
            Issue.record("Expected service to be in .retryHint but got \(service.biometricSignInState)")
        }
    }

    // MARK: - 9. isLoadingReflectsServiceState

    @Test("isLoading is false on a freshly constructed model before any sign-in attempt")
    func isLoadingReflectsServiceState() {
        let (model, _) = makeSUT()
        #expect(model.isLoading == false)
    }

    // MARK: - 10. autoAttemptDoesNotFireWhenNoHardware

    @Test("autoAttemptIfNeeded does not fire when readiness is .noHardware", .serialized)
    func autoAttemptDoesNotFireWhenNoHardware() async {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .noHardware
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)

        LoginBiometricModel.resetAutoAttemptFlagForTesting()
        await model.autoAttemptIfNeeded()

        #expect(model.biometricSignInState == .idle)
        #expect(model.isLoading == false)
    }

    // MARK: - 11. autoAttemptDoesNotFireWhenNoEnrolledUser

    @Test("autoAttemptIfNeeded does not fire when there is no enrolled user", .serialized)
    func autoAttemptDoesNotFireWhenNoEnrolledUser() async {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        // No enrollment in credential store
        let (model, _) = makeSUT(biometricAuthenticator: authenticator)

        LoginBiometricModel.resetAutoAttemptFlagForTesting()
        await model.autoAttemptIfNeeded()

        #expect(model.biometricSignInState == .idle)
        #expect(model.isLoading == false)
    }

    // MARK: - 12. autoAttemptFiresExactlyOnceWithEnrolledUser

    @Test("autoAttemptIfNeeded fires exactly once when conditions are met", .serialized)
    func autoAttemptFiresExactlyOnceWithEnrolledUser() async throws {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        authenticator.stubbedResult = .success
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let (model, service) = makeSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        // Log in and enroll so the auto-attempt conditions are met.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()
        // Log out so we're in the sign-in flow.
        await service.logout()
        try #require(service.isAuthenticated == false)
        try #require(model.buttonState == .showEnrolled(firstName: "Alice"))

        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        // First call: should trigger signInWithBiometric.
        await model.autoAttemptIfNeeded()

        // The attempt fired: hasAutoAttempted is true, and state is non-idle
        // (the credential store read will attempt a token refresh which modifies state).
        #expect(LoginBiometricModel.hasAutoAttempted == true)

        // Record the state after first attempt.
        let stateAfterFirst = model.biometricSignInState

        // Second call: should NOT fire (flag is already set).
        await model.autoAttemptIfNeeded()

        // State must not change on the second call.
        #expect(model.biometricSignInState == stateAfterFirst,
                "Second autoAttemptIfNeeded call must not trigger another sign-in attempt")
    }

    // MARK: - 13. autoAttemptDoesNotFireIfAlreadyAttempted

    @Test("autoAttemptIfNeeded does not fire a second sign-in attempt after the flag is set", .serialized)
    func autoAttemptDoesNotFireIfAlreadyAttempted() async throws {
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedReadiness = .ready
        authenticator.stubbedResult = .success
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let (model, service) = makeSUT(
            repo: repo,
            credentialStore: store,
            biometricAuthenticator: authenticator
        )

        // Log in and enroll to satisfy conditions.
        await service.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(service.isAuthenticated == true)
        try await service.enrollCurrentSession()
        await service.logout()
        try #require(service.isAuthenticated == false)

        LoginBiometricModel.resetAutoAttemptFlagForTesting()

        // First call: fires, sets the process-once flag.
        await model.autoAttemptIfNeeded()
        #expect(LoginBiometricModel.hasAutoAttempted == true)

        let stateAfterFirst = model.biometricSignInState

        // Second call: must not fire again — state must remain unchanged.
        await model.autoAttemptIfNeeded()

        #expect(model.biometricSignInState == stateAfterFirst,
                "autoAttemptIfNeeded must not fire a second sign-in after hasAutoAttempted is true")
    }
}
