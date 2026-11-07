// AuthResponseDecodingTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Package I2b-2c, story U1 (contract C15 and C16).
//
// Pins that the auth operations decode the newly documented statuses into the typed
// Output cases when called through the real TrackerClientFactory.make-built client
// with a fake ClientTransport (no network, no sleeps), and that login and register
// success responses decode the now-required `expiresIn`.
//
// Error envelopes follow Docs/client-guide.md section 4 (with the full meta object
// {timestamp, requestId, sessionId}); codes and messages follow Docs/error-codes.md.
//
// 429 on a POST: RateLimitMiddleware never retries a POST and throws
// TrackerAPIError.rateLimited(retryAfter:) before the generated decoder runs, so the
// typed `.tooManyRequests` case is not reachable through the factory-built client.
// The refreshToken 429 test asserts what the client actually surfaces.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import TrackerAPI

@Suite("Auth response decoding (C15, C16)")
struct AuthResponseDecodingTests {

    // MARK: - SUT

    private func makeSUT(
        token: String? = "test-access-token"
    ) throws -> (client: Client, transport: FakeTransport) {
        let transport = FakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: makeBaseURL(),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: FakeAccessTokenProvider(token: token),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
        return (client, transport)
    }

    // MARK: - Fixtures

    /// Error envelope in the shape of Docs/client-guide.md section 4, full meta object.
    private func errorEnvelope(
        code: Int,
        errorCode: String,
        message: String,
        detailsJSON: String = "{}"
    ) -> HTTPBody {
        jsonBody("""
        {
          "success": false,
          "error": {
            "code": \(code),
            "errorCode": "\(errorCode)",
            "message": "\(message)",
            "details": \(detailsJSON)
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00.000Z",
            "requestId": "req-abc123",
            "sessionId": "ses-abc123"
          }
        }
        """)
    }

