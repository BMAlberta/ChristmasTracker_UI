//
//  ProfileToggleEnrollmentTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a S3: ProfileBiometricToggleModel with the new
//  init(authService: AuthenticationService) interface.
//
//  RED-phase: will fail to compile until ProfileBiometricToggleModel is updated
//  to replace `preference` and `enablementModel` dependencies with
//  `authService: AuthenticationService` per the Gate 1 spec.
//
//  Also requires the new AuthenticationService members:
//    func enrollCurrentSession() async throws
//    func revokeEnrollment() throws
//    var enrolledUser: (userId: String, firstName: String)? { get }
//    var enrolledUserMatchesSession: Bool { get }
//    var isDisabledForOtherUser: Bool { get }
//    var disabledMessage: String? { get }
//
//  Concurrency: suite is @MainActor because ProfileBiometricToggleModel and
//  AuthenticationService are @MainActor.
//  No real Keychain — InMemoryBiometricCredentialStore is used throughout.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ProfileToggleEnrollment Tests")
@MainActor
struct ProfileToggleEnrollmentTests {

    // MARK: - Factory

    /// Builds a fresh AuthenticationService with an injectable biometric result and
    /// an optional pre-seeded enrollment.
    private func makeAuthService(
        authenticatorResult: BiometricResult = .success,
        enrolledEmail: String? = nil,
        sessionEmail: String? = nil
    ) async -> (service: AuthenticationService,
                store: InMemoryBiometricCredentialStore,
                authenticator: FakeBiometricAuthenticator) {
        let repo = MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: repo)
        let store = InMemoryBiometricCredentialStore()
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = authenticatorResult
        let service = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager,
            biometricAuthenticator: auth,
            credentialStore: store
        )
        // Optionally pre-seed a foreign enrollment (without biometric prompt)
        if let enrolled = enrolledEmail {
            let localPart = enrolled.components(separatedBy: "@").first ?? enrolled
            let userId = "mock-\(localPart.lowercased())"
            let firstName = localPart.prefix(1).uppercased() + localPart.dropFirst()
            try? store.enroll(refreshToken: "seeded-token", userId: userId, firstName: String(firstName))
        }
        // Optionally login as a session user
        if let email = sessionEmail {
            await service.login(email: email, password: "password", rememberEmail: false)
        }
        return (service, store, auth)
    }

    /// Returns a fresh ProfileBiometricToggleModel for the given service.
    private func makeSUT(authService: AuthenticationService) -> ProfileBiometricToggleModel {
        ProfileBiometricToggleModel(authService: authService)
    }

    // MARK: - P1: isEnabled true when enrolled user matches session user

    @Test("P1: isEnabled is true when enrolled user matches session user")
    func isEnabledTrueWhenEnrolledUserMatchesSession() async throws {
        let (service, _, auth) = await makeAuthService(
            authenticatorResult: .success,
            sessionEmail: "u1@example.com"
        )
        // Enroll the current session user
        auth.stubbedResult = .success
        try await service.enrollCurrentSession()
        try #require(service.enrolledUserMatchesSession, "Precondition: enrolled user must match session")

        let sut = makeSUT(authService: service)

        #expect(sut.isEnabled == true,
                "isEnabled must be true when enrolledUserMatchesSession is true")
    }

    // MARK: - P2: isEnabled false when no enrollment exists

    @Test("P2: isEnabled is false when no enrollment exists")
    func isEnabledFalseWhenNoEnrollment() async {
        let (service, _, _) = await makeAuthService(sessionEmail: "u1@example.com")
        // No enrollment made

        let sut = makeSUT(authService: service)

        #expect(sut.isEnabled == false,
                "isEnabled must be false when no enrollment exists")
    }

    // MARK: - P3: isDisabledForOtherUser and disabledMessage when different user enrolled

    @Test("P3: isDisabledForOtherUser is true and disabledMessage is non-nil when different user is enrolled")
    func isDisabledForOtherUserTrueWhenDifferentUserEnrolled() async {
        // Enroll u2, login as u1
        let (service, _, _) = await makeAuthService(
            authenticatorResult: .success,
            enrolledEmail: "u2@example.com",
            sessionEmail: "u1@example.com"
        )

        let sut = makeSUT(authService: service)

        #expect(sut.isDisabledForOtherUser == true,
                "isDisabledForOtherUser must be true when enrolled user differs from session user")
        #expect(sut.disabledMessage != nil,
                "disabledMessage must be non-nil when isDisabledForOtherUser is true")
        let message = try? #require(sut.disabledMessage)
        // The spec prescribes this exact string.
        #expect(sut.disabledMessage == "Face ID is set up for another account on this device.",
                "disabledMessage must equal the spec-prescribed string")
    }

    // MARK: - P4: isDisabledForOtherUser false when enrolled user matches session user

    @Test("P4: isDisabledForOtherUser is false when enrolled user matches session user")
    func isDisabledForOtherUserFalseWhenMatchingUser() async throws {
        let (service, _, _) = await makeAuthService(
            authenticatorResult: .success,
            sessionEmail: "u1@example.com"
        )
        try await service.enrollCurrentSession()

        let sut = makeSUT(authService: service)

        #expect(sut.isDisabledForOtherUser == false,
                "isDisabledForOtherUser must be false when enrolled user matches session user")
    }

    // MARK: - P5: toggle(to: false) calls revokeEnrollment; isEnabled becomes false

    @Test("P5: toggle(to: false) revokes enrollment and sets isEnabled to false")
    func toggleToFalseRevokesEnrollment() async throws {
        let (service, _, _) = await makeAuthService(
            authenticatorResult: .success,
            sessionEmail: "u1@example.com"
        )
        try await service.enrollCurrentSession()
        let sut = makeSUT(authService: service)
        try #require(sut.isEnabled == true, "Precondition: toggle must start enabled")

        await sut.toggle(to: false)

        #expect(sut.isEnabled == false,
                "isEnabled must be false after toggle(to: false)")
        #expect(service.enrolledUser == nil,
                "enrolledUser must be nil after revokeEnrollment() is called by toggle(to: false)")
    }

    // MARK: - P6: toggle(to: true) with .success enrolls; isEnabled becomes true

    @Test("P6: toggle(to: true) with success authenticator enrolls and sets isEnabled to true")
    func toggleToTrueWithSuccessEnrolls() async {
        let (service, _, _) = await makeAuthService(
            authenticatorResult: .success,
            sessionEmail: "u1@example.com"
        )
        // No pre-existing enrollment
        let sut = makeSUT(authService: service)
        #expect(sut.isEnabled == false, "Precondition: starts unenrolled")

        await sut.toggle(to: true)

        #expect(sut.isEnabled == true,
                "isEnabled must be true after a successful toggle(to: true)")
        #expect(service.enrolledUser != nil,
                "enrolledUser must be non-nil after toggle(to: true) with success")
    }

    // MARK: - P7: toggle(to: true) on isDisabledForOtherUser is a no-op

    @Test("P7: toggle(to: true) when isDisabledForOtherUser is a no-op")
    func toggleToTrueIsNoOpWhenDisabledForOtherUser() async {
        // Enroll u2, login as u1
        let (service, store, _) = await makeAuthService(
            authenticatorResult: .success,
            enrolledEmail: "u2@example.com",
            sessionEmail: "u1@example.com"
        )
        let sut = makeSUT(authService: service)
        #expect(sut.isDisabledForOtherUser == true, "Precondition: must be disabled for other user")

        // Capture the enrolled userId before the no-op toggle
        let enrolledBefore = store.enrolledUser()?.userId

        await sut.toggle(to: true)

        #expect(sut.isEnabled == false,
                "isEnabled must stay false when isDisabledForOtherUser and toggle(to: true) is called")
        #expect(store.enrolledUser()?.userId == enrolledBefore,
                "enrollment must be unchanged when toggle(to: true) is a no-op for other user")
    }

    // MARK: - P8: toggle(to: true) with .userCancelled does not enroll; isEnabled stays false

    @Test("P8: toggle(to: true) with userCancelled does not enroll; isEnabled stays false")
    func toggleToTrueWithUserCancelledDoesNotEnroll() async {
        let (service, _, _) = await makeAuthService(
            authenticatorResult: .userCancelled,
            sessionEmail: "u1@example.com"
        )
        let sut = makeSUT(authService: service)
        #expect(sut.isEnabled == false, "Precondition: starts unenrolled")

        await sut.toggle(to: true)

        #expect(sut.isEnabled == false,
                "isEnabled must remain false when biometric authentication was cancelled")
        #expect(service.enrolledUser == nil,
                "enrolledUser must remain nil when toggle(to: true) fails due to cancellation")
    }
}
