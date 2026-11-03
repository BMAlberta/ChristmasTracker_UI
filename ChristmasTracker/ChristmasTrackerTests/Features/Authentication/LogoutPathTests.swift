//
//  LogoutPathTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R1: route every session-ending path through teardown with a reason,
//  remove notification observers from AuthenticationService, and expose
//  SessionManager.lastTeardownReason for verification.
//
//  Expected state BEFORE R1 implementation:
//  - Tests 1–4: compile errors on `sessionManager.lastTeardownReason` (property does not
//    exist yet on SessionManager). The compile error IS the red state for those tests.
//    Tests 1–2 also verify behavioral assertions that will fail at runtime once the property
//    is added but the reason-routing logic is not yet complete.
//  - Test 5: compiles and passes today — regression guard.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Private mock repository

/// Fast, configurable repository for logout and refresh failure scenarios.
/// `loginExpiresIn` controls the `expiresIn` value returned by `login`, allowing
/// tests to produce tokens that satisfy `AuthTokens.needsRefresh` immediately (pass 0).
private actor ThrowingLogoutRepository: AuthenticationRepository {
    var shouldFailLogout = false
    var shouldFailRefresh = false
    var loginExpiresIn: Int = 900

    private let mockUser = User(
        id: "mock-user-123",
        email: "test@example.com",
        name: "Test User",
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        AuthData(user: mockUser, accessToken: "access", refreshToken: "refresh", expiresIn: loginExpiresIn)
    }

    func register(email: String, password: String, name: String) async throws -> AuthData {
        AuthData(user: mockUser, accessToken: "access", refreshToken: "refresh", expiresIn: 900)
    }

    func biometricLogin(userId: String, biometricToken: String) async throws -> AuthData {
        AuthData(user: mockUser, accessToken: "access", refreshToken: "refresh", expiresIn: 900)
    }

    func refreshToken(_ refreshToken: String) async throws -> AuthData {
        if shouldFailRefresh {
            throw AuthenticationError.invalidRefreshToken
        }
        return AuthData(user: mockUser, accessToken: "access", refreshToken: "refresh", expiresIn: 900)
    }

    func logout(refreshToken: String) async throws {
        if shouldFailLogout {
            throw AuthenticationError.networkError
        }
    }

    func ping() async throws {}

    func forgotPassword(email: String) async throws {}

    func setFailLogout(_ value: Bool) { shouldFailLogout = value }
    func setFailRefresh(_ value: Bool) { shouldFailRefresh = value }
    func setLoginExpiresIn(_ value: Int) { loginExpiresIn = value }
}

// MARK: - Suite

@Suite("Logout Path Tests")
@MainActor
struct LogoutPathTests {

    // MARK: - Helpers

    private func makeSampleList() -> GiftList {
        let person = ListPerson(id: "u1", displayName: "Alice")
        return GiftList(
            id: "list-1",
            name: "Test List",
            theme: "christmas",
            year: 2026,
            visibility: .private,
            status: .active,
            recipient: person,
            owner: person,
            coOwner: nil,
            myRole: .owner,
            itemCount: 1,
            purchasedCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Test 1

    /// `logout()` (no argument) must route through teardown with `.userLogout`, clearing
    /// any registered `ListDataStore` and recording the teardown reason.
    ///
    /// FAILS before R1:
    ///   - Compile error: `SessionManager` has no `lastTeardownReason` property.
    ///   - After property is added but reason-routing is missing, the `lastTeardownReason`
    ///     assertion fails because the default call path does not set the reason.
    @Test("logout() clears a registered ListDataStore and records .userLogout reason")
    func profileLogoutPathSendsTeardownWithUserLogoutReason() async throws {
        let repo = ThrowingLogoutRepository()
        let sessionManager = SessionManager(authRepository: repo)
        let listDataStore = ListDataStore()
        let authService = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager
        )

        await sessionManager.register(listDataStore)

        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated before logout")

        await listDataStore.setLists([makeSampleList()])
        let before = await listDataStore.getLists()
        #expect(!before.isEmpty, "Precondition: ListDataStore must have data before logout")

        await authService.logout()

        let after = await listDataStore.getLists()
        #expect(after.isEmpty, "ListDataStore must be empty after authService.logout()")

        // Requires R1: lastTeardownReason does not exist on SessionManager yet.
        let reason = await sessionManager.lastTeardownReason
        #expect(reason == .userLogout, "teardown reason must be .userLogout for a direct logout() call")
    }

    // MARK: - Test 2

    /// When `refreshTokenIfNeeded()` fails, the resulting logout must call
    /// `teardown(reason: .sessionExpired)`, clearing registered stores and recording the reason.
    ///
    /// FAILS before R1:
    ///   - Compile error: `SessionManager` has no `lastTeardownReason` property.
    ///   - After property is added, `refreshTokenIfNeeded()` still calls `logout()` (no reason
    ///     param), so `lastTeardownReason` is `.userLogout`, not `.sessionExpired`.
    @Test("refreshTokenIfNeeded() failure calls logout with .sessionExpired reason")
    func refreshFailureCallsLogoutWithSessionExpiredReason() async throws {
        let repo = ThrowingLogoutRepository()
        // expiresIn: 0 → expiresAt = Date() → needsRefresh is immediately true
        // (Date().addingTimeInterval(5*60) >= Date() is always true)
        await repo.setLoginExpiresIn(0)

        let sessionManager = SessionManager(authRepository: repo)
        let listDataStore = ListDataStore()
        let authService = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager
        )

        await sessionManager.register(listDataStore)

        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        await listDataStore.setLists([makeSampleList()])
        let before = await listDataStore.getLists()
        #expect(!before.isEmpty, "Precondition: ListDataStore must have data before refresh failure")

        await repo.setFailRefresh(true)
        await authService.refreshTokenIfNeeded()

        #expect(authService.isAuthenticated == false, "isAuthenticated must be false after refresh failure")

        let after = await listDataStore.getLists()
        #expect(after.isEmpty, "ListDataStore must be empty after refresh-failure logout")

        // Requires R1: property does not exist yet and reason will be wrong until logic is changed.
        let reason = await sessionManager.lastTeardownReason
        #expect(reason == .sessionExpired, "teardown reason must be .sessionExpired when refresh fails")
    }

