// SessionGenerationTests.swift
// ChristmasTrackerTests
//
// Package I3a, story H2 (part B): a sign-in that completes while an earlier session end is
// still in flight must not be wiped by that end.
//
// Interface on AuthenticationService (internal, no protocol), now implemented:
//   - a session generation counter, owned by the service;
//   - endSession captures it when the end starts;
//   - the end's final clearing steps (clear auth state, clear stored tokens) run only if the
//     generation is unchanged;
//   - a successful sign-in (handleAuthSuccess: login, register, biometric sign-in) increments it.
// Server logout rule (H2 fix round): a superseded end makes NO server logout call, because the
// call would carry the NEW user's access token and could invalidate the new session; a normal
// end makes exactly one best-effort server logout.
// The tests use only the existing public/internal surface (login, register, logout,
// isAuthenticated, currentUser, currentAccessToken). The biometric sign-in path is not covered
// here: SessionEndSignInPath has no biometric case and it needs enrollment setup.
//
// Deterministic handshake: GatedClearable suspends the FIRST teardown call (the OLD session's
// data) until the test releases it; the test signs in the new user while it is held. No sleeps,
// no yield loops. No real Keychain, LocalAuthentication or network: the repository is an
// instant in-test fake, the credential store is InMemoryBiometricCredentialStore.

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - GatedClearable

/// Counts clearForSession calls. The first call signals `waitUntilEntered()` and suspends
/// until `release()`. Later calls are counted and never held.
@MainActor private final class GatedClearable: SessionClearable {
    private(set) var clearCallCount = 0
    private(set) var completedCount = 0
    private var hasEntered = false
    private var isReleased = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var heldCall: CheckedContinuation<Void, Never>?

    func clearForSession() async throws {
        clearCallCount += 1
        if clearCallCount == 1 {
            hasEntered = true
            enteredWaiter?.resume()
            enteredWaiter = nil
            if !isReleased {
                await withCheckedContinuation { continuation in
                    heldCall = continuation
                }
            }
        }
        completedCount += 1
    }

    /// Returns once the first clearForSession call has been entered (immediately if it has).
    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { continuation in
            enteredWaiter = continuation
        }
    }

    /// Lets the held first call finish.
    func release() {
        isReleased = true
        heldCall?.resume()
        heldCall = nil
    }
}

// MARK: - InstantAuthRepository

/// Login and register succeed at once for a user derived from the email, with a distinct
/// access token per sign-in. Refresh is never expected.
@MainActor private final class InstantAuthRepository: AuthenticationRepository {
    private(set) var signInCount = 0
    private(set) var logoutCallCount = 0
    private var logoutWaiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?

    /// Returns once logout has been called at least `count` times (immediately if already so).
    func waitForLogoutCalls(atLeast count: Int) async {
        guard logoutCallCount < count else { return }
        await withCheckedContinuation { continuation in
            logoutWaiter = (count, continuation)
        }
    }

    private func makeSession(email: String) -> AuthSession {
        signInCount += 1
        let localPart = String(email.prefix(while: { $0 != "@" }))
        let user = User(
            id: "user-\(localPart)",
            email: email,
            name: localPart,
            role: .user,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return AuthSession(
            user: user,
            accessToken: "tok-access-\(signInCount)-FAKE",
            refreshToken: "tok-refresh-\(signInCount)-FAKE",
            expiresIn: 3600
        )
    }

    func login(email: String, password: String) async throws -> AuthSession {
        makeSession(email: email)
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        makeSession(email: email)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        throw AuthenticationError.invalidRefreshToken
    }

    func logout() async throws {
        logoutCallCount += 1
        if let waiter = logoutWaiter, logoutCallCount >= waiter.count {
            logoutWaiter = nil
            waiter.continuation.resume()
        }
    }
}

// MARK: - InMemoryEmailStore

private struct InMemoryEmailStore: RememberedEmailStoring {
    var rememberedEmail: String?
}

// MARK: - Suite

@Suite("Session generation (I3a H2)")
@MainActor
struct SessionGenerationTests {

    private static let password = "password-FAKE"
    private static let emailA = "alice@test.invalid"
    private static let emailB = "bob@test.invalid"

    private struct SUT {
        let service: AuthenticationService
        let repository: InstantAuthRepository
        let clearable: GatedClearable
        let legacyCleanup: FakeLegacyTokenCleanup
    }

    private func makeSUT() -> SUT {
        let clearable = GatedClearable()
        let legacyCleanup = FakeLegacyTokenCleanup()
        let repository = InstantAuthRepository()
        let service = AuthenticationService(
            repository: repository,
            sessionManager: SessionManager(initialClearables: [clearable]),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: InMemoryEmailStore(),
            legacyCleanup: legacyCleanup,
            credentialStore: InMemoryBiometricCredentialStore()
        )
        return SUT(service: service, repository: repository, clearable: clearable, legacyCleanup: legacyCleanup)
    }

    private func signIn(
        _ service: AuthenticationService,
        email: String,
        via path: SessionEndSignInPath = .login
    ) async throws -> String {
        switch path {
        case .login:
            await service.login(email: email, password: Self.password)
        case .register:
            await service.register(
                email: email,
                password: Self.password,
                firstName: "First",
                lastName: "Last",
                registrationCode: "CODE-FAKE"
            )
        }
        try #require(service.isAuthenticated, "Precondition: the fake repository must sign the service in")
        return try #require(service.currentAccessToken, "Precondition: a signed-in service has an access token")
    }

