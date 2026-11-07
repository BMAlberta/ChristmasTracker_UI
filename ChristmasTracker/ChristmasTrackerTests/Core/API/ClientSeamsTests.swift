// ClientSeamsTests.swift
// ChristmasTrackerTests
//
// Package I2b-2c, story U2 (Decision D-a): the extracted composition function
// makeClientSeams() and the session-ending adapter it builds.
//
// - The session-ending seam signs out a signed-in session, is a no-op when signed out,
//   is idempotent, and never touches the biometric enrollment.
// - Composition test 1: after the function that composed the seams has returned and every
//   local except the three seam objects and the service is gone, all three seams still
//   reach the service (the box must be held strongly by the seam closures).
// - Composition test 2: with the service released, the seams fail safely with typed
//   errors, and nothing retains the service (the box must hold it weakly).
// - I2b-2d E1: the adapter ends the session only when the request token equals the
//   service's current access token. A stale token, a nil token, or a token a refresh has
//   since rotated is ignored while signed in; signed out is a no-op. The existing tests
//   pass the current token so their meaning is unchanged.
//
// No real Keychain-backed credential store, no LocalAuthentication, no network: the
// service uses MockAuthenticationRepository, FakeBiometricAuthenticator, an in-memory
// credential store that counts deletes, and an in-memory remembered-email store.
//
// Fails to compile until the implementer changes SessionEnding to
// sessionEnded(reason:requestToken:) (package Seams.swift, Core/API/SessionEndingSeam.swift).

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - DeleteCountingCredentialStore

/// Wraps InMemoryBiometricCredentialStore and counts delete() calls.
// @unchecked Sendable: the only mutable state (_deleteCallCount) is protected by an NSLock; inner is itself lock-protected.
private final class DeleteCountingCredentialStore: BiometricCredentialStoring, @unchecked Sendable {
    private let inner = InMemoryBiometricCredentialStore()
    private let lock = NSLock()
    private var _deleteCallCount = 0

    var deleteCallCount: Int { lock.withLock { _deleteCallCount } }

    func enrolledUser() -> (userId: String, firstName: String)? {
        inner.enrolledUser()
    }

    func enroll(refreshToken: String, userId: String, firstName: String) throws {
        try inner.enroll(refreshToken: refreshToken, userId: userId, firstName: firstName)
    }

    func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String {
        try await inner.readRefreshToken(reason: reason)
    }

    func updateRefreshToken(_ newToken: String) throws {
        try inner.updateRefreshToken(newToken)
    }

    func delete() throws {
        lock.withLock { _deleteCallCount += 1 }
        try inner.delete()
    }
}

// MARK: - InMemoryRememberedEmailStore

private struct InMemoryRememberedEmailStore: RememberedEmailStoring {
    var rememberedEmail: String?
}

// MARK: - Suite

@Suite("ClientSeams composition Tests")
@MainActor
struct ClientSeamsTests {

    // MARK: - Fixtures

    private static let email = "alice@test.invalid"
    private static let password = "password-FAKE"
    /// MockAuthenticationRepository derives the user ID "mock-<local part>" from the email.
    private static let userId = "mock-alice"

    private struct Dependencies {
        let store: DeleteCountingCredentialStore
        let clearable: MockSessionClearable
    }

    /// Builds the collaborators with a biometric enrollment for the signed-in user present.
    private func makeDependencies() throws -> Dependencies {
        let store = DeleteCountingCredentialStore()
        try store.enroll(refreshToken: "mock_rt_\(Self.userId)_FAKE", userId: Self.userId, firstName: "Alice")
        return Dependencies(store: store, clearable: MockSessionClearable())
    }

