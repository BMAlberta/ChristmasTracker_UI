// TrackerClientFactoryTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// Tests for TrackerClientFactory.make — URL validation, date transcoder wiring,
// required headers, and bearer token presence/absence on public vs. authenticated ops.
// These tests reference the new `transport:` parameter and `throws` signature that the
// implementer must add before the tests compile and can be made green.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import TrackerAPI

@Suite("TrackerClientFactory")
struct TrackerClientFactoryTests {

    // MARK: - Helpers

    private func makeInfo() -> AppClientInfo {
        AppClientInfo(
            platform: "ios",
            clientPlatform: "ios",
            build: "1",
            version: "1.0.0"
        )
    }

    /// Full getCurrentUser 200 JSON with whole-second (no fractional) ISO 8601 dates.
    /// Used by both the transcoder test and the bearer-token authenticated request test.
    private var currentUserJSON: String {
        """
        {
          "success": true,
          "data": {
            "id": "00000000-0000-0000-0000-000000000001",
            "email": "alice@test.invalid",
            "firstName": "Alice",
            "lastName": "Smith",
            "displayName": "Alice Smith",
            "role": "USER",
            "isActive": true,
            "createdAt": "2026-11-02T00:00:00Z",
            "updatedAt": "2026-11-02T00:00:00Z"
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00Z",
            "requestId": "req-00000001",
            "sessionId": "sess-00000001"
          }
        }
        """
    }

    /// Minimal valid checkAppVersion 200 JSON.
    private var checkAppVersionJSON: String {
        """
        {
          "success": true,
          "data": {
            "state": "ok",
            "platform": "ios",
            "minimumVersion": "1.0.0",
            "recommendedVersion": "1.0.0",
            "latestVersion": "2.0.0",
            "minimumBuild": 1,
            "latestBuild": 10,
            "enabled": true,
            "updatedAt": "2026-11-02T00:00:00Z"
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00Z",
            "requestId": "req-00000002",
            "sessionId": "sess-00000002"
          }
        }
        """
    }

    // MARK: - URL validation: invalid URLs must throw TrackerAPIError.invalidServerURL

