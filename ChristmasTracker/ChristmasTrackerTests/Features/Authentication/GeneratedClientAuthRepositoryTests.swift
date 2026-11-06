// GeneratedClientAuthRepositoryTests.swift
// ChristmasTrackerTests
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Story F1 (fix pass: i2b2b-generated-auth) — updated failing tests for
// GeneratedClientAuthenticationRepository.
//
// DELETED TESTS (reason: asserted fallback behavior):
//   - loginSuccessMapsFields: asserted fallback behavior: fixture used role "viewer",
//     which the generated decoder cannot handle; the test was exercising the JSONSerialization
//     fallback path, not the generated-client path. Replaced by loginSuccessDecodesThroughGeneratedClient.
//   - register400ThrowsValidationFailed: asserted fallback behavior: asserted .validationFailed
//     which is the old case name; replaced by register400PasswordTooWeakThrowsValidationWithMessage
//     and register400PasswordMismatchThrowsValidationWithMessage.
//   - login429ThrowsRateLimited: asserted fallback behavior: asserted .rateLimited with no
//     associated value; the case now carries retryAfter. Replaced by login429ThrowsRateLimitedWithRetryAfter.
//   - refreshSuccessReturnsNewSession: asserted fallback behavior: fixture used role "viewer";
//     replaced by refreshSuccessDecodesThroughGeneratedClient.
//   - registerSuccessReturnsSessionWithExpiresIn900: asserted fallback behavior: fixture used
//     role "viewer"; replaced by registerSuccessDecodesThroughGeneratedClient.
//
// These tests will not compile until the implementer renames:
//   - AuthenticationError.validationFailed → AuthenticationError.validation(message: String)
//   - AuthenticationError.rateLimited → AuthenticationError.rateLimited(retryAfter: TimeInterval)

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Shared fixtures

private let baseURL = URL(string: "https://api.example.com")!

/// Full meta block required by the generated schema (fractional-seconds timestamp).
private let metaJSON = """
{
  "timestamp": "2026-11-02T00:00:00.000Z",
  "requestId": "req-00000001",
  "sessionId": "sess-00000001"
}
"""

/// Success body with role "USER" so the generated decoder accepts it.
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
          "role": "USER",
          "isActive": true,
          "createdAt": "2026-11-02T00:00:00.000Z",
          "updatedAt": "2026-11-02T00:00:00.000Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE",
        "expiresIn": 900
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
          "role": "USER",
          "isActive": true,
          "createdAt": "2026-11-02T00:00:00.000Z",
          "updatedAt": "2026-11-02T00:00:00.000Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE",
        "expiresIn": 900
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
          "role": "USER",
          "isActive": true,
          "createdAt": "2026-11-02T00:00:00.000Z",
          "updatedAt": "2026-11-02T00:00:00.000Z",
          "lastLoginAt": null
        },
        "accessToken": "tok-access-FAKE",
        "refreshToken": "tok-refresh-FAKE",
        "expiresIn": 900
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
          "role": "USER",
          "isActive": true,
          "createdAt": "2026-11-02T00:00:00.000Z",
          "updatedAt": "2026-11-02T00:00:00.000Z",
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

