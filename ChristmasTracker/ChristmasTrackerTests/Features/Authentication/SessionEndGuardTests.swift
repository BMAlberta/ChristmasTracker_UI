// SessionEndGuardTests.swift
// ChristmasTrackerTests
//
// Package I2b-2d, story E2: one single-flight session-end entry point, owned by
// AuthenticationService (Gate 1 spec "### E2: one session-end entry point").
//
// Interface under test (all on the @MainActor AuthenticationService):
// - internal func endSession(reason: TeardownReason, deletingEnrollmentForCurrentUser: Bool = false) async
// - func logout(reason: TeardownReason = .userLogout) async (now forwards to endSession)
// - internal func handleServerSessionEnd(reason: SessionEndReason, requestToken: String?) async
// - refreshTokenIfNeeded() and forceRefresh() call endSession(reason: .sessionExpired,
//   deletingEnrollmentForCurrentUser: true) on a refresh credential failure, only when signed in.
//
// Acceptance items covered: 1 (server end + refresh credential failure, both orders),
// 2 (user logout + server end, both orders), 3 (user logout + refresh credential failure),
// 4 (the guard resets after a new sign-in), 5 (a server end never deletes the enrollment),
// 6 (handleServerSessionEnd: stale token, nil token and signed out are no-ops), plus the
// guard semantics (a fresh service can end once; a completed end makes later ends no-ops;
// a joining endSession never deletes the enrollment).
//
// Deterministic handshakes only. GatedClearable holds the FIRST clearForSession call: it
// resumes a waiter when the call is entered and suspends until release(). Later calls are
// counted and not held, so a second teardown fails the count instead of hanging.
// GatedRefreshRepository can hold its first refresh the same way. No sleeps, no yields.
// Tests that hold a continuation carry `.timeLimit(.minutes(1))`.
//
// Ordering note: a Task created from this @MainActor suite inherits the main actor, so its
// first job is enqueued on the main actor before the test suspends. The held teardown can
// only resume on the main actor after the test calls release(), so a call started in such a
// Task reaches the guard while the end is still in flight. Where the second caller must
// first come back from a refresh (server-first and logout-first refresh cases), the point at
// which it reaches the guard cannot be observed through the interface; those tests pin the
// outcome, which is the same whether it joins the in-flight end or arrives after it.
//
// No real Keychain-backed credential store, no LocalAuthentication, no network: every
// AuthenticationService here injects FakeBiometricAuthenticator, FakeLegacyTokenCleanup,
// a delete-counting in-memory credential store and an in-memory remembered-email store.
// The credential store and email store fakes are private here because the equivalents in
// ClientSeamsTests.swift are private to that file.
//
// Fails to compile until the implementer adds endSession(reason:deletingEnrollmentForCurrentUser:)
// and handleServerSessionEnd(reason:requestToken:) to AuthenticationService.

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

// MARK: - GatedClearable

/// Counts clearForSession calls. When `holdsFirstCall` is true, the first call signals
/// `waitUntilEntered()` and suspends until `release()`. Later calls are never held.
@MainActor private final class GatedClearable: SessionClearable {
    private let holdsFirstCall: Bool
    private(set) var clearCallCount = 0
    private(set) var completedCount = 0
    private var hasEntered = false
    private var isReleased = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var heldCall: CheckedContinuation<Void, Never>?

    init(holdsFirstCall: Bool) {
        self.holdsFirstCall = holdsFirstCall
    }