    // MARK: - Test 3

    /// Calling `teardown(reason: .sessionExpired)` directly on `SessionManager` must invoke
    /// all registered clearables and record `.sessionExpired` as the teardown reason.
    ///
    /// FAILS before R1:
    ///   - Compile error: `SessionManager` has no `lastTeardownReason` property.
    @Test("teardown(.sessionExpired) clears registered clearable and records reason")
    func sessionExpiredTeardownClearsRegisteredClearable() async throws {
        let repo = ThrowingLogoutRepository()
        let sessionManager = SessionManager(authRepository: repo)
        let mockClearable = MockSessionClearable()

        await sessionManager.register(mockClearable)
        await sessionManager.teardown(reason: .sessionExpired)

        #expect(mockClearable.wasClearCalled, "clearForSession() must be invoked by teardown")
        #expect(mockClearable.clearCallCount == 1, "clearForSession() must be called exactly once")

        // Requires R1: lastTeardownReason does not exist on SessionManager yet.
        let reason = await sessionManager.lastTeardownReason
        #expect(reason == .sessionExpired, "lastTeardownReason must be .sessionExpired")
    }

    // MARK: - Test 4

    /// Calling `teardown(reason: .forcedUpdate)` directly on `SessionManager` must invoke
    /// all registered clearables and record `.forcedUpdate` as the teardown reason.
    ///
    /// FAILS before R1:
    ///   - Compile error: `SessionManager` has no `lastTeardownReason` property.
    @Test("teardown(.forcedUpdate) clears registered clearable and records reason")
    func forcedUpdateTeardownClearsRegisteredClearable() async throws {
        let repo = ThrowingLogoutRepository()
        let sessionManager = SessionManager(authRepository: repo)
        let mockClearable = MockSessionClearable()

        await sessionManager.register(mockClearable)
        await sessionManager.teardown(reason: .forcedUpdate)

        #expect(mockClearable.wasClearCalled, "clearForSession() must be invoked by teardown")
        #expect(mockClearable.clearCallCount == 1, "clearForSession() must be called exactly once")

        // Requires R1: lastTeardownReason does not exist on SessionManager yet.
        let reason = await sessionManager.lastTeardownReason
        #expect(reason == .forcedUpdate, "lastTeardownReason must be .forcedUpdate")
    }

    // MARK: - Test 5 (regression guard)

    /// When the network logout call throws, `isAuthenticated` must still become `false`
    /// and `currentUser` must be nil.
    ///
    /// This test passes today and acts as a regression guard to ensure R1 does not
    /// accidentally break the error-tolerant sign-out path.
    @Test("Network logout failure does not prevent sign-out (regression guard)")
    func networkLogoutFailureDoesNotPreventSignOut() async throws {
        let repo = ThrowingLogoutRepository()
        await repo.setFailLogout(true)

        let sessionManager = SessionManager(authRepository: repo)
        let authService = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager
        )

        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        await authService.logout()

        #expect(
            authService.isAuthenticated == false,
            "isAuthenticated must be false even when the network logout call throws"
        )
        #expect(authService.currentUser == nil, "currentUser must be nil after logout")
    }
}
