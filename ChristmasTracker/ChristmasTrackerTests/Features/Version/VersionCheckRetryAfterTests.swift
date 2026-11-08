// VersionCheckRetryAfterTests.swift
// ChristmasTrackerTests
// Copyright © 2026 BMAlberta. All rights reserved.
//
// I2b-2d E4 (decision D3): a 429 from checkAppVersion reaches callers as
// TrackerAPIError.rateLimited(retryAfter:) with the server's retry-after seconds, never the
// numeric error code (8001), and never wrapped in ClientError, so VersionService backs off.
// All fakes are local; no real sleeps (the rate-limit sleeper is a recording fake).

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

@Suite("VersionCheck retry-after")
@MainActor
struct VersionCheckRetryAfterTests {

    // MARK: - SUT factories

    /// A generated Client with only the package's real RateLimitMiddleware, using a recording
    /// sleeper so retries do not wait.
    private func makeRateLimitedSUT(
        responses: [(HTTPResponse, HTTPBody?)]
    ) throws -> (GeneratedClientAppVersionRepository, RecordingSleeper) {
        let sleeper = RecordingSleeper()
        let client = Client(
            serverURL: try makeBaseURL(),
            configuration: Configuration(dateTranscoder: TrackerDateTranscoder()),
            transport: ScriptedTransport(responses: responses),
            middlewares: [RateLimitMiddleware(sleeper: sleeper)]
        )
        return (GeneratedClientAppVersionRepository(client: client, info: makeInfo()), sleeper)
    }

    /// A generated Client with no middleware, so a 429 reaches the repository's typed
    /// `.tooManyRequests` arm.
    private func makeTypedSUT(response: (HTTPResponse, HTTPBody?)) throws -> GeneratedClientAppVersionRepository {
        let client = Client(
            serverURL: try makeBaseURL(),
            configuration: Configuration(dateTranscoder: TrackerDateTranscoder()),
            transport: ScriptedTransport(responses: [response]),
            middlewares: []
        )
        return GeneratedClientAppVersionRepository(client: client, info: makeInfo())
    }

    /// A factory-built client (the production middleware chain), as VersionCheckRepositoryTests does.
    private func makeFactorySUT(responses: [(HTTPResponse, HTTPBody?)]) throws -> GeneratedClientAppVersionRepository {
        let client = try TrackerClientFactory.make(
            serverURL: try makeBaseURL(),
            info: makeInfo(),
            tokenProvider: NilAccessTokenProvider(),
            sessionRefresher: NoopSessionRefresher(),
            versionOutdatedHandler: NoopVersionOutdatedHandler(),
            transport: ScriptedTransport(responses: responses)
        )
        return GeneratedClientAppVersionRepository(client: client, info: makeInfo())
    }

    // MARK: - 1. Real RateLimitMiddleware with a recording sleeper

