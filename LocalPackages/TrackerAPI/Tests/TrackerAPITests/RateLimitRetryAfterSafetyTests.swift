// RateLimitRetryAfterSafetyTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// I3a-H2 (hardening): a negative, NaN, infinite, "1e999" or huge Retry-After (header or
// error.details.retryAfter) must never crash and must never produce a wait outside [0, cap].
// Rules under test:
//   - the parsed wait is clamped to at least 0 and at most the single-wait cap (10 seconds);
//   - a non-finite value is treated as ABSENT (the next source, then the 1 second default, is used).

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

@Suite("RateLimitMiddleware Retry-After safety")
struct RateLimitRetryAfterSafetyTests {

    private static let cap: TimeInterval = 10
    private static let defaultWait: TimeInterval = 1

    /// A header value (or body number) and the wait the middleware must apply for it when it is
    /// the only source.
    struct Case: Sendable, CustomTestStringConvertible {
        let text: String
        let expectedWait: TimeInterval
        var testDescription: String { text }
    }

    static let headerCases: [Case] = [
        Case(text: "-5", expectedWait: 0),
        Case(text: "nan", expectedWait: defaultWait),
        Case(text: "inf", expectedWait: defaultWait),
        Case(text: "-inf", expectedWait: defaultWait),
        Case(text: "1e999", expectedWait: defaultWait),
        Case(text: "1e300", expectedWait: cap),
        Case(text: "1.7976931348623157e308", expectedWait: cap),
    ]

    /// JSON numbers only; NaN and Infinity are not valid JSON numbers, so those tokens are
    /// covered separately by `invalidJSONTokens`.
    static let bodyCases: [Case] = [
        Case(text: "-5", expectedWait: 0),
        Case(text: "1e999", expectedWait: defaultWait),
        Case(text: "1e300", expectedWait: cap),
        Case(text: "1.7976931348623157e308", expectedWait: cap),
    ]

    static let invalidJSONTokens: [String] = ["NaN", "Infinity", "-Infinity"]

    // MARK: - SUT

    private func makeSUT(sleeper: any RateLimitSleeping) -> any ClientMiddleware {
        RateLimitMiddleware(sleeper: sleeper)
    }

    private func call(
        _ middleware: any ClientMiddleware,
        transport: FakeTransport,
        method: HTTPRequest.Method = .get
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let request = HTTPRequest(method: method, scheme: nil, authority: nil, path: "/test")
        return try await middleware.intercept(
            request,
            body: nil,
            baseURL: makeBaseURL(),
            operationID: "listLists",
            next: { req, body, url in
                try await transport.send(req, body: body, baseURL: url, operationID: "listLists")
            }
        )
    }

    private func response429(header: String? = nil) throws -> HTTPResponse {
        var fields = HTTPFields()
        if let header {
            let name = try #require(HTTPField.Name("Retry-After"))
            fields[name] = header
        }
        return HTTPResponse(status: .init(code: 429), headerFields: fields)
    }

    private func body(retryAfterLiteral literal: String) -> HTTPBody {
        HTTPBody("""
        {"success": false, "error": {"code": 4290, "errorCode": "RATE_LIMITED", \
        "message": "Too many requests", "details": {"retryAfter": \(literal)}}}
        """)
    }

    /// Runs one GET that is rate limited once and then succeeds; returns the single sleep.
    private func singleWait(header: String?, body: HTTPBody?) async throws -> TimeInterval {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue([
            (try response429(header: header), body),
            (HTTPResponse(status: .ok), nil)
        ])
        let (response, _) = try await call(makeSUT(sleeper: sleeper), transport: transport)
        #expect(response.status.code == 200)
        let durations = await sleeper.sleepDurations
        try #require(durations.count == 1, "One retry means exactly one sleep")
        return durations[0]
    }

    // MARK: - Header

    @Test("Retry-After header value is clamped to [0, cap] or ignored when non-finite", arguments: headerCases)
    func headerValueYieldsSafeWait(_ testCase: Case) async throws {
        let wait = try await singleWait(header: testCase.text, body: nil)

        #expect(wait.isFinite)
        #expect(wait >= 0 && wait <= Self.cap)
        #expect(wait == testCase.expectedWait)
    }

    // MARK: - Body details.retryAfter

    @Test("details.retryAfter is clamped to [0, cap] or ignored when non-finite", arguments: bodyCases)
    func bodyValueYieldsSafeWait(_ testCase: Case) async throws {
        let wait = try await singleWait(header: nil, body: body(retryAfterLiteral: testCase.text))

        #expect(wait.isFinite)
        #expect(wait >= 0 && wait <= Self.cap)
        #expect(wait == testCase.expectedWait)
    }

    @Test("A non-finite details.retryAfter is absent, so a finite header is used", arguments: ["1e999", "-1e999"])
    func nonFiniteBodyFallsBackToHeader(_ literal: String) async throws {
        let wait = try await singleWait(header: "3", body: body(retryAfterLiteral: literal))

        #expect(wait == 3)
    }

    @Test("Invalid JSON number tokens (NaN, Infinity) never crash and use the default", arguments: invalidJSONTokens)
    func invalidJSONTokenUsesDefault(_ token: String) async throws {
        let wait = try await singleWait(header: nil, body: body(retryAfterLiteral: token))

        #expect(wait == Self.defaultWait)
    }

    @Test("A non-finite header is absent, so a finite details.retryAfter is not displaced", arguments: ["nan", "inf", "-inf", "1e999"])
    func nonFiniteHeaderWithFiniteBody(_ header: String) async throws {
        let wait = try await singleWait(header: header, body: body(retryAfterLiteral: "4"))

        #expect(wait == 4)
    }

    // MARK: - Surfaced error

    @Test("A POST 429 surfaces rateLimited with a finite retryAfter within [0, cap]", arguments: headerCases)
    func surfacedRetryAfterIsFiniteAndWithinCap(_ testCase: Case) async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        await transport.enqueue(try response429(header: testCase.text))

        do {
            _ = try await call(makeSUT(sleeper: sleeper), transport: transport, method: .post)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch let error as TrackerAPIError {
            guard case .rateLimited(let retryAfter) = error else {
                Issue.record("Expected .rateLimited but got \(error)")
                return
            }
            #expect(retryAfter.isFinite)
            #expect(retryAfter >= 0 && retryAfter <= Self.cap)
            #expect(retryAfter == testCase.expectedWait)
        }
        #expect(await sleeper.sleepCallCount == 0)
    }

    @Test("Persistent 429 with a hostile header never traps and sleeps stay within [0, cap]", arguments: headerCases)
    func persistentHostileHeaderStaysBounded(_ testCase: Case) async throws {
        let sleeper = FakeSleeper()
        let transport = FakeTransport()
        let hostile = try response429(header: testCase.text)
        await transport.enqueue([(hostile, nil), (hostile, nil), (hostile, nil)])

        do {
            _ = try await call(makeSUT(sleeper: sleeper), transport: transport)
            Issue.record("Expected TrackerAPIError.rateLimited")
        } catch is TrackerAPIError {
            // Expected
        }

        let durations = await sleeper.sleepDurations
        #expect(durations.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= Self.cap })
        #expect(durations.count <= 2)
    }
}
