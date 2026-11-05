//
//  MockAuthenticationRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S1): MockAuthenticationRepository per-email stable users
//  and token rotation behaviour.
//
//  Contract (from Gate 1 spec, S1):
//
//  - login(email:password:rememberMe:) derives a stable user from email:
//      id = "mock-\(stableHash(email))" where stableHash is deterministic
//      name = part before '@' (capitalized)
//      email = the email passed in
//      Specifically: "a@example.com" → id "mock-a", name "A"
//
//  - refreshToken(_ refreshToken:) rotates: returns a NEW token each call.
//    Token format: "mock_rt_{userId}_{uuid}" (components split by "_" at indices 0,1,2,3)
//
//  - Tokens not starting with "mock_rt_" → throws .invalidRefreshToken
//  - Tokens encoding userId "mock-expired" (from "expired@example.com") → throws .invalidRefreshToken
//  - fail@example.com login → throws .invalidCredentials (unchanged)
//
//  Will fail to compile/pass until:
//    - MockAuthenticationRepository.login derives stable per-email user
//    - MockAuthenticationRepository.refreshToken rotates token and validates format
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("MockAuthenticationRepository — per-email users and rotation")
struct MockAuthenticationRepositoryTests {

    // MARK: - Factory

    private func makeSUT() -> MockAuthenticationRepository {
        MockAuthenticationRepository()
    }

    // MARK: - Stable per-email user derivation

    @Test("login(a@example.com) returns user with id containing stable hash and name A")
    func loginDerivedUserForA() async throws {
        let sut = makeSUT()
        let authData = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        // id must be "mock-a" (or any stable deterministic value derived from "a@example.com")
        #expect(authData.user.id == "mock-a",
                "login with 'a@example.com' must produce user id 'mock-a' (got '\(authData.user.id)')")
        // name must be capitalized local-part "A"
        let name = authData.user.name
        #expect(name.lowercased().contains("a"),
                "User name must reflect the local-part of the email (got '\(name)')")
    }

    @Test("login(b@example.com) returns a different stable user than a@example.com")
    func loginDerivedUserForBDiffersFromA() async throws {
        let sut = makeSUT()
        let authA = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        let authB = try await sut.login(email: "b@example.com", password: "password", rememberMe: false)
        #expect(authA.user.id != authB.user.id,
                "Different emails must produce different user IDs")
    }

    @Test("login(a@example.com) is stable — same id on second call")
    func loginStableAcrossCalls() async throws {
        let sut = makeSUT()
        let auth1 = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        let auth2 = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        #expect(auth1.user.id == auth2.user.id,
                "Same email must produce the same user ID across calls")
    }

    // MARK: - Existing fail@example.com behaviour preserved

    @Test("login(fail@example.com) throws invalidCredentials")
    func loginFailEmailThrowsInvalidCredentials() async throws {
        let sut = makeSUT()
        await #expect(throws: AuthenticationError.invalidCredentials) {
            _ = try await sut.login(email: "fail@example.com", password: "password", rememberMe: false)
        }
    }

    // MARK: - Token rotation

    @Test("refreshToken returns a DIFFERENT token from the one passed in (rotation)")
    func refreshTokenRotates() async throws {
        let sut = makeSUT()
        let loginData = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        let firstToken = loginData.refreshToken
        let refreshData = try await sut.refreshToken(firstToken)
        #expect(refreshData.refreshToken != firstToken,
                "refreshToken must return a new token different from the input (rotation)")
    }

    @Test("refreshToken called twice returns two different tokens")
    func refreshTokenReturnsDifferentTokensOnConsecutiveCalls() async throws {
        let sut = makeSUT()
        let loginData = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        let data1 = try await sut.refreshToken(loginData.refreshToken)
        let data2 = try await sut.refreshToken(data1.refreshToken)
        #expect(data1.refreshToken != data2.refreshToken,
                "Each refreshToken call must produce a unique token")
    }

    @Test("refreshToken returns a user matching the user from login")
    func refreshTokenUserMatchesLoginUser() async throws {
        let sut = makeSUT()
        let loginData = try await sut.login(email: "a@example.com", password: "password", rememberMe: false)
        let refreshData = try await sut.refreshToken(loginData.refreshToken)
        #expect(refreshData.user.id == loginData.user.id,
                "User id in refresh response must match user id from login")
    }

    // MARK: - Token from an earlier launch

    @Test("refreshToken accepts a manually-constructed valid mock token (earlier-launch simulation)")
    func refreshTokenAcceptsManuallyConstructedToken() async throws {
        let sut = makeSUT()
        // Construct a token in the documented format without having logged in first.
        // Format: "mock_rt_{userId}_{uuid}"
        let earlierLaunchToken = "mock_rt_mock-a_\(UUID().uuidString)"
        // Must NOT throw — a token from a previous app launch must remain valid
        let refreshData = try await sut.refreshToken(earlierLaunchToken)
        #expect(refreshData.user.id == "mock-a",
                "Parsing earlier-launch token must recover userId 'mock-a'")
    }

    // MARK: - Invalid tokens

    @Test("refreshToken with malformed token (no mock prefix) throws invalidRefreshToken")
    func refreshTokenMalformedThrows() async throws {
        let sut = makeSUT()
        await #expect(throws: AuthenticationError.invalidRefreshToken) {
            _ = try await sut.refreshToken("not-a-mock-token")
        }
    }

    @Test("refreshToken with empty string throws invalidRefreshToken")
    func refreshTokenEmptyStringThrows() async throws {
        let sut = makeSUT()
        await #expect(throws: AuthenticationError.invalidRefreshToken) {
            _ = try await sut.refreshToken("")
        }
    }

    @Test("refreshToken with expired@example.com token throws invalidRefreshToken")
    func refreshTokenForExpiredUserThrows() async throws {
        let sut = makeSUT()
        // The token encodes the userId derived from "expired@example.com" → "mock-expired"
        let expiredUserToken = "mock_rt_mock-expired_\(UUID().uuidString)"
        await #expect(throws: AuthenticationError.invalidRefreshToken) {
            _ = try await sut.refreshToken(expiredUserToken)
        }
    }
}
