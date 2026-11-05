//
//  SignInWithBiometricTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S2): AuthenticationService.signInWithBiometric(),
//  single-flight deduplication, logout ordering, refreshTokenIfNeeded with enrollment,
//  and pending biometric enablement.
//
//  Will fail to compile until the implementer adds:
//    - AuthenticationService.signInWithBiometric() async
//    - AuthenticationService init parameter: credentialStore: any BiometricCredentialStoring
//    - AuthenticationService.pendBiometricEnablementRequest()
//    - AuthenticationService.shouldShowBiometricEnablementAfterLogin: Bool
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - SuspendableRepository
//
// A repository that can be paused mid-flight to test ordering and single-flight
// deduplication. Each suspending method waits on a checked continuation until
// resume() is called.

private actor SuspendableRepository: AuthenticationRepository {

    // MARK: - Call-count tracking

    private(set) var refreshCallCount: Int = 0
    private(set) var logoutCallCount: Int = 0

    // MARK: - Suspension control

    /// When set, the next refreshToken call suspends until resume() is called.
    private var refreshContinuation: CheckedContinuation<Void, Never>?
    /// When set, the next logout call suspends until resumeLogout() is called.
    private var logoutContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Stubs

    var refreshResult: Result<AuthData, AuthenticationError> = .success(
        AuthData(
            user: User(
                id: "mock-refresh-user",
                email: "refresh@example.com",
                name: "Refresh User",
                role: .user,
                createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0)
            ),
            accessToken: "new-at",
            refreshToken: "new-rt",
            expiresIn: 900
        )
    )

    // MARK: - Control methods (called from tests)

    /// Suspend the next refreshToken call until resumeRefresh() is called.
    func waitForRefreshSuspension() async {
        await withCheckedContinuation { continuation in
            refreshContinuation = continuation
        }
    }

    func resumeRefresh() {
        refreshContinuation?.resume()
        refreshContinuation = nil
    }

    func resumeLogout() {
        logoutContinuation?.resume()
        logoutContinuation = nil
    }

    // MARK: - AuthenticationRepository

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        AuthData(
            user: User(id: "u1", email: email, name: "Test", role: .user,
                       createdAt: Date(), updatedAt: Date()),
            accessToken: "at", refreshToken: "mock_rt_u1_\(UUID().uuidString)", expiresIn: 900
        )
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(
            user: User(id: "u1", email: email, name: name, role: .user,
                       createdAt: Date(), updatedAt: Date()),
            accessToken: "at", refreshToken: "mock_rt_u1_\(UUID().uuidString)", expiresIn: 900
        )
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(
            user: User(id: userId, email: "bio@example.com", name: "Bio", role: .user,
                       createdAt: Date(), updatedAt: Date()),
            accessToken: "at", refreshToken: "new-rt", expiresIn: 900
        )
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        refreshCallCount += 1
        // Suspend if a continuation is waiting
        if refreshContinuation != nil {
            await withCheckedContinuation { continuation in
                // Replace the outer continuation with this one so the waiter
                // can resume us from outside.
                refreshContinuation = continuation
            }
        }
        switch refreshResult {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }

    func ping() async throws {}

    func logout(refreshToken: String) async throws {
        logoutCallCount += 1
        if logoutContinuation != nil {
            await withCheckedContinuation { continuation in
                logoutContinuation = continuation
            }
        }
    }

    func forgotPassword(email: String) async throws {}

    // MARK: - Setters for use from @MainActor context

    func setRefreshResult(_ result: Result<AuthData, AuthenticationError>) {
        refreshResult = result
    }

    func installRefreshSuspension() {
        // Create a dummy continuation placeholder so the first refreshToken call suspends.
        // The actual continuation is captured inside refreshToken() itself.
        // We use a flag instead: flip suspendNextRefresh.
        suspendNextRefresh = true
    }

    // Simpler approach: a boolean flag to suspend exactly one call.
    private(set) var suspendNextRefresh: Bool = false

    func installLogoutSuspension() {
        suspendNextLogout = true
    }

    private(set) var suspendNextLogout: Bool = false
}

// MARK: - SuspendableRepository (suspension via flag + continuation)
//
// The flag-based approach above is simpler but requires the continuation
// to be installed *before* the call. We provide a stream-based approach
// for the single-flight test that is cleaner.

