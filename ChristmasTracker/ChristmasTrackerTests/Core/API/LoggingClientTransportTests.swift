// LoggingClientTransportTests.swift
// ChristmasTrackerTests
//
// Package LG1, story L2: LoggingClientTransport wraps a ClientTransport and writes metadata-only
// lines (operation, method, attempt, status, duration, request id, error category) to the
// operation log under the network category. Verbose and release-style lines, error categories
// and pass-through. Attempt numbering, request id sanitizing and secrets have their own files.
// Fakes are in LoggingTransportTestSupport.swift. No network.
//
// Fails to compile until LoggingClientTransport exists (Core/API/LoggingClientTransport.swift).

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import ChristmasTracker

@Suite("LoggingClientTransport (LG1 L2)", .timeLimit(.minutes(1)))
struct LoggingClientTransportTests {

    private typealias F = LoggingTransportFixture

    private func makeSUT(_ outcomes: [LoggingTransportOutcome], verbose: Bool) -> F.SUT {
        F.makeSUT(outcomes, verbose: verbose)
    }

    private func respond(
        _ status: Int,
        id: String? = "resp-1"
    ) -> LoggingTransportOutcome {
        .response(status: status, headers: id.map { ["X-Request-Id": $0] } ?? [:], body: nil)
    }

    // MARK: - Verbose: made and received

