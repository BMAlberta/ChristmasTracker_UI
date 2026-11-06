// SeamTests.swift
// ChristmasTrackerTests
//
// Failing tests for Story B2 — Interfaces 3-7:
//   - AccessTokenSeam (AccessTokenProviding)
//   - SessionRefreshSeam (SessionRefreshing)
//   - VersionGate (VersionOutdatedHandling)
//   - RequestIDSeam (RequestIDObserving)
//   - AppDependencies composition root (APIMode-driven client construction)
//
// These tests will fail to compile until the implementer adds the production symbols.

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - AccessTokenSeam Tests

@Suite("AccessTokenSeam Tests")
struct AccessTokenSeamTests {

    // MARK: Helper

    private func makeSUT(token: String?) -> AccessTokenSeam {
        AccessTokenSeam(tokenGetter: { token })
    }

    // MARK: - No token

    @Test("returns nil when token getter returns nil")
    func returnsNilWhenNoToken() async {
        let sut = makeSUT(token: nil)
        let result = await sut.accessToken()
        #expect(result == nil)
    }

    // MARK: - Token present

    @Test("returns token value when token getter returns a string")
    func returnsTokenWhenPresent() async {
        let sut = makeSUT(token: "test-access-token-abc123")
        let result = await sut.accessToken()
        #expect(result == "test-access-token-abc123")
    }
}

// MARK: - SessionRefreshSeam Tests

@Suite("SessionRefreshSeam Tests")
struct SessionRefreshSeamTests {

    // MARK: Helper

    private func makeSUT(
        refresher: @escaping @Sendable () async throws -> Void
    ) -> SessionRefreshSeam {
        SessionRefreshSeam(forceRefresh: refresher)
    }

    // MARK: - Successful refresh

    @Test("refresh completes without throwing when forceRefresh succeeds")
    func refreshSucceeds() async throws {
        let sut = makeSUT(refresher: { /* no-op */ })
        try await sut.refresh()
        // Test passes if no error is thrown
    }

    // MARK: - Credential failure

    @Test("refresh throws credentialFailure when forceRefresh throws invalidRefreshToken")
    func throwsCredentialFailureForInvalidRefreshToken() async throws {
        let sut = makeSUT(refresher: {
            throw AuthenticationError.invalidRefreshToken
        })
        do {
            try await sut.refresh()
            Issue.record("Expected SessionRefreshError.credentialFailure but no error was thrown")
        } catch SessionRefreshError.credentialFailure {
            // Expected
        } catch {
            Issue.record("Expected SessionRefreshError.credentialFailure but got: \(error)")
        }
    }

    @Test("refresh throws credentialFailure when forceRefresh throws sessionExpired")
    func throwsCredentialFailureForSessionExpired() async throws {
        let sut = makeSUT(refresher: {
            throw AuthenticationError.sessionExpired
        })
        do {
            try await sut.refresh()
            Issue.record("Expected SessionRefreshError.credentialFailure but no error was thrown")
        } catch SessionRefreshError.credentialFailure {
            // Expected
        } catch {
            Issue.record("Expected SessionRefreshError.credentialFailure but got: \(error)")
        }
    }

    // MARK: - Non-credential failure

    @Test("refresh throws other when forceRefresh throws a non-credential error")
    func throwsOtherForNetworkError() async throws {
        let sut = makeSUT(refresher: {
            throw AuthenticationError.networkError
        })
        do {
            try await sut.refresh()
            Issue.record("Expected SessionRefreshError.other but no error was thrown")
        } catch SessionRefreshError.other {
            // Expected
        } catch SessionRefreshError.credentialFailure {
            Issue.record("Expected SessionRefreshError.other but got credentialFailure")
        } catch {
            Issue.record("Expected SessionRefreshError.other but got: \(error)")
        }
    }

    // MARK: - Single call-through