    func clearForSession() async throws {
        clearCallCount += 1
        if holdsFirstCall && clearCallCount == 1 {
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

    /// Lets the held first call finish (or, if it has not arrived yet, lets it pass through).
    func release() {
        isReleased = true
        heldCall?.resume()
        heldCall = nil
    }
}

// MARK: - GatedRefreshRepository

/// Login and register always succeed for user "u1" with a fresh access token per call.
/// Refresh always throws `refreshError`. When `holdsFirstRefresh` is true, the first refresh
/// signals `waitUntilRefreshEntered()` and suspends until `releaseRefresh()`.
@MainActor private final class GatedRefreshRepository: AuthenticationRepository {
    static let userId = "u1"

    private let refreshError: AuthenticationError
    private let loginExpiresIn: Int
    private let holdsFirstRefresh: Bool
    private(set) var signInCount = 0
    private(set) var refreshCallCount = 0
    private var hasEnteredRefresh = false
    private var isRefreshReleased = false
    private var refreshEnteredWaiter: CheckedContinuation<Void, Never>?
    private var heldRefresh: CheckedContinuation<Void, Never>?

    init(refreshError: AuthenticationError, loginExpiresIn: Int, holdsFirstRefresh: Bool) {
        self.refreshError = refreshError
        self.loginExpiresIn = loginExpiresIn
        self.holdsFirstRefresh = holdsFirstRefresh
    }

    private func makeSession() -> AuthSession {
        signInCount += 1
        let user = User(
            id: Self.userId,
            email: "u1@test.invalid",
            name: "Alice Example",
            role: .user,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return AuthSession(
            user: user,
            accessToken: "tok-access-\(signInCount)-FAKE",
            refreshToken: "tok-refresh-\(signInCount)-FAKE",
            expiresIn: loginExpiresIn
        )
    }

    func login(email: String, password: String) async throws -> AuthSession {
        makeSession()
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        makeSession()
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        refreshCallCount += 1
        if holdsFirstRefresh && refreshCallCount == 1 {
            hasEnteredRefresh = true
            refreshEnteredWaiter?.resume()
            refreshEnteredWaiter = nil
            if !isRefreshReleased {
                await withCheckedContinuation { continuation in
                    heldRefresh = continuation
                }
            }
        }
        throw refreshError
    }

    func logout() async throws {}

    /// Returns once the first refresh call has been entered (immediately if it has).
    func waitUntilRefreshEntered() async {
        guard !hasEnteredRefresh else { return }
        await withCheckedContinuation { continuation in
            refreshEnteredWaiter = continuation
        }
    }

    /// Lets the held refresh throw its error.
    func releaseRefresh() {
        isRefreshReleased = true
        heldRefresh?.resume()
        heldRefresh = nil
    }
}

// MARK: - Test parameters

/// Which refresh credential-failure path a test drives.
enum SessionEndRefreshPath: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case refreshTokenIfNeeded
    case forceRefresh

    var testDescription: String { rawValue }
}

/// Which session-starting call a test uses to begin the next session.
enum SessionEndSignInPath: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case login
    case register

    var testDescription: String { rawValue }
}

// MARK: - Suite

@Suite("Session-end guard Tests (I2b-2d E2)")
@MainActor
struct SessionEndGuardTests {

    // MARK: - Fixtures

    private static let email = "u1@test.invalid"
    private static let password = "password-FAKE"

    private struct SUT {
        let service: AuthenticationService
        let repo: GatedRefreshRepository
        let clearable: GatedClearable
        let sessionManager: SessionManager
        let store: DeleteCountingCredentialStore
    }

    /// Builds the service with fakes only. `loginExpiresIn` defaults to 0 so that
    /// refreshTokenIfNeeded() always reaches the repository.
    private func makeSUT(
        refreshError: AuthenticationError = .accountDisabled,
        holdFirstRefresh: Bool = false,
        holdFirstTeardown: Bool = false,
        loginExpiresIn: Int = 0
    ) -> SUT {
        let repo = GatedRefreshRepository(
            refreshError: refreshError,
            loginExpiresIn: loginExpiresIn,
            holdsFirstRefresh: holdFirstRefresh
        )
        let clearable = GatedClearable(holdsFirstCall: holdFirstTeardown)
        let sessionManager = SessionManager(initialClearables: [clearable])
        let store = DeleteCountingCredentialStore()
        let service = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: InMemoryRememberedEmailStore(),
            legacyCleanup: FakeLegacyTokenCleanup(),
            credentialStore: store
        )
        return SUT(service: service, repo: repo, clearable: clearable, sessionManager: sessionManager, store: store)
    }