    @Test("Retry-After 7 on three 429s throws rateLimited(7) directly and waits [7, 7]")
    func retryAfterHeaderSevenThrowsRateLimitedSevenDirectly() async throws {
        let r429 = try make429(retryAfterHeader: "7")
        let (repo, sleeper) = try makeRateLimitedSUT(responses: [
            (r429, nil), (r429, nil), (r429, nil)
        ])

        let error = try #require(await thrownError(from: repo))

        #expect(!(error is ClientError), "rateLimited must be thrown directly, not wrapped in ClientError: \(error)")
        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds == 7)
        #expect(await sleeper.recordedWaits == [7, 7])
    }

    @Test("details.retryAfter 12 with no header throws rateLimited(10), the middleware's single-wait cap")
    func bodyRetryAfterTwelveIsCappedAtTen() async throws {
        // RateLimitMiddleware caps a single wait at 10 seconds (RateLimitMiddleware.swift:10
        // `maxSingleWait`, applied at :70), so a server value of 12 is reported and waited as 10.
        let r429 = make429()
        let (repo, sleeper) = try makeRateLimitedSUT(responses: [
            (r429, rateLimitBody(retryAfter: "12")),
            (r429, rateLimitBody(retryAfter: "12")),
            (r429, rateLimitBody(retryAfter: "12"))
        ])

        let error = try #require(await thrownError(from: repo))

        #expect(!(error is ClientError), "rateLimited must be thrown directly, not wrapped in ClientError: \(error)")
        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds == 10)
        #expect(await sleeper.recordedWaits == [10, 10])
    }

    @Test("Three 429s with neither header nor details throw rateLimited(1), the package default")
    func neitherHeaderNorDetailsGivesPackageDefault() async throws {
        let r429 = make429()
        let (repo, sleeper) = try makeRateLimitedSUT(responses: [
            (r429, rateLimitBody(retryAfter: nil)),
            (r429, rateLimitBody(retryAfter: nil)),
            (r429, rateLimitBody(retryAfter: nil))
        ])

        let error = try #require(await thrownError(from: repo))

        #expect(!(error is ClientError), "rateLimited must be thrown directly, not wrapped in ClientError: \(error)")
        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds == 1)
        #expect(await sleeper.recordedWaits == [1, 1])
    }

    // MARK: - 2. Typed .tooManyRequests arm (no middleware)

    @Test("Typed arm: details.retryAfter 12 gives rateLimited(12), never the error code 8001")
    func typedArmReadsDetailsRetryAfter() async throws {
        let repo = try makeTypedSUT(response: (make429(), rateLimitBody(retryAfter: "12")))

        let error = try #require(await thrownError(from: repo))

        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds != 8001, "The error code 8001 must never be used as the retry-after seconds")
        #expect(seconds == 12)
    }

    @Test("Typed arm: no details gives rateLimited(1), never the error code 8001")
    func typedArmWithoutDetailsGivesPackageDefault() async throws {
        let repo = try makeTypedSUT(response: (make429(), rateLimitBody(retryAfter: nil)))

        let error = try #require(await thrownError(from: repo))

        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds != 8001, "The error code 8001 must never be used as the retry-after seconds")
        #expect(seconds == 1)
    }

    @Test("Typed arm: the contract's RateLimitError example (retryAfter 900) gives 900 uncapped, never 8001")
    func typedArmContractExampleIsNotCapped() async throws {
        // The typed arm applies no cap (Gate 1 E4 (b)); only RateLimitMiddleware caps waits.
        let repo = try makeTypedSUT(response: (make429(), rateLimitBody(retryAfter: "900")))

        let error = try #require(await thrownError(from: repo))

        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds != 8001, "The error code 8001 must never be used as the retry-after seconds")
        #expect(seconds == 900)
    }

    @Test("Typed arm: a floating-point details.retryAfter 2.5 gives rateLimited(2.5)")
    func typedArmAcceptsFloatingPointRetryAfter() async throws {
        let repo = try makeTypedSUT(response: (make429(), rateLimitBody(retryAfter: "2.5")))

        let error = try #require(await thrownError(from: repo))

        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds == 2.5)
    }

    @Test("Typed arm: a non-number details.retryAfter falls back to rateLimited(1)")
    func typedArmNonNumberRetryAfterGivesPackageDefault() async throws {
        let repo = try makeTypedSUT(response: (make429(), rateLimitBody(retryAfter: "\"12\"")))

        let error = try #require(await thrownError(from: repo))

        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds != 8001, "The error code 8001 must never be used as the retry-after seconds")
        #expect(seconds == 1)
    }

    // MARK: - 3. Factory-built client

    @Test("Factory-built: Retry-After 0 on three 429s throws rateLimited(0) directly")
    func factoryBuiltRetryAfterZeroThrowsRateLimitedDirectly() async throws {
        // Retry-After 0 means the factory's DefaultSleeper waits zero seconds between retries.
        let r429 = try make429(retryAfterHeader: "0")
        let repo = try makeFactorySUT(responses: [(r429, nil), (r429, nil), (r429, nil)])

        let error = try #require(await thrownError(from: repo))

        #expect(!(error is ClientError), "rateLimited must be thrown directly, not wrapped in ClientError: \(error)")
        let seconds = try #require(directRateLimitedSeconds(error), "Expected TrackerAPIError.rateLimited, got \(error)")
        #expect(seconds == 0)
    }

    // MARK: - 4. VersionService backs off

    @Test("VersionService.check() over a factory-built 429 (Retry-After 0 x3) sets lastErrorCategory to backOff")
    func versionServiceBacksOffOnRateLimit() async throws {
        let r429 = try make429(retryAfterHeader: "0")
        let repo = try makeFactorySUT(responses: [(r429, nil), (r429, nil), (r429, nil)])
        let sut = VersionService(repository: repo)

        await sut.check()

        #expect(sut.lastErrorCategory == .backOff)
        #expect(sut.lastPolicy == nil)
    }

    // MARK: - Helpers

    private func thrownError(from repo: GeneratedClientAppVersionRepository) async -> (any Error)? {
        do {
            _ = try await repo.checkVersion()
            return nil
        } catch {
            return error
        }
    }

    /// The seconds of a TrackerAPIError.rateLimited thrown directly; nil for anything else,
    /// including a rateLimited wrapped in ClientError.
    private func directRateLimitedSeconds(_ error: any Error) -> TimeInterval? {
        guard let trackerError = error as? TrackerAPIError,
              case .rateLimited(let retryAfter) = trackerError else {
            return nil
        }
        return retryAfter
    }
}

