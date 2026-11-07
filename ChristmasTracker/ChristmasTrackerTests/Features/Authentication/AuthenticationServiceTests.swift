//
//  AuthenticationServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/12/26.
//

import Foundation
import Testing
@testable import ChristmasTracker

// MARK: - R9 test helper: FakeLegacyTokenCleanup

/// Counts how many times cleanUpLegacyTokens() is called.
/// Lives in the test target only — never used in Previews or production.
internal final class FakeLegacyTokenCleanup: LegacyTokenCleaning {
    private(set) var cleanUpCallCount: Int = 0
    func cleanUpLegacyTokens() { cleanUpCallCount += 1 }
}

// MARK: - R9 test helper: MockAuthenticationRepository actor-setter extension

extension MockAuthenticationRepository {
    /// Actor-bridging helper so @MainActor tests can mutate shouldFail without
    /// a bare `await` on the actor isolation boundary.
    func setFail(_ value: Bool) { shouldFail = value }
}

// MARK: - I2b-2c U3 test helper: login always fails with 403 ACCOUNT_DISABLED

private actor AccountDisabledLoginRepository: AuthenticationRepository {
    func login(email: String, password: String) async throws -> AuthSession {
        throw AuthenticationError.accountDisabled
    }

    func register(email: String, password: String, firstName: String, lastName: String, registrationCode: String) async throws -> AuthSession {
        throw AuthenticationError.accountDisabled
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        throw AuthenticationError.accountDisabled
    }

    func logout() async throws {}
}

