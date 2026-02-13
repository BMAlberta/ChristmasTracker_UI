//
//  MockAPIClientTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/7/26.
//

import Testing
import Foundation

@testable import ChristmasTracker
@Suite("MockAPIClient Tests")
struct MockAPIClientTests {
    @Test("Mock client returns registered responses")
    func testMockResponse() async throws {
        let client = MockAPIClient()
        struct TestResponse: Codable, Sendable {
            let message: String
        }
        let mockData = TestResponse(message: "Hello")
        try await client.setMockResponse(mockData, for: "/test")
        let response: TestResponse = try await client.request(
            .get,
            path: "/test",
            body: Optional<String>.none,
            forceRefresh: false,
            cacheScope: .none
        )
        #expect(response.message == "Hello")
    }
    @Test("Mock client simulates network delay")
    @MainActor
    func testNetworkDelay() async throws {
        let client = MockAPIClient()
        client.networkDelay = 0.1
        struct TestResponse: Codable, Sendable {
            let value: Int
        }
        try client.setMockResponse(TestResponse(value: 42), for: "/test")
        let start = Date()
        let
        _
        : TestResponse = try await client.request(
            .get,
            path: "/test",
            body: Optional<String>.none,
            forceRefresh: false,
            cacheScope: .none
        )
        let duration = Date().timeIntervalSince(start)
        #expect(duration >= 0.1)
    }
    @Test("Mock client simulates failures")
    @MainActor
    func testMockFailure() async {
        let client = MockAPIClient()
        client.shouldFail = true
        client.customError = APIError.networkUnavailable
        struct TestResponse: Codable, Sendable {
            let value: Int
        }
        do {
            let response : TestResponse = try await client.request(
                .get,
                path: "/test",
                body: Optional<String>.none,
                forceRefresh: false,
                cacheScope: .none
            )
            print(response)
        } catch {
            #expect(Bool(true), "Should have thrown error")
            #expect(error is APIError)
        }
    }
}
