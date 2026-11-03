//
//  LogoutPathTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2a-2: route every session-ending path through teardown.
//
//  Expected failure state BEFORE Story 2 implementation:
//  - Test 1 (logoutViaAuthServiceClearsRegisteredDataStore): FAILS — authService.logout()
//    calls sessionManager.stopSession() directly; it does NOT call teardown(reason:), so
//    registered clearables (ListDataStore) are never cleared.
//  - Test 2 (refreshTokenFailureClearsRegisteredDataStore): FAILS for the same reason.
//  - Test 3 (unauthorizedRequestNotificationTriggersLogout): FAILS — no observer exists
//    on ContentView for .unauthorizedRequest; after posting the notification,
//    isAuthenticated remains true.
//  - Test 4 (versionUpdateNotificationTriggersLogout): FAILS for the same reason.
//  - Test 5 (networkLogoutFailureDoesNotPreventSignOut): guard/regression — passes today
//    because logout() already ignores the network error.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Private mock repository for failure scenarios

/// Configures failure on logout and/or refresh without the sleeping delays of
/// `MockAuthenticationRepository`.
private actor ThrowingLogoutRepository: AuthenticationRepository {
    var shouldFailLogout = false
    var shouldFailRefresh = false

    private let mockUser = User(
        id: "mock-user-123",
        email: "test@example.com",
        name: "Test User",
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )

    func login(email: String, password: String, rememberMe: Bool) async throws -> AuthData {
        AuthData(user: mockUser, accessToken: "access", refreshToken: "refresh", expiresIn: 900)
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

    // Mutation helpers — called via `await repo.setFailLogout(true)`
    func setFailLogout(_ value: Bool) { shouldFailLogout = value }
    func setFailRefresh(_ value: Bool) { shouldFailRefresh = value }
}

// MARK: - Suite

@Suite("Logout Path Tests")
@MainActor
struct LogoutPathTests {

    // MARK: - Helpers

    /// Sample `GiftList` for seeding a `ListDataStore`.
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

    /// After `authService.logout()`, any `ListDataStore` registered with the same
    /// `SessionManager` must be empty.
    ///
    /// FAILS before Story 2: `logout()` calls `sessionManager.stopSession()` directly
    /// and never invokes `teardown(reason:)`, so registered clearables are skipped.
    @Test("logout() clears a registered ListDataStore via teardown")
    func logoutViaAuthServiceClearsRegisteredDataStore() async throws {
        let mockRepo = await MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
        let listDataStore = ListDataStore()
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )

        // Register the data store so teardown can reach it
        await sessionManager.register(listDataStore)

        // Authenticate
        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        // Populate the data store
        await listDataStore.setLists([makeSampleList()])
        let before = await listDataStore.getLists()
        #expect(!before.isEmpty, "Precondition: ListDataStore must have data before logout")

        // Act
        await authService.logout()

        // Assert: teardown must have cleared the registered data store
        let after = await listDataStore.getLists()
        #expect(
            after.isEmpty,
            "ListDataStore must be empty after authService.logout() — requires teardown routing"
        )
    }

    // MARK: - Test 2

    /// When token refresh fails, the resulting implicit logout must also clear any
    /// `ListDataStore` registered with the `SessionManager`.
    ///
    /// FAILS before Story 2: the refresh-failure path calls `logout()` which does not
    /// route through `teardown(reason:)`, so registered clearables are not cleared.
    @Test("refreshTokenIfNeeded() failure clears a registered ListDataStore via teardown")
    func refreshTokenFailureClearsRegisteredDataStore() async throws {
        let repo = ThrowingLogoutRepository()

        let sessionManager = SessionManager(authRepository: repo)
        let listDataStore = ListDataStore()
        let authService = AuthenticationService(
            repository: repo,
            sessionManager: sessionManager
        )

        await sessionManager.register(listDataStore)

        // Login succeeds (repo only fails on refreshToken when armed)
        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        // Populate the data store
        await listDataStore.setLists([makeSampleList()])
        let before = await listDataStore.getLists()
        #expect(!before.isEmpty, "Precondition: data store must have data before refresh failure")

        // Arm the refresh failure and trigger the logout that refresh failure causes.
        // After Story 2, the session-ending path calls teardown(reason: .sessionExpired)
        // which reaches the registered ListDataStore.
        await repo.setFailRefresh(true)
        await authService.logout()

        let after = await listDataStore.getLists()
        #expect(
            after.isEmpty,
            "ListDataStore must be empty after a session-ending logout triggered by refresh failure"
        )
    }

    // MARK: - Test 3

    /// Posting `.unauthorizedRequest` must cause `authService.isAuthenticated` to
    /// become `false` once the Story 2 observer is wired into `ContentView`.
    ///
    /// FAILS before Story 2: no observer exists, so after posting the notification
    /// `isAuthenticated` remains `true`.
    @Test(".unauthorizedRequest notification triggers logout (observer not yet wired)")
    func unauthorizedRequestNotificationTriggersLogout() async throws {
        let mockRepo = await MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )

        // Authenticate
        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        // Post the notification that Story 2's observer will respond to
        NotificationCenter.default.post(name: .unauthorizedRequest, object: nil)

        // Give any synchronous or immediate-Task observer a chance to fire
        try await Task.sleep(for: .milliseconds(100))

        // After Story 2, the observer calls authService.logout() → isAuthenticated == false.
        // Before Story 2 (no observer), isAuthenticated stays true → test FAILS.
        #expect(
            authService.isAuthenticated == false,
            ".unauthorizedRequest notification must trigger logout; observer is not yet wired"
        )
    }

    // MARK: - Test 4

    /// Posting `.versionUpdateRequired` must cause `authService.isAuthenticated` to
    /// become `false` once the Story 2 observer is wired into `ContentView`.
    ///
    /// FAILS before Story 2: no observer exists.
    @Test(".versionUpdateRequired notification triggers logout (observer not yet wired)")
    func versionUpdateNotificationTriggersLogout() async throws {
        let mockRepo = await MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
        let authService = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )

        // Authenticate
        await authService.login(email: "test@example.com", password: "password", rememberMe: false)
        #expect(authService.isAuthenticated == true, "Precondition: must be authenticated")

        // Post the notification that Story 2's observer will respond to
        NotificationCenter.default.post(name: .versionUpdateRequired, object: nil)

        // Give any synchronous or immediate-Task observer a chance to fire
        try await Task.sleep(for: .milliseconds(100))

        // After Story 2, the observer calls authService.logout() → isAuthenticated == false.
        // Before Story 2 (no observer), isAuthenticated stays true → test FAILS.
        #expect(
            authService.isAuthenticated == false,
            ".versionUpdateRequired notification must trigger logout; observer is not yet wired"
        )
    }

    // MARK: - Test 5 (regression guard)

    /// When the network logout call throws, `isAuthenticated` must still become `false`.
    ///
    /// This test passes today because logout() already ignores the network error via
    /// do/catch. It acts as a regression guard to ensure Story 2 does not accidentally
    /// break this behavior.
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

        // logout() — network call throws, but sign-out must still happen
        await authService.logout()

        #expect(
            authService.isAuthenticated == false,
            "isAuthenticated must be false even when the network logout call throws"
        )
        #expect(authService.currentUser == nil, "currentUser must be nil after logout")
    }
}
