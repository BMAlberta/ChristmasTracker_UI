//
//  EnrollCurrentSessionTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a S3: enrollCurrentSession(), revokeEnrollment(),
//  enrolledUser, enrolledUserMatchesSession on AuthenticationService.
//
//  RED-phase: will fail to compile until AuthenticationService gains the four
//  new members defined in the Gate 1 spec:
//    func enrollCurrentSession() async throws
//    func revokeEnrollment() throws
//    var enrolledUser: (userId: String, firstName: String)? { get }
//    var enrolledUserMatchesSession: Bool { get }
//
//  Also covers E7: the silent token rotation path in handleAuthSuccess when the
//  enrolled userId matches the signed-in user.
//
//  Concurrency: suite is @MainActor because AuthenticationService is @MainActor.
//  No real Keychain — InMemoryBiometricCredentialStore is used throughout.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("EnrollCurrentSession Tests")
@MainActor
struct EnrollCurrentSessionTests {

    // MARK: - Factory

    /// Returns a fresh SUT wired to an InMemoryBiometricCredentialStore and a
    /// FakeBiometricAuthenticator. The caller may configure both before use.
    private func makeSUT(
        authenticatorResult: BiometricResult = .success
    ) -> (
        service: AuthenticationService,
        repo: MockAuthenticationRepository,
        credentialStore: InMemoryBiometricCredentialStore,
        authenticator: FakeBiometricAuthenticator
    ) {
        let repo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let store = InMemoryBiometricCredentialStore()
        let auth = FakeBiometricAuthenticator()
        auth.stubbedResult = authenticatorResult
        let service = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager,
            biometricAuthenticator: auth,
            credentialStore: store
        )
        return (service, repo, store, auth)
    }

    // MARK: - E1: enrollCurrentSession with .success stores the enrolled user

    @Test("E1: enrollCurrentSession success enrolls the session user")
    func enrollCurrentSessionSuccessStoresUser() async throws {
        let (service, _, store, _) = makeSUT(authenticatorResult: .success)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")

        try await service.enrollCurrentSession()

        let enrolled = try #require(service.enrolledUser, "enrolledUser must be non-nil after a successful enroll")
        #expect(enrolled.userId == "mock-u1",
                "enrolledUser.userId must equal the stable mock id for u1@example.com")
    }

    // MARK: - E2: enrollCurrentSession always enrolls (auth stub is irrelevant — E4 moved auth to caller)

    @Test("E2: enrollCurrentSession always enrolls regardless of auth stub (authentication is caller's responsibility)")
    func enrollCurrentSessionAlwaysEnrollsRegardlessOfAuthStub() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .userCancelled)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")

        // After the E4 fix, enrollCurrentSession() no longer calls biometricAuthenticator.
        // It always enrolls when a session exists — authentication is the caller's responsibility.
        try await service.enrollCurrentSession()

        #expect(service.enrolledUser != nil,
                "enrollCurrentSession() must enroll regardless of auth stub — authentication was moved to the caller (toggle model)")
    }

    // MARK: - E3: enrollCurrentSession always enrolls (auth stub is irrelevant — E4 moved auth to caller)

    @Test("E3: enrollCurrentSession always enrolls with .failed stub (authentication is caller's responsibility)")
    func enrollCurrentSessionAlwaysEnrollsWithFailedStub() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .failed)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")

        // After the E4 fix, authentication is the caller's responsibility.
        // enrollCurrentSession() no longer calls authenticate — it always enrolls.
        try await service.enrollCurrentSession()

        #expect(service.enrolledUser != nil,
                "enrollCurrentSession() must enroll regardless of auth stub — authentication was moved to the caller (toggle model)")
    }

    // MARK: - E4: enrollCurrentSession before login is a no-op

    @Test("E4: enrollCurrentSession before login is a no-op and does not throw")
    func enrollCurrentSessionBeforeLoginIsNoOp() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .success)
        // Not logged in — tokens == nil, currentUser == nil
        #expect(service.isAuthenticated == false, "Precondition: must not be logged in")

        // Must not throw — no-op
        try await service.enrollCurrentSession()

        #expect(service.enrolledUser == nil,
                "enrolledUser must remain nil when called before any login")
    }

    // MARK: - E5: revokeEnrollment removes the enrollment

    @Test("E5: revokeEnrollment removes enrollment; enrolledUser returns nil afterwards")
    func revokeEnrollmentRemovesEnrollment() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .success)
        await service.login(email: "u2@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")
        try await service.enrollCurrentSession()
        try #require(service.enrolledUser != nil, "Precondition: enrollment must exist before revoke")

        try service.revokeEnrollment()

        #expect(service.enrolledUser == nil,
                "enrolledUser must be nil after revokeEnrollment()")
    }

    // MARK: - E6: enrolledUserMatchesSession

    @Test("E6a: enrolledUserMatchesSession is true when enrolled userId matches currentUser.id")
    func enrolledUserMatchesSessionTrueWhenMatch() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .success)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")
        try await service.enrollCurrentSession()

        #expect(service.enrolledUserMatchesSession == true,
                "enrolledUserMatchesSession must be true when enrolled user equals session user")
    }

    @Test("E6b: enrolledUserMatchesSession is false when different user is enrolled")
    func enrolledUserMatchesSessionFalseWhenDifferentUser() async throws {
        // Enroll with u2, then login as u1 — they should not match
        let (service, _, store, auth) = makeSUT(authenticatorResult: .success)

        // Enroll u2 directly into the store (bypassing login flow to seed a foreign enrollment)
        try store.enroll(refreshToken: "tok-u2", userId: "mock-u2", firstName: "U2")

        // Now login as u1
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")

        // The enrollment belongs to u2, not u1
        #expect(service.enrolledUserMatchesSession == false,
                "enrolledUserMatchesSession must be false when enrolled userId differs from currentUser.id")
    }

    @Test("E6c: enrolledUserMatchesSession is false when no enrollment exists")
    func enrolledUserMatchesSessionFalseWhenNoEnrollment() async throws {
        let (service, _, _, _) = makeSUT(authenticatorResult: .success)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")
        // No enrollment — no call to enrollCurrentSession()

        #expect(service.enrolledUserMatchesSession == false,
                "enrolledUserMatchesSession must be false when no enrollment exists")
    }

    // MARK: - E7: Silent token rotation — no shouldShowBiometricEnablementAfterLogin for enrolled user

    @Test("E7: Login by enrolled user does not set shouldShowBiometricEnablementAfterLogin")
    func loginByEnrolledUserDoesNotSetOfferFlag() async throws {
        let (service, _, store, _) = makeSUT(authenticatorResult: .success)

        // First login and enroll
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: first login succeeded")
        try await service.enrollCurrentSession()
        try #require(service.enrolledUser?.userId == "mock-u1",
                     "Precondition: enrollment must exist for u1")

        // The flag must NOT have been set for a login by the already-enrolled user.
        // (The pend flag was never set, and the enrolled-user path must not set the offer flag.)
        #expect(service.shouldShowBiometricEnablementAfterLogin == false,
                "shouldShowBiometricEnablementAfterLogin must stay false for an already-enrolled user's login")
    }

    @Test("E7b: After login by enrolled user, credentialStore refresh token is updated silently")
    func loginByEnrolledUserRotatesStoredRefreshToken() async throws {
        let (service, _, store, _) = makeSUT(authenticatorResult: .success)

        // First login and enroll
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: first login succeeded")
        try await service.enrollCurrentSession()

        // Capture the token now in the store
        let tokenBefore = try await store.readRefreshToken(reason: "test")

        // Login again as the same enrolled user — this should silently rotate the stored token
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: second login succeeded")

        let tokenAfter = try await store.readRefreshToken(reason: "test")

        // The stored token must have been updated (MockAuthenticationRepository issues new UUIDs per login)
        #expect(tokenAfter != tokenBefore,
                "credentialStore refresh token must be rotated after a login by the enrolled user")
    }

    // MARK: - E8: enrolledUser firstName derived from name field

    @Test("E8: enrolledUser firstName is the first component of the user name field")
    func enrolledUserFirstNameDerivedFromNameField() async throws {
        // MockAuthenticationRepository.stableUser capitalises the local part of the email.
        // "u1@example.com" → name "U1" → firstName "U1"
        let (service, _, _, _) = makeSUT(authenticatorResult: .success)
        await service.login(email: "u1@example.com", password: "password", rememberEmail: false)
        try #require(service.isAuthenticated, "Precondition: must be logged in")

        try await service.enrollCurrentSession()

        let enrolled = try #require(service.enrolledUser,
                                     "enrolledUser must be non-nil after successful enrollment")
        // name from MockAuthenticationRepository.stableUser for "u1@example.com" is "U1"
        // firstName = name.components(separatedBy:" ").first ?? "" = "U1"
        #expect(enrolled.firstName == "U1",
                "enrolledUser.firstName must equal 'U1' for user derived from 'u1@example.com'")
    }
}