    @Test("refresh calls the underlying forceRefresh exactly once")
    func callsForceRefreshExactlyOnce() async throws {
        actor CallCounter {
            var count = 0
            func increment() { count += 1 }
        }
        let counter = CallCounter()
        let sut = makeSUT(refresher: {
            await counter.increment()
        })
        try await sut.refresh()
        let callCount = await counter.count
        #expect(callCount == 1)
    }
}

// MARK: - VersionGate Tests

@Suite("VersionGate Tests")
@MainActor
struct VersionGateTests {

    // MARK: Helper

    private func makeSUT() -> VersionGate {
        VersionGate()
    }

    private func makeDetails(minimumVersion: String = "2.0.0") -> VersionOutdatedDetails {
        VersionOutdatedDetails(
            minimumVersion: minimumVersion,
            minimumBuild: nil,
            latestVersion: nil,
            latestBuild: nil,
            manifestUrl: nil,
            ipaUrl: nil
        )
    }

    // MARK: - Initial state

    @Test("latestDetails is nil on init")
    func initiallyNil() {
        let sut = makeSUT()
        #expect(sut.latestDetails == nil)
    }

    // MARK: - After one call

    @Test("latestDetails equals details after one handleVersionOutdated call")
    func storesDetailsAfterOneCall() async {
        let sut = makeSUT()
        let details = makeDetails(minimumVersion: "1.5.0")
        await sut.handleVersionOutdated(details)
        #expect(sut.latestDetails?.minimumVersion == "1.5.0")
    }

    // MARK: - After two calls

    @Test("latestDetails equals the most recent details after two calls")
    func storesLatestAfterTwoCalls() async {
        let sut = makeSUT()
        let first = makeDetails(minimumVersion: "1.0.0")
        let second = makeDetails(minimumVersion: "2.0.0")
        await sut.handleVersionOutdated(first)
        await sut.handleVersionOutdated(second)
        #expect(sut.latestDetails?.minimumVersion == "2.0.0")
    }
}

// MARK: - RequestIDSeam Tests

@Suite("RequestIDSeam Tests")
struct RequestIDSeamTests {

    // MARK: Helper

    private func makeSUT(isSentryEnabled: Bool = false) -> RequestIDSeam {
        RequestIDSeam(isSentryEnabled: isSentryEnabled)
    }

    // MARK: - Single observe

    @Test("lastRequestID equals observed ID after one observe call")
    func storesFirstRequestID() async {
        let sut = makeSUT()
        await sut.observe(requestID: "req-abc-123")
        #expect(sut.lastRequestID == "req-abc-123")
    }

    // MARK: - Two observations

    @Test("lastRequestID equals the latest ID after two observe calls")
    func storesLatestRequestID() async {
        let sut = makeSUT()
        await sut.observe(requestID: "req-first")
        await sut.observe(requestID: "req-second")
        #expect(sut.lastRequestID == "req-second")
    }

    // MARK: - Sentry disabled

    @Test("observe does not crash and stores ID when Sentry is disabled")
    func doesNotCrashWhenSentryDisabled() async {
        let sut = makeSUT(isSentryEnabled: false)
        await sut.observe(requestID: "req-no-sentry")
        #expect(sut.lastRequestID == "req-no-sentry")
    }
}

// MARK: - AppDependencies Composition Root Tests

@Suite("AppDependencies APIMode Tests")
struct AppDependenciesAPIModeTests {

    // MARK: - Mock mode produces no client

    @Test("trackerClient is nil when effective mode is mock")
    func trackerClientIsNilInMockMode() {
        let deps = AppDependencies.make(mode: .mock, baseURL: URL(string: "https://api.example.com"))
        #expect(deps.trackerClient == nil)
    }

    // MARK: - Real mode produces a client

    @Test("trackerClient is non-nil when effective mode is real and baseURL is provided")
    func trackerClientIsNonNilInRealMode() {
        let deps = AppDependencies.make(mode: .real, baseURL: URL(string: "https://api.example.com"))
        #expect(deps.trackerClient != nil)
    }
}
