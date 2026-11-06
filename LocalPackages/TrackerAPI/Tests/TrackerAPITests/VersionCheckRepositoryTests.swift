// VersionCheckRepositoryTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import TrackerAPI

// MARK: - JSON fixture helpers

private let baseURL = URL(string: "https://api.example.com")!

private func makeInfo() -> AppClientInfo {
    AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0")
}

private func makeClientAndTransport() throws -> (GeneratedClientAppVersionRepository, FakeTransport) {
    let transport = FakeTransport()
    let client = try TrackerClientFactory.make(
        serverURL: baseURL,
        info: makeInfo(),
        tokenProvider: FakeAccessTokenProvider(token: nil),
        sessionRefresher: FakeSessionRefresher(),
        versionOutdatedHandler: FakeVersionOutdatedHandler(),
        transport: transport
    )
    let repo = GeneratedClientAppVersionRepository(client: client, info: makeInfo())
    return (repo, transport)
}

private func okJSON(state: String, extraFields: String = "") -> HTTPBody {
    HTTPBody("""
    {
      "success": true,
      "data": {
        "state": "\(state)",
        "platform": "ios",
        "minimumVersion": "1.0.0",
        "recommendedVersion": "1.0.0",
        "latestVersion": "2.0.0",
        "minimumBuild": 1,
        "latestBuild": 10,
        "enabled": true,
        "updatedAt": "2026-11-02T00:00:00Z"\(extraFields.isEmpty ? "" : ",\n        \(extraFields)")
      },
      "meta": {
        "timestamp": "2026-11-02T00:00:00Z",
        "requestId": "req-00000001",
        "sessionId": "sess-00000001"
      }
    }
    """)
}

private func errorJSON() -> HTTPBody {
    HTTPBody("""
    {"success": false, "error": {"code": 9001, "errorCode": "RATE_LIMIT", "message": "bad request"}, "meta": {"timestamp": "2026-11-02T00:00:00Z", "requestId": "req-00000001", "sessionId": "sess-00000001"}}
    """)
}

// MARK: - VersionCheckRepository Suite

@Suite("VersionCheckRepository")
struct VersionCheckRepositoryTests {

    // MARK: A — 200 state mapping

