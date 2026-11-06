//
//  ObservableSnapshotTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R1 of I2b-2a: AuthenticationService observable snapshot properties
//  and biometricSignInState state machine.
//
//  These tests will FAIL until the implementer:
//    - Adds enrolledUserSnapshot: (userId: String, firstName: String)? to AuthenticationService
//    - Makes enrolledUser a computed property returning enrolledUserSnapshot
//    - Adds refreshBiometricState() that sets enrolledUserSnapshot
//    - Adds biometricSignInState: BiometricSignInState (starts .idle)
//    - Adds clearBiometricSignInState()
//    - Updates signInWithBiometric() to set biometricSignInState on failure paths
//    - Creates BiometricSignInState.swift
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - ErroringBiometricCredentialStore
//
// A credential store that can be configured to throw a specific BiometricCredentialError
// on readRefreshToken. Used to drive signInWithBiometric() failure paths.

private final class ErroringBiometricCredentialStore: BiometricCredentialStoring, @unchecked Sendable {
    private let inner: InMemoryBiometricCredentialStore
    var readError: BiometricCredentialError?

    init(wrapping inner: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore()) {
        self.inner = inner
    }

    func enrolledUser() -> (userId: String, firstName: String)? {
        inner.enrolledUser()
    }

    func enroll(refreshToken: String, userId: String, firstName: String) throws {
        try inner.enroll(refreshToken: refreshToken, userId: userId, firstName: firstName)
    }

    func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String {
        if let error = readError {
            throw error
        }
        return try await inner.readRefreshToken(reason: reason)
    }

    func updateRefreshToken(_ newToken: String) throws {
        try inner.updateRefreshToken(newToken)
    }

    func delete() throws {
        try inner.delete()
    }
}

// MARK: - AuthenticationRepository that throws on biometric login/refresh

