// RefreshOn401MiddlewareTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

@Suite("RefreshOn401Middleware")
struct RefreshOn401MiddlewareTests {

    // MARK: - SUT

    private func makeSUT(
        refresher: any SessionRefreshing,
        tokenProvider: any AccessTokenProviding = FakeAccessTokenProvider(token: "initial-token")
    ) -> any ClientMiddleware {
        RefreshOn401Middleware(refresher: refresher, tokenProvider: tokenProvider)
    }

    private func callMiddleware(
        _ middleware: any ClientMiddleware,
        transport: FakeTransport,
        operationID: String = "listLists",
        method: HTTPRequest.Method = .get
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let request = HTTPRequest(method: method, scheme: nil, authority: nil, path: "/test")
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

    // MARK: - 1. Happy path: 401 triggers one refresh then replay returns 200

    @Test("401 on non-public operation triggers one refresh and replays with new token to get 200")
    func happyPath401TriggersRefreshAndReplay() async throws {
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .ok), nil)
        ])
        let refresher = FakeSessionRefresher()
        let sut = makeSUT(refresher: refresher)

        let (response, _) = try await callMiddleware(sut, transport: transport, operationID: "listLists")

        #expect(response.status.code == 200)
        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 1)
        let requestCount = await transport.requestCount
        #expect(requestCount == 2)
    }

    // MARK: - 2. Concurrent 401s cause exactly one refresh

    @Test("Concurrent 401 responses cause exactly one refresh call")
    func concurrent401sResultInSingleRefresh() async throws {
        let refresher = FakeSessionRefresher()
        let sut = makeSUT(refresher: refresher)

        // Each task will see 401 on first attempt and 200 on replay
        // We need enough scripted responses: 3 initial 401s + 3 replays
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .ok), nil),
            (HTTPResponse(status: .ok), nil),
            (HTTPResponse(status: .ok), nil)
        ])

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    _ = try? await self.callMiddleware(sut, transport: transport, operationID: "listLists")
                }
            }
        }

        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 1)
    }

    // MARK: - 3. Credential failure on refresh surfaces TrackerAPIError.unauthorized

    @Test("Credential failure during refresh surfaces TrackerAPIError.unauthorized with no replay")
    func credentialFailureOnRefreshSurfacesUnauthorized() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 401)))
        let refresher = FakeSessionRefresher()
        await refresher.setError(SessionRefreshError.credentialFailure)
        let sut = makeSUT(refresher: refresher)

        do {
            _ = try await callMiddleware(sut, transport: transport, operationID: "listLists")
            Issue.record("Expected TrackerAPIError.unauthorized to be thrown")
        } catch let error as TrackerAPIError {
            if case .unauthorized = error {
                // Expected
            } else {
                Issue.record("Expected .unauthorized but got \(error)")
            }
        }

        // No replay after credential failure
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }

    // MARK: - 4. Non-credential refresh failure is surfaced directly

    @Test("Non-credential refresh failure is surfaced without replay")
    func nonCredentialRefreshFailureSurfacedDirectly() async throws {
        struct NetworkError: Error {}
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 401)))
        let refresher = FakeSessionRefresher()
        await refresher.setError(SessionRefreshError.other(NetworkError()))
        let sut = makeSUT(refresher: refresher)

        var caughtError: Error?
        do {
            _ = try await callMiddleware(sut, transport: transport, operationID: "listLists")
            Issue.record("Expected an error to be thrown")
        } catch {
            caughtError = error
        }

        #expect(caughtError != nil)
        // Verify no replay happened
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }

    // MARK: - 5. Second 401 after replay surfaces TrackerAPIError.unauthorized without second refresh

    @Test("Second 401 after replay surfaces .unauthorized without triggering a second refresh")
    func second401AfterReplayIsUnauthorized() async throws {
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .init(code: 401)), nil)
        ])
        let refresher = FakeSessionRefresher()
        let sut = makeSUT(refresher: refresher)

        do {
            _ = try await callMiddleware(sut, transport: transport, operationID: "listLists")
            Issue.record("Expected TrackerAPIError.unauthorized")
        } catch let error as TrackerAPIError {
            if case .unauthorized = error {
                // Expected
            } else {
                Issue.record("Expected .unauthorized but got \(error)")
            }
        }

        // Exactly one refresh, no second attempt
        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 1)
    }

    // MARK: - 6. Non-re-iterable body is not replayed on 401

    @Test("Single-iteration body is not replayed on 401 — error surfaced directly")
    func nonReiterableBodyNotReplayed() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 401)))
        let refresher = FakeSessionRefresher()
        let sut = makeSUT(refresher: refresher)

        // Construct a single-iteration body using the AsyncStream init, which always
        // produces iterationBehavior: .single
        let singleIterationBody = HTTPBody(
            AsyncStream<HTTPBody.ByteChunk> { continuation in
                continuation.yield(ArraySlice("hello".utf8))
                continuation.finish()
            },
            length: .unknown
        )

        let request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/test")
        var threwError = false
        do {
            _ = try await sut.intercept(
                request,
                body: singleIterationBody,
                baseURL: makeBaseURL(),
                operationID: "createList",
                next: { req, body, url in
                    try await transport.send(req, body: body, baseURL: url, operationID: "createList")
                }
            )
        } catch {
            threwError = true
        }

        #expect(threwError, "Middleware must not replay a single-iteration body — it should surface an error")
        // No replay: only the original request was sent
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
        // No refresh attempted
        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 0)
    }

    // MARK: - 8. Stale-token 401 replays without calling refresh when token has already rotated

    @Test("Stale-token 401 replays without calling refresh when token has already rotated")
    func staleTokenReplaySkipsRefresh() async throws {
        // tokenProvider: first call returns "T1" (the token used in the initial request),
        //                second call returns "T2" (a new token, already rotated by another caller)
        let tokenProvider = FakeAccessTokenProvider(tokens: ["T1", "T2"])
        let transport = FakeTransport()
        await transport.enqueue([
            (HTTPResponse(status: .init(code: 401)), nil),
            (HTTPResponse(status: .ok), nil)
        ])
        let refresher = FakeSessionRefresher()
        let sut = RefreshOn401Middleware(refresher: refresher, tokenProvider: tokenProvider)

        let (response, _) = try await sut.intercept(
            HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/test"),
            body: nil,
            baseURL: makeBaseURL(),
            operationID: "listLists",
            next: { req, body, url in
                try await transport.send(req, body: body, baseURL: url, operationID: "listLists")
            }
        )

        #expect(response.status.code == 200)
        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 0, "No refresh should occur when token has already rotated")
        let requestCount = await transport.requestCount
        #expect(requestCount == 2, "One initial request + one replay")
    }

    // MARK: - 7. 401 on a public operation (login) is not refreshed

    @Test("401 on login (public operation) does not trigger refresh and returns response as-is")
    func publicOperation401NotRefreshed() async throws {
        let transport = FakeTransport()
        await transport.enqueue(HTTPResponse(status: .init(code: 401)))
        let refresher = FakeSessionRefresher()
        let sut = makeSUT(refresher: refresher)

        let (response, _) = try await callMiddleware(sut, transport: transport, operationID: "login")

        // Response should be returned without refresh
        #expect(response.status.code == 401)
        let refreshCount = await refresher.refreshCallCount
        #expect(refreshCount == 0)
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }
}
