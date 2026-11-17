// LoggingTransportRequestIDTests.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: a request id (from the response or the request header) is logged only
// if it is 1 to 64 characters, all in [A-Za-z0-9-]. Otherwise the ", request id <id>" part is
// omitted; a response id that fails the check falls back to the request header id if that passes.
//
// Note: HTTPField cannot hold a newline or other control characters (the type rejects them), so a
// newline id cannot be built through the fake transport. Space, tab, slash, semicolon, a 65
// character id and an empty id stand in for "unsafe".
//
// Fails to compile until LoggingClientTransport exists.

import Testing
import Foundation
import HTTPTypes
@testable import ChristmasTracker

@Suite("LoggingClientTransport request id sanitizing (LG1 L2)", .timeLimit(.minutes(1)))
struct LoggingTransportRequestIDTests {

    private typealias F = LoggingTransportFixture

    private static let longest = String(repeating: "a", count: 64)
    private static let tooLong = String(repeating: "a", count: 65)

    /// Runs a 500 through the transport and returns the single failure line's message.
    private func failureLine(
        verbose: Bool,
        responseID: String?,
        requestID: String?
    ) async throws -> String? {
        let headers = responseID.map { ["X-Request-Id": $0] } ?? [:]
        let sut = F.makeSUT([.response(status: 500, headers: headers, body: nil)], verbose: verbose)

        try await F.send(sut, try F.makeRequest(requestID: requestID))

        return sut.log.lines.last?.message
    }

    private func expected(verbose: Bool, id: String?) -> String {
        let duration = verbose ? ", 25 ms" : ""
        let idPart = id.map { ", request id \($0)" } ?? ""
        return "getListDetail response received (500\(duration)\(idPart))"
    }

    @Test(
        "an unsafe response id is not logged and the valid request id is used instead",
        arguments: [true, false],
        ["bad id", "bad\tid", "bad/id", "bad;id", "bad_id", "", LoggingTransportRequestIDTests.tooLong]
    )
    func unsafeResponseIDFallsBack(verbose: Bool, unsafe: String) async throws {
        let line = try await failureLine(verbose: verbose, responseID: unsafe, requestID: "req-9")

        #expect(line == expected(verbose: verbose, id: "req-9"))
    }

    @Test(
        "an unsafe response id with no request id omits the id part",
        arguments: [true, false],
        ["bad id", "bad\tid", "bad/id", "", LoggingTransportRequestIDTests.tooLong]
    )
    func unsafeResponseIDWithoutRequestID(verbose: Bool, unsafe: String) async throws {
        let line = try await failureLine(verbose: verbose, responseID: unsafe, requestID: nil)

        #expect(line == expected(verbose: verbose, id: nil))
    }

    @Test("an unsafe response id and an unsafe request id omit the id part", arguments: [true, false])
    func bothUnsafe(verbose: Bool) async throws {
        let line = try await failureLine(verbose: verbose, responseID: "bad id", requestID: "also bad")

        #expect(line == expected(verbose: verbose, id: nil))
    }

    @Test("an unsafe request id is omitted when there is no response id", arguments: [true, false])
    func unsafeRequestIDOnly(verbose: Bool) async throws {
        let line = try await failureLine(verbose: verbose, responseID: nil, requestID: "bad id")

        #expect(line == expected(verbose: verbose, id: nil))
    }

    @Test("ids of 1 and 64 characters in [A-Za-z0-9-] are logged", arguments: [true, false])
    func boundaryIDsAreLogged(verbose: Bool) async throws {
        for id in ["a", Self.longest, "Req-ABC-123"] {
            let line = try await failureLine(verbose: verbose, responseID: id, requestID: nil)

            #expect(line == expected(verbose: verbose, id: id))
        }
    }

    @Test("a 65 character request id is not logged", arguments: [true, false])
    func tooLongRequestID(verbose: Bool) async throws {
        let line = try await failureLine(verbose: verbose, responseID: nil, requestID: Self.tooLong)

        #expect(line == expected(verbose: verbose, id: nil))
    }
}
