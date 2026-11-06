// GeneratedClientAuthRepositoryTests.swift
// ChristmasTrackerTests
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Story C1 — failing tests for GeneratedClientAuthenticationRepository.
// These tests will not compile until the implementer creates:
//   - AuthSession struct
//   - Updated AuthenticationRepository protocol (new signatures)
//   - GeneratedClientAuthenticationRepository actor
//   - Updated AuthenticationError enum (new cases)

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Shared fixtures

private let baseURL = URL(string: "https://api.example.com")!

private let userFixtureJSON = """
{
  "id": "u1",
  "email": "user@test.invalid",
  "firstName": "Alice",
  "lastName": "Smith",
  "displayName": "Alice Smith",
  "role": "viewer",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "lastLoginAt": null
}
"""

private let metaJSON = """
{
  "timestamp": "2024-01-01T00:00:00Z",
  "requestId": "req-00000001",
  "sessionId": "sess-00000001"
}
"""

private func loginSuccessBody(email: String = "user@test.invalid") -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": {
        "user": {
          "id": "u1",
          "email": "\(email)",
          "firstName": "Alice",
          "lastName": "Smith",
          "displayName": "Alice Smith",
          "role": "viewer",
          "isActive": true,
          "createdAt": "2024-01-01T00:00:00Z",
          "updatedAt": "2024-01-01T00:00:00Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE"
      },
      "meta": \(metaJSON)
    }
    """)
}

private func loginNilEmailBody() -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": {
        "user": {
          "id": "u1",
          "email": null,
          "firstName": "Alice",
          "lastName": "Smith",
          "displayName": "Alice Smith",
          "role": "viewer",
          "isActive": true,
          "createdAt": "2024-01-01T00:00:00Z",
          "updatedAt": "2024-01-01T00:00:00Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE"
      },
      "meta": \(metaJSON)
    }
    """)
}

private func registerSuccessBody() -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": {
        "user": {
          "id": "u1",
          "email": "user@test.invalid",
          "firstName": "Alice",
          "lastName": "Smith",
          "displayName": "Alice Smith",
          "role": "viewer",
          "isActive": true,
          "createdAt": "2024-01-01T00:00:00Z",
          "updatedAt": "2024-01-01T00:00:00Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE"
      },
      "meta": \(metaJSON)
    }
    """)
}

private func refreshSuccessBody() -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": {
        "user": {
          "id": "u1",
          "email": "user@test.invalid",
          "firstName": "Alice",
          "lastName": "Smith",
          "displayName": "Alice Smith",
          "role": "viewer",
          "isActive": true,
          "createdAt": "2024-01-01T00:00:00Z",
          "updatedAt": "2024-01-01T00:00:00Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-new-FAKE",
        "expiresIn": 900,
        "refreshToken": "tok-refresh-new-FAKE"
      },
      "meta": \(metaJSON)
    }
    """)
}