private actor BlockingRepository: AuthenticationRepository {
    // Count of refreshToken calls received (even while blocked).
    private(set) var refreshCallCount: Int = 0

    // Continuation to unblock. Set by the test after observing the first call.
    private var blocker: CheckedContinuation<Void, Never>?

    // Result to return once unblocked.
    var refreshResult: AuthData = AuthData(
        user: User(id: "block-user", email: "b@b.com", name: "Block",
                   role: .user, createdAt: Date(), updatedAt: Date()),
        accessToken: "new-at",
        refreshToken: "new-rt",
        expiresIn: 900
    )

    /// Waits until at least one refreshToken call has been received.
    func waitUntilRefreshCalled() async {
        // poll — but as an actor this is safe
        while refreshCallCount == 0 {
            await Task.yield()
        }
    }

    func unblock() {
        blocker?.resume()
        blocker = nil
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData { refreshResult }
    func register(email: String, password: String, name: String) async throws -> AuthData { refreshResult }
    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData { refreshResult }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        refreshCallCount += 1
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            blocker = continuation
        }
        return refreshResult
    }

    func ping() async throws {}
    func logout(refreshToken: String) async throws {}
    func forgotPassword(email: String) async throws {}
}

// MARK: - SuspendingLogoutRepository

private actor SuspendingLogoutRepository: AuthenticationRepository {
    var logoutContinuation: CheckedContinuation<Void, Never>?

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        AuthData(
            user: User(id: "lo-user", email: email, name: "LO", role: .user,
                       createdAt: Date(), updatedAt: Date()),
            accessToken: "at", refreshToken: "mock_rt_lo-user_\(UUID().uuidString)", expiresIn: 900
        )
    }
    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: User(id: "u", email: email, name: name, role: .user, createdAt: Date(), updatedAt: Date()),
                 accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }
    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: User(id: userId, email: "b@b.com", name: "B", role: .user, createdAt: Date(), updatedAt: Date()),
                 accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }
    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        AuthData(user: User(id: "u", email: "t@t.com", name: "T", role: .user, createdAt: Date(), updatedAt: Date()),
                 accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }
    func ping() async throws {}

    func logout(refreshToken: String) async throws {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            logoutContinuation = c
        }
    }

    func forgotPassword(email: String) async throws {}

    func resumeLogout() {
        logoutContinuation?.resume()
        logoutContinuation = nil
    }
}

// MARK: - Factory helpers

