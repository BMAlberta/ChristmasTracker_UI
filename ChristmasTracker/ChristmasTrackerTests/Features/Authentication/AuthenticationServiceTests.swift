//
//  AuthenticationServiceTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/12/26.
//

import Testing
@testable import ChristmasTracker
@Suite("AuthenticationService Tests")
@MainActor
struct AuthenticationServiceTests {
    @Test("Login with valid credentials succeeds")
    func testLoginSuccess() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        await service.register(
            email: "new@example.com",
            password: "password123",
            name: "New User"
        )
        #expect(service.isAuthenticated == true)
        #expect(service.currentUser?.name == "New User")
        #expect(service.error == nil)
    }
    @Test("Logout clears authentication state")
    func testLogout() async {
        let mockRepo = MockAuthenticationRepository()
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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
        let sessionManager = SessionManager(authRepository: mockRepo)
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

    @Test("isLoading is false after forgotPassword() returns")
    func forgotPasswordResetsIsLoadingOnReturn() async {
        let (service, _) = makeSUT()
        await service.forgotPassword(email: "any@example.com")
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
}