@Suite("AuthenticationService Tests")
@MainActor
struct AuthenticationServiceTests {
    @Test("Login with valid credentials succeeds")
    func testLoginSuccess() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        await service.login(
            email: "test@example.com",
            password: "password",
            rememberEmail: false
        )
        #expect(service.isAuthenticated == true)
        #expect(service.currentUser != nil)
        #expect(service.currentUser?.email == "test@example.com")
        #expect(service.error == nil)
    }
    @Test("Login with invalid credentials fails")
    func testLoginFailure() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        await service.login(
            email: "fail@example.com",
            password: "wrong",
            rememberEmail: false
        )
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.error != nil)
    }
    @Test("Register with valid data succeeds")
    func testRegisterSuccess() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        await service.register(
            email: "new@example.com",
            password: "password123",
            firstName: "New",
            lastName: "User",
            registrationCode: "CODE-FAKE"
        )
        #expect(service.isAuthenticated == true)
        #expect(service.currentUser?.name == "New User")
        #expect(service.error == nil)
    }
    @Test("Logout clears authentication state")
    func testLogout() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        // Login first
        await service.login(
            email: "test@example.com",
            password: "password",
            rememberEmail: false
        )
        #expect(service.isAuthenticated == true)
        // Logout
        await service.logout()
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
    }

    // MARK: - R5: refreshBiometricAvailability() via injected BiometricAuthenticating

    @Test("Injected authenticator with isAvailable=false sets isBiometricAvailable false")
    func injectedAuthenticatorWithIsAvailableFalseSetsIsBiometricAvailableFalse() {
        let fakeAuth = FakeBiometricAuthenticator()
        fakeAuth.stubbedIsAvailable = false
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: fakeAuth
        )
        service.refreshBiometricAvailability()
        #expect(service.isBiometricAvailable == false)
    }

    @Test("Injected authenticator with .touchID sets biometricType to .touchID")
    func injectedAuthenticatorWithTouchIDSetsBiometricTypeTouchID() {
        let fakeAuth = FakeBiometricAuthenticator()
        fakeAuth.stubbedBiometryType = .touchID
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: fakeAuth
        )
        service.refreshBiometricAvailability()
        #expect(service.biometricType == .touchID)
    }

    @Test("Injected authenticator with .faceID sets biometricType to .faceID")
    func injectedAuthenticatorWithFaceIDSetsBiometricTypeFaceID() {
        let fakeAuth = FakeBiometricAuthenticator()
        fakeAuth.stubbedBiometryType = .faceID
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: fakeAuth
        )
        service.refreshBiometricAvailability()
        #expect(service.biometricType == .faceID)
    }

    @Test("handleAuthSuccess refreshes biometric availability from injected authenticator")
    func handleAuthSuccessRefreshesBiometricAvailability() async {
        let fakeAuth = FakeBiometricAuthenticator()
        fakeAuth.stubbedIsAvailable = false
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: fakeAuth
        )
        #expect(service.isBiometricAvailable == false)
        fakeAuth.stubbedIsAvailable = true
        await service.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(service.isBiometricAvailable == true)
    }

    // MARK: - R7: isLoading reset, clearError, rememberEmail param rename

    private func makeSUT() -> (service: AuthenticationService, mockRepo: MockAuthenticationRepository) {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator()
        )
        return (service, mockRepo)
    }

    @Test("isLoading is false after login() returns on failure")
    func loginResetsIsLoadingOnFailure() async {
        let (service, _) = makeSUT()
        await service.login(email: "fail@example.com", password: "wrong", rememberEmail: false)
        #expect(service.isLoading == false)
    }

    @Test("isLoading is false after login() returns on success")
    func loginResetsIsLoadingOnSuccess() async {
        let (service, _) = makeSUT()
        await service.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(service.isLoading == false)
    }

    @Test("clearError sets service.error to nil")
    func clearErrorClearsServiceError() async {
        let (service, _) = makeSUT()
        await service.login(email: "fail@example.com", password: "wrong", rememberEmail: false)
        #expect(service.error != nil)
        service.clearError()
        #expect(service.error == nil)
    }

    // MARK: - R9: emailStore and legacyCleanup injection

    private func makeSUTWithEmailStore() -> (
        service: AuthenticationService,
        mockRepo: MockAuthenticationRepository,
        emailStore: RememberedEmailStore,
        cleanup: FakeLegacyTokenCleanup
    ) {
        let suiteName = "com.christmastracker.tests.r9.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let emailStore = RememberedEmailStore(defaults: defaults)
        let cleanup = FakeLegacyTokenCleanup()
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            emailStore: emailStore,
            legacyCleanup: cleanup
        )
        return (service, mockRepo, emailStore, cleanup)
    }

    // AC1: Successful login with rememberEmail:true stores the email.
    @Test("Successful login with rememberEmail true stores email in emailStore")
    func successfulLoginWithRememberEmailTrueStoresEmail() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        await service.login(email: "test@example.com", password: "password", rememberEmail: true)
        #expect(emailStore.rememberedEmail == "test@example.com")
    }

    // AC2: Failed login does not touch emailStore; previously stored value is preserved.
    @Test("Failed login with rememberEmail true leaves emailStore unchanged")
    func failedLoginWithRememberEmailTrueDoesNotTouchEmailStore() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        // Pre-seed a value
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "saved@example.com"
        // Attempt a failing login
        await service.login(email: "fail@example.com", password: "wrong", rememberEmail: true)
        #expect(emailStore.rememberedEmail == "saved@example.com")
    }

    // AC3: Successful login with rememberEmail:false removes any previously stored email.
    @Test("Successful login with rememberEmail false clears previously stored email")
    func successfulLoginWithRememberEmailFalseClearsStoredEmail() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "old@example.com"
        await service.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(emailStore.rememberedEmail == nil)
    }

    // AC4: register() does not touch emailStore on success.
    @Test("register success does not store email in emailStore")
    func registerSuccessDoesNotStoreEmailInEmailStore() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        await service.register(email: "new@example.com", password: "password123", firstName: "New", lastName: "User", registrationCode: "CODE-FAKE")
        #expect(emailStore.rememberedEmail == nil)
    }

    // AC4: register() does not touch emailStore on failure.
    @Test("register failure does not store email in emailStore")
    func registerFailureDoesNotStoreEmailInEmailStore() async {
        let (service, mockRepo, emailStore, _) = makeSUTWithEmailStore()
        await mockRepo.setFail(true)
        await service.register(email: "new@example.com", password: "password123", firstName: "New", lastName: "User", registrationCode: "CODE-FAKE")
        #expect(emailStore.rememberedEmail == nil)
    }

    // AC5: Stored email survives logout(reason: .userLogout).
    @Test("Stored email is preserved after logout with reason userLogout")
    func storedEmailPreservedAfterLogoutUserLogout() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "saved@example.com"
        await service.logout(reason: .userLogout)
        #expect(emailStore.rememberedEmail == "saved@example.com")
    }

    // AC5: Stored email survives logout(reason: .sessionExpired).
    @Test("Stored email is preserved after logout with reason sessionExpired")
    func storedEmailPreservedAfterLogoutSessionExpired() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "saved@example.com"
        await service.logout(reason: .sessionExpired)
        #expect(emailStore.rememberedEmail == "saved@example.com")
    }

    // AC5: Stored email survives logout(reason: .forcedUpdate).
    @Test("Stored email is preserved after logout with reason forcedUpdate")
    func storedEmailPreservedAfterLogoutForcedUpdate() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "saved@example.com"
        await service.logout(reason: .forcedUpdate)
        #expect(emailStore.rememberedEmail == "saved@example.com")
    }

    // AC5: Stored email survives logout(reason: .lockFallback).
    @Test("Stored email is preserved after logout with reason lockFallback")
    func storedEmailPreservedAfterLogoutLockFallback() async {
        let (service, _, emailStore, _) = makeSUTWithEmailStore()
        var mutableStore = emailStore
        mutableStore.rememberedEmail = "saved@example.com"
        await service.logout(reason: .lockFallback)
        #expect(emailStore.rememberedEmail == "saved@example.com")
    }

    // AC7: legacyCleanup.cleanUpLegacyTokens() called exactly once at init.
    @Test("legacyCleanup cleanUpLegacyTokens is called exactly once at init")
    func legacyCleanupCalledOnceAtInit() {
        let (_, _, _, cleanup) = makeSUTWithEmailStore()
        #expect(cleanup.cleanUpCallCount == 1)
    }

    // AC7: After a successful login, the cleanup call count is still 1.
    @Test("legacyCleanup call count remains 1 after successful login")
    func legacyCleanupCallCountRemainsOneAfterSuccessfulLogin() async {
        let (service, _, _, cleanup) = makeSUTWithEmailStore()
        await service.login(email: "test@example.com", password: "password", rememberEmail: false)
        #expect(cleanup.cleanUpCallCount == 1)
    }

    // MARK: - I2b-2c U3 (D-c): login 403 shows the administrator message only

    @Test("login 403 accountDisabled sets error, keeps the Face ID enrollment, and maps to the administrator message")
    func login403AccountDisabledShowsAdministratorMessageAndKeepsEnrollment() async throws {
        let store = InMemoryBiometricCredentialStore()
        try store.enroll(refreshToken: "tok-enrolled-FAKE", userId: "u1", firstName: "Alice")
        let service = AuthenticationService(
            repository: AccountDisabledLoginRepository(),
            sessionManager: SessionManager(initialClearables: []),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            credentialStore: store
        )

        await service.login(email: "u1@test.invalid", password: "password-FAKE", rememberEmail: false)

        #expect(service.error == .accountDisabled)
        #expect(service.isAuthenticated == false)
        #expect(store.enrolledUser()?.userId == "u1", "A login 403 must not delete the stored Face ID token (D-c)")
        let error = try #require(service.error)
        #expect(userMessage(for: error) == "This account has been disabled. Contact your administrator.")
    }

    // AC8: Failed registration leaves isLoading == false.
    @Test("isLoading is false after register returns on failure")
    func registerResetsIsLoadingOnFailure() async {
        let (service, mockRepo, _, _) = makeSUTWithEmailStore()
        await mockRepo.setFail(true)
        await service.register(email: "new@example.com", password: "password123", firstName: "New", lastName: "User", registrationCode: "CODE-FAKE")
        #expect(service.isLoading == false)
    }
}