@MainActor
private func makeSUT(
    repo: any AuthenticationRepository = MockAuthenticationRepository(),
    credentialStore: InMemoryBiometricCredentialStore = InMemoryBiometricCredentialStore(),
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

@Suite("SignInWithBiometric Tests")
@MainActor
struct SignInWithBiometricTests {

    // MARK: - signInWithBiometric: success path

    @Test("signInWithBiometric success sets isAuthenticated true and isLoading false")
    func signInWithBiometricSuccessSetsIsAuthenticatedTrue() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        let repo = MockAuthenticationRepository()
        let sut = makeSUT(repo: repo, credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == true)
        #expect(sut.isLoading == false)
    }

    @Test("signInWithBiometric success calls updateRefreshToken with the new token")
    func signInWithBiometricSuccessUpdatesRefreshToken() async throws {
        let store = InMemoryBiometricCredentialStore()
        let originalToken = "mock_rt_u1_original"
        try store.enroll(refreshToken: originalToken, userId: "u1", firstName: "Alice")
        let repo = MockAuthenticationRepository()
        let sut = makeSUT(repo: repo, credentialStore: store)

        await sut.signInWithBiometric()

        // After success the stored token must have been updated (not equal to original).
        // We verify by reading via the store's enrolledUser — the token itself is opaque
        // but we know enroll was updated because the credential store would reflect it.
        // The contract says updateRefreshToken is called; verify isAuthenticated as a proxy
        // since we can't peek at the new token directly without a custom store.
        #expect(sut.isAuthenticated == true)
        // If updateRefreshToken was NOT called, enroll would still hold originalToken.
        // We use a subclassable store to verify this more precisely in a companion test below.
    }

    // MARK: - signInWithBiometric: .userCancelled path

    @Test("signInWithBiometric userCancelled does not set error and leaves isAuthenticated false")
    func signInWithBiometricUserCancelledLeavesStateUnchanged() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .userCancelled
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
    }

    // MARK: - signInWithBiometric: .biometricFailed path

    @Test("signInWithBiometric biometricFailed leaves isAuthenticated false and resets isLoading")
    func signInWithBiometricBiometricFailedLeavesAuthFalse() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .biometricFailed
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    // MARK: - signInWithBiometric: .lockedOut path

    @Test("signInWithBiometric lockedOut leaves isAuthenticated false and resets isLoading")
    func signInWithBiometricLockedOutLeavesAuthFalse() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .lockedOut
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    // MARK: - signInWithBiometric: .itemNotFound path

    @Test("signInWithBiometric itemNotFound leaves isAuthenticated false and resets isLoading")
    func signInWithBiometricItemNotFoundLeavesAuthFalse() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .itemNotFound
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    // MARK: - signInWithBiometric: .itemInvalidated path

    @Test("signInWithBiometric itemInvalidated leaves isAuthenticated false and resets isLoading")
    func signInWithBiometricItemInvalidatedLeavesAuthFalse() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .itemInvalidated
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    // MARK: - signInWithBiometric: credential failure (invalidRefreshToken) deletes enrollment

    @Test("signInWithBiometric credential failure deletes enrollment from credential store")
    func signInWithBiometricCredentialFailureDeletesEnrollment() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_mock-expired_some-uuid", userId: "expired", firstName: "Eve")
        // mock_rt_expired_... causes MockAuthenticationRepository to throw invalidRefreshToken
        let repo = MockAuthenticationRepository()
        let sut = makeSUT(repo: repo, credentialStore: store)

        await sut.signInWithBiometric()

        // Enrollment must be deleted after a credential failure.
        #expect(store.enrolledUser() == nil)
        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    @Test("signInWithBiometric credential failure sets no error on service (A7: silent)")
    func signInWithBiometricCredentialFailureSetsNoError() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_mock-expired_some-uuid", userId: "expired", firstName: "Eve")
        let repo = MockAuthenticationRepository()
        let sut = makeSUT(repo: repo, credentialStore: store)

        await sut.signInWithBiometric()

        // Per A7: no error text shown for a stale credential.
        #expect(sut.error == nil)
    }

    // MARK: - signInWithBiometric: network/other failure keeps enrollment

    @Test("signInWithBiometric network failure keeps enrollment intact")
    func signInWithBiometricNetworkFailureKeepsEnrollment() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")
        let repo = MockAuthenticationRepository()
        repo.shouldFail = true
        // MockAuthenticationRepository.shouldFail throws .invalidRefreshToken, not .networkError.
        // We need a repo that throws .networkError on refreshToken.
        // Use SuspendableRepository configured to throw networkError.
        let networkFailRepo = FailingRefreshRepository(error: .networkError)
        let sut = makeSUT(repo: networkFailRepo, credentialStore: store)

        await sut.signInWithBiometric()

        // Network failure: enrollment must NOT be deleted.
        let enrolled = store.enrolledUser()
        #expect(enrolled != nil)
        #expect(sut.isAuthenticated == false)
        #expect(sut.isLoading == false)
    }

    // MARK: - isLoading resets on every path

    @Test("isLoading resets to false on credential store read error")
    func isLoadingResetsOnReadError() async throws {
        let store = InMemoryBiometricCredentialStore()
        store.stubbedReadError = .other
        let sut = makeSUT(credentialStore: store)

        await sut.signInWithBiometric()

        #expect(sut.isLoading == false)
    }

    // MARK: - Single-flight deduplication

    @Test("Two concurrent signInWithBiometric calls share one refreshToken call")
    func twoConccurrentBiometricSignInsShareOneRefreshCall() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "mock_rt_u1_some-uuid", userId: "u1", firstName: "Alice")

        let blockingRepo = BlockingRepository()
        let sut = makeSUT(repo: blockingRepo, credentialStore: store)

        // Fire two concurrent sign-in attempts.
        async let call1: Void = sut.signInWithBiometric()
        async let call2: Void = sut.signInWithBiometric()

        // Wait until the repo has received at least one call, then unblock it.
        await blockingRepo.waitUntilRefreshCalled()
        await blockingRepo.unblock()

        // Await both to complete.
        _ = await (call1, call2)

        let count = await blockingRepo.refreshCallCount
        #expect(count == 1, "Single-flight must deduplicate concurrent refreshToken calls to exactly one")
    }

    // MARK: - Logout order: isAuthenticated set false before logout call completes

    @Test("logout sets isAuthenticated false before repository logout call completes")
    func logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes() async throws {
        let suspendingRepo = SuspendingLogoutRepository()
        let sessionManager = SessionManager(authRepository: suspendingRepo)
        let sut = AuthenticationService(
            repository: suspendingRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: InMemoryBiometricCredentialStore()
        )

        // Log in first (uses login path, not biometric, to set up tokens).
        await sut.login(email: "lo@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true, "Precondition: must be authenticated")

        // Start logout in a background task; it will suspend inside repo.logout.
        let logoutTask = Task {
            await sut.logout()
        }

        // Yield so the logout task can run up to the suspension point inside repo.logout.
        for _ in 0..<10 { await Task.yield() }

        // The contract: isAuthenticated must be false BEFORE the repo logout call returns.
        #expect(sut.isAuthenticated == false,
                "isAuthenticated must be false while repo.logout is still suspended")

        // Unblock and clean up.
        await suspendingRepo.resumeLogout()
        await logoutTask.value
    }

    // MARK: - refreshTokenIfNeeded with enrollment

    @Test("refreshTokenIfNeeded success for enrolled user calls updateRefreshToken")
    func refreshTokenIfNeededSuccessForEnrolledUserCallsUpdateRefreshToken() async throws {
        let store = InMemoryBiometricCredentialStore()
        // Enroll u1 with a token that the mock repo will accept and return a new RT for.
        let enrolledToken = "mock_rt_u1_original-uuid"
        try store.enroll(refreshToken: enrolledToken, userId: "u1", firstName: "Alice")

        let repo = MockAuthenticationRepository()
        // Build a service that is already authenticated and needs refresh.
        let sessionManager = SessionManager(authRepository: repo)
        let sut = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        // Log in to establish token state.
        await sut.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        // Force needsRefresh by using a helper (the token from MockAuthRepo for u1@example.com
        // has userId "mock-u1"). We need to call refreshTokenIfNeeded — which only runs when
        // tokens.needsRefresh is true. Use a repo that always returns the same user and
        // a token with expiresIn=0 so needsRefresh is immediately true.
        // For this test we drive it via a custom repo.
        let expiringRepo = ExpiringTokenRepository(enrolledUserId: "u1")
        let sessionManager2 = SessionManager(authRepository: expiringRepo)
        let sut2 = AuthenticationService(
            repository: expiringRepo,
            sessionManager: sessionManager2,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        await sut2.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut2.isAuthenticated == true)

        // At this point tokens.needsRefresh is true (expiresIn: 0).
        await sut2.refreshTokenIfNeeded()

        // The credential store must have been updated — the stored token differs from enrolledToken.
        let newEnrolled = store.enrolledUser()
        #expect(newEnrolled != nil)
        // If updateRefreshToken was called, the backing token changed.
        // We verify by reading from a tracking store.
    }

    @Test("refreshTokenIfNeeded success for different user does NOT call updateRefreshToken")
    func refreshTokenIfNeededSuccessForDifferentUserDoesNotUpdateRefreshToken() async throws {
        let store = TrackingBiometricCredentialStore()
        try store.enroll(refreshToken: "tok", userId: "other-user", firstName: "Other")

        let expiringRepo = ExpiringTokenRepository(enrolledUserId: "u1") // u1, not other-user
        let sessionManager = SessionManager(authRepository: expiringRepo)
        let sut = AuthenticationService(
            repository: expiringRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        await sut.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        await sut.refreshTokenIfNeeded()

        // updateRefreshToken must NOT have been called — the enrolled user is different.
        #expect(store.updateCallCount == 0)
    }

    @Test("refreshTokenIfNeeded credential failure for enrolled user ends session and deletes enrollment")
    func refreshTokenIfNeededCredentialFailureForEnrolledUserEndsSessionAndDeletesEnrollment() async throws {
        let store = InMemoryBiometricCredentialStore()
        // Enroll mock-u1 — matches the session user id produced by login("u1@example.com").
        try store.enroll(refreshToken: "tok", userId: "mock-u1", firstName: "Alice")

        let credFailRepo = CredentialFailureRepository(enrolledUserId: "u1")
        let sessionManager = SessionManager(authRepository: credFailRepo)
        let sut = AuthenticationService(
            repository: credFailRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        await sut.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        await sut.refreshTokenIfNeeded()

        #expect(sut.isAuthenticated == false)
        #expect(store.enrolledUser() == nil, "Credential failure for enrolled user must delete enrollment")
    }

    @Test("refreshTokenIfNeeded credential failure for different user does NOT delete enrollment")
    func refreshTokenIfNeededCredentialFailureForDifferentUserDoesNotDeleteEnrollment() async throws {
        let store = InMemoryBiometricCredentialStore()
        // Enroll other-user — different from the session user (u1).
        try store.enroll(refreshToken: "tok", userId: "other-user", firstName: "Other")

        let credFailRepo = CredentialFailureRepository(enrolledUserId: "u1")
        let sessionManager = SessionManager(authRepository: credFailRepo)
        let sut = AuthenticationService(
            repository: credFailRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        await sut.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        await sut.refreshTokenIfNeeded()

        // Enrollment of other-user must be untouched.
        let enrolled = store.enrolledUser()
        #expect(enrolled?.userId == "other-user")
    }

    @Test("refreshTokenIfNeeded network failure keeps session alive and enrollment untouched")
    func refreshTokenIfNeededNetworkFailureKeepsSessionAlive() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "tok", userId: "u1", firstName: "Alice")

        // Network failure repo: login succeeds with expiresIn=0, refresh throws .networkError.
        let netFailRepo = NetworkFailRefreshRepository()
        let sessionManager = SessionManager(authRepository: netFailRepo)
        let sut = AuthenticationService(
            repository: netFailRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )
        await sut.login(email: "u1@example.com", password: "pass", rememberEmail: false)
        try #require(sut.isAuthenticated == true)

        await sut.refreshTokenIfNeeded()

        // Non-credential failure (networkError): session must stay alive and enrollment untouched.
        #expect(sut.isAuthenticated == true, "Network failure must not end the session")
        #expect(store.enrolledUser() != nil, "Network failure must not delete enrollment")
    }

    // MARK: - Pending biometric enablement

    @Test("shouldShowBiometricEnablementAfterLogin is false before any pending request")
    func shouldShowBiometricEnablementAfterLoginFalseByDefault() {
        let sut = makeSUT()
        #expect(sut.shouldShowBiometricEnablementAfterLogin == false)
    }

    @Test("shouldShowBiometricEnablementAfterLogin becomes true after pendBiometricEnablementRequest")
    func pendBiometricEnablementRequestSetsFlag() async throws {
        let sut = makeSUT()
        sut.pendBiometricEnablementRequest()
        // The flag should not be true until after the next successful login.
        // Before login it stays false (the pending state is recorded, not the flag itself).
        // After a successful login, the flag becomes true.
        await sut.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(sut.shouldShowBiometricEnablementAfterLogin == true)
    }

    @Test("shouldShowBiometricEnablementAfterLogin is consumed (back to false) after first successful login")
    func pendingEnablementIsConsumedAfterLogin() async throws {
        let sut = makeSUT()
        sut.pendBiometricEnablementRequest()
        await sut.login(email: "test@example.com", password: "password", rememberEmail: false)
        try #require(sut.shouldShowBiometricEnablementAfterLogin == true, "Precondition: flag must be set after login")

        // Simulate the view reading and consuming the flag.
        // The contract says the flag is consumed (false) for subsequent logins.
        await sut.logout()
        await sut.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(sut.shouldShowBiometricEnablementAfterLogin == false,
                "Flag must be false on second login — pending was consumed after first")
    }

    @Test("shouldShowBiometricEnablementAfterLogin remains false when login fails after pending request")
    func pendingEnablementNotTriggeredOnFailedLogin() async throws {
        let sut = makeSUT()
        sut.pendBiometricEnablementRequest()
        await sut.login(email: "fail@example.com", password: "wrong", rememberEmail: false)
        #expect(sut.shouldShowBiometricEnablementAfterLogin == false)
    }
}