/// Error body with full meta block required by the generated schema.
private func errorBody(code: Int, errorCode: String, message: String) -> HTTPBody {
    HTTPBody("""
    {
      "success": false,
      "error": {
        "code": \(code),
        "errorCode": "\(errorCode)",
        "message": "\(message)"
      },
      "meta": \(metaJSON)
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
      },
      "meta": \(metaJSON)
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

    // MARK: Login — AC1: success (generated-client path, role: "USER")

    @Test("login success decodes through generated client; maps email, accessToken, refreshToken, expiresIn==900")
    func loginSuccessDecodesThroughGeneratedClient() async throws {
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

    // MARK: Login — AC6: 400 VALIDATION_ERROR → validation(message:)

    @Test("login 400 VALIDATION_ERROR throws AuthenticationError.validation(message:) with server message")
    func login400ValidationThrowsWithMessage() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(400),
            body: errorBody(code: 3001, errorCode: "VALIDATION_ERROR", message: "Validation error")
        )

        do {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
            Issue.record("Expected AuthenticationError.validation to be thrown")
        } catch let error as AuthenticationError {
            guard case let .validation(msg) = error else {
                Issue.record("Expected .validation(message:) but got \(error)")
                return
            }
            #expect(msg == "Validation error")
        }
    }

    // MARK: Login — AC7: transport failure → networkError

    @Test("login transport failure throws AuthenticationError.networkError")
    func loginTransportFailureThrowsNetworkError() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueueThrow(URLError(.notConnectedToInternet))

        await #expect(throws: AuthenticationError.networkError) {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
        }
    }

    // MARK: Login — AC8: 429 rate limited with retryAfter

    @Test("login 429 RATE_LIMIT_EXCEEDED throws AuthenticationError.rateLimited(retryAfter:) with retryAfter > 0")
    func login429ThrowsRateLimitedWithRetryAfter() async throws {
        let (repo, transport) = try makeClientAndTransport()
        var fields = HTTPFields()
        fields[HTTPField.Name("Retry-After")!] = "60"
        // Enqueue 3 times to exhaust RateLimitMiddleware retries
        let r429 = HTTPResponse(status: .init(code: 429), headerFields: fields)
        await transport.enqueue([
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down")),
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down")),
            (r429, errorBody(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Slow down"))
        ])

        do {
            _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")
            Issue.record("Expected AuthenticationError.rateLimited to be thrown")
        } catch let error as AuthenticationError {
            guard case let .rateLimited(retryAfter) = error else {
                Issue.record("Expected .rateLimited(retryAfter:) but got \(error)")
                return
            }
            #expect(retryAfter > 0)
        }
    }

    // MARK: Login — AC9: 500

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

    // MARK: Login — AC10: no Authorization header

    @Test("login request does not carry an Authorization header")
    func loginRequestHasNoAuthorizationHeader() async throws {
        let (repo, transport) = try makeClientAndTransport(accessToken: nil)
        await transport.enqueue(.ok(), body: loginSuccessBody())

        _ = try await repo.login(email: "user@test.invalid", password: "password-FAKE")

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)
        #expect(req.headerFields[.authorization] == nil)
    }

    // MARK: Login — AC11: required client headers

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

    // MARK: Register — AC12: success (generated-client path, role: "USER")

    @Test("register success decodes through generated client; expiresIn==900, accessToken correct")
    func registerSuccessDecodesThroughGeneratedClient() async throws {
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

    // MARK: Register — AC13: 403 REGISTRATION_CODE_INVALID

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

    // MARK: Register — AC14: 409 EMAIL_ALREADY_EXISTS

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

    // MARK: Register — AC15: 400 PASSWORD_TOO_WEAK → validation(message:)

    @Test("register 400 PASSWORD_TOO_WEAK throws AuthenticationError.validation(message:) with server message")
    func register400PasswordTooWeakThrowsValidationWithMessage() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(400),
            body: errorBody(code: 4000, errorCode: "PASSWORD_TOO_WEAK", message: "Password does not meet requirements")
        )

        do {
            _ = try await repo.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-FAKE"
            )
            Issue.record("Expected AuthenticationError.validation to be thrown")
        } catch let error as AuthenticationError {
            guard case let .validation(msg) = error else {
                Issue.record("Expected .validation(message:) but got \(error)")
                return
            }
            #expect(msg == "Password does not meet requirements")
        }
    }

    // MARK: Register — AC16: 400 PASSWORD_MISMATCH → validation(message:)

    @Test("register 400 PASSWORD_MISMATCH throws AuthenticationError.validation(message:) with server message")
    func register400PasswordMismatchThrowsValidationWithMessage() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(
            .status(400),
            body: errorBody(code: 4001, errorCode: "PASSWORD_MISMATCH", message: "Passwords do not match")
        )

        do {
            _ = try await repo.register(
                email: "user@test.invalid",
                password: "password-FAKE",
                firstName: "Alice",
                lastName: "Smith",
                registrationCode: "CODE-FAKE"
            )
            Issue.record("Expected AuthenticationError.validation to be thrown")
        } catch let error as AuthenticationError {
            guard case let .validation(msg) = error else {
                Issue.record("Expected .validation(message:) but got \(error)")
                return
            }
            #expect(msg == "Passwords do not match")
        }
    }

    // MARK: Refresh — AC17: success (generated-client path, role: "USER")

    @Test("refresh success decodes through generated client; new refreshToken, expiresIn==900")
    func refreshSuccessDecodesThroughGeneratedClient() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: refreshSuccessBody())

        let session = try await repo.refresh(refreshToken: "tok-refresh-FAKE")

        #expect(session.refreshToken == "tok-refresh-new-FAKE")
        #expect(session.expiresIn == 900)
    }

    // MARK: Refresh — AC18: 401 REFRESH_TOKEN_EXPIRED

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

    // MARK: Refresh — AC19: 401 REFRESH_TOKEN_INVALID

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

    // MARK: Refresh — AC20: refreshToken in JSON body, no cookie

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

    // MARK: Refresh — AC21: 426

    @Test("refresh 426 throws AuthenticationError.updateRequired")
    func refresh426ThrowsUpdateRequired() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(426), body: versionOutdatedBody())

        await #expect(throws: AuthenticationError.updateRequired) {
            _ = try await repo.refresh(refreshToken: "tok-refresh-FAKE")
        }
    }

    // MARK: Logout — AC22: success; no throw

    @Test("logout success does not throw")
    func logoutSuccessDoesNotThrow() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: logoutSuccessBody())

        try await repo.logout()
    }

    // MARK: Logout — AC23: no body

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

    // MARK: Logout — AC24: Authorization header present

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

    // MARK: Logout — AC25: 401 → throws something

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
    private var scriptedThrow: (any Error)? = nil
    private(set) var recordedRequests: [RecordedRequest] = []

    func enqueue(_ response: HTTPResponse, body: HTTPBody? = nil) {
        scriptedResponses.append((response, body))
    }

    func enqueue(_ pairs: [(HTTPResponse, HTTPBody?)]) {
        scriptedResponses.append(contentsOf: pairs)
    }

    func enqueueThrow(_ error: any Error) {
        scriptedThrow = error
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
        if let toThrow = scriptedThrow {
            scriptedThrow = nil
            throw toThrow
        }
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
