//
//  NetworkAuthRepositoryRequestTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S2): network request shape verification for
//  NetworkAuthenticationRepository.logout(refreshToken:) and
//  NetworkAuthenticationRepository.refreshToken(_:).
//
//  Uses a SpyAPIClient actor that records (method, path, encodedBody) for each call.
//  No real network. Compile fails until NetworkAuthenticationRepository is accessible
//  (it is an actor in the production module, so @testable import suffices).
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - SpyAPIClient

/// Actor-based spy that records each request the caller makes.
/// Returns a minimal decodable stub so the caller does not throw on decoding.
private actor SpyAPIClient: APIClient {

    struct RecordedCall: Sendable {
        let method: HTTPMethod
        let path: String
        let encodedBody: Data?
    }

    private(set) var calls: [RecordedCall] = []
    private var stubResponseData: Data = Data()

    func setStubResponseData(_ data: Data) {
        stubResponseData = data
    }

    func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        body: (any Encodable & Sendable)?,
        forceRefresh: Bool,
        cacheScope: CacheScope
    ) async throws -> T {
        let encoded: Data?
        if let body {
            encoded = try? JSONEncoder().encode(body)
        } else {
            encoded = nil
        }
        calls.append(RecordedCall(method: method, path: path, encodedBody: encoded))
        return try JSONDecoder().decode(T.self, from: stubResponseData)
    }
}

// MARK: - Helpers

/// Minimal stub for the EmptyResponse the repository decodes from logout/ping.
private struct EmptyStub: Codable {}

private func emptyResponseData() -> Data {
    (try? JSONEncoder().encode(EmptyStub())) ?? Data()
}

private func authResponseData(userId: String = "u1") -> Data {
    let json: [String: Any] = [
        "success": true,
        "data": [
            "user": [
                "id": userId,
                "email": "t@t.com",
                "name": "T",
                "role": "USER",
                "created_at": 1767225600,
                "updated_at": 1767225600
            ],
            "accessToken": "at",
            "refreshToken": "rt",
            "expiresIn": 900
        ],
        "meta": [
            "timestamp": "2026-01-01T00:00:00Z",
            "requestId": "req-1",
            "sessionId": "sess-1"
        ]
    ]
    return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
}

// MARK: - Suite

@Suite("NetworkAuthRepository Request Tests")
@MainActor
struct NetworkAuthRepositoryRequestTests {

    // MARK: - Logout request shape

    @Test("logout sends POST to /auth/logout")
    func logoutSendsPostToLogoutPath() async throws {
        let spy = SpyAPIClient()
        await spy.setStubResponseData(emptyResponseData())
        let repo = NetworkAuthenticationRepository(apiClient: spy)
        try await repo.logout(refreshToken: "token-abc")
        let calls = await spy.calls
        try #require(calls.count == 1)
        #expect(calls[0].method == .post)
        #expect(calls[0].path == "/auth/logout")
    }

    @Test("logout sends nil body (no refresh token in body)")
    func logoutSendsNilBody() async throws {
        let spy = SpyAPIClient()
        await spy.setStubResponseData(emptyResponseData())
        let repo = NetworkAuthenticationRepository(apiClient: spy)
        try await repo.logout(refreshToken: "token-abc")
        let calls = await spy.calls
        try #require(calls.count == 1)
        // Body must be nil — the refresh token is NOT sent in the request body.
        #expect(calls[0].encodedBody == nil)
    }

    // MARK: - Refresh token request shape

    @Test("refreshToken sends POST to /auth/refresh")
    func refreshTokenSendsPostToRefreshPath() async throws {
        let spy = SpyAPIClient()
        await spy.setStubResponseData(authResponseData())
        let repo = NetworkAuthenticationRepository(apiClient: spy)
        _ = try await repo.refreshToken("some-refresh-token")
        let calls = await spy.calls
        try #require(calls.count == 1)
        #expect(calls[0].method == .post)
        #expect(calls[0].path == "/auth/refresh")
    }

    @Test("refreshToken body contains only the refreshToken field")
    func refreshTokenBodyContainsOnlyRefreshTokenField() async throws {
        let spy = SpyAPIClient()
        await spy.setStubResponseData(authResponseData())
        let repo = NetworkAuthenticationRepository(apiClient: spy)
        _ = try await repo.refreshToken("my-rt-value")
        let calls = await spy.calls
        try #require(calls.count == 1)
        let bodyData = try #require(calls[0].encodedBody, "refreshToken body must not be nil")
        let json = try #require(
            try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "body must be valid JSON"
        )
        // Must contain refreshToken key with the correct value.
        #expect(json["refreshToken"] as? String == "my-rt-value")
        // Must contain exactly one key (no extra fields).
        #expect(json.count == 1)
    }

    @Test("refreshToken body refreshToken value matches the argument passed")
    func refreshTokenBodyValueMatchesArgument() async throws {
        let spy = SpyAPIClient()
        await spy.setStubResponseData(authResponseData())
        let repo = NetworkAuthenticationRepository(apiClient: spy)
        let tokenValue = "rt-\(UUID().uuidString)"
        _ = try await repo.refreshToken(tokenValue)
        let calls = await spy.calls
        try #require(calls.count == 1)
        let bodyData = try #require(calls[0].encodedBody)
        let json = try #require(try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(json["refreshToken"] as? String == tokenValue)
    }
}