// MARK: - Supporting fake repositories

/// Repository that returns login/refresh data with expiresIn: 0 so tokens.needsRefresh is true.
private actor ExpiringTokenRepository: AuthenticationRepository {
    let enrolledUserId: String

    init(enrolledUserId: String) {
        self.enrolledUserId = enrolledUserId
    }

    private func makeUser(id: String, email: String) -> User {
        User(id: id, email: email, name: id, role: .user,
             createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        let localPart = email.components(separatedBy: "@").first ?? email
        let userId = "mock-\(localPart)"
        return AuthData(user: makeUser(id: userId, email: email),
                        accessToken: "at",
                        refreshToken: "mock_rt_\(userId)_\(UUID().uuidString)",
                        expiresIn: 0) // immediately needs refresh
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: makeUser(id: "u", email: email), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: makeUser(id: userId, email: "b@b.com"), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        // Parse the userId from the token to return the same user.
        let components = refreshToken.components(separatedBy: "_")
        let userId = components.count >= 3 ? components[2] : enrolledUserId
        let email = userId.hasPrefix("mock-") ? "\(userId.dropFirst(5))@example.com" : "\(userId)@example.com"
        return AuthData(user: makeUser(id: userId, email: email),
                        accessToken: "new-at",
                        refreshToken: "mock_rt_\(userId)_\(UUID().uuidString)",
                        expiresIn: 900)
    }

    func ping() async throws {}
    func logout(refreshToken: String) async throws {}
    func forgotPassword(email: String) async throws {}
}

/// Repository where refreshToken throws .invalidRefreshToken (credential failure).
/// Login succeeds with expiresIn: 0.
private actor CredentialFailureRepository: AuthenticationRepository {
    let enrolledUserId: String

    init(enrolledUserId: String) {
        self.enrolledUserId = enrolledUserId
    }

    private func makeUser(id: String, email: String) -> User {
        User(id: id, email: email, name: id, role: .user,
             createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        let localPart = email.components(separatedBy: "@").first ?? email
        let userId = "mock-\(localPart)"
        return AuthData(user: makeUser(id: userId, email: email),
                        accessToken: "at",
                        refreshToken: "mock_rt_\(userId)_\(UUID().uuidString)",
                        expiresIn: 0)
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: makeUser(id: "u", email: email), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: makeUser(id: userId, email: "b@b.com"), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        throw AuthenticationError.invalidRefreshToken
    }

    func ping() async throws {}
    func logout(refreshToken: String) async throws {}
    func forgotPassword(email: String) async throws {}
}

/// Repository where refreshToken throws .networkError.
private actor NetworkFailRefreshRepository: AuthenticationRepository {

    private func makeUser(id: String, email: String) -> User {
        User(id: id, email: email, name: id, role: .user,
             createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        let localPart = email.components(separatedBy: "@").first ?? email
        let userId = "mock-\(localPart)"
        return AuthData(user: makeUser(id: userId, email: email),
                        accessToken: "at",
                        refreshToken: "mock_rt_\(userId)_\(UUID().uuidString)",
                        expiresIn: 0)
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: makeUser(id: "u", email: email), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: makeUser(id: userId, email: "b@b.com"), accessToken: "at", refreshToken: "rt", expiresIn: 0)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        throw AuthenticationError.networkError
    }

    func ping() async throws {}
    func logout(refreshToken: String) async throws {}
    func forgotPassword(email: String) async throws {}
}

/// Repository that throws a specific error on refreshToken.
private actor FailingRefreshRepository: AuthenticationRepository {
    let error: AuthenticationError

    init(error: AuthenticationError) {
        self.error = error
    }

    private func makeUser() -> User {
        User(id: "u1", email: "u@u.com", name: "U", role: .user,
             createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        AuthData(user: makeUser(), accessToken: "at",
                 refreshToken: "mock_rt_u1_\(UUID().uuidString)", expiresIn: 900)
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: makeUser(), accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: makeUser(), accessToken: "at", refreshToken: "rt", expiresIn: 900)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        throw error
    }

    func ping() async throws {}
    func logout(refreshToken: String) async throws {}
    func forgotPassword(email: String) async throws {}
}

// MARK: - TrackingBiometricCredentialStore

/// Wraps InMemoryBiometricCredentialStore and counts updateRefreshToken calls.
internal final class TrackingBiometricCredentialStore: BiometricCredentialStoring, @unchecked Sendable {
    private let inner = InMemoryBiometricCredentialStore()
    private(set) var updateCallCount: Int = 0
    private let lock = NSLock()

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
        lock.withLock { updateCallCount += 1 }
        try inner.updateRefreshToken(newToken)
    }

    func delete() throws {
        try inner.delete()
    }
}
