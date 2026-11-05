// RateLimitMiddlewareTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

@Suite("RateLimitMiddleware")
struct RateLimitMiddlewareTests {

    // MARK: - SUT

    private func makeSUT(sleeper: any RateLimitSleeping = FakeSleeper()) -> any ClientMiddleware {
        RateLimitMiddleware(sleeper: sleeper)
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

    private func make429Response(retryAfter: String? = nil) -> HTTPResponse {
        var fields = HTTPFields()
        if let retryAfter {
            fields[.init("Retry-After")!] = retryAfter
        }
        return HTTPResponse(status: .init(code: 429), headerFields: fields)
    }

    // MARK: - 1. GET retries on 429 with Retry-After header, then returns 200

    @Test("GET retries on 429, sleeps ~2 seconds from Retry-After header, final result is 200")
    func getRetriesOnTwoTwentyNineAndReturns200() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue([
            (make429Response(retryAfter: "2"), nil),
            (HTTPResponse(status: .ok), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        let (response, _) = try await callMiddleware(sut, transport: transport, method: .get)

        #expect(response.status.code == 200)
        let durations = await sleeper.sleepDurations
        #expect(durations.count == 1)
        #expect(abs(durations[0] - 2.0) < 0.001)
    }

    // MARK: - 2. GET retries up to 2 times then gives up with rateLimited

    @Test("GET retries at most 2 times on persistent 429, then surfaces rateLimited error")
    func getRetriesMaxTwiceThenRateLimited() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue([
            (make429Response(retryAfter: "1"), nil),
            (make429Response(retryAfter: "1"), nil),
            (make429Response(retryAfter: "1"), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        do {
            _ = try await callMiddleware(sut, transport: transport, method: .get)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            if case .rateLimited = error {
                // Expected
            } else {
                Issue.record("Expected .rateLimited but got \(error)")
            }
        }

        let sleepCount = await sleeper.sleepCallCount
        #expect(sleepCount == 2)
    }

    // MARK: - 3. Wait capped at 10 seconds

    @Test("Retry-After of 100 is capped to 10 seconds")
    func retryAfterCappedAt10Seconds() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue([
            (make429Response(retryAfter: "100"), nil),
            (HTTPResponse(status: .ok), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        _ = try await callMiddleware(sut, transport: transport, method: .get)

        let durations = await sleeper.sleepDurations
        #expect(durations.count == 1)
        #expect(durations[0] <= 10.0)
    }

    // MARK: - 4. Total wait cap: 2 retries attempted before 20 second total exceeded

    @Test("Total retry wait is bounded — no more than 2 retries when each sleep would be 10s")
    func totalWaitIsBounded() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        // Each retry would sleep 10s (100 capped to 10), 2 * 10 = 20 total
        await transport.enqueue([
            (make429Response(retryAfter: "100"), nil),
            (make429Response(retryAfter: "100"), nil),
            (make429Response(retryAfter: "100"), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        do {
            _ = try await callMiddleware(sut, transport: transport, method: .get)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            guard case .rateLimited = error else {
                Issue.record("Expected .rateLimited but got \(error)")
                return
            }
        }

        let sleepCount = await sleeper.sleepCallCount
        #expect(sleepCount <= 2)
    }

    // MARK: - 5. POST never retries on 429

    @Test("POST returns rateLimited immediately on 429 without sleeping")
    func postNeverRetriesOn429() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue(make429Response(retryAfter: "5"))
        let sut = makeSUT(sleeper: sleeper)

        do {
            _ = try await callMiddleware(sut, transport: transport, method: .post)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            if case .rateLimited = error {
                // Expected
            } else {
                Issue.record("Expected .rateLimited but got \(error)")
            }
        }

        let sleepCount = await sleeper.sleepCallCount
        #expect(sleepCount == 0)
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }

    // MARK: - 6. DELETE never retries on 429

    @Test("DELETE returns rateLimited immediately on 429 without sleeping")
    func deleteNeverRetriesOn429() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue(make429Response(retryAfter: "5"))
        let sut = makeSUT(sleeper: sleeper)

        do {
            _ = try await callMiddleware(sut, transport: transport, method: .delete)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            if case .rateLimited = error {
                // Expected
            } else {
                Issue.record("Expected .rateLimited but got \(error)")
            }
        }

        let sleepCount = await sleeper.sleepCallCount
        #expect(sleepCount == 0)
        let requestCount = await transport.requestCount
        #expect(requestCount == 1)
    }

    // MARK: - 7. retryAfter from JSON body takes priority over Retry-After header

    @Test("retryAfter from error details JSON body takes priority over Retry-After header")
    func bodyRetryAfterTakesPriorityOverHeader() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()

        // Header says 5s, body says 3s — body should win
        let jsonBody = HTTPBody("""
        {
            "success": false,
            "error": {
                "code": 4290,
                "errorCode": "RATE_LIMITED",
                "message": "Too many requests",
                "details": {
                    "retryAfter": 3
                }
            }
        }
        """)
        await transport.enqueue([
            (make429Response(retryAfter: "5"), jsonBody),
            (HTTPResponse(status: .ok), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        _ = try await callMiddleware(sut, transport: transport, method: .get)

        let durations = await sleeper.sleepDurations
        #expect(durations.count == 1)
        #expect(abs(durations[0] - 3.0) < 0.001)
    }

    // MARK: - 8. rateLimited error carries retryAfter value

    @Test("TrackerAPIError.rateLimited carries the correct retryAfter value")
    func rateLimitedErrorCarriesRetryAfter() async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue([
            (make429Response(retryAfter: "7"), nil),
            (make429Response(retryAfter: "7"), nil),
            (make429Response(retryAfter: "7"), nil)
        ])
        let sut = makeSUT(sleeper: sleeper)

        do {
            _ = try await callMiddleware(sut, transport: transport, method: .get)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            if case .rateLimited(let retryAfter) = error {
                #expect(retryAfter > 0)
            } else {
                Issue.record("Expected .rateLimited but got \(error)")
            }
        }
    }
}
