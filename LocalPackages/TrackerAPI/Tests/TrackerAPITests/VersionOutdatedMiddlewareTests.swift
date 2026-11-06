// VersionOutdatedMiddlewareTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

@Suite("VersionOutdatedMiddleware")
struct VersionOutdatedMiddlewareTests {

    // MARK: - SUT

    private func makeSUT(handler: any VersionOutdatedHandling) -> any ClientMiddleware {
        VersionOutdatedMiddleware(handler: handler)
    }

    private func callMiddleware(
        _ middleware: any ClientMiddleware,
        transport: FakeTransport,
        operationID: String = "listLists"
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

    private func make426Body(minimumVersion: String = "2.0.0") -> HTTPBody {
        HTTPBody("""
        {
            "minimumVersion": "\(minimumVersion)",
            "minimumBuild": 10,
            "latestVersion": "2.1.0",
            "latestBuild": 20,
            "manifestUrl": null,
            "ipaUrl": "https://example.com/app.ipa"
        }
        """)
    }

    // MARK: - 1. 426 calls handler exactly once with correct details

    @Test("426 response calls VersionOutdatedHandling exactly once with correct minimumVersion")
    func fourTwoSixCallsHandlerOnce() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 426)), body: make426Body(minimumVersion: "2.0.0"))
        let sut = makeSUT(handler: handler)

        _ = try? await callMiddleware(sut, transport: transport)

        let callCount = await handler.callCount
        #expect(callCount == 1)
        let details = await handler.lastDetails
        let resolved = try #require(details)
        #expect(resolved.minimumVersion == "2.0.0")
    }

    // MARK: - 2. 426 body is buffered and readable by caller

    @Test("426 response body is buffered so caller can still read it after middleware processing")
    func fourTwoSixBodyIsBufferedForCaller() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        let body426 = make426Body(minimumVersion: "3.0.0")
        await transport.enqueue(HTTPResponse(status: .init(code: 426)), body: body426)
        let sut = makeSUT(handler: handler)

        let (response, returnedBody) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 426)
        // Body must be non-nil and readable (can be collected)
        let resolvedBody = try #require(returnedBody)
        let bodyData = try await Data(collecting: resolvedBody, upTo: 1024 * 1024)
        #expect(bodyData.isEmpty == false)
    }

    // MARK: - 3. 426 never retries — exactly one transport call

    @Test("426 response never causes a retry — transport called exactly once")
    func fourTwoSixNeverRetries() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .init(code: 426)), make426Body()),
            (HTTPResponse(status: .ok), nil)
        ])
        let sut = makeSUT(handler: handler)

        _ = try? await callMiddleware(sut, transport: transport)

        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }

    // MARK: - 4. 426 on a public operation also triggers handler

    @Test("426 on login (public operation) also triggers the VersionOutdatedHandling callback")
    func fourTwoSixOnPublicOperationTriggersHandler() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 426)), body: make426Body())
        let sut = makeSUT(handler: handler)

        _ = try? await callMiddleware(sut, transport: transport, operationID: "login")

        let callCount = await handler.callCount
        #expect(callCount == 1)
    }

    // MARK: - 5. Other status codes pass through without calling handler

    @Test("403 response does not call VersionOutdatedHandling")
    func fourOhThreeDoesNotCallHandler() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 403)))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 403)
        let callCount = await handler.callCount
        #expect(callCount == 0)
    }

    @Test("200 response does not call VersionOutdatedHandling")
    func twoHundredDoesNotCallHandler() async throws {
        let handler = FakeVersionOutdatedHandler()
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .ok))
        let sut = makeSUT(handler: handler)

        let (response, _) = try await callMiddleware(sut, transport: transport)

        #expect(response.status.code == 200)
        let callCount = await handler.callCount
        #expect(callCount == 0)
    }
}