/// Repository that throws a specified AuthenticationError on refresh.
/// Login succeeds so we can reach the refresh step in signInWithBiometric().
private actor BiometricRefreshFailingRepository: AuthenticationRepository {
    let refreshError: AuthenticationError

    init(refreshError: AuthenticationError) {
        self.refreshError = refreshError
    }

    private func makeUser(email: String) -> User {
        let local = email.components(separatedBy: "@").first ?? email
        return User(id: "mock-\(local)", email: email, name: local, role: .user,
                    createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }

    func login(email: String, password: String) async throws -> AuthSession {
        AuthSession(user: makeUser(email: email), accessToken: "at",
                    refreshToken: "mock_rt_mock-\(email.components(separatedBy: "@").first ?? "u")_\(UUID().uuidString)",
                    expiresIn: 900)
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        AuthSession(user: makeUser(email: email), accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        throw refreshError
    }

    func logout() async throws {}
}

// MARK: - Factory

@MainActor
private func makeSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: any BiometricCredentialStoring = InMemoryBiometricCredentialStore(),
    biometricAuthenticator: FakeBiometricAuthenticator = FakeBiometricAuthenticator()
) -> AuthenticationService {
    let sessionManager = SessionManager(authRepository: repo)
    return AuthenticationService(
        repository: repo,
        sessionManager: sessionManager,
        biometricAuthenticator: biometricAuthenticator,
        credentialStore: credentialStore
    )
}

// MARK: - Suite

@Suite("Observable Snapshot Tests")
@MainActor
struct ObservableSnapshotTests {

    // MARK: - enrolledUserSnapshot: initial state

    @Test("enrolledUserSnapshot is nil when no credentials are enrolled")
    func enrolledUserSnapshotIsNilInitially() async {
        let store = InMemoryBiometricCredentialStore()
        let sut = makeSUT(credentialStore: store)
        await sut.refreshBiometricState()
        #expect(sut.enrolledUserSnapshot == nil)
    }

    // MARK: - enrolledUserSnapshot: after enroll

    @Test("enrolledUserSnapshot reflects enrolled user after enrollCurrentSession completes")
    func enrolledUserSnapshotReflectsEnrolledUser() async throws {
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let authenticator = FakeBiometricAuthenticator()
        authenticator.stubbedResult = .success
        let sut = makeSUT(repo: repo, credentialStore: store, biometricAuthenticator: authenticator)

        // Log in first to have a session
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        try await sut.enrollCurrentSession()
        await sut.refreshBiometricState()

        #expect(sut.enrolledUserSnapshot != nil)
    }

    // MARK: - enrolledUserSnapshot: after revoke

    @Test("enrolledUserSnapshot is nil after revokeEnrollment")
    func enrolledUserSnapshotIsNilAfterRevoke() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        let sut = makeSUT(credentialStore: store)
        await sut.refreshBiometricState()
        try #require(sut.enrolledUserSnapshot != nil, "Precondition: snapshot must be populated")

        try sut.revokeEnrollment()
        await sut.refreshBiometricState()

        #expect(sut.enrolledUserSnapshot == nil)
    }

    // MARK: - enrolledUser computed property returns snapshot

    @Test("enrolledUser returns enrolledUserSnapshot, not a fresh Keychain read")
    func enrolledUserReturnsSnapshot() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        let sut = makeSUT(credentialStore: store)
        await sut.refreshBiometricState()

        // Both should agree once snapshot is populated
        let snapshot = sut.enrolledUserSnapshot
        let computed = sut.enrolledUser
        #expect(snapshot?.userId == computed?.userId)
        #expect(snapshot?.firstName == computed?.firstName)
    }

    // MARK: - enrolledUserMatchesSession

    @Test("enrolledUserMatchesSession is true when enrolled user id matches session user id")
    func enrolledUserMatchesSessionTrueWhenMatch() async throws {
        let store = InMemoryBiometricCredentialStore()
        let repo = MockAuthenticationRepository()
        let sut = makeSUT(repo: repo, credentialStore: store)

        // Log in to establish a session
        await sut.login(email: "alice@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        // Enroll with the session user's id
        let sessionUserId = sut.currentUser?.id ?? ""
        try store.enroll(refreshToken: "mock_rt_some-uuid", userId: sessionUserId, firstName: "Alice")
        await sut.refreshBiometricState()

        #expect(sut.enrolledUserMatchesSession == true)
    }

    @Test("enrolledUserMatchesSession is false when no enrollment exists")
    func enrolledUserMatchesSessionFalseWhenNoEnrollment() {
        let store = InMemoryBiometricCredentialStore()
        let sut = makeSUT(credentialStore: store)
        // No login, no enrollment
        #expect(sut.enrolledUserMatchesSession == false)
    }

    // MARK: - biometricSignInState initial state

    @Test("biometricSignInState starts as .idle")
    func biometricSignInStateStartsAsIdle() {
        let sut = makeSUT()
        #expect(sut.biometricSignInState == .idle)
    }

    // MARK: - clearBiometricSignInState

    @Test("clearBiometricSignInState sets biometricSignInState back to idle")
    func clearBiometricSignInStateSetsIdle() async {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .biometricFailed
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()
        // After biometricFailed, state should be retryHint (not idle)
        // Then clearBiometricSignInState must reset it
        sut.clearBiometricSignInState()
        #expect(sut.biometricSignInState == .idle)
    }

    // MARK: - signInWithBiometric: biometricFailed sets retryHint

    @Test("signInWithBiometric with biometricFailed sets biometricSignInState to retryHint")
    func signInWithBiometricFailedSetsRetryHint() async {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .biometricFailed
        let authenticator = FakeBiometricAuthenticator()
        let sut = makeSUT(credentialStore: store, biometricAuthenticator: authenticator)

        await sut.signInWithBiometric()

        if case .retryHint = sut.biometricSignInState {
            // expected
        } else {
            Issue.record("Expected biometricSignInState to be .retryHint, got \(sut.biometricSignInState)")
        }
    }

    // MARK: - signInWithBiometric: itemNotFound deletes enrollment and refreshes snapshot

    @Test("signInWithBiometric with itemNotFound deletes enrollment, refreshes snapshot to nil, state stays idle")
    func signInWithBiometricItemNotFoundDeletesEnrollmentAndRefreshesSnapshot() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        store.stubbedReadError = .itemNotFound
        let sut = makeSUT(credentialStore: store)
        await sut.refreshBiometricState()
        try #require(sut.enrolledUserSnapshot != nil, "Precondition: snapshot must be set before call")

        await sut.signInWithBiometric()

        #expect(store.enrolledUser() == nil, "Enrollment must be deleted on itemNotFound")
        #expect(sut.enrolledUserSnapshot == nil, "Snapshot must be refreshed to nil")
        #expect(sut.biometricSignInState == .idle)
    }

    // MARK: - signInWithBiometric: itemInvalidated deletes enrollment and refreshes snapshot

    @Test("signInWithBiometric with itemInvalidated deletes enrollment, refreshes snapshot to nil, state stays idle")
    func signInWithBiometricItemInvalidatedDeletesEnrollmentAndRefreshesSnapshot() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        store.stubbedReadError = .itemInvalidated
        let sut = makeSUT(credentialStore: store)
        await sut.refreshBiometricState()
        try #require(sut.enrolledUserSnapshot != nil, "Precondition: snapshot must be set before call")

        await sut.signInWithBiometric()

        #expect(store.enrolledUser() == nil, "Enrollment must be deleted on itemInvalidated")
        #expect(sut.enrolledUserSnapshot == nil, "Snapshot must be refreshed to nil")
        #expect(sut.biometricSignInState == .idle)
    }

    // MARK: - signInWithBiometric: credential AuthenticationError

    @Test("signInWithBiometric with invalidCredentials AuthenticationError deletes enrollment, snapshot nil, state passwordRequired")
    func signInWithBiometricCredentialAuthErrorSetsPasswordRequired() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        let failingRepo = BiometricRefreshFailingRepository(refreshError: .invalidCredentials)
        let sut = makeSUT(repo: failingRepo, credentialStore: store)
        await sut.refreshBiometricState()
        try #require(sut.enrolledUserSnapshot != nil, "Precondition: snapshot must be set before call")

        await sut.signInWithBiometric()

        #expect(store.enrolledUser() == nil, "Enrollment must be deleted on credential failure")
        #expect(sut.enrolledUserSnapshot == nil, "Snapshot must be refreshed to nil")
        #expect(sut.biometricSignInState == .passwordRequired)
    }
}