    @Test("verbose: a 200 logs made (attempt 1) then received with status, ms and the response request id")
    func verboseSuccess() async throws {
        let sut = makeSUT([respond(200)], verbose: true)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines == [
            .init(level: .debug, message: "getListDetail request made (GET, attempt 1)", category: .network),
            .init(
                level: .debug,
                message: "getListDetail response received (200, 25 ms, request id resp-1)",
                category: .network
            )
        ])
    }

    @Test("verbose: the method appears in the made line")
    func verboseMethod() async throws {
        let sut = makeSUT([respond(201)], verbose: true)

        try await F.send(sut, try F.makeRequest(method: .post), operationID: "createItem")

        #expect(F.messages(sut).first == "createItem request made (POST, attempt 1)")
    }

    @Test("verbose: without a response request id the request header id is used")
    func verboseFallsBackToRequestID() async throws {
        let sut = makeSUT([respond(200, id: nil)], verbose: true)

        try await F.send(sut, try F.makeRequest(requestID: "req-9"))

        #expect(F.messages(sut).last == "getListDetail response received (200, 25 ms, request id req-9)")
    }

    @Test("verbose: the response request id wins over the request header id")
    func verbosePrefersResponseID() async throws {
        let sut = makeSUT([respond(200)], verbose: true)

        try await F.send(sut, try F.makeRequest(requestID: "req-9"))

        #expect(F.messages(sut).last == "getListDetail response received (200, 25 ms, request id resp-1)")
    }

    @Test("verbose: with no request id anywhere the id part is omitted")
    func verboseNoID() async throws {
        let sut = makeSUT([respond(200, id: nil)], verbose: true)

        try await F.send(sut, try F.makeRequest())

        #expect(F.messages(sut).last == "getListDetail response received (200, 25 ms)")
    }

    @Test("verbose: a 500 is a warning with the same wording")
    func verbose500() async throws {
        let sut = makeSUT([respond(500)], verbose: true)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines.last == .init(
            level: .warning,
            message: "getListDetail response received (500, 25 ms, request id resp-1)",
            category: .network
        ))
        #expect(sut.log.lines.first?.level == .debug)
    }

    @Test("verbose: a 404 is a warning")
    func verbose404() async throws {
        let sut = makeSUT([respond(404)], verbose: true)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines.last == .init(
            level: .warning,
            message: "getListDetail response received (404, 25 ms, request id resp-1)",
            category: .network
        ))
    }

    // MARK: - Verbose: errors

    @Test("verbose: a timeout logs made then one error with category timeout, and rethrows the identical error")
    func verboseTimeout() async throws {
        let thrown = URLError(.timedOut)
        let sut = makeSUT([.failure(thrown)], verbose: true)

        let caught = await #expect(throws: URLError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(caught == thrown)
        #expect(sut.log.lines == [
            .init(level: .debug, message: "getListDetail request made (GET, attempt 1)", category: .network),
            .init(level: .error, message: "getListDetail request failed (timeout, 25 ms)", category: .network)
        ])
    }

    @Test(
        "error categories are stable strings",
        arguments: [
            (URLError.Code.timedOut, "timeout"),
            (.notConnectedToInternet, "offline"),
            (.networkConnectionLost, "offline"),
            (.cannotFindHost, "dns"),
            (.dnsLookupFailed, "dns"),
            (.secureConnectionFailed, "tls"),
            (.serverCertificateUntrusted, "tls"),
            (.badServerResponse, "other")
        ]
    )
    func errorCategories(code: URLError.Code, category: String) async throws {
        let sut = makeSUT([.failure(URLError(code))], verbose: true)

        _ = await #expect(throws: URLError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(sut.log.lines.last == .init(
            level: .error, message: "getListDetail request failed (\(category), 25 ms)", category: .network
        ))
    }

    @Test("verbose: an unknown error type is category other")
    func verboseOtherError() async throws {
        let sut = makeSUT([.failure(LoggingSecretError())], verbose: true)

        _ = await #expect(throws: LoggingSecretError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(sut.log.lines.last?.message == "getListDetail request failed (other, 25 ms)")
        #expect(sut.log.lines.last?.level == .error)
    }

    @Test("verbose: URLError.cancelled logs a debug cancelled line, no error, and rethrows")
    func verboseURLCancelled() async throws {
        let thrown = URLError(.cancelled)
        let sut = makeSUT([.failure(thrown)], verbose: true)

        let caught = await #expect(throws: URLError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(caught == thrown)
        #expect(sut.log.lines.last == .init(
            level: .debug, message: "getListDetail request cancelled (25 ms)", category: .network
        ))
        #expect(sut.log.lines.contains { $0.level == .error } == false)
    }

    @Test("verbose: CancellationError logs a debug cancelled line, no error, and rethrows")
    func verboseCancellationError() async throws {
        let sut = makeSUT([.failure(CancellationError())], verbose: true)

        _ = await #expect(throws: CancellationError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(sut.log.lines.last == .init(
            level: .debug, message: "getListDetail request cancelled (25 ms)", category: .network
        ))
        #expect(sut.log.lines.contains { $0.level == .error } == false)
    }

    // MARK: - Release-style

    @Test("release: success logs nothing")
    func releaseSuccessLogsNothing() async throws {
        let sut = makeSUT([respond(200)], verbose: false)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines.isEmpty)
    }

    @Test("release: a 500 logs exactly one warning with the request id, no duration and no made line")
    func release500() async throws {
        let sut = makeSUT([respond(500)], verbose: false)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines == [
            .init(
                level: .warning,
                message: "getListDetail response received (500, request id resp-1)",
                category: .network
            )
        ])
    }

    @Test("release: a transport error logs one error without duration and rethrows the identical error")
    func releaseTransportError() async throws {
        let thrown = URLError(.notConnectedToInternet)
        let sut = makeSUT([.failure(thrown)], verbose: false)

        let caught = await #expect(throws: URLError.self) { try await F.send(sut, try F.makeRequest()) }

        #expect(caught == thrown)
        #expect(sut.log.lines == [
            .init(level: .error, message: "getListDetail request failed (offline)", category: .network)
        ])
    }

    @Test("release: cancellation logs nothing", arguments: [0, 1])
    func releaseCancellation(variant: Int) async throws {
        let error: any Error = variant == 0 ? URLError(.cancelled) : CancellationError()
        let sut = makeSUT([.failure(error)], verbose: false)

        do {
            try await F.send(sut, try F.makeRequest())
            Issue.record("Expected the cancellation to be rethrown")
        } catch {}

        #expect(sut.log.lines.isEmpty)
    }

    @Test("release: 401, 404, 409 and 426 log nothing", arguments: [401, 404, 409, 426])
    func releaseExpectedStatusesLogNothing(status: Int) async throws {
        let sut = makeSUT([respond(status)], verbose: false)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines.isEmpty)
    }

    @Test("release: a 403 and a 429 log a warning", arguments: [403, 429])
    func releaseOtherClientErrorsWarn(status: Int) async throws {
        let sut = makeSUT([respond(status)], verbose: false)

        try await F.send(sut, try F.makeRequest())

        #expect(sut.log.lines == [
            .init(
                level: .warning,
                message: "getListDetail response received (\(status), request id resp-1)",
                category: .network
            )
        ])
    }

    @Test("release: a 500 without any request id omits the id part")
    func release500NoID() async throws {
        let sut = makeSUT([respond(500, id: nil)], verbose: false)

        try await F.send(sut, try F.makeRequest())

        #expect(F.messages(sut) == ["getListDetail response received (500)"])
    }

    // MARK: - Pass-through

    @Test("the inner transport gets request, body bytes, baseURL and operationID unchanged; the response is unchanged")
    func passThrough() async throws {
        let sut = makeSUT(
            [.response(status: 202, headers: ["X-Custom": "v1"], body: "response-bytes")],
            verbose: true
        )
        let request = try F.makeRequest(
            method: .put, path: "/api/items/9", requestID: "req-1", extra: ["X-Custom": "c1"]
        )
        let url = try #require(URL(string: "https://api.example.invalid/base"))

        let (response, responseBody) = try await sut.transport.send(
            request, body: HTTPBody("request-bytes"), baseURL: url, operationID: "updateItem"
        )

        let received = try #require(sut.inner.received.first)
        #expect(sut.inner.received.count == 1)
        #expect(received.request == request)
        #expect(received.bodyBytes == Data("request-bytes".utf8))
        #expect(received.baseURL == url)
        #expect(received.operationID == "updateItem")
        #expect(response.status.code == 202)
        let customName = try #require(HTTPField.Name("X-Custom"))
        #expect(response.headerFields[customName] == "v1")
        let returned = try #require(responseBody)
        #expect(try await Data(collecting: returned, upTo: 1_000) == Data("response-bytes".utf8))
    }

    @Test("a nil request body and a nil response body pass through as nil")
    func passThroughNilBodies() async throws {
        let sut = makeSUT([respond(204, id: nil)], verbose: true)

        let (response, responseBody) = try await F.send(sut, try F.makeRequest())

        #expect(sut.inner.received.first?.bodyBytes == nil)
        #expect(response.status.code == 204)
        #expect(responseBody == nil)
    }
}
