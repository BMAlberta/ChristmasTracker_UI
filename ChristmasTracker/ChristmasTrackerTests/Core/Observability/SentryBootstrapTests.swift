//
//  SentryBootstrapTests.swift
//  ChristmasTrackerTests
//

import Testing
import Sentry
@testable import ChristmasTracker

@Suite("SentryBootstrap Tests")
struct SentryBootstrapTests {

    // MARK: - makeOptions

    @Test("makeOptions returns nil for empty DSN")
    func makeOptionsEmptyDSN() {
        #expect(SentryBootstrap.makeOptions(dsn: "", environment: "development", release: "1.0") == nil)
    }

    @Test("makeOptions returns nil for blank DSN")
    func makeOptionsBlankDSN() {
        #expect(SentryBootstrap.makeOptions(dsn: "   ", environment: "development", release: "1.0") == nil)
    }

    @Test("makeOptions sendDefaultPii is false")
    func makeOptionsSendDefaultPiiOff() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "development",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.sendDefaultPii == false)
    }

    @Test("makeOptions attachScreenshot and attachViewHierarchy are false")
    func makeOptionsScreenshotAndViewHierarchyOff() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "qa",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.attachScreenshot == false)
        #expect(opts.attachViewHierarchy == false)
    }

    @Test("makeOptions network breadcrumbs and tracking are false")
    func makeOptionsNetworkOff() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "production",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.enableNetworkBreadcrumbs == false)
        #expect(opts.enableNetworkTracking == false)
    }

    @Test("makeOptions enableCaptureFailedRequests is false")
    func makeOptionsCaptureFailedRequestsOff() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "production",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.enableCaptureFailedRequests == false)
    }

    @Test("makeOptions enableUserInteractionTracing is false")
    func makeOptionsUserInteractionTracingOff() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "production",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.enableUserInteractionTracing == false)
    }

    @Test("makeOptions tracesSampleRate is <= 0.1")
    func makeOptionsTracesSampleRateLow() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "production",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        let rate = opts.tracesSampleRate?.doubleValue ?? 1.0
        #expect(rate <= 0.1)
    }

    @Test("makeOptions sets expected environment and release strings")
    func makeOptionsEnvironmentAndRelease() throws {
        let opts = try #require(SentryBootstrap.makeOptions(
            dsn: "https://key@o0.ingest.sentry.io/0",
            environment: "qa",
            release: "com.alberta.ChristmasTracker@5.0+500"
        ))
        #expect(opts.environment == "qa")
        #expect(opts.releaseName == "com.alberta.ChristmasTracker@5.0+500")
    }

    // MARK: - scrubEvent

    @Test("scrubEvent redacts email in message")
    func scrubEventEmail() {
        let event = Event()
        event.message = SentryMessage(formatted: "User test@example.com logged in")
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.message?.formatted.contains("test@example.com") == false)
        #expect(result.message?.formatted.contains("[REDACTED]") == true)
    }

    @Test("scrubEvent redacts Bearer token in exception value")
    func scrubEventBearerToken() {
        let event = Event()
        let exc = Exception(value: "Bearer abc123token", type: "AuthError")
        event.exceptions = [exc]
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.exceptions?.first?.value?.contains("Bearer") == false)
    }

    @Test("scrubEvent redacts email in extras")
    func scrubEventExtras() {
        let event = Event()
        event.extra = ["userEmail": "secret@example.com"]
        let result = SentryBootstrap.scrubEvent(event)
        let val = result.extra?["userEmail"] as? String
        #expect(val?.contains("secret@example.com") == false)
    }

    @Test("scrubEvent redacts email in tags")
    func scrubEventTags() {
        let event = Event()
        event.tags = ["userTag": "user@example.com"]
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.tags?["userTag"]?.contains("user@example.com") == false)
    }

    @Test("scrubEvent clears user and serverName")
    func scrubEventClearsUserAndServerName() {
        let event = Event()
        event.user = User(userId: "u123")
        event.serverName = "prod-server-1"
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.user == nil)
        #expect(result.serverName == nil)
    }

    @Test("scrubEvent redacts UUID in request query string")
    func scrubEventQueryString() {
        let event = Event()
        let req = SentryRequest()
        req.queryString = "token=550e8400-e29b-41d4-a716-446655440000"
        event.request = req
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.request?.queryString?.contains("550e8400") == false)
    }

    @Test("scrubEvent does not alter a clean event except clearing user and serverName")
    func scrubEventCleanEvent() {
        let event = Event()
        event.message = SentryMessage(formatted: "List loaded successfully")
        let result = SentryBootstrap.scrubEvent(event)
        #expect(result.message?.formatted == "List loaded successfully")
        #expect(result.user == nil)
        #expect(result.serverName == nil)
    }

    // MARK: - scrubBreadcrumb

    @Test("scrubBreadcrumb redacts email in message")
    func scrubBreadcrumbEmail() {
        let crumb = Breadcrumb()
        crumb.message = "User user@example.com opened app"
        let result = SentryBootstrap.scrubBreadcrumb(crumb)
        #expect(result.message?.contains("user@example.com") == false)
        #expect(result.message?.contains("[REDACTED]") == true)
    }

    @Test("scrubBreadcrumb redacts Bearer token in data")
    func scrubBreadcrumbData() {
        let crumb = Breadcrumb()
        crumb.data = ["auth": "Bearer supersecrettoken123"]
        let result = SentryBootstrap.scrubBreadcrumb(crumb)
        let val = result.data?["auth"] as? String
        #expect(val?.contains("Bearer") == false)
    }

    @Test("scrubBreadcrumb does not alter a clean breadcrumb")
    func scrubBreadcrumbClean() {
        let crumb = Breadcrumb()
        crumb.message = "Navigation to HomeView"
        let result = SentryBootstrap.scrubBreadcrumb(crumb)
        #expect(result.message == "Navigation to HomeView")
    }
}