private func logoutSuccessBody() -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": { "message": "Logged out" },
      "meta": \(metaJSON)
    }
    """)
}

private func errorBody(code: Int, errorCode: String, message: String) -> HTTPBody {
    HTTPBody("""
    {
      "success": false,
      "error": {
        "code": \(code),
        "errorCode": "\(errorCode)",
        "message": "\(message)"
      }
    }
    """)
}

private func versionOutdatedBody() -> HTTPBody {
    HTTPBody("""
    {
      "success": false,
      "error": {
        "code": 1014,
        "errorCode": "VERSION_OUTDATED",
        "message": "Update required",
        "details": {
          "minimumVersion": "2.0.0",
          "minimumBuild": 5,
          "latestVersion": "2.1.0",
          "latestBuild": 6,
          "manifestUrl": "https://example.invalid/manifest.plist",
          "ipaUrl": "https://example.invalid/app.ipa"
        }
      }
    }
    """)
}

// MARK: - SUT factory

private func makeInfo() -> AppClientInfo {
    AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0")
}

private func makeClientAndTransport(accessToken: String? = "tok-access-FAKE") throws -> (GeneratedClientAuthenticationRepository, AuthFakeTransport) {
    let transport = AuthFakeTransport()
    let client = try TrackerClientFactory.make(
        serverURL: baseURL,
        info: makeInfo(),
        tokenProvider: AuthFakeAccessTokenProvider(token: accessToken),
        sessionRefresher: AuthFakeSessionRefresher(),
        versionOutdatedHandler: AuthFakeVersionOutdatedHandler(),
        transport: transport
    )
    let repo = GeneratedClientAuthenticationRepository(client: client)
    return (repo, transport)
}

// MARK: - GeneratedClientAuthRepositoryTests Suite

@Suite("GeneratedClientAuthenticationRepository")
struct GeneratedClientAuthRepositoryTests {

    // MARK: Login — AC1: success

    @Test("login success maps user email, accessToken, refreshToken; expiresIn==900")
    func loginSuccessMapsFields() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: loginSuccessBody())

        let session = try await repo.login(email: "user@test.invalid", password: "password-FAKE")

        #expect(session.user.email == "user@test.invalid")
        #expect(session.accessToken == "tok-access-FAKE")
        #expect(session.refreshToken == "tok-refresh-FAKE")
        #expect(session.expiresIn == 900)
    }

    // MARK: Login — AC2: nil email → invalidResponse

    @Test("login with nil email in response body throws AuthenticationError.invalidResponse")
    func loginNilEmailThrowsInvalidResponse() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: loginNilEmailBody())

        await #expect(throws: AuthenticationError.invalidResponse) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC3: 401 INVALID_CREDENTIALS

    @Test("login 401 INVALID_CREDENTIALS throws AuthenticationError.invalidCredentials")
    func login401InvalidCredentialsThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(401),
            body: errorBody(code: 1001, errorCode: "INVALID_CREDENTIALS", message: "Bad credentials")
        )

        await #expect(throws: AuthenticationError.invalidCredentials) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC4: undocumented 403 ACCOUNT_DISABLED

    @Test("login undocumented 403 ACCOUNT_DISABLED throws AuthenticationError.accountDisabled")
    func login403AccountDisabledThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(403),
            body: errorBody(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "Disabled")
        )

        await #expect(throws: AuthenticationError.accountDisabled) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC5: 426 VERSION_OUTDATED

    @Test("login 426 VERSION_OUTDATED throws AuthenticationError.updateRequired")
    func login426ThrowsUpdateRequired() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(426), body: versionOutdatedBody())

        await #expect(throws: AuthenticationError.updateRequired) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC6: 429 rate limited

    @Test("login 429 RATE_LIMIT_EXCEEDED throws AuthenticationError.rateLimited")
    func login429ThrowsRateLimited() async throws {
        let (repo, transport) = try makeClientAndTransport()
        var fields = HTTPFields()
        fields[HTTPField.Name("Retry-After")!] = "0"
        // Enqueue 3 times to exhaust RateLimitMiddleware retries
        let r429 = HTTPResponse(status: .init(code: 429), headerFields: fields)
        await transport.enqueue([
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down")),
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down")),
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down"))
        ])

        await #expect(throws: AuthenticationError.rateLimited) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC7: 500

    @Test("login 500 throws AuthenticationError.serverError")
    func login500ThrowsServerError() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(500),
            body: errorBody(code: 9000, errorCode: "INTERNAL_SERVER_ERROR", message: "Internal error")
        )

        await #expect(throws: AuthenticationError.serverError) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC8: no Authorization header

    @Test("login request does not carry an Authorization header")
    func loginRequestHasNoAuthorizationHeader() async throws {
        let (repo, transport) = try makeClientAndTransport(accessToken: nil)
        await transport.enqueue(.ok(), body: loginSuccessBody())

        _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)
        #expect(req.headerFields[.authorization] == nil)
    }

    // MARK: Login — AC9: required client headers

    @Test("login request carries X-Platform, X-Build, X-App-Version, X-Client-Platform: ios")
    func loginRequestCarriesRequiredClientHeaders() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: loginSuccessBody())

        _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)
        #expect(req.headerFields[HTTPField.Name("X-Platform")!] == "ios")
        #expect(req.headerFields[HTTPField.Name("X-Build")!] == "1")
        #expect(req.headerFields[HTTPField.Name("X-App-Version")!] == "1.0.0")
        #expect(req.headerFields[HTTPField.Name("X-Client-Platform")!] == "ios")
    }

    // MARK: Register — AC10: success; expiresIn == 900

    @Test("register success returns AuthSession with expiresIn==900")
    func registerSuccessReturnsSessionWithExpiresIn900() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(201), body: registerSuccessBody())

        let session = try await repo.register(
            email: "user@test.invalid",
            password: "password-FAKE",
            firstName: "Alice",
            lastName: "Smith",
            registrationCode: "CODE-FAKE"
        )

        #expect(session.expiresIn == 900)
        #expect(session.accessToken == "tok-access-FAKE")
    }

    // MARK: Register — AC11: 403 REGISTRATION_CODE_INVALID

    @Test("register 403 REGISTRATION_CODE_INVALID throws AuthenticationError.invalidRegistrationCode")
    func register403RegistrationCodeInvalidThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(403),
            body: errorBody(code: 1017, errorCode: "REGISTRATION_CODE_INVALID", message: "Bad code")
        )

        await #expect(throws: AuthenticationError.invalidRegistrationCode) {
            _ = try await repo.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-INVALID-FAKE"
            )
        }
    }

    // MARK: Register — AC12: 409 EMAIL_ALREADY_EXISTS

    @Test("register 409 EMAIL_ALREADY_EXISTS throws AuthenticationError.emailAlreadyExists")
    func register409EmailAlreadyExistsThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(409),
            body: errorBody(code: 1009, errorCode: "EMAIL_ALREADY_EXISTS", message: "Taken")
        )

        await #expect(throws: AuthenticationError.emailAlreadyExists) {
            _ = try await repo.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-FAKE"
            )
        }
    }

    // MARK: Register — AC13: 400 validation

    @Test("register 400 validation throws AuthenticationError.validationFailed")
    func register400ThrowsValidationFailed() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(400),
            body: errorBody(code: 4000, errorCode: "VALIDATION_ERROR", message: "Invalid fields")
        )

        await #expect(throws: AuthenticationError.validationFailed) {
            _ = try await repo.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-FAKE"
            )
        }
    }

    // MARK: Refresh — AC14: success

    @Test("refresh success returns AuthSession with new refreshToken and expiresIn==900")
    func refreshSuccessReturnsNewSession() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: refreshSuccessBody())

        let session = try await repo.refresh(refreshToken: "tok-refresh-FAKE")

        #expect(session.refreshToken == "tok-refresh-new-FAKE")
        #expect(session.expiresIn == 900)
    }

    // MARK: Refresh — AC15: 401 REFRESH_TOKEN_EXPIRED

    @Test("refresh 401 REFRESH_TOKEN_EXPIRED throws AuthenticationError.credentialExpired")
    func refresh401RefreshTokenExpiredThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(401),
            body: errorBody(code: 1005, errorCode: "REFRESH_TOKEN_EXPIRED", message: "Expired")
        )

        await #expect(throws: AuthenticationError.credentialExpired) {
            _ = try await repo.refresh(refreshToken: "tok-refresh-FAKE")
        }
    }

    // MARK: Refresh — AC16: 401 REFRESH_TOKEN_INVALID

    @Test("refresh 401 REFRESH_TOKEN_INVALID throws AuthenticationError.invalidRefreshToken")
    func refresh401RefreshTokenInvalidThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(401),
            body: errorBody(code: 1006, errorCode: "REFRESH_TOKEN_INVALID", message: "Invalid")
        )

        await #expect(throws: AuthenticationError.invalidRefreshToken) {
            _ = try await repo.refresh(refreshToken: "tok-refresh-FAKE")
        }
    }

    // MARK: Refresh — AC17: refreshToken in JSON body, no cookie

    @Test("refresh request body contains refreshToken field")
    func refreshRequestBodyContainsRefreshTokenField() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: refreshSuccessBody())

        _ = try await repo.refresh(refreshToken: "tok-refresh-FAKE")

        let recorded = await transport.lastRequest()
        let bodyData = try await #require(recorded?.collectedBody())
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let tokenInBody = try #require(json?["refreshToken"] as? String)
        #expect(!tokenInBody.isEmpty)
        // Confirm no Cookie header is sent (cookie handling disabled per CLAUDE.md)
        let req = try #require(recorded?.request)
        #expect(req.headerFields[HTTPField.Name("Cookie")!] == nil)
    }

    // MARK: Refresh — AC18: 426

    @Test("refresh 426 throws AuthenticationError.updateRequired")
    func refresh426ThrowsUpdateRequired() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(426), body: versionOutdatedBody())

        await #expect(throws: AuthenticationError.updateRequired) {
            _ = try await repo.refresh(refreshToken: "tok-refresh-FAKE")
        }
    }

    // MARK: Logout — AC19: success; no throw

    @Test("logout success does not throw")
    func logoutSuccessDoesNotThrow() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: logoutSuccessBody())

        try await repo.logout()
    }

    // MARK: Logout — AC20: no body

    @Test("logout request sends empty body")
    func logoutRequestSendsEmptyBody() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: logoutSuccessBody())

        try await repo.logout()

        let recorded = await transport.lastRequest()
        let req = try #require(recorded)
        // The logout operation has no request body in the generated schema
        let body = req.body
        #expect(body == nil)
    }

    // MARK: Logout — AC21: Authorization header present

    @Test("logout request carries Authorization: Bearer header")
    func logoutRequestCarriesAuthorizationHeader() async throws {
        let (repo, transport) = try makeClientAndTransport(accessToken: "tok-access-FAKE")
        await transport.enqueue(.ok(), body: logoutSuccessBody())

        try await repo.logout()

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)
        let authHeader = try #require(req.headerFields[.authorization])
        #expect(authHeader == "Bearer tok-access-FAKE")
    }

    // MARK: Logout — AC22: 401 → throws something

    @Test("logout 401 throws an error")
    func logout401Throws() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(401),
            body: errorBody(code: 1002, errorCode: "ACCESS_TOKEN_EXPIRED", message: "Expired")
        )

        await #expect(throws: (any Error).self) {
            try await repo.logout()
        }
    }
}

// MARK: - AuthFakeTransport (private to this file)

private actor AuthFakeTransport: ClientTransport {
    struct RecordedRequest {
        let request: HTTPRequest
        let body: HTTPBody?
        let baseURL: URL
        let operationID: String

        func collectedBody() async throws -> Data {
            guard let b = body else { return Data() }
            var collected = Data()
            for try await chunk in b {
                collected.append(contentsOf: chunk)
            }
            return collected
        }
    }

    private var scriptedResponses: [(HTTPResponse, HTTPBody?)] = []
    private(set) var recordedRequests: [RecordedRequest] = []

    func enqueue(_ response: HTTPResponse, body: HTTPBody? = nil) {
        scriptedResponses.append((response, body))
    }

    func enqueue(_ pairs: [(HTTPResponse, HTTPBody?)]) {
        scriptedResponses.append(contentsOf: pairs)
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        recordedRequests.append(
            RecordedRequest(request: request, body: body, baseURL: baseURL, operationID: operationID)
        )
        if scriptedResponses.isEmpty {
            return (HTTPResponse(status: .ok), nil)
        }
        return scriptedResponses.removeFirst()
    }

    func lastRequest() -> RecordedRequest? { recordedRequests.last }
}

// MARK: - Extension helpers

private extension HTTPResponse {
    static func ok() -> HTTPResponse { HTTPResponse(status: .ok) }
    static func status(_ code: Int) -> HTTPResponse {
        HTTPResponse(status: HTTPResponse.Status(code: code))
    }
}

// MARK: - Local fakes for seam protocols

private final class AuthFakeAccessTokenProvider: AccessTokenProviding, @unchecked Sendable {
    private let token: String?
    init(token: String?) { self.token = token }
    func accessToken() async -> String? { token }
}

private actor AuthFakeSessionRefresher: SessionRefreshing {
    func refresh() async throws {}
}

private actor AuthFakeVersionOutdatedHandler: VersionOutdatedHandling {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async {}
}
