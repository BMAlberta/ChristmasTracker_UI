// MockAuthenticationRepositoryC1Tests.swift
// ChristmasTrackerTests
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Story C1 — failing tests for the updated MockAuthenticationRepository.
// These tests will not compile until the implementer updates MockAuthenticationRepository
// to conform to the new AuthenticationRepository protocol returning AuthSession.

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("MockAuthenticationRepository C1")
struct MockAuthenticationRepositoryC1Tests {

    // MARK: SUT factory

    private func makeSUT() -> MockAuthenticationRepository {
        MockAuthenticationRepository()
    }

    // MARK: AC23: mock login success → AuthSession with non-empty accessToken

    @Test("mock login with valid credentials returns AuthSession with non-empty accessToken")
    func mockLoginSuccessReturnsAuthSession() async throws {
        let sut = makeSUT()

        let session = try await sut.login(
            email: "user@test.invalid",
            password: "password-FAKE"
        )

        #expect(!session.accessToken.isEmpty)
        #expect(!session.refreshToken.isEmpty)
    }

    // MARK: AC24: mock login fail@test.invalid → invalidCredentials

    @Test("mock login with fail@test.invalid throws AuthenticationError.invalidCredentials")
    func mockLoginFailEmailThrowsInvalidCredentials() async throws {
        let sut = makeSUT()

        await #expect(throws: AuthenticationError.invalidCredentials) {
            _ = try await sut.login(email: "fail@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: AC25: mock register with CODE-INVALID-FAKE → invalidRegistrationCode

    @Test("mock register with CODE-INVALID-FAKE throws AuthenticationError.invalidRegistrationCode")
    func mockRegisterWithInvalidCodeThrows() async throws {
        let sut = makeSUT()

        await #expect(throws: AuthenticationError.invalidRegistrationCode) {
            _ = try await sut.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-INVALID-FAKE"
            )
        }
    }

    // MARK: AC26: mock register success → AuthSession

    @Test("mock register with valid code returns AuthSession")
    func mockRegisterSuccessReturnsAuthSession() async throws {
        let sut = makeSUT()

        let session = try await sut.register(
            email: "user@test.invalid",
            password: "password-FAKE",
            firstName: "Alice",
            lastName: "Smith",
            registrationCode: "CODE-FAKE"
        )

        #expect(!session.accessToken.isEmpty)
    }

    // MARK: AC27: mock refresh success → AuthSession with non-empty accessToken

    @Test("mock refresh with valid token returns AuthSession with non-empty accessToken")
    func mockRefreshSuccessReturnsAuthSession() async throws {
        let sut = makeSUT()

        // First login to get a valid refresh token
        let loginSession = try await sut.login(
            email: "user@test.invalid",
            password: "password-FAKE"
        )

        let refreshSession = try await sut.refresh(refreshToken: loginSession.refreshToken)

        #expect(!refreshSession.accessToken.isEmpty)
    }

    // MARK: AC28: mock logout → no throw

    @Test("mock logout does not throw")
    func mockLogoutDoesNotThrow() async throws {
        let sut = makeSUT()

        try await sut.logout()
    }

    // MARK: expired@test.invalid → credentialExpired

    @Test("mock login with expired@test.invalid throws AuthenticationError.credentialExpired")
    func mockLoginExpiredEmailThrowsCredentialExpired() async throws {
        let sut = makeSUT()

        await #expect(throws: AuthenticationError.credentialExpired) {
            _ = try await sut.login(email: "expired@test.invalid", password: "password-FAKE")
        }
    }
}
