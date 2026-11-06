// AuthServiceRegisterSignatureTests.swift
// ChristmasTrackerTests
//
// Story C2 — Group D: AuthenticationService.register new signature tests.
//
// D2: compile-time check — register(email:password:name:) must not exist.
//     Verified by grep in acceptance review.

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("AuthenticationService.register — C2 signature")
@MainActor
struct AuthServiceRegisterSignatureTests {

    // MARK: - SUT factory
    //
    // After C2, SessionManager.init no longer accepts authRepository:.
    // Using SessionManager(initialClearables:) here asserts that the C2 init is in place.

    private func makeSUT() -> (
        service: AuthenticationService,
        mockRepo: SpyAuthenticationRepository
    ) {
        let mockRepo = SpyAuthenticationRepository()
        let sessionManager = SessionManager(initialClearables: [])
        let service = AuthenticationService(
            repository: mockRepo,
            sessionManager: sessionManager
        )
        return (service, mockRepo)
    }

    // MARK: - D1: 5-param register exists, is callable, and routes correct parameters

    @Test("register(email:password:firstName:lastName:registrationCode:) exists and passes all params to repository")
    func registerFiveParamSignatureExistsAndPassesParams() async {
        let (service, mockRepo) = makeSUT()

        await service.register(
            email: "user@test.invalid",
            password: "Password1!-FAKE",
            firstName: "Alice",
            lastName: "Smith",
            registrationCode: "CODE-FAKE"
        )

        // The service must have called the repo with the correct parameters.
        #expect(mockRepo.lastRegisteredFirstName == "Alice")
        #expect(mockRepo.lastRegisteredLastName == "Smith")
        #expect(mockRepo.lastRegisteredRegistrationCode == "CODE-FAKE")
        #expect(mockRepo.lastRegisteredEmail == "user@test.invalid")

        // And the service reflects success.
        #expect(service.isAuthenticated == true)
        #expect(service.currentUser?.firstName == "Alice")
        #expect(service.currentUser?.lastName == "Smith")
    }

    @Test("register with invalid registrationCode surfaces the error on the service")
    func registerWithInvalidCodeSurfacesError() async {
        let (service, _) = makeSUT()

        await service.register(
            email: "user@test.invalid",
            password: "Password1!-FAKE",
            firstName: "Alice",
            lastName: "Smith",
            registrationCode: "CODE-INVALID-FAKE"
        )

        #expect(service.isAuthenticated == false)
        #expect(service.error == .invalidRegistrationCode)
    }
}

// MARK: - SpyAuthenticationRepository

/// Records parameters from the most recent register() call for assertion in D1.
/// Wraps MockAuthenticationRepository behaviour so the full success/failure logic is preserved.
nonisolated final class SpyAuthenticationRepository: AuthenticationRepository, @unchecked Sendable {

    private let lock = NSLock()
    private var _lastRegisteredEmail: String?
    private var _lastRegisteredFirstName: String?
    private var _lastRegisteredLastName: String?
    private var _lastRegisteredRegistrationCode: String?

    var lastRegisteredEmail: String? {
        lock.lock(); defer { lock.unlock() }
        return _lastRegisteredEmail
    }
    var lastRegisteredFirstName: String? {
        lock.lock(); defer { lock.unlock() }
        return _lastRegisteredFirstName
    }
    var lastRegisteredLastName: String? {
        lock.lock(); defer { lock.unlock() }
        return _lastRegisteredLastName
    }
    var lastRegisteredRegistrationCode: String? {
        lock.lock(); defer { lock.unlock() }
        return _lastRegisteredRegistrationCode
    }

    // Delegate to MockAuthenticationRepository for realistic behaviour.
    private let inner = MockAuthenticationRepository()

    func login(email: String, password: String) async throws -> AuthSession {
        try await inner.login(email: email, password: password)
    }

    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        registrationCode: String
    ) async throws -> AuthSession {
        lock.lock()
        _lastRegisteredEmail = email
        _lastRegisteredFirstName = firstName
        _lastRegisteredLastName = lastName
        _lastRegisteredRegistrationCode = registrationCode
        lock.unlock()

        return try await inner.register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            registrationCode: registrationCode
        )
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        try await inner.refresh(refreshToken: refreshToken)
    }

    func logout() async throws {
        try await inner.logout()
    }
}
