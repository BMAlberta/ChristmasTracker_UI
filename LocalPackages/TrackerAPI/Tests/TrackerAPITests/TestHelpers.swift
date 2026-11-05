// TestHelpers.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI

// MARK: - FakeTransport

/// A fake ClientTransport that records requests sent through it and returns
/// pre-scripted (response, body) pairs in FIFO order. If the script is
/// exhausted it returns a 200 OK with no body.
actor FakeTransport: ClientTransport {
    struct RecordedRequest {
        let request: HTTPRequest
        let body: HTTPBody?
        let baseURL: URL
        let operationID: String
    }

    private var scriptedResponses: [(HTTPResponse, HTTPBody?)] = []
    private(set) var recordedRequests: [RecordedRequest] = []

    /// Enqueue a response that will be returned on the next `send` call.
    func enqueue(_ response: HTTPResponse, body: HTTPBody? = nil) {
        scriptedResponses.append((response, body))
    }

    /// Enqueue several responses at once.
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

    var requestCount: Int { recordedRequests.count }

    func lastRequest() -> RecordedRequest? { recordedRequests.last }
}

// MARK: - FakeAccessTokenProvider

final class FakeAccessTokenProvider: AccessTokenProviding {
    private let token: String?
    init(token: String? = "test-access-token") {
        self.token = token
    }
    func accessToken() async -> String? { token }
}

// MARK: - FakeSessionRefresher

actor FakeSessionRefresher: SessionRefreshing {
    private(set) var refreshCallCount = 0
    var errorToThrow: Error?

    func setError(_ error: Error?) {
        errorToThrow = error
    }

    func refresh() async throws {
        refreshCallCount += 1
        if let error = errorToThrow {
            throw error
        }
    }
}

// MARK: - FakeVersionOutdatedHandler

actor FakeVersionOutdatedHandler: VersionOutdatedHandling {
    private(set) var callCount = 0
    private(set) var lastDetails: VersionOutdatedDetails?

    func handleVersionOutdated(_ details: VersionOutdatedDetails) async {
        callCount += 1
        lastDetails = details
    }
}

// MARK: - FakeRequestIDObserver

actor FakeRequestIDObserver: RequestIDObserving {
    private(set) var observedIDs: [String] = []

    func observe(requestID: String) async {
        observedIDs.append(requestID)
    }
}

// MARK: - FakeSleeper

actor FakeSleeper: RateLimitSleeping {
    private(set) var sleepCallCount = 0
    private(set) var sleepDurations: [TimeInterval] = []

    func sleep(seconds: TimeInterval) async {
        sleepCallCount += 1
        sleepDurations.append(seconds)
    }
}

// MARK: - Helpers

extension HTTPResponse {
    static func ok() -> HTTPResponse { HTTPResponse(status: .ok) }
    static func status(_ code: Int) -> HTTPResponse {
        HTTPResponse(status: HTTPResponse.Status(code: code))
    }
}

func makeBaseURL() -> URL {
    URL(string: "https://api.example.com")!
}

// MARK: - JSON body helpers

func jsonBody(_ string: String) -> HTTPBody {
    HTTPBody(string)
}
