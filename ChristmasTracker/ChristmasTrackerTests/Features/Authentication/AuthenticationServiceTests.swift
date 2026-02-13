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
            rememberMe: false
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
            rememberMe: false
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
            rememberMe: false
        )
        #expect(service.isAuthenticated == true)
        // Logout
        await service.logout()
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
    }
}
