// HeadersMiddlewareTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

// MARK: - HeadersMiddlewareTests

@Suite("HeadersMiddleware")
struct HeadersMiddlewareTests {

    private func makeSUT(
        info: AppClientInfo = AppClientInfo(
            platform: "ios",
            clientPlatform: "ios",
            build: "42",
            version: "1.0.0"
        ),
        observer: (any RequestIDObserving)? = nil
    ) -> any ClientMiddleware {
        HeadersMiddleware(info: info, requestIDObserver: observer)
    }

    private func sendThrough(
        middleware: any ClientMiddleware,
        transport: FakeTransport,
        operationID: String
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

    // MARK: - 1. Public operation carries all four named headers

    @Test("Public operation (login) carries X-Platform, X-Build, X-App-Version, X-Client-Platform")
    func publicOperationHasRequiredHeaders() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        let headers = recorded.request.headerFields
        #expect(headers[.init("X-Platform")!] != nil)
        #expect(headers[.init("X-Build")!] != nil)
        #expect(headers[.init("X-App-Version")!] != nil)
        #expect(headers[.init("X-Client-Platform")!] != nil)
    }

    // MARK: - 2. Authenticated operation carries all four named headers

    @Test("Authenticated operation (listLists) carries X-Platform, X-Build, X-App-Version, X-Client-Platform")
    func authenticatedOperationHasRequiredHeaders() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "listLists")

        let recorded = try #require(await transport.lastRequest())
        let headers = recorded.request.headerFields
        #expect(headers[.init("X-Platform")!] != nil)
        #expect(headers[.init("X-Build")!] != nil)
        #expect(headers[.init("X-App-Version")!] != nil)
        #expect(headers[.init("X-Client-Platform")!] != nil)
    }

    // MARK: - 3. X-Request-Id is a valid UUID

    @Test("X-Request-Id header is a valid UUID string")
    func requestIdIsValidUUID() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "getList")

        let recorded = try #require(await transport.lastRequest())
        let requestIdValue = try #require(recorded.request.headerFields[.init("X-Request-Id")!])
        let uuid = UUID(uuidString: requestIdValue)
        #expect(uuid != nil, "X-Request-Id '\(requestIdValue)' must be a valid UUID")
    }

    // MARK: - 4. Two different requests get different X-Request-Id values

    @Test("Two requests receive different X-Request-Id values")
    func twoRequestsGetDifferentRequestIDs() async throws {
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .ok), nil),
            (HTTPResponse(status: .ok), nil)
        ])
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "getList")
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "getList")

        let requests = await transport.recordedRequests
        #expect(requests.count == 2)
        let id1 = try #require(requests[0].request.headerFields[.init("X-Request-Id")!])
        let id2 = try #require(requests[1].request.headerFields[.init("X-Request-Id")!])
        #expect(id1 != id2)
    }

    // MARK: - 5. RequestIDObserving callback receives same UUID as sent in header

    @Test("RequestIDObserving callback receives the same UUID that was sent in X-Request-Id header")
    func requestIDObserverReceivesSameUUIDAsHeader() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let observer = FakeRequestIDObserver()
        let sut = makeSUT(observer: observer)
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        let headerID = try #require(recorded.request.headerFields[.init("X-Request-Id")!])
        let observedIDs = await observer.observedIDs
        #expect(observedIDs.count == 1)
        #expect(observedIDs.first == headerID)
    }

    // MARK: - Header value correctness

    @Test("X-Platform header value is 'ios'")
    func xPlatformIsIos() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "10", version: "2.0.0"))
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.init("X-Platform")!] == "ios")
    }

    @Test("X-Client-Platform header value is 'ios'")
    func xClientPlatformIsIos() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "10", version: "2.0.0"))
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.init("X-Client-Platform")!] == "ios")
    }

    @Test("X-Build header reflects the build string from AppClientInfo")
    func xBuildReflectsBuildString() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "99", version: "3.1.0"))
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.init("X-Build")!] == "99")
    }

    @Test("X-App-Version header reflects the version string from AppClientInfo")
    func xAppVersionReflectsVersionString() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "99", version: "3.1.0"))
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.init("X-App-Version")!] == "3.1.0")
    }
}

// MARK: - BearerAuthMiddlewareTests

@Suite("BearerAuthMiddleware")
struct BearerAuthMiddlewareTests {

    private func makeSUT(token: String? = "test-token") -> any ClientMiddleware {
        BearerAuthMiddleware(tokenProvider: FakeAccessTokenProvider(token: token))
    }

    private func sendThrough(
        middleware: any ClientMiddleware,
        transport: FakeTransport,
        operationID: String
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

    // MARK: - 6. No bearer token for public operations

    @Test("login operation does not get an Authorization header")
    func loginHasNoBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "login")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.authorization] == nil)
    }

    @Test("register operation does not get an Authorization header")
    func registerHasNoBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "register")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.authorization] == nil)
    }

    @Test("checkAppVersion operation does not get an Authorization header")
    func checkAppVersionHasNoBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "checkAppVersion")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.authorization] == nil)
    }

    @Test("refreshToken operation does not get an Authorization header")
    func refreshTokenHasNoBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT()
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "refreshToken")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.authorization] == nil)
    }

    // MARK: - 7. Bearer token IS attached for authenticated operations when token exists

    @Test("Authenticated operation (listLists) gets Authorization: Bearer <token>")
    func authenticatedOperationGetsBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(token: "my-access-token")
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "listLists")

        let recorded = try #require(await transport.lastRequest())
        let authHeader = try #require(recorded.request.headerFields[.authorization])
        #expect(authHeader == "Bearer my-access-token")
    }

    @Test("Authenticated operation (getList) gets Authorization: Bearer <token>")
    func getListGetsBearerToken() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(token: "another-token")
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "getList")

        let recorded = try #require(await transport.lastRequest())
        let authHeader = try #require(recorded.request.headerFields[.authorization])
        #expect(authHeader == "Bearer another-token")
    }

    // MARK: - 8. No bearer token when provider returns nil

    @Test("No Authorization header when token provider returns nil")
    func noTokenWhenProviderReturnsNil() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(token: nil)
        _ = try await sendThrough(middleware: sut, transport: transport, operationID: "listLists")

        let recorded = try #require(await transport.lastRequest())
        #expect(recorded.request.headerFields[.authorization] == nil)
    }
}