    private func accountDisabledEnvelope() -> HTTPBody {
        errorEnvelope(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled")
    }

    private func userNotFoundEnvelope() -> HTTPBody {
        errorEnvelope(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    }

    private func validationEnvelope() -> HTTPBody {
        errorEnvelope(code: 3001, errorCode: "VALIDATION_ERROR", message: "Validation error")
    }

    /// Auth success envelope (login 200 / register 201) in the shape of client-guide 3.1,
    /// with a non-null email and a non-default expiresIn.
    private func authSuccessBody(expiresIn: Int) -> HTTPBody {
        jsonBody("""
        {
          "success": true,
          "data": {
            "user": {
              "id": "00000000-0000-0000-0000-000000000001",
              "email": "alice@test.invalid",
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
            "expiresIn": \(expiresIn),
            "refreshToken": "tok-refresh-FAKE"
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00.000Z",
            "requestId": "req-abc123",
            "sessionId": "ses-abc123"
          }
        }
        """)
    }

    private func loginInput() -> Operations.Login.Input {
        .init(body: .json(.init(email: "alice@test.invalid", password: "password-FAKE")))
    }

    private func registerInput() -> Operations.Register.Input {
        .init(body: .json(.init(
            email: "alice@test.invalid",
            password: "password-FAKE",
            firstName: "Alice",
            lastName: "Smith",
            registrationCode: "CODE-FAKE"
        )))
    }

    private func refreshInput() -> Operations.RefreshToken.Input {
        .init(body: .json(.init(refreshToken: "tok-refresh-FAKE")))
    }

    /// Extracts the retryAfter of a TrackerAPIError.rateLimited, unwrapping the
    /// OpenAPIRuntime ClientError the runtime wraps middleware errors in.
    private func rateLimitedRetryAfter(_ error: any Error) -> TimeInterval? {
        let root: any Error
        if let clientError = error as? ClientError {
            root = clientError.underlyingError
        } else {
            root = error
        }
        if case let TrackerAPIError.rateLimited(retryAfter) = root {
            return retryAfter
        }
        return nil
    }

    // MARK: - login

    @Test("login 403 ACCOUNT_DISABLED decodes as .forbidden with a readable error envelope")
    func login403DecodesAsForbidden() async throws {
        let (client, transport) = try makeSUT(token: nil)
        await transport.enqueue(.status(403), body: accountDisabledEnvelope())

        let output = try await client.login(loginInput())

        guard case let .forbidden(forbidden) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbidden.body.json
        #expect(envelope.success == false)
        #expect(envelope.error.code == 1008)
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
        #expect(envelope.error.message == "This account has been disabled")
    }

    @Test("login 200 decodes the required expiresIn and the non-null user email")
    func loginSuccessDecodesExpiresIn() async throws {
        let (client, transport) = try makeSUT(token: nil)
        await transport.enqueue(.ok(), body: authSuccessBody(expiresIn: 3600))

        let output = try await client.login(loginInput())

        guard case let .ok(ok) = output else {
            Issue.record("Expected .ok but got \(output)")
            return
        }
        let payload = try ok.body.json
        #expect(payload.data.expiresIn == 3600)
        #expect(payload.data.user.email == "alice@test.invalid")
        #expect(payload.data.accessToken == "tok-access-FAKE")
    }

    // MARK: - register

    @Test("register 201 decodes the required expiresIn and the non-null user email")
    func registerSuccessDecodesExpiresIn() async throws {
        let (client, transport) = try makeSUT(token: nil)
        await transport.enqueue(.status(201), body: authSuccessBody(expiresIn: 3600))

        let output = try await client.register(registerInput())

        guard case let .created(created) = output else {
            Issue.record("Expected .created but got \(output)")
            return
        }
        let payload = try created.body.json
        #expect(payload.data.expiresIn == 3600)
        #expect(payload.data.user.email == "alice@test.invalid")
        #expect(payload.data.accessToken == "tok-access-FAKE")
    }

    // MARK: - refreshToken

    @Test("refreshToken 400 VALIDATION_ERROR decodes as .badRequest with a readable error envelope")
    func refresh400DecodesAsBadRequest() async throws {
        let (client, transport) = try makeSUT(token: nil)
        await transport.enqueue(.status(400), body: validationEnvelope())

        let output = try await client.refreshToken(refreshInput())

        guard case let .badRequest(badRequest) = output else {
            Issue.record("Expected .badRequest but got \(output)")
            return
        }
        let envelope = try badRequest.body.json
        #expect(envelope.error.code == 3001)
        #expect(envelope.error.errorCode == "VALIDATION_ERROR")
        #expect(envelope.error.message == "Validation error")
    }

    @Test("refreshToken 403 ACCOUNT_DISABLED decodes as .forbidden with a readable error envelope")
    func refresh403DecodesAsForbidden() async throws {
        let (client, transport) = try makeSUT(token: nil)
        await transport.enqueue(.status(403), body: accountDisabledEnvelope())

        let output = try await client.refreshToken(refreshInput())

        guard case let .forbidden(forbidden) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbidden.body.json
        #expect(envelope.error.code == 1008)
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
    }

    @Test("refreshToken 429 surfaces TrackerAPIError.rateLimited from RateLimitMiddleware without a retry")
    func refresh429SurfacesRateLimited() async throws {
        let (client, transport) = try makeSUT(token: nil)
        var fields = HTTPFields()
        let retryAfterName = try #require(HTTPField.Name("Retry-After"))
        fields[retryAfterName] = "5"
        await transport.enqueue(
            HTTPResponse(status: .init(code: 429), headerFields: fields),
            body: errorEnvelope(
                code: 8001,
                errorCode: "RATE_LIMIT_EXCEEDED",
                message: "Rate limit exceeded",
                detailsJSON: #"{ "retryAfter": 5 }"#
            )
        )

        do {
            let output = try await client.refreshToken(refreshInput())
            Issue.record("Expected TrackerAPIError.rateLimited to be thrown but got \(output)")
        } catch {
            let retryAfter = try #require(
                rateLimitedRetryAfter(error),
                "Expected TrackerAPIError.rateLimited but got \(error)"
            )
            #expect(retryAfter == 5)
        }
        // POST is never retried by RateLimitMiddleware.
        #expect(await transport.requestCount == 1)
    }

    // MARK: - getCurrentUser

    @Test("getCurrentUser 403 ACCOUNT_DISABLED decodes as .forbidden with a readable error envelope")
    func getCurrentUser403DecodesAsForbidden() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(.status(403), body: accountDisabledEnvelope())

        let output = try await client.getCurrentUser()

        guard case let .forbidden(forbidden) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbidden.body.json
        #expect(envelope.error.code == 1008)
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
    }

    @Test("getCurrentUser 404 USER_NOT_FOUND decodes as .notFound with a readable error envelope")
    func getCurrentUser404DecodesAsNotFound() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(.status(404), body: userNotFoundEnvelope())

        let output = try await client.getCurrentUser()

        guard case let .notFound(notFound) = output else {
            Issue.record("Expected .notFound but got \(output)")
            return
        }
        let envelope = try notFound.body.json
        #expect(envelope.error.code == 4002)
        #expect(envelope.error.errorCode == "USER_NOT_FOUND")
        #expect(envelope.error.message == "User not found")
    }

    // MARK: - logout

    @Test("logout 403 ACCOUNT_DISABLED decodes as .forbidden with a readable error envelope")
    func logout403DecodesAsForbidden() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(.status(403), body: accountDisabledEnvelope())

        let output = try await client.logout()

        guard case let .forbidden(forbidden) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbidden.body.json
        #expect(envelope.error.code == 1008)
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
    }

    @Test("logout 404 USER_NOT_FOUND decodes as .notFound with a readable error envelope")
    func logout404DecodesAsNotFound() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(.status(404), body: userNotFoundEnvelope())

        let output = try await client.logout()

        guard case let .notFound(notFound) = output else {
            Issue.record("Expected .notFound but got \(output)")
            return
        }
        let envelope = try notFound.body.json
        #expect(envelope.error.code == 4002)
        #expect(envelope.error.errorCode == "USER_NOT_FOUND")
    }
}