    /// Signs user A in, starts A's end (logout) and waits until its teardown is held in flight.
    private func startHeldEnd(_ sut: SUT) async throws -> Task<Void, Never> {
        _ = try await signIn(sut.service, email: Self.emailA)
        let service = sut.service
        let endTask = Task { await service.logout() }
        await sut.clearable.waitUntilEntered()
        return endTask
    }

    // MARK: - (1) Sign-in during an in-flight end keeps the new session

    @Test(
        "Sign-in during an in-flight end is not wiped when the end completes",
        .timeLimit(.minutes(1)),
        arguments: SessionEndSignInPath.allCases
    )
    func signInDuringInFlightEndKeepsNewSession(_ path: SessionEndSignInPath) async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)

        // While A's teardown is held, B signs in.
        let tokenB = try await signIn(sut.service, email: Self.emailB, via: path)
        #expect(sut.service.currentUser?.id == "user-bob")
        let tokenCleanupsBeforeRelease = sut.legacyCleanup.clearStoredSessionTokensCallCount

        sut.clearable.release()
        await endTask.value

        #expect(sut.service.isAuthenticated == true, "The new session must survive the old end")
        #expect(sut.service.currentUser?.id == "user-bob")
        #expect(sut.service.currentAccessToken == tokenB, "The new session's tokens are kept")
        #expect(
            sut.legacyCleanup.clearStoredSessionTokensCallCount == tokenCleanupsBeforeRelease,
            "The old end must not clear stored tokens after the new sign-in"
        )
        #expect(sut.clearable.clearCallCount == 1, "The new session's data is not torn down")
    }

    // MARK: - (2) The old end still tears down the OLD data exactly once

    @Test("The superseded end tears down the old session's data exactly once", .timeLimit(.minutes(1)))
    func supersededEndTearsDownOldDataOnce() async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)
        #expect(sut.clearable.clearCallCount == 1, "The old session's teardown has started once")

        _ = try await signIn(sut.service, email: Self.emailB)
        sut.clearable.release()
        await endTask.value

        #expect(sut.clearable.clearCallCount == 1, "Exactly one teardown call overall")
        #expect(sut.clearable.completedCount == 1, "The old teardown ran to completion")
    }

    // MARK: - (3) Existing meaning: an end with no intervening sign-in still clears everything

    @Test("An end with no intervening sign-in clears state and tokens", .timeLimit(.minutes(1)))
    func endWithoutNewSignInClearsEverything() async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)

        sut.clearable.release()
        await endTask.value

        #expect(sut.service.isAuthenticated == false)
        #expect(sut.service.currentUser == nil)
        #expect(sut.service.currentAccessToken == nil)
        #expect(sut.legacyCleanup.clearStoredSessionTokensCallCount == 1)
        #expect(sut.clearable.clearCallCount == 1)
    }

    // MARK: - (4) The new session can still be ended normally afterwards

    @Test("After surviving a superseded end, the new session ends normally", .timeLimit(.minutes(1)))
    func newSessionEndsNormallyAfterSupersededEnd() async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)
        _ = try await signIn(sut.service, email: Self.emailB)
        sut.clearable.release()
        await endTask.value
        try #require(sut.service.isAuthenticated, "Precondition: B survived A's end")

        await sut.service.logout()

        #expect(sut.service.isAuthenticated == false)
        #expect(sut.service.currentUser == nil)
        #expect(sut.service.currentAccessToken == nil)
        #expect(sut.clearable.clearCallCount == 2, "A's end and B's end each tear down once")
    }

    // MARK: - (5) Server logout: superseded end makes none, normal end makes exactly one

    /// The server logout is a non-awaited Task, so a call that never starts cannot be awaited.
    /// This hops through the main actor once; the logout Task (if any) was enqueued on the main
    /// actor before this hop, and the main actor runs work in FIFO order, so it has run by now.
    private func drainMainActorQueue() async {
        await Task { @MainActor in }.value
    }

    @Test(
        "A superseded end makes no server logout call",
        .timeLimit(.minutes(1)),
        arguments: SessionEndSignInPath.allCases
    )
    func supersededEndMakesNoServerLogout(_ path: SessionEndSignInPath) async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)
        _ = try await signIn(sut.service, email: Self.emailB, via: path)

        sut.clearable.release()
        await endTask.value
        await drainMainActorQueue()

        // Assertion of absence, made after all awaited work of the end plus one main-actor hop.
        #expect(sut.repository.logoutCallCount == 0, "A stale logout would carry the new user's token")
    }

    @Test("A normal end makes exactly one server logout call", .timeLimit(.minutes(1)))
    func normalEndMakesExactlyOneServerLogout() async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)
        sut.clearable.release()
        await endTask.value

        await sut.repository.waitForLogoutCalls(atLeast: 1)
        await drainMainActorQueue()

        #expect(sut.repository.logoutCallCount == 1)
    }

    @Test("Ending the new session after a superseded end makes exactly one server logout", .timeLimit(.minutes(1)))
    func newSessionEndAfterSupersededEndMakesOneServerLogout() async throws {
        let sut = makeSUT()
        let endTask = try await startHeldEnd(sut)
        _ = try await signIn(sut.service, email: Self.emailB)
        sut.clearable.release()
        await endTask.value
        await drainMainActorQueue()
        try #require(sut.repository.logoutCallCount == 0, "Precondition: the superseded end made no logout")

        await sut.service.logout()
        await sut.repository.waitForLogoutCalls(atLeast: 1)
        await drainMainActorQueue()

        #expect(sut.repository.logoutCallCount == 1)
    }
}
