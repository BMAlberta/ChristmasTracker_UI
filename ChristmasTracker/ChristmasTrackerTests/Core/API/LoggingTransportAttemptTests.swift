// LoggingTransportAttemptTests.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: attempt numbering per X-Request-Id, and the bounded counter. The
// transport tracks at most 64 request ids; a 65th distinct id evicts the oldest, so a terminal
// 401 or 429 never grows memory without bound. `trackedRequestCount` is the internal test seam.
//
// Fails to compile until LoggingClientTransport (with trackedRequestCount) exists.

import Testing
import Foundation
import HTTPTypes
@testable import ChristmasTracker

@Suite("LoggingClientTransport attempt counter (LG1 L2)", .timeLimit(.minutes(1)))
struct LoggingTransportAttemptTests {

    private typealias F = LoggingTransportFixture

    private func status(_ code: Int) -> LoggingTransportOutcome {
        .response(status: code, headers: [:], body: nil)
    }

    private func attemptNumbers(_ sut: F.SUT) -> [Int] {
        F.madeMessages(sut).map { $0.hasSuffix("attempt 1)") ? 1 : ($0.hasSuffix("attempt 2)") ? 2 : 0) }
    }

    // MARK: - Numbering

    @Test("a 401 then a replay with the same request id logs attempt 1 then attempt 2")
    func replayAttemptNumbers() async throws {
        let sut = F.makeSUT([status(401), status(200)], verbose: true)
        let request = try F.makeRequest(requestID: "req-1")

        try await F.send(sut, request)
        try await F.send(sut, request)

        #expect(F.madeMessages(sut) == [
            "getListDetail request made (GET, attempt 1)",
            "getListDetail request made (GET, attempt 2)"
        ])
    }

    @Test("after a send that ends with 200 the counter for that id is discarded, so a later send is attempt 1")
    func counterDiscardedAfterSuccess() async throws {
        let sut = F.makeSUT([status(401), status(200), status(200)], verbose: true)
        let request = try F.makeRequest(requestID: "req-1")

        try await F.send(sut, request)
        try await F.send(sut, request)
        try await F.send(sut, request)

        #expect(attemptNumbers(sut) == [1, 2, 1])
    }

    @Test("a 429 keeps the counter, so the retry is attempt 2")
    func counterKeptAfter429() async throws {
        let sut = F.makeSUT([status(429), status(200)], verbose: true)
        let request = try F.makeRequest(requestID: "req-1")

        try await F.send(sut, request)
        try await F.send(sut, request)

        #expect(F.madeMessages(sut).last == "getListDetail request made (GET, attempt 2)")
    }

    @Test("a thrown error discards the counter")
    func counterDiscardedAfterThrow() async throws {
        let sut = F.makeSUT([status(401), .failure(URLError(.timedOut)), status(200)], verbose: true)
        let request = try F.makeRequest(requestID: "req-1")

        try await F.send(sut, request)
        _ = await #expect(throws: URLError.self) { try await F.send(sut, request) }
        try await F.send(sut, request)

        #expect(attemptNumbers(sut) == [1, 2, 1])
    }

    @Test("a request without an X-Request-Id header is always attempt 1")
    func noHeaderAlwaysAttemptOne() async throws {
        let sut = F.makeSUT([status(401)], verbose: true)

        try await F.send(sut, try F.makeRequest())
        try await F.send(sut, try F.makeRequest())

        #expect(attemptNumbers(sut) == [1, 1])
    }

    @Test("different request ids count independently")
    func independentIDs() async throws {
        let sut = F.makeSUT([status(401)], verbose: true)

        try await F.send(sut, try F.makeRequest(requestID: "req-a"))
        try await F.send(sut, try F.makeRequest(requestID: "req-b"))

        #expect(attemptNumbers(sut) == [1, 1])
    }

    // MARK: - Bounded counter

    @Test("200 distinct ids that each end in 401 keep at most 64 tracked ids")
    func trackedCountIsBounded() async throws {
        let sut = F.makeSUT([status(401)], verbose: false)

        for index in 0..<200 {
            try await F.send(sut, try F.makeRequest(requestID: "req-\(index)"))
        }

        #expect(sut.transport.trackedRequestCount <= 64)
        #expect(sut.transport.trackedRequestCount > 0)
    }

    @Test("a terminal 401 with no replay, followed by a 200 on another id, keeps working")
    func terminalUnauthorizedThenSuccess() async throws {
        let sut = F.makeSUT([status(401), status(200)], verbose: true)

        try await F.send(sut, try F.makeRequest(requestID: "req-a"))
        let (response, _) = try await F.send(sut, try F.makeRequest(requestID: "req-b"))

        #expect(response.status.code == 200)
        #expect(attemptNumbers(sut) == [1, 1])
        #expect(sut.transport.trackedRequestCount == 1)
    }

    @Test("the replay of a still-tracked id logs attempt 2 even after many other ids")
    func replayOfTrackedIDAfterOthers() async throws {
        let sut = F.makeSUT([status(401)], verbose: true)

        try await F.send(sut, try F.makeRequest(requestID: "req-first"))
        for index in 0..<10 {
            try await F.send(sut, try F.makeRequest(requestID: "req-\(index)"))
        }
        try await F.send(sut, try F.makeRequest(requestID: "req-first"))

        #expect(attemptNumbers(sut).last == 2)
    }

    @Test("the 65th distinct id evicts the oldest: its replay restarts at attempt 1, the newest stays at attempt 2")
    func oldestIDIsEvicted() async throws {
        let sut = F.makeSUT([status(401)], verbose: true)

        for index in 0..<65 {
            try await F.send(sut, try F.makeRequest(requestID: "req-\(index)"))
        }
        #expect(sut.transport.trackedRequestCount == 64)

        try await F.send(sut, try F.makeRequest(requestID: "req-64"))
        try await F.send(sut, try F.makeRequest(requestID: "req-0"))

        let numbers = attemptNumbers(sut)
        #expect(numbers[65] == 2, "the newest id is still tracked")
        #expect(numbers[66] == 1, "the oldest id was evicted")
    }

    @Test("ids discarded after a 200 reduce the tracked count")
    func discardReducesCount() async throws {
        let sut = F.makeSUT([status(401), status(401), status(401), status(200)], verbose: false)

        for id in ["req-a", "req-b", "req-c"] {
            try await F.send(sut, try F.makeRequest(requestID: id))
        }
        #expect(sut.transport.trackedRequestCount == 3)

        try await F.send(sut, try F.makeRequest(requestID: "req-a"))

        #expect(sut.transport.trackedRequestCount == 2)
    }

    @Test("a thrown error reduces the tracked count")
    func throwReducesCount() async throws {
        let sut = F.makeSUT([status(401), .failure(URLError(.timedOut))], verbose: false)
        let request = try F.makeRequest(requestID: "req-a")

        try await F.send(sut, request)
        #expect(sut.transport.trackedRequestCount == 1)
        _ = await #expect(throws: URLError.self) { try await F.send(sut, request) }

        #expect(sut.transport.trackedRequestCount == 0)
    }
}