    @Test("200 state=ok maps to VersionPolicyState.ok")
    func stateOkMapsCorrectly() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "ok"))

        let policy = try await repo.checkVersion()

        #expect(policy.state == .ok)
        #expect(policy.minimumVersion == "1.0.0")
        #expect(policy.latestBuild == 10)
    }

    @Test("200 state=update_recommended maps to VersionPolicyState.updateRecommended")
    func stateUpdateRecommendedMapsCorrectly() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "update_recommended"))

        let policy = try await repo.checkVersion()

        #expect(policy.state == .updateRecommended)
        #expect(policy.minimumVersion == "1.0.0")
        #expect(policy.latestBuild == 10)
    }

    @Test("200 state=force_update maps to VersionPolicyState.forceUpdate")
    func stateForceUpdateMapsCorrectly() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "force_update"))

        let policy = try await repo.checkVersion()

        #expect(policy.state == .forceUpdate)
        #expect(policy.minimumVersion == "1.0.0")
        #expect(policy.latestBuild == 10)
    }

    // MARK: B — Optional fields absent → URL fields nil

    @Test("200 without optional fields yields nil manifestURL, ipaURL, releaseNotes")
    func missingOptionalFieldsAreNil() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "ok"))

        let policy = try await repo.checkVersion()

        #expect(policy.manifestURL == nil)
        #expect(policy.ipaURL == nil)
        #expect(policy.releaseNotes == nil)
    }

    // MARK: C — Optional fields present → URL fields parsed

    @Test("200 with manifestUrl and ipaUrl parses them as URLs")
    func presentOptionalURLFieldsParsedCorrectly() async throws {
        let (repo, transport) = try makeClientAndTransport()
        let extra = #""manifestUrl": "https://example.com/manifest.plist", "ipaUrl": "https://example.com/app.ipa""#
        await transport.enqueue(.ok(), body: okJSON(state: "ok", extraFields: extra))

        let policy = try await repo.checkVersion()

        #expect(policy.manifestURL == URL(string: "https://example.com/manifest.plist"))
        #expect(policy.ipaURL != nil)
    }

    // MARK: D — Fractional-second date decodes correctly

    @Test("200 with fractional-second updatedAt decodes the correct second component")
    func fractionalSecondDateDecodesCorrectly() async throws {
        let (repo, transport) = try makeClientAndTransport()
        let body = HTTPBody("""
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
            "updatedAt": "2026-11-02T12:34:56.789Z"
          },
          "meta": {
            "timestamp": "2026-11-02T00:00:00Z",
            "requestId": "req-00000001",
            "sessionId": "sess-00000001"
          }
        }
        """)
        await transport.enqueue(.ok(), body: body)

        let policy = try await repo.checkVersion()

        let second = Calendar.current.component(.second, from: policy.updatedAt)
        #expect(second == 56)
    }

    // MARK: E — 304 with no prior cache → throws

    @Test("304 with no prior cache throws")
    func notModifiedWithoutCacheThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(304))

        await #expect(throws: (any Error).self) {
            _ = try await repo.checkVersion()
        }
    }

    // MARK: F — 304 with prior cache → returns cached policy

    @Test("304 after a 200 returns the cached policy from the first successful call")
    func notModifiedAfterSuccessReturnsCachedPolicy() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "ok"))
        let firstPolicy = try await repo.checkVersion()

        await transport.enqueue(.status(304))
        let secondPolicy = try await repo.checkVersion()

        #expect(secondPolicy.minimumVersion == firstPolicy.minimumVersion)
    }

    // MARK: G — 400 → throws

    @Test("400 throws")
    func badRequestThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(400), body: errorJSON())

        await #expect(throws: (any Error).self) {
            _ = try await repo.checkVersion()
        }
    }

    // MARK: H — 429 exhausted → throws TrackerAPIError.rateLimited

    @Test("429 exhausted after retries throws TrackerAPIError.rateLimited")
    func tooManyRequestsExhaustedThrowsRateLimited() async throws {
        let (repo, transport) = try makeClientAndTransport()

        var fields429 = HTTPFields()
        fields429[HTTPField.Name("Retry-After")!] = "0"
        let r429 = HTTPResponse(status: .init(code: 429), headerFields: fields429)

        // Enqueue 3 — one original + 2 retries
        await transport.enqueue([(r429, nil), (r429, nil), (r429, nil)])

        do {
            _ = try await repo.checkVersion()
            Issue.record("Expected TrackerAPIError.rateLimited but no error was thrown")
        } catch {
            // The generated Client wraps middleware errors in ClientError; unwrap to find the TrackerAPIError.
            let underlying: any Error
            if let clientError = error as? ClientError {
                underlying = clientError.underlyingError
            } else {
                underlying = error
            }
            if let trackerError = underlying as? TrackerAPIError, case .rateLimited = trackerError {
                // Expected
            } else {
                Issue.record("Expected TrackerAPIError.rateLimited but got \(error)")
            }
        }
    }

    // MARK: I — 500 → throws

    @Test("500 throws")
    func internalServerErrorThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(500), body: errorJSON())

        await #expect(throws: (any Error).self) {
            _ = try await repo.checkVersion()
        }
    }

    // MARK: J — Undocumented status code → throws

    @Test("418 (undocumented) throws")
    func undocumentedStatusThrows() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.status(418))

        await #expect(throws: (any Error).self) {
            _ = try await repo.checkVersion()
        }
    }

    // MARK: K — Transport failure → throws

    @Test("transport failure throws")
    func transportFailureThrows() async throws {
        let throwingTransport = AlwaysThrowingTransport()
        let client = try TrackerClientFactory.make(
            serverURL: baseURL,
            info: makeInfo(),
            tokenProvider: FakeAccessTokenProvider(token: nil),
            sessionRefresher: FakeSessionRefresher(),
            versionOutdatedHandler: FakeVersionOutdatedHandler(),
            transport: throwingTransport
        )
        let repo = GeneratedClientAppVersionRepository(client: client, info: makeInfo())

        await #expect(throws: (any Error).self) {
            _ = try await repo.checkVersion()
        }
    }

    // MARK: L — Request carries required headers

    @Test("request carries X-Platform, X-App-Version, X-Client-Platform and no Authorization header")
    func requestCarriesRequiredHeaders() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "ok"))

        _ = try await repo.checkVersion()

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)

        #expect(req.headerFields[HTTPField.Name("X-Platform")!] == "ios")
        #expect(req.headerFields[HTTPField.Name("X-Build")!] == "1")
        #expect(req.headerFields[HTTPField.Name("X-App-Version")!] == "1.0.0")
        #expect(req.headerFields[HTTPField.Name("X-Client-Platform")!] == "ios")
        // checkAppVersion is a public operation — no bearer token
        #expect(req.headerFields[.authorization] == nil)
    }

    // MARK: M — Request carries platform/version/build query items

    @Test("request URL contains platform, version, and build query parameters")
    func requestURLContainsRequiredQueryItems() async throws {
        let (repo, transport) = try makeClientAndTransport()
        await transport.enqueue(.ok(), body: okJSON(state: "ok"))

        _ = try await repo.checkVersion()

        let recorded = await transport.lastRequest()
        let req = try #require(recorded?.request)
        let path = req.path ?? ""

        #expect(path.contains("platform=ios"))
        #expect(path.contains("version=1.0.0"))
        #expect(path.contains("build=1"))
    }
}

// MARK: - AlwaysThrowingTransport (local to this test file)

private actor AlwaysThrowingTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        throw URLError(.notConnectedToInternet)
    }
}