    private func makeService(dependencies: Dependencies) -> AuthenticationService {
        AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(initialClearables: [dependencies.clearable]),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: InMemoryRememberedEmailStore(),
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: dependencies.store
        )
    }

    private func signIn(_ service: AuthenticationService) async throws {
        await service.login(email: Self.email, password: Self.password)
        try #require(service.isAuthenticated, "Precondition: the mock login must sign the service in")
    }

    /// Composes the seams and returns ONLY the three seam objects. The ClientSeams value and
    /// its box go out of scope when this function returns, so the seams can reach the
    /// service only if their closures retain the box.
    private func composeSeams(
        attaching service: AuthenticationService
    ) -> (tokenProvider: AccessTokenSeam, sessionRefresher: SessionRefreshSeam, sessionEnding: SessionEndingSeam) {
        let seams = makeClientSeams()
        seams.box.value = service
        return (seams.tokenProvider, seams.sessionRefresher, seams.sessionEnding)
    }

    private func expectCredentialFailure(
        _ refresher: SessionRefreshSeam,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        do {
            try await refresher.refresh()
            Issue.record("Expected SessionRefreshError.credentialFailure but no error was thrown", sourceLocation: sourceLocation)
        } catch SessionRefreshError.credentialFailure {
            // Expected
        } catch {
            Issue.record("Expected SessionRefreshError.credentialFailure but got: \(error)", sourceLocation: sourceLocation)
        }
    }

    // MARK: - Session-ending adapter via makeClientSeams()

    @Test(
        "sessionEnded signs out a signed-in service and leaves the biometric enrollment intact",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func sessionEndedSignsOutSignedInService(reason: SessionEndReason) async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service

        await seams.sessionEnding.sessionEnded(reason: reason, requestToken: currentToken)

        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.currentAccessToken == nil)
        #expect(dependencies.clearable.clearCallCount == 1)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("sessionEnded is a no-op when the service is signed out: no teardown, enrollment intact")
    func sessionEndedIsNoOpWhenSignedOut() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        let seams = makeClientSeams()
        seams.box.value = service
        #expect(service.isAuthenticated == false)

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: "T1")

        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(dependencies.clearable.clearCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("sessionEnded twice on a signed-in session signs out once and leaves the enrollment intact")
    func sessionEndedTwiceIsIdempotent() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: currentToken)
        await seams.sessionEnding.sessionEnded(reason: .userNotFound, requestToken: currentToken)

        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(dependencies.clearable.clearCallCount == 1)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("Concurrent sessionEnded calls on a signed-in session run the teardown exactly once")
    func concurrentSessionEndedRunsTeardownOnce() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service
        let sessionEnding = seams.sessionEnding

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask { @MainActor in
                    await sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: currentToken)
                }
            }
            await group.waitForAll()
        }

        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(dependencies.clearable.clearCallCount == 1)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    // MARK: - Composition test 1: seams outlive the composition function

    @Test("Composition 1: after composition returns, all three seams still reach the signed-in service")
    func seamsReachServiceAfterCompositionReturns() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let signedInToken = try #require(service.currentAccessToken)

        // Only the three seam objects (and the service) survive this call.
        let (tokenProvider, sessionRefresher, sessionEnding) = composeSeams(attaching: service)

        // Token provider reaches the service.
        #expect(await tokenProvider.accessToken() == signedInToken)

        // Session refresher reaches the service: the mock repository rotates the tokens.
        try await sessionRefresher.refresh()
        let rotatedToken = try #require(service.currentAccessToken)
        #expect(rotatedToken != signedInToken)
        #expect(await tokenProvider.accessToken() == rotatedToken)
        #expect(service.isAuthenticated == true)

        // Session-ending adapter reaches the service: with the current (rotated) token it signs out.
        await sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: rotatedToken)
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(await tokenProvider.accessToken() == nil)
        #expect(dependencies.store.deleteCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
    }

    // MARK: - Composition test 2: the box holds the service weakly

    @Test("Composition 2: with the service released, nothing retains it and the seams fail safely")
    func seamsFailSafelyAfterServiceReleased() async throws {
        let dependencies = try makeDependencies()
        let seams = makeClientSeams()
        weak var probe: AuthenticationService?
        var service: AuthenticationService? = makeService(dependencies: dependencies)
        probe = service
        seams.box.value = service
        if let signedIn = service {
            try await signIn(signedIn)
        }
        // Precondition: while the service is alive the token seam reaches it.
        #expect(await seams.tokenProvider.accessToken() != nil)

        service = nil

        // No retain cycle: neither the box nor the seam closures keep the service alive.
        #expect(probe == nil)
        #expect(seams.box.value == nil)

        // Token provider returns nil.
        #expect(await seams.tokenProvider.accessToken() == nil)

        // Refresher fails with the typed credential failure.
        await expectCredentialFailure(seams.sessionRefresher)

        // Session-ending adapter returns without crashing and touches nothing.
        let clearsBefore = dependencies.clearable.clearCallCount
        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: "T1")
        await seams.sessionEnding.sessionEnded(reason: .userNotFound, requestToken: nil)
        #expect(dependencies.clearable.clearCallCount == clearsBefore)
        #expect(dependencies.store.deleteCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
    }

    @Test("Composition 2: seams with no service ever attached fail safely")
    func seamsFailSafelyWithNoServiceAttached() async {
        let seams = makeClientSeams()

        #expect(seams.box.value == nil)
        #expect(await seams.tokenProvider.accessToken() == nil)
        await expectCredentialFailure(seams.sessionRefresher)
        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: "T1")
    }

    // MARK: - I2b-2d E1: the request token must match the current access token

    @Test(
        "A stale request token is ignored: still signed in, no teardown, enrollment intact",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func staleTokenIsIgnored(reason: SessionEndReason) async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service
        let staleToken = "stale-token-FAKE"
        try #require(staleToken != currentToken)

        await seams.sessionEnding.sessionEnded(reason: reason, requestToken: staleToken)

        #expect(service.isAuthenticated == true)
        #expect(service.currentUser?.id == Self.userId)
        #expect(service.currentAccessToken == currentToken)
        #expect(dependencies.clearable.clearCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test(
        "A nil request token while signed in is ignored: still signed in, no teardown, enrollment intact",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func nilTokenWhileSignedInIsIgnored(reason: SessionEndReason) async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service

        await seams.sessionEnding.sessionEnded(reason: reason, requestToken: nil)

        #expect(service.isAuthenticated == true)
        #expect(service.currentUser?.id == Self.userId)
        #expect(service.currentAccessToken == currentToken)
        #expect(dependencies.clearable.clearCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("Signed out, a nil request token is a no-op: no teardown, enrollment intact")
    func signedOutWithNilTokenIsNoOp() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        let seams = makeClientSeams()
        seams.box.value = service
        try #require(service.isAuthenticated == false)

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: nil)
        await seams.sessionEnding.sessionEnded(reason: .userNotFound, requestToken: nil)

        #expect(service.isAuthenticated == false)
        #expect(dependencies.clearable.clearCallCount == 0)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("A stale token does not block a later matching token: the matching call ends the session once")
    func staleThenMatchingTokenEndsSessionOnce() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let currentToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: "stale-token-FAKE")
        #expect(service.isAuthenticated == true)
        #expect(dependencies.clearable.clearCallCount == 0)

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: currentToken)

        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.currentAccessToken == nil)
        #expect(dependencies.clearable.clearCallCount == 1)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("The token from a previous sign-in of the same user is ignored after signing in again")
    func previousSignInTokenIsIgnored() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let firstToken = try #require(service.currentAccessToken)
        await service.logout()
        try await signIn(service)
        let secondToken = try #require(service.currentAccessToken)
        try #require(firstToken != secondToken, "Precondition: each mock login issues a new access token")
        let clearsAfterSecondSignIn = dependencies.clearable.clearCallCount
        let seams = makeClientSeams()
        seams.box.value = service

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: firstToken)

        #expect(service.isAuthenticated == true)
        #expect(service.currentAccessToken == secondToken)
        #expect(dependencies.clearable.clearCallCount == clearsAfterSecondSignIn)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }

    @Test("Documented trade-off: a token a refresh has since rotated is ignored; the rotated token still ends the session")
    func refreshRotatedTokenIsIgnored() async throws {
        let dependencies = try makeDependencies()
        let service = makeService(dependencies: dependencies)
        try await signIn(service)
        let preRefreshToken = try #require(service.currentAccessToken)
        let seams = makeClientSeams()
        seams.box.value = service
        try await seams.sessionRefresher.refresh()
        let rotatedToken = try #require(service.currentAccessToken)
        try #require(rotatedToken != preRefreshToken, "Precondition: the mock refresh rotates the access token")

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: preRefreshToken)

        #expect(service.isAuthenticated == true)
        #expect(service.currentAccessToken == rotatedToken)
        #expect(dependencies.clearable.clearCallCount == 0)

        await seams.sessionEnding.sessionEnded(reason: .accountDisabled, requestToken: rotatedToken)

        #expect(service.isAuthenticated == false)
        #expect(dependencies.clearable.clearCallCount == 1)
        #expect(dependencies.store.enrolledUser()?.userId == Self.userId)
        #expect(dependencies.store.deleteCallCount == 0)
    }
}
