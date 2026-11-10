// OperationResponseTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Package I3a, story H1: per-operation response decoding through the real
// TrackerClientFactory-built client with a fake transport, for the error responses added by
// contract revision 26 (Docs/error-codes.md rows 4011 and 6402). No network, no sleeps.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import TrackerAPI

@Suite("Operation responses — revision 26 errors")
struct OperationResponseTests {

    // MARK: - SUT

    private func makeSUT() throws -> (client: Client, transport: FakeTransport) {
        let transport = FakeTransport()
        let client = try TrackerClientFactory.make(
            serverURL: makeBaseURL(),
            info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
            tokenProvider: FakeAccessTokenProvider(token: "test-access-token"),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
        return (client, transport)
    }

    private func envelope(code: Int, errorCode: String, message: String) -> String {
        """
        {
          "success": false,
          "error": {
            "code": \(code),
            "errorCode": "\(errorCode)",
            "message": "\(message)",
            "details": {}
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00.000Z",
            "requestId": "req-abc123",
            "sessionId": "ses-abc123"
          }
        }
        """
    }

    // MARK: - getUser 404 PERSON_NOT_FOUND

    @Test("getUser 404 PERSON_NOT_FOUND decodes as .notFound with code 4011")
    func getUserPersonNotFound() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(
            .status(404),
            body: HTTPBody(envelope(code: 4011, errorCode: "PERSON_NOT_FOUND", message: "Person not found"))
        )

        let output = try await client.getUser(.init(path: .init(id: "00000000-0000-0000-0000-000000000077")))

        guard case let .notFound(notFound) = output else {
            Issue.record("Expected .notFound but got \(output)")
            return
        }
        let body = try notFound.body.json
        #expect(body.error.code == 4011)
        #expect(body.error.errorCode == "PERSON_NOT_FOUND")
    }

    // MARK: - updateList 422 CANNOT_EDIT_ARCHIVED_LIST

    @Test("updateList 422 CANNOT_EDIT_ARCHIVED_LIST decodes as .unprocessableContent with code 6402")
    func updateListCannotEditArchivedList() async throws {
        let (client, transport) = try makeSUT()
        await transport.enqueue(
            .status(422),
            body: HTTPBody(envelope(code: 6402, errorCode: "CANNOT_EDIT_ARCHIVED_LIST", message: "Cannot edit an archived list"))
        )

        let output = try await client.updateList(
            .init(
                path: .init(id: "00000000-0000-0000-0000-000000000078"),
                body: .json(.init(name: "Renamed Fake List"))
            )
        )

        guard case let .unprocessableContent(unprocessable) = output else {
            Issue.record("Expected .unprocessableContent but got \(output)")
            return
        }
        let body = try unprocessable.body.json
        #expect(body.error.code == 6402)
        #expect(body.error.errorCode == "CANNOT_EDIT_ARCHIVED_LIST")
        #expect(classifyErrorCode(errorCode: body.error.code) == .showMessage)
        #expect(await transport.requestCount == 1)
    }
}
