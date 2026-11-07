// SessionEndingMiddlewareTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Package I2b-2c, story U2 (client guide section 4, middleware statuses on
// authenticated endpoints, C15).
//
// Pins SessionEndingMiddleware: on a non-public operation, a 403 whose envelope has
// errorCode ACCOUNT_DISABLED or a 404 whose envelope has errorCode USER_NOT_FOUND calls
// the SessionEnding handler exactly once per response, and the response body is
// returned still readable and byte-identical. Never for FORBIDDEN, LIST_NOT_FOUND, other
// codes, public operations, 2xx, or unreadable bodies.
//
// Envelopes follow Docs/client-guide.md section 4 (full meta object); codes and
// messages follow Docs/error-codes.md. No network, no sleeps.
//
// Fails to compile until the implementer adds SessionEndReason, SessionEnding,
// SessionEndingMiddleware, and TrackerClientFactory.make(sessionEndingHandler:).

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import TrackerAPI

// MARK: - RecordingSessionEndingHandler

/// Records every reason it receives, in order.
private actor RecordingSessionEndingHandler: SessionEnding {
    private(set) var reasons: [SessionEndReason] = []

    func sessionEnded(reason: SessionEndReason) async {
        reasons.append(reason)
    }

    var callCount: Int { reasons.count }
}

// MARK: - RotatingSession

/// A token provider and refresher sharing one token: refresh() rotates "T1" to "T2".
// @unchecked Sendable: NSLock protects all mutable state (token, refreshCallCount).
private final class RotatingSession: AccessTokenProviding, SessionRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var token = "T1"
    private var _refreshCallCount = 0

    var refreshCallCount: Int { lock.withLock { _refreshCallCount } }

    func accessToken() async -> String? {
        lock.withLock { token }
    }

    func refresh() async throws {
        lock.withLock {
            _refreshCallCount += 1
            token = "T2"
        }
    }
}

// MARK: - Suite

@Suite("SessionEndingMiddleware")
struct SessionEndingMiddlewareTests {

    // MARK: - SUT

    private func makeSUT(handler: any SessionEnding) -> any ClientMiddleware {
        SessionEndingMiddleware(handler: handler)
    }

    private func callMiddleware(
        _ middleware: any ClientMiddleware,
        transport: FakeTransport,
        operationID: String = "getCurrentUser"
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test")
        return try await middleware.intercept(
            request,
            body: nil,
            baseURL: makeBaseURL(),
            operationID: operationID,
            next: { req, body, url in
                try await transport.send(req, body: body, baseURL: url, operationID: operationID)
            }
        )
    }

    private func collect(_ body: HTTPBody?) async throws -> Data {
        let resolved = try #require(body, "Expected a non-nil response body")
        return try await Data(collecting: resolved, upTo: 1024 * 1024)
    }

    // MARK: - Fixtures

    /// Error envelope in the shape of Docs/client-guide.md section 4, full meta object.
    private func envelopeString(code: Int, errorCode: String, message: String) -> String {
        """
        {
          "success": false,
          "error": {
            "code": \(code),
            "errorCode": "\(errorCode)",
            "message": "\(message)",
            "details": {}
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00.000Z",
            "requestId": "req-abc123",
            "sessionId": "ses-abc123"
          }
        }
        """
    }

    private var accountDisabled: String {
        envelopeString(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled")
    }

    private var userNotFound: String {
        envelopeString(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    }

    private var forbidden: String {
        envelopeString(code: 2001, errorCode: "FORBIDDEN", message: "Access forbidden")
    }

    private var listNotFound: String {
        envelopeString(code: 4003, errorCode: "LIST_NOT_FOUND", message: "List not found")
    }

    // MARK: - 1. 403 ACCOUNT_DISABLED on a non-public operation

    @Test(
        "403 ACCOUNT_DISABLED on a non-public operation calls the handler once with .accountDisabled",
        arguments: ["getCurrentUser", "logout", "listLists"]
    )
    func accountDisabledCallsHandlerOnce(operationID: String) async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(403), body: HTTPBody(accountDisabled))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport, operationID: operationID)