    @Test("make throws invalidServerURL for ftp scheme")
    func makeThrowsForFtpScheme() throws {
        let transport = FakeTransport()
        #expect {
            _ = try TrackerClientFactory.make(
                serverURL: URL(string: "ftp://api.example.com")!,
                info: makeInfo(),
                tokenProvider: FakeAccessTokenProvider(),
                sessionRefresher: FakeSessionRefresher(),
                versionOutdatedHandler: FakeVersionOutdatedHandler(),
                transport: transport
            )
        } throws: { error in
            if case TrackerAPIError.invalidServerURL = error { return true }
            Issue.record("Expected .invalidServerURL but got \(error)")
            return false
        }
    }

    @Test("make throws invalidServerURL for empty host")
    func makeThrowsForEmptyHost() throws {
        let transport = FakeTransport()
        #expect {
            _ = try TrackerClientFactory.make(
                serverURL: URL(string: "https:///path")!,
                info: makeInfo(),
                tokenProvider: FakeAccessTokenProvider(),
                sessionRefresher: FakeSessionRefresher(),
                versionOutdatedHandler: FakeVersionOutdatedHandler(),
                transport: transport
            )
        } throws: { error in
            if case TrackerAPIError.invalidServerURL = error { return true }
            Issue.record("Expected .invalidServerURL but got \(error)")
            return false
        }
    }

    @Test("make throws invalidServerURL for non-empty path longer than /")
    func makeThrowsForNonRootPath() throws {
        let transport = FakeTransport()
        #expect {
            _ = try TrackerClientFactory.make(
                serverURL: URL(string: "https://api.example.com/tracker/v2")!,
                info: makeInfo(),
                tokenProvider: FakeAccessTokenProvider(),
                sessionRefresher: FakeSessionRefresher(),
                versionOutdatedHandler: FakeVersionOutdatedHandler(),
                transport: transport
            )
        } throws: { error in
            if case TrackerAPIError.invalidServerURL = error { return true }
            Issue.record("Expected .invalidServerURL but got \(error)")
            return false
        }
    }

    @Test("make succeeds for http://localhost:3010")
    func makeSucceedsForLocalhostHTTP() throws {
        let transport = FakeTransport()
        _ = try TrackerClientFactory.make(
            serverURL: URL(string: "http://localhost:3010")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
    }

    @Test("make succeeds for https://api.bmalberta.com")
    func makeSucceedsForHTTPS() throws {
        let transport = FakeTransport()
        _ = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.bmalberta.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
    }

    @Test("make succeeds for https://api.bmalberta.com/ (trailing slash)")
    func makeSucceedsForHTTPSTrailingSlash() throws {
        let transport = FakeTransport()
        _ = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.bmalberta.com/")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: transport
        )
    }

    // MARK: - Date transcoder: whole-second ISO 8601 dates must decode without throwing

    @Test("Client decodes ISO 8601 dates without fractional seconds (transcoder wired up)")
    func clientDecodesWholeSecondISO8601Dates() async throws {
        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(currentUserJSON)
        )

        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        // If TrackerDateTranscoder is not wired up, the generated decoder rejects the
        // whole-second date and this call throws. A throw here is a test failure.
        let response = try await client.getCurrentUser()
        switch response {
        case .ok(let ok):
            let body = try ok.body.json
            #expect(body.data.firstName == "Alice")
        default:
            Issue.record("Expected .ok response but got \(response)")
        }
    }

    @Test("Client decodes ISO 8601 dates with fractional seconds (transcoder wired up)")
    func clientDecodesFractionalSecondISO8601Dates() async throws {
        let fractionalJSON = """
        {
          "success": true,
          "data": {
            "id": "00000000-0000-0000-0000-000000000001",
            "email": "alice@test.invalid",
            "firstName": "Alice",
            "lastName": "Smith",
            "displayName": "Alice Smith",
            "role": "USER",
            "isActive": true,
            "createdAt": "2025-12-30T10:00:00.123Z",
            "updatedAt": "2025-12-30T10:00:00.456Z"
          },
          "meta": {
            "timestamp": "2025-12-30T10:00:00.789Z",
            "requestId": "req-00000003",
            "sessionId": "sess-00000003"
          }
        }
        """

        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(fractionalJSON)
        )

        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        // If TrackerDateTranscoder does not handle fractional seconds, the generated
        // decoder rejects the timestamp and this call throws — which is a test failure.
        let response = try await client.getCurrentUser()
        switch response {
        case .ok(let ok):
            let body = try ok.body.json
            #expect(body.data.firstName == "Alice")
        default:
            Issue.record("Expected .ok response but got \(response)")
        }
    }

    @Test("Client decodes ISO 8601 dates with zero fractional seconds (.000Z)")
    func clientDecodesZeroFractionalSecondISO8601Dates() async throws {
        let zeroFractionalJSON = """
        {
          "success": true,
          "data": {
            "id": "00000000-0000-0000-0000-000000000001",
            "email": "alice@test.invalid",
            "firstName": "Alice",
            "lastName": "Smith",
            "displayName": "Alice Smith",
            "role": "USER",
            "isActive": true,
            "createdAt": "2025-12-30T10:00:00.000Z",
            "updatedAt": "2025-12-30T10:00:00.000Z"
          },
          "meta": {
            "timestamp": "2025-12-30T10:00:00.000Z",
            "requestId": "req-00000004",
            "sessionId": "sess-00000004"
          }
        }
        """

        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(zeroFractionalJSON)
        )

        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        // .000Z is a legal fractional-second timestamp. If TrackerDateTranscoder
        // cannot handle it, this call throws — which is a test failure.
        let response = try await client.getCurrentUser()
        switch response {
        case .ok(let ok):
            let body = try ok.body.json
            #expect(body.data.firstName == "Alice")
        default:
            Issue.record("Expected .ok response but got \(response)")
        }
    }

    // MARK: - Required headers: all 4 platform headers must be present on every request

    @Test("Client sends all required headers on every request")
    func clientSendsRequiredHeadersOnEveryRequest() async throws {
        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(checkAppVersionJSON)
        )

        let info = AppClientInfo(
            platform: "ios",
            clientPlatform: "ios",
            build: "42",
            version: "2.1.0"
        )
        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: info,
            tokenProvider: FakeAccessTokenProvider(),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        _ = try await client.checkAppVersion(
            query: .init(platform: "ios", version: "2.1.0", build: 42)
        )

        let recorded = await fakeTransport.recordedRequests.first
        let req = try #require(recorded?.request, "Expected a recorded request")

        #expect(
            req.headerFields[HTTPField.Name("X-Platform")!] == "ios",
            "X-Platform header must be 'ios'"
        )
        #expect(
            req.headerFields[HTTPField.Name("X-Build")!] == "42",
            "X-Build header must be '42'"
        )
        #expect(
            req.headerFields[HTTPField.Name("X-App-Version")!] == "2.1.0",
            "X-App-Version header must be '2.1.0'"
        )
        #expect(
            req.headerFields[HTTPField.Name("X-Client-Platform")!] == "ios",
            "X-Client-Platform header must be 'ios'"
        )
        // X-Request-Id just needs to be present (UUID, not checked for format)
        let requestID = req.headerFields[HTTPField.Name("X-Request-Id")!]
        #expect(requestID != nil, "X-Request-Id header must be present")
    }

    // MARK: - Bearer token: present on authenticated ops, absent on public ops

    @Test("Client sends Bearer token on authenticated requests")
    func clientSendsBearerTokenOnAuthenticatedRequests() async throws {
        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(currentUserJSON)
        )

        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(token: "my-secret-token"),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        _ = try await client.getCurrentUser()

        let recorded = await fakeTransport.recordedRequests.first
        let req = try #require(recorded?.request, "Expected a recorded request")
        let authHeader = req.headerFields[.authorization]
        #expect(authHeader == "Bearer my-secret-token", "Authorization header must be 'Bearer my-secret-token'")
    }

    @Test("Client does not send Bearer token on public requests")
    func clientDoesNotSendBearerTokenOnPublicRequests() async throws {
        let fakeTransport = FakeTransport()
        await fakeTransport.enqueue(
            HTTPResponse(status: .ok),
            body: jsonBody(checkAppVersionJSON)
        )

        let client = try TrackerClientFactory.make(
            serverURL: URL(string: "https://api.example.com")!,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(token: "my-secret-token"),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: fakeTransport
        )

        _ = try await client.checkAppVersion(
            query: .init(platform: "ios", version: "1.0.0")
        )

        let recorded = await fakeTransport.recordedRequests.first
        let req = try #require(recorded?.request, "Expected a recorded request")
        let authHeader = req.headerFields[.authorization]
        #expect(authHeader == nil, "Authorization header must be absent on public operations")
    }
}
