// LoggingTransportLeakTests.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: no URL, path, query, header value, body or error text ever reaches the
// log, and every line is under the network category. Fakes are in LoggingTransportTestSupport.swift.
//
// Fails to compile until LoggingClientTransport exists.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import ChristmasTracker

@Suite("LoggingClientTransport leaks (LG1 L2)", .timeLimit(.minutes(1)))
struct LoggingTransportLeakTests {

    private typealias F = LoggingTransportFixture

    private static let secrets = [
        "ZZ-secret-path", "ZZ-secret-query", "ZZ-secret-token", "ZZ-secret-body", "ZZ-secret-error"
    ]
    private static let forbiddenFragments = ["http", "?", "/", "Bearer"]

    private func runScenarios(verbose: Bool) async throws -> [CapturingOperationLog.Line] {
        var all: [CapturingOperationLog.Line] = []
        let secretHeaders = ["X-Custom": "ZZ-secret-token"]
        let outcomes: [LoggingTransportOutcome] = [
            .response(status: 200, headers: secretHeaders, body: "ZZ-secret-error"),
            .response(status: 404, headers: secretHeaders, body: "ZZ-secret-error"),
            .response(status: 500, headers: ["X-Request-Id": "resp-1"], body: "ZZ-secret-error"),
            .response(status: 403, headers: ["X-Request-Id": "resp-1"], body: "ZZ-secret-error"),
            .failure(LoggingSecretError()),
            .failure(URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "ZZ-secret-error"]))
        ]
        for outcome in outcomes {
            let sut = F.makeSUT([outcome], verbose: verbose)
            let request = try F.makeRequest(
                method: .post,
                path: "/ZZ-secret-path?token=ZZ-secret-query",
                requestID: "req-1",
                extra: ["Authorization": "Bearer ZZ-secret-token", "X-Custom": "ZZ-secret-token"]
            )
            _ = try? await F.send(sut, request, body: HTTPBody("ZZ-secret-body"))
            all.append(contentsOf: sut.log.lines)
        }
        return all
    }

    @Test("no secret, URL, path, query, header value, body or error text appears in any line", arguments: [true, false])
    func noSecretsInAnyLine(verbose: Bool) async throws {
        let lines = try await runScenarios(verbose: verbose)

        #expect(!lines.isEmpty, "Precondition: the failure scenarios must log something")
        for line in lines {
            for secret in Self.secrets + Self.forbiddenFragments {
                #expect(!line.message.contains(secret), "\"\(secret)\" leaked into: \(line.message)")
            }
        }
    }

    @Test("every captured line has the network category", arguments: [true, false])
    func everyLineIsNetwork(verbose: Bool) async throws {
        let lines = try await runScenarios(verbose: verbose)

        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.category == .network })
    }
}