    /// Signs in and, by default, enrolls the signed-in user for Face ID.
    /// Returns the access token that is current after sign-in.
    @discardableResult
    private func signIn(
        _ sut: SUT,
        via path: SessionEndSignInPath = .login,
        enroll: Bool = true
    ) async throws -> String {
        switch path {
        case .login:
            await sut.service.login(email: Self.email, password: Self.password)
        case .register:
            await sut.service.register(
                email: Self.email,
                password: Self.password,
                firstName: "Alice",
                lastName: "Example",
                registrationCode: "CODE-FAKE"
            )
        }
        try #require(sut.service.isAuthenticated, "Precondition: the fake repository must sign the service in")
        if enroll && sut.store.enrolledUser() == nil {
            try await sut.service.enrollCurrentSession()
        }
        if enroll {
            try #require(
                sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId,
                "Precondition: the signed-in user is enrolled"
            )
        }
        return try #require(sut.service.currentAccessToken, "Precondition: a signed-in service has an access token")
    }

    /// Drives one refresh path. Returns the error forceRefresh rethrew (nil for refreshTokenIfNeeded).
    private func runRefresh(_ path: SessionEndRefreshPath, on service: AuthenticationService) async -> AuthenticationError? {
        switch path {
        case .refreshTokenIfNeeded:
            await service.refreshTokenIfNeeded()
            return nil
        case .forceRefresh:
            do {
                try await service.forceRefresh()
                return nil
            } catch let authError as AuthenticationError {
                return authError
            } catch {
                Issue.record("forceRefresh threw a non-AuthenticationError: \(error)")
                return nil
            }
        }
    }

    private func expectRefreshResult(
        _ result: AuthenticationError?,
        path: SessionEndRefreshPath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        switch path {
        case .refreshTokenIfNeeded:
            #expect(result == nil, sourceLocation: sourceLocation)
        case .forceRefresh:
            #expect(result == .accountDisabled, "forceRefresh must still rethrow the refresh error", sourceLocation: sourceLocation)
        }
    }

    // MARK: - 1. Server end overlapping a refresh credential failure

    @Test(
        "1a. Server end first, refresh credential failure during it: one teardown, enrollment intact",
        .timeLimit(.minutes(1)),
        arguments: SessionEndRefreshPath.allCases
    )
    func serverEndThenRefreshFailureTearsDownOnce(path: SessionEndRefreshPath) async throws {
        let sut = makeSUT(holdFirstRefresh: true, holdFirstTeardown: true)
        let token = try await signIn(sut)
        let service = sut.service

        // The refresh is in flight (held in the repository) before the server end starts,
        // so it cannot have started the end.
        let refreshTask = Task { await runRefresh(path, on: service) }
        await sut.repo.waitUntilRefreshEntered()

        // The server end starts the teardown and is held inside it.
        let serverEndTask = Task { () -> Bool in
            await service.handleServerSessionEnd(reason: .accountDisabled, requestToken: token)
            return service.isAuthenticated
        }
        await sut.clearable.waitUntilEntered()
        #expect(sut.store.deleteCallCount == 0, "A server end must not delete the enrollment")

        // The refresh now fails with a credential failure while the end is in flight.
        await sut.repo.releaseRefresh()
        await sut.clearable.release()

        let signedInWhenServerEndReturned = await serverEndTask.value
        let refreshResult = await refreshTask.value

        #expect(signedInWhenServerEndReturned == false, "The server end returns after the teardown")
        expectRefreshResult(refreshResult, path: path)
        #expect(await sut.clearable.clearCallCount == 1, "Overlapping ends must tear down exactly once")
        #expect(await sut.sessionManager.lastTeardownReason == .sessionExpired)
        #expect(sut.store.deleteCallCount == 0, "The refresh failure did not start the end, so it must not delete the enrollment")
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
        #expect(service.isAuthenticated == false)
        #expect(service.currentAccessToken == nil)
    }

    @Test(
        "1b. Refresh credential failure first, server end during it: one teardown, enrollment deleted once",
        .timeLimit(.minutes(1)),
        arguments: SessionEndRefreshPath.allCases
    )
    func refreshFailureThenServerEndTearsDownOnce(path: SessionEndRefreshPath) async throws {
        let sut = makeSUT(holdFirstTeardown: true)
        let token = try await signIn(sut)
        let service = sut.service

        // The refresh fails immediately and starts the end; it is held inside the teardown.
        let refreshTask = Task { await runRefresh(path, on: service) }
        await sut.clearable.waitUntilEntered()
        #expect(sut.store.deleteCallCount == 1, "The refresh failure started the end, so it deletes the enrollment")

        // A matching-token server end arrives while the end is in flight.
        let serverEndTask = Task { () -> Bool in
            await service.handleServerSessionEnd(reason: .userNotFound, requestToken: token)
            return service.isAuthenticated
        }
        await sut.clearable.release()

        let refreshResult = await refreshTask.value
        let signedInWhenServerEndReturned = await serverEndTask.value

        expectRefreshResult(refreshResult, path: path)
        #expect(signedInWhenServerEndReturned == false, "The joining server end returns after the teardown")
        #expect(await sut.clearable.clearCallCount == 1, "Overlapping ends must tear down exactly once")
        #expect(await sut.sessionManager.lastTeardownReason == .sessionExpired)
        #expect(sut.store.deleteCallCount == 1, "The enrollment is deleted once, by the refresh failure that started the end")
        #expect(sut.store.enrolledUser() == nil)
        #expect(service.enrolledUserSnapshot == nil, "The enrolled-user snapshot follows the deletion")
        #expect(service.isAuthenticated == false)
    }

    // MARK: - 2. User logout overlapping a server end

    @Test("2a. Logout held inside the teardown, matching server end during it: one teardown, both return after it", .timeLimit(.minutes(1)))
    func logoutThenServerEndTearsDownOnce() async throws {
        let sut = makeSUT(holdFirstTeardown: true)
        let tokenBeforeLogout = try await signIn(sut)
        let service = sut.service

        let logoutTask = Task { () -> Bool in
            await service.logout()
            return service.isAuthenticated
        }
        await sut.clearable.waitUntilEntered()

        // While logout is held, a server end arrives for the token that was current before logout.
        let serverEndTask = Task { () -> Bool in
            await service.handleServerSessionEnd(reason: .accountDisabled, requestToken: tokenBeforeLogout)
            return service.isAuthenticated
        }
        await sut.clearable.release()

        let signedInWhenLogoutReturned = await logoutTask.value
        let signedInWhenServerEndReturned = await serverEndTask.value

        #expect(signedInWhenLogoutReturned == false, "Logout returns after the teardown")
        #expect(signedInWhenServerEndReturned == false, "The server end returns after the teardown")
        #expect(await sut.clearable.clearCallCount == 1, "Overlapping ends must tear down exactly once")
        #expect(await sut.clearable.completedCount == 1)
        #expect(await sut.sessionManager.lastTeardownReason == .userLogout, "Logout started the end")
        #expect(sut.store.deleteCallCount == 0)
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
        #expect(service.currentUser == nil)
        #expect(service.currentAccessToken == nil)
    }

    @Test("2b. Server end held inside the teardown, logout during it: one teardown, both return after it", .timeLimit(.minutes(1)))
    func serverEndThenLogoutTearsDownOnce() async throws {
        let sut = makeSUT(holdFirstTeardown: true)
        let token = try await signIn(sut)
        let service = sut.service

        let serverEndTask = Task { () -> Bool in
            await service.handleServerSessionEnd(reason: .accountDisabled, requestToken: token)
            return service.isAuthenticated
        }
        await sut.clearable.waitUntilEntered()

        let logoutTask = Task { () -> Bool in
            await service.logout()
            return service.isAuthenticated
        }
        await sut.clearable.release()

        let signedInWhenServerEndReturned = await serverEndTask.value
        let signedInWhenLogoutReturned = await logoutTask.value

        #expect(signedInWhenServerEndReturned == false)
        #expect(signedInWhenLogoutReturned == false, "A joining logout returns after the teardown")
        #expect(await sut.clearable.clearCallCount == 1, "Overlapping ends must tear down exactly once")
        #expect(await sut.sessionManager.lastTeardownReason == .sessionExpired, "The server end started the end")
        #expect(sut.store.deleteCallCount == 0)
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
    }

    // MARK: - 3. User logout overlapping a refresh credential failure

    @Test(
        "3. Logout first, refresh credential failure during it: one teardown, enrollment intact",
        .timeLimit(.minutes(1)),
        arguments: SessionEndRefreshPath.allCases
    )
    func logoutThenRefreshFailureTearsDownOnceAndKeepsEnrollment(path: SessionEndRefreshPath) async throws {
        let sut = makeSUT(holdFirstRefresh: true, holdFirstTeardown: true)
        try await signIn(sut)
        let service = sut.service

        // The refresh is in flight before logout starts, so logout starts the end.
        let refreshTask = Task { await runRefresh(path, on: service) }
        await sut.repo.waitUntilRefreshEntered()

        let logoutTask = Task { () -> Bool in
            await service.logout()
            return service.isAuthenticated
        }
        await sut.clearable.waitUntilEntered()

        await sut.repo.releaseRefresh()
        await sut.clearable.release()

        let signedInWhenLogoutReturned = await logoutTask.value
        let refreshResult = await refreshTask.value

        #expect(signedInWhenLogoutReturned == false)
        expectRefreshResult(refreshResult, path: path)
        #expect(await sut.clearable.clearCallCount == 1, "Overlapping ends must tear down exactly once")
        #expect(await sut.sessionManager.lastTeardownReason == .userLogout, "Logout started the end")
        #expect(sut.store.deleteCallCount == 0, "Logout started the end, so the enrollment stays")
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
        #expect(service.enrolledUserSnapshot?.userId == GatedRefreshRepository.userId)
        #expect(service.isAuthenticated == false)
    }

    @Test("3 (direct). An endSession that deletes, arriving during an in-flight logout, joins it and does not delete", .timeLimit(.minutes(1)))
    func joiningEndSessionDoesNotDeleteEnrollment() async throws {
        let sut = makeSUT(holdFirstTeardown: true)
        try await signIn(sut)
        let service = sut.service

        let logoutTask = Task { await service.logout() }
        await sut.clearable.waitUntilEntered()

        let joiningTask = Task { () -> Bool in
            await service.endSession(reason: .sessionExpired, deletingEnrollmentForCurrentUser: true)
            return service.isAuthenticated
        }
        await sut.clearable.release()

        await logoutTask.value
        let signedInWhenJoinerReturned = await joiningTask.value

        #expect(signedInWhenJoinerReturned == false, "The joining caller returns after the teardown")
        #expect(await sut.clearable.clearCallCount == 1)
        #expect(await sut.sessionManager.lastTeardownReason == .userLogout)
        #expect(sut.store.deleteCallCount == 0, "A caller that joins an in-flight end never deletes the enrollment")
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
    }

    // MARK: - 4. The guard resets after a new sign-in

    @Test("4a. Server end, new sign-in, server end again: two teardowns, signed out", arguments: SessionEndSignInPath.allCases)
    func serverEndAfterNewSignInTearsDownAgain(path: SessionEndSignInPath) async throws {
        let sut = makeSUT()
        let firstToken = try await signIn(sut)

        await sut.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: firstToken)
        try #require(sut.service.isAuthenticated == false)
        try #require(await sut.clearable.clearCallCount == 1)

        let secondToken = try await signIn(sut, via: path)
        try #require(secondToken != firstToken, "Precondition: each sign-in issues a new access token")

        await sut.service.handleServerSessionEnd(reason: .userNotFound, requestToken: secondToken)

        #expect(await sut.clearable.clearCallCount == 2, "The guard resets on a new sign-in, so the second end tears down")
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.service.currentUser == nil)
        #expect(sut.service.currentAccessToken == nil)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test("4b. Logout, new sign-in, refresh credential failure: two teardowns, the second deletes the enrollment", arguments: SessionEndRefreshPath.allCases)
    func refreshFailureAfterNewSignInTearsDownAgain(path: SessionEndRefreshPath) async throws {
        let sut = makeSUT()
        try await signIn(sut)

        await sut.service.logout()
        try #require(await sut.clearable.clearCallCount == 1)
        try #require(sut.store.deleteCallCount == 0)

        try await signIn(sut)
        let refreshResult = await runRefresh(path, on: sut.service)

        expectRefreshResult(refreshResult, path: path)
        #expect(await sut.clearable.clearCallCount == 2, "The guard resets on a new sign-in, so the second end tears down")
        #expect(await sut.sessionManager.lastTeardownReason == .sessionExpired)
        #expect(sut.store.deleteCallCount == 1, "The refresh failure started the second end, so it deletes the enrollment")
        #expect(sut.store.enrolledUser() == nil)
        #expect(sut.service.isAuthenticated == false)
    }

    @Test("4c. Logout, new sign-in, logout: two teardowns, signed out")
    func logoutAfterNewSignInTearsDownAgain() async throws {
        let sut = makeSUT()
        try await signIn(sut)
        await sut.service.logout()
        try #require(await sut.clearable.clearCallCount == 1)

        try await signIn(sut)
        await sut.service.logout()

        #expect(await sut.clearable.clearCallCount == 2)
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.store.deleteCallCount == 0)
    }

    // MARK: - Guard semantics: fresh service, completed end

    @Test("A fresh service that was never signed in can still end once; a second end is a no-op")
    func freshServiceEndsOnceThenNoOp() async throws {
        let sut = makeSUT()

        await sut.service.logout(reason: .lockFallback)

        #expect(await sut.clearable.clearCallCount == 1, "A never-signed-in service can still end once")
        #expect(await sut.sessionManager.lastTeardownReason == .lockFallback)

        await sut.service.logout()

        #expect(await sut.clearable.clearCallCount == 1, "After an end completes, further ends are no-ops until a new session")
        #expect(await sut.sessionManager.lastTeardownReason == .lockFallback)
        #expect(sut.service.isAuthenticated == false)
    }

    @Test("After an end completes, a second logout before any new sign-in does not tear down again")
    func secondLogoutWithoutNewSessionIsNoOp() async throws {
        let sut = makeSUT()
        try await signIn(sut)

        await sut.service.logout()
        await sut.service.logout()

        #expect(await sut.clearable.clearCallCount == 1)
        #expect(await sut.sessionManager.lastTeardownReason == .userLogout)
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test("endSession that deletes, as the first end, deletes only the current user's enrollment")
    func firstEndSessionDeletesCurrentUsersEnrollment() async throws {
        let sut = makeSUT()
        try await signIn(sut)

        await sut.service.endSession(reason: .sessionExpired, deletingEnrollmentForCurrentUser: true)

        #expect(await sut.clearable.clearCallCount == 1)
        #expect(sut.store.deleteCallCount == 1)
        #expect(sut.store.enrolledUser() == nil)
        #expect(sut.service.enrolledUserSnapshot == nil, "The enrolled-user snapshot follows the deletion")
        #expect(sut.service.isAuthenticated == false)
    }

    @Test("endSession that deletes keeps another user's enrollment")
    func endSessionKeepsAnotherUsersEnrollment() async throws {
        let sut = makeSUT()
        try sut.store.enroll(refreshToken: "tok-other-FAKE", userId: "other-user", firstName: "Other")
        try await signIn(sut, enroll: false)

        await sut.service.endSession(reason: .sessionExpired, deletingEnrollmentForCurrentUser: true)

        #expect(await sut.clearable.clearCallCount == 1)
        #expect(sut.store.deleteCallCount == 0)
        #expect(sut.store.enrolledUser()?.userId == "other-user")
        #expect(sut.service.isAuthenticated == false)
    }

    // MARK: - 5. A server-initiated end never deletes the Face ID enrollment

    @Test(
        "5. A matching-token server end signs out once and never deletes the enrollment",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func serverEndNeverDeletesEnrollment(reason: SessionEndReason) async throws {
        let sut = makeSUT()
        let token = try await signIn(sut)

        await sut.service.handleServerSessionEnd(reason: reason, requestToken: token)

        #expect(sut.service.isAuthenticated == false)
        #expect(sut.service.currentUser == nil)
        #expect(sut.service.currentAccessToken == nil)
        #expect(await sut.clearable.clearCallCount == 1)
        #expect(await sut.sessionManager.lastTeardownReason == .sessionExpired)
        #expect(sut.store.deleteCallCount == 0, "A server-initiated end never deletes the Face ID enrollment")
        #expect(sut.store.enrolledUser()?.userId == GatedRefreshRepository.userId)
        #expect(sut.service.enrolledUserSnapshot?.userId == GatedRefreshRepository.userId)
    }

    // MARK: - 6. handleServerSessionEnd no-ops

    @Test(
        "6a. A stale token while signed in is ignored: still signed in, no teardown",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func staleTokenIsNoOp(reason: SessionEndReason) async throws {
        let sut = makeSUT()
        let token = try await signIn(sut)
        let staleToken = "tok-stale-FAKE"
        try #require(staleToken != token)

        await sut.service.handleServerSessionEnd(reason: reason, requestToken: staleToken)

        #expect(sut.service.isAuthenticated == true)
        #expect(sut.service.currentAccessToken == token)
        #expect(await sut.clearable.clearCallCount == 0)
        #expect(await sut.sessionManager.lastTeardownReason == nil)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test(
        "6b. A nil token while signed in is ignored: still signed in, no teardown",
        arguments: [SessionEndReason.accountDisabled, .userNotFound]
    )
    func nilTokenIsNoOp(reason: SessionEndReason) async throws {
        let sut = makeSUT()
        let token = try await signIn(sut)

        await sut.service.handleServerSessionEnd(reason: reason, requestToken: nil)

        #expect(sut.service.isAuthenticated == true)
        #expect(sut.service.currentAccessToken == token)
        #expect(await sut.clearable.clearCallCount == 0)
        #expect(await sut.sessionManager.lastTeardownReason == nil)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test("6c. Signed out (never signed in) is a no-op for any token: no teardown")
    func signedOutIsNoOp() async throws {
        let sut = makeSUT()
        try #require(sut.service.isAuthenticated == false)

        await sut.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: "tok-access-1-FAKE")
        await sut.service.handleServerSessionEnd(reason: .userNotFound, requestToken: nil)

        // A never-signed-in service could still end once through endSession, so a teardown
        // here would mean handleServerSessionEnd did not check the signed-in state.
        #expect(await sut.clearable.clearCallCount == 0)
        #expect(await sut.sessionManager.lastTeardownReason == nil)
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test("6d. Signed out after a logout, the previous session's token is a no-op")
    func signedOutAfterLogoutIsNoOp() async throws {
        let sut = makeSUT()
        let token = try await signIn(sut)
        await sut.service.logout()
        try #require(await sut.clearable.clearCallCount == 1)

        await sut.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: token)

        #expect(await sut.clearable.clearCallCount == 1)
        #expect(await sut.sessionManager.lastTeardownReason == .userLogout)
        #expect(sut.service.isAuthenticated == false)
        #expect(sut.store.deleteCallCount == 0)
    }

    @Test("6e. A stale token does not consume the guard: a later matching token ends the session once")
    func staleTokenDoesNotBlockMatchingToken() async throws {
        let sut = makeSUT()
        let token = try await signIn(sut)

        await sut.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: "tok-stale-FAKE")
        try #require(sut.service.isAuthenticated == true)

        await sut.service.handleServerSessionEnd(reason: .accountDisabled, requestToken: token)

        #expect(sut.service.isAuthenticated == false)
        #expect(await sut.clearable.clearCallCount == 1)
        #expect(sut.store.deleteCallCount == 0)
    }
}
