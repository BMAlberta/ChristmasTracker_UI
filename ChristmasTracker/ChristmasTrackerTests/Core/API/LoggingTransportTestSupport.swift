// LoggingTransportTestSupport.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: shared fakes for the LoggingClientTransport suites. No network.
//
// The fake clock advances 25 ms on every call. The suites assume the transport reads the clock
// exactly twice per send (once before sending, once after), so a duration is always 25 ms.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import ChristmasTracker

/// What the fake inner transport does for one send.
nonisolated enum LoggingTransportOutcome: Sendable {
    case response(status: Int, headers: [String: String], body: String?)
    case failure(any Error)
}

/// Scripted inner transport. Outcomes are consumed in order; the last one repeats.
nonisolated final class FakeInnerTransport: ClientTransport, @unchecked Sendable {

    struct Received: Sendable {
        let request: HTTPRequest
        let bodyBytes: Data?
        let baseURL: URL
        let operationID: String
    }

    private let lock = NSLock()
    private var outcomes: [LoggingTransportOutcome]
    private var storage: [Received] = []

    init(_ outcomes: [LoggingTransportOutcome]) {
        self.outcomes = outcomes
    }

    var received: [Received] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var bytes: Data?
        if let body {
            bytes = try await Data(collecting: body, upTo: 1_000_000)
        }
        let outcome: LoggingTransportOutcome = {
            lock.lock()
            defer { lock.unlock() }
            storage.append(Received(request: request, bodyBytes: bytes, baseURL: baseURL, operationID: operationID))
            return outcomes.count > 1 ? outcomes.removeFirst() : outcomes[0]
        }()
        switch outcome {
        case let .response(status, headers, responseBody):
            var response = HTTPResponse(status: HTTPResponse.Status(code: status))
            for (name, value) in headers {
                if let field = HTTPField.Name(name) {
                    response.headerFields[field] = value
                }
            }
            return (response, responseBody.map { HTTPBody($0) })
        case let .failure(error):
            throw error
        }
    }
}

/// Steps 25 ms on every call.
nonisolated final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private let base = ContinuousClock.now
    private var ticks = 0

    func now() -> ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        ticks += 1
        return base.advanced(by: .milliseconds(ticks * 25))
    }
}

nonisolated struct LoggingSecretError: Error, LocalizedError, CustomStringConvertible {
    var description: String { "ZZ-secret-error" }
    var errorDescription: String? { "ZZ-secret-error" }
}

/// Builders shared by the LoggingClientTransport suites.
enum LoggingTransportFixture {

    static let operation = "getListDetail"

    struct SUT {
        let transport: LoggingClientTransport
        let inner: FakeInnerTransport
        let log: CapturingOperationLog
    }

    static func makeSUT(_ outcomes: [LoggingTransportOutcome], verbose: Bool) -> SUT {
        let inner = FakeInnerTransport(outcomes)
        let log = CapturingOperationLog()
        let clock = SteppingClock()
        let transport = LoggingClientTransport(
            wrapping: inner,
            log: log,
            verbosity: LogVerbosity(isVerbose: verbose),
            now: { clock.now() }
        )
        return SUT(transport: transport, inner: inner, log: log)
    }

    static func makeRequest(
        method: HTTPRequest.Method = .get,
        path: String = "/api/lists/abc",
        requestID: String? = nil,
        extra: [String: String] = [:]
    ) throws -> HTTPRequest {
        var request = HTTPRequest(method: method, scheme: nil, authority: nil, path: path)
        if let requestID {
            let name = try #require(HTTPField.Name("X-Request-Id"))
            request.headerFields[name] = requestID
        }
        for (key, value) in extra {
            let name = try #require(HTTPField.Name(key))
            request.headerFields[name] = value
        }
        return request
    }

    @discardableResult
    static func send(
        _ sut: SUT,
        _ request: HTTPRequest,
        body: HTTPBody? = nil,
        operationID: String = LoggingTransportFixture.operation
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let url = try #require(URL(string: "https://api.example.invalid"))
        return try await sut.transport.send(request, body: body, baseURL: url, operationID: operationID)
    }

    static func messages(_ sut: SUT) -> [String] {
        sut.log.lines.map(\.message)
    }

    static func madeMessages(_ sut: SUT) -> [String] {
        messages(sut).filter { $0.contains("request made") }
    }
}