        #expect(response.status.code == 403)
        #expect(await handler.reasons == [.accountDisabled])
    }

    @Test("403 ACCOUNT_DISABLED response body is still readable and byte-identical")
    func accountDisabledBodyIsByteIdentical() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = accountDisabled
        await transport.enqueue(.status(403), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (_, body) = try await callMiddleware(sut, transport: transport)

        let data = try await collect(body)
        #expect(data == Data(original.utf8))
        #expect(await handler.callCount == 1)
    }

    @Test("403 ACCOUNT_DISABLED is never retried: the transport is called exactly once")
    func accountDisabledIsNotRetried() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue([
            (.status(403), HTTPBody(accountDisabled)),
            (.ok(), nil)
        ])
        let sut = makeSUT(handler: handler)

        _ = try await callMiddleware(sut, transport: transport)

        #expect(await transport.requestCount == 1)
    }

    @Test("A minimal envelope with only error.errorCode ACCOUNT_DISABLED still calls the handler")
    func minimalEnvelopeIsTolerated() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(403), body: HTTPBody(#"{ "error": { "errorCode": "ACCOUNT_DISABLED" }, "extra": [1, 2] }"#))
        let sut = makeSUT(handler: handler)

        _ = try await callMiddleware(sut, transport: transport)

        #expect(await handler.reasons == [.accountDisabled])
    }

    // MARK: - 2. 404 USER_NOT_FOUND on a non-public operation

    @Test(
        "404 USER_NOT_FOUND on a non-public operation calls the handler once with .userNotFound",
        arguments: ["getCurrentUser", "logout", "listLists"]
    )
    func userNotFoundCallsHandlerOnce(operationID: String) async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(404), body: HTTPBody(userNotFound))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport, operationID: operationID)

        #expect(response.status.code == 404)
        #expect(await handler.reasons == [.userNotFound])
    }

    @Test("404 USER_NOT_FOUND response body is still readable and byte-identical")
    func userNotFoundBodyIsByteIdentical() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = userNotFound
        await transport.enqueue(.status(404), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (_, body) = try await callMiddleware(sut, transport: transport)

        let data = try await collect(body)
        #expect(data == Data(original.utf8))
        #expect(await handler.callCount == 1)
    }

    // MARK: - 3. Other 403 and 404 codes do not end the session

    @Test("403 FORBIDDEN does not call the handler and the body is still readable")
    func forbiddenDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = forbidden
        await transport.enqueue(.status(403), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (response, body) = try await callMiddleware(sut, transport: transport, operationID: "getList")

        #expect(response.status.code == 403)
        #expect(try await collect(body) == Data(original.utf8))
        #expect(await handler.callCount == 0)
    }

    @Test("404 LIST_NOT_FOUND does not call the handler and the body is still readable")
    func listNotFoundDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = listNotFound
        await transport.enqueue(.status(404), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (response, body) = try await callMiddleware(sut, transport: transport, operationID: "getList")

        #expect(response.status.code == 404)
        #expect(try await collect(body) == Data(original.utf8))
        #expect(await handler.callCount == 0)
    }

    @Test("404 carrying ACCOUNT_DISABLED does not call the handler (status and code must pair)")
    func accountDisabledOn404DoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(404), body: HTTPBody(accountDisabled))
        let sut = makeSUT(handler: handler)

        _ = try await callMiddleware(sut, transport: transport)

        #expect(await handler.callCount == 0)
    }

    @Test("403 carrying USER_NOT_FOUND does not call the handler (status and code must pair)")
    func userNotFoundOn403DoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(403), body: HTTPBody(userNotFound))
        let sut = makeSUT(handler: handler)

        _ = try await callMiddleware(sut, transport: transport)

        #expect(await handler.callCount == 0)
    }

    @Test(
        "Other error statuses carrying ACCOUNT_DISABLED do not call the handler",
        arguments: [400, 401, 409, 500]
    )
    func otherStatusesDoNotCallHandler(statusCode: Int) async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(statusCode), body: HTTPBody(accountDisabled))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == statusCode)
        #expect(await handler.callCount == 0)
    }

    // MARK: - 4. Public operations never end the session

    @Test(
        "403 ACCOUNT_DISABLED on a public operation does not call the handler",
        arguments: publicOperationIDs.sorted()
    )
    func publicOperation403DoesNotCallHandler(operationID: String) async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = accountDisabled
        await transport.enqueue(.status(403), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (response, body) = try await callMiddleware(sut, transport: transport, operationID: operationID)

        #expect(response.status.code == 403)
        #expect(try await collect(body) == Data(original.utf8))
        #expect(await handler.callCount == 0)
    }

    @Test("404 USER_NOT_FOUND on login (public operation) does not call the handler")
    func publicOperation404DoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(404), body: HTTPBody(userNotFound))
        let sut = makeSUT(handler: handler)

        _ = try await callMiddleware(sut, transport: transport, operationID: "login")

        #expect(await handler.callCount == 0)
    }

    // MARK: - 5. 2xx and unreadable bodies

    @Test("200 does not call the handler and the body passes through unchanged")
    func okDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = #"{ "success": true, "data": { "errorCode": "ACCOUNT_DISABLED" } }"#
        await transport.enqueue(.ok(), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (response, body) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 200)
        #expect(try await collect(body) == Data(original.utf8))
        #expect(await handler.callCount == 0)
    }

    @Test("403 with a non-JSON body does not call the handler, does not throw, and the body is readable")
    func nonJSONBodyDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        let original = "<html><body>Forbidden</body></html>"
        await transport.enqueue(.status(403), body: HTTPBody(original))
        let sut = makeSUT(handler: handler)

        let (response, body) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 403)
        #expect(try await collect(body) == Data(original.utf8))
        #expect(await handler.callCount == 0)
    }

    @Test("403 with an empty body does not call the handler and does not throw")
    func emptyBodyDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(403), body: HTTPBody(""))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 403)
        #expect(await handler.callCount == 0)
    }

    @Test("404 with no body does not call the handler and does not throw")
    func nilBodyDoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        await transport.enqueue(.status(404), body: nil)
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 404)
        #expect(await handler.callCount == 0)
    }

    // MARK: - 6. Concurrent responses each call the handler

    @Test("Concurrent requests that each get 403 ACCOUNT_DISABLED each call the handler once")
    func concurrentResponsesEachCallHandler() async throws {
        let requestCount = 5
        let handler = RecordingSessionEndingHandler()
        let transport = FakeTransport()
        for _ in 0..<requestCount {
            await transport.enqueue(.status(403), body: HTTPBody(accountDisabled))
        }
        let sut = makeSUT(handler: handler)

        let statusCodes = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<requestCount {
                group.addTask {
                    let (response, _) = try await callMiddleware(sut, transport: transport)
                    return response.status.code
                }
            }
            var codes: [Int] = []
            for try await code in group {
                codes.append(code)
            }
            return codes
        }

        #expect(statusCodes == Array(repeating: 403, count: requestCount))
        #expect(await handler.callCount == requestCount)
        #expect(await handler.reasons.allSatisfy { $0 == .accountDisabled })
    }

    // MARK: - 7. Through the real TrackerClientFactory.make

    private func makeFactoryClient(
        sessionEndingHandler: any SessionEnding,
        token: String? = "test-access-token"
    ) throws -> (client: Client, transport: FakeTransport) {
        let transport = FakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: makeBaseURL(),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: FakeAccessTokenProvider(token: token),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            requestIDObserver: nil,
            sessionEndingHandler: sessionEndingHandler,
            transport: transport
        )
        return (client, transport)
    }

    @Test("Factory client: getCurrentUser 403 ACCOUNT_DISABLED calls the handler once and still decodes as .forbidden")
    func factoryGetCurrentUser403CallsHandlerAndDecodes() async throws {
        let handler = RecordingSessionEndingHandler()
        let (client, transport) = try makeFactoryClient(sessionEndingHandler: handler)
        await transport.enqueue(.status(403), body: HTTPBody(accountDisabled))

        let output = try await client.getCurrentUser()

        guard case let .forbidden(forbiddenOutput) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbiddenOutput.body.json
        #expect(envelope.error.code == 1008)
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
        #expect(await handler.reasons == [.accountDisabled])
        #expect(await transport.requestCount == 1)
    }

    @Test("Factory client: getCurrentUser 404 USER_NOT_FOUND calls the handler once and still decodes as .notFound")
    func factoryGetCurrentUser404CallsHandlerAndDecodes() async throws {
        let handler = RecordingSessionEndingHandler()
        let (client, transport) = try makeFactoryClient(sessionEndingHandler: handler)
        await transport.enqueue(.status(404), body: HTTPBody(userNotFound))

        let output = try await client.getCurrentUser()

        guard case let .notFound(notFoundOutput) = output else {
            Issue.record("Expected .notFound but got \(output)")
            return
        }
        let envelope = try notFoundOutput.body.json
        #expect(envelope.error.code == 4002)
        #expect(envelope.error.errorCode == "USER_NOT_FOUND")
        #expect(await handler.reasons == [.userNotFound])
    }

    @Test("Factory client: login 403 ACCOUNT_DISABLED does not call the handler and still decodes as .forbidden")
    func factoryLogin403DoesNotCallHandler() async throws {
        let handler = RecordingSessionEndingHandler()
        let (client, transport) = try makeFactoryClient(sessionEndingHandler: handler, token: nil)
        await transport.enqueue(.status(403), body: HTTPBody(accountDisabled))

        let output = try await client.login(
            .init(body: .json(.init(email: "alice@test.invalid", password: "password-FAKE")))
        )

        guard case let .forbidden(forbiddenOutput) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbiddenOutput.body.json
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
        #expect(await handler.callCount == 0)
    }

    @Test("Factory client: 401, refresh, replay 403 ACCOUNT_DISABLED calls the handler once (SessionEnding inside RefreshOn401)")
    func factoryRefreshThenAccountDisabledCallsHandlerOnce() async throws {
        let handler = RecordingSessionEndingHandler()
        let session = RotatingSession()
        let transport = FakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: makeBaseURL(),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: session,
            sessionRefresher: session,
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            requestIDObserver: nil,
            sessionEndingHandler: handler,
            transport: transport
        )
        await transport.enqueue([
            (.status(401), HTTPBody(envelopeString(code: 1002, errorCode: "TOKEN_EXPIRED", message: "Your session has expired. Please log in again"))),
            (.status(403), HTTPBody(accountDisabled))
        ])

        let output = try await client.getCurrentUser()

        guard case let .forbidden(forbiddenOutput) = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
        let envelope = try forbiddenOutput.body.json
        #expect(envelope.error.errorCode == "ACCOUNT_DISABLED")
        #expect(session.refreshCallCount == 1)
        #expect(await handler.reasons == [.accountDisabled])
        #expect(await transport.requestCount == 2)
        let replay = try #require(await transport.lastRequest())
        #expect(replay.request.headerFields[.authorization] == "Bearer T2")
    }

    @Test("Factory client: make() without sessionEndingHandler still builds and decodes getCurrentUser 403")
    func factoryWithoutHandlerStillWorks() async throws {
        let transport = FakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: makeBaseURL(),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
        await transport.enqueue(.status(403), body: HTTPBody(accountDisabled))

        let output = try await client.getCurrentUser()

        guard case .forbidden = output else {
            Issue.record("Expected .forbidden but got \(output)")
            return
        }
    }
}