// MARK: - Fixtures

private func makeBaseURL() throws -> URL {
    try #require(URL(string: "https://api.example.com"))
}

private func makeInfo() -> AppClientInfo {
    AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0")
}

private func make429() -> HTTPResponse {
    var fields = HTTPFields()
    fields[.contentType] = "application/json"
    return HTTPResponse(status: .init(code: 429), headerFields: fields)
}

private func make429(retryAfterHeader value: String) throws -> HTTPResponse {
    let name = try #require(HTTPField.Name("Retry-After"))
    var response = make429()
    response.headerFields[name] = value
    return response
}

/// A full error envelope per the contract's Error schema (success, error.code, error.errorCode,
/// error.message, meta) and its RateLimitError example (code 8001, RATE_LIMIT_EXCEEDED).
/// `retryAfter` is the raw JSON value for error.details.retryAfter; nil omits details entirely.
private func rateLimitBody(retryAfter: String?) -> HTTPBody {
    let details = retryAfter.map { #", "details": {"retryAfter": \#($0)}"# } ?? ""
    return HTTPBody("""
    {
      "success": false,
      "error": {
        "code": 8001,
        "errorCode": "RATE_LIMIT_EXCEEDED",
        "message": "Too many requests. Please try again later"\(details)
      },
      "meta": {
        "timestamp": "2025-12-30T10:00:00Z",
        "requestId": "123e4567-e89b-12d3-a456-426614174000",
        "sessionId": "987fcdeb-51a2-43f7-8912-314159265358"
      }
    }
    """)
}

// MARK: - Fakes

/// Records each requested wait and returns at once (no real sleep).
private actor RecordingSleeper: RateLimitSleeping {
    private(set) var recordedWaits: [TimeInterval] = []

    func sleep(seconds: TimeInterval) async {
        recordedWaits.append(seconds)
    }
}

/// Returns the scripted responses in order; a plain 200 with no body once they run out.
private actor ScriptedTransport: ClientTransport {
    private var responses: [(HTTPResponse, HTTPBody?)]

    init(responses: [(HTTPResponse, HTTPBody?)]) {
        self.responses = responses
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if responses.isEmpty {
            return (HTTPResponse(status: .ok), nil)
        }
        return responses.removeFirst()
    }
}

private actor NilAccessTokenProvider: AccessTokenProviding {
    func accessToken() async -> String? { nil }
}

private actor NoopSessionRefresher: SessionRefreshing {
    func refresh() async throws {}
}

private actor NoopVersionOutdatedHandler: VersionOutdatedHandling {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async {}
}
