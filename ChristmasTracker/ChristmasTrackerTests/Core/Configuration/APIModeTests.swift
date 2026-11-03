//
//  APIModeTests.swift
//  ChristmasTrackerTests
//

import Testing
@testable import ChristmasTracker

@Suite("APIMode Tests")
struct APIModeTests {
    @Test("parse 'mock' returns mock")
    func parseMock() {
        #expect(APIMode.parse("mock") == .mock)
    }

    @Test("parse 'real' returns real")
    func parseReal() {
        #expect(APIMode.parse("real") == .real)
    }

    @Test("parse ' Mock ' (whitespace + mixed case) returns mock")
    func parseMockTrimmedMixedCase() {
        #expect(APIMode.parse(" Mock ") == .mock)
    }

    @Test("parse 'REAL' (uppercase) returns real")
    func parseRealUppercase() {
        #expect(APIMode.parse("REAL") == .real)
    }

    @Test("parse nil returns real")
    func parseNil() {
        #expect(APIMode.parse(nil) == .real)
    }

    @Test("parse empty string returns real")
    func parseEmpty() {
        #expect(APIMode.parse("") == .real)
    }

    @Test("parse unknown value returns real")
    func parseUnknown() {
        #expect(APIMode.parse("staging") == .real)
    }
}

@Suite("readConfiguration Tests")
struct ReadConfigurationTests {
    @Test("apiMode from info dictionary with 'mock'")
    func apiModeFromDictMock() {
        let info: [String: Any] = ["API_MODE": "mock", "APP_ENVIRONMENT": "development",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info)
        #expect(config.apiMode == .mock)
    }

    @Test("apiMode from info dictionary with 'real'")
    func apiModeFromDictReal() {
        let info: [String: Any] = ["API_MODE": "real", "APP_ENVIRONMENT": "production",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info)
        #expect(config.apiMode == .real)
    }

    @Test("apiMode from info dictionary missing API_MODE key defaults to real")
    func apiModeMissingKeyDefaultsReal() {
        let info: [String: Any] = ["APP_ENVIRONMENT": "production",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info)
        #expect(config.apiMode == .real)
    }

    @Test("sentryDSN is nil when SENTRY_DSN is empty")
    func sentryDSNEmptyIsNil() {
        let info: [String: Any] = ["SENTRY_DSN": ""]
        let config = readConfiguration(from: info)
        #expect(config.sentryDSN == nil)
    }

    @Test("sentryDSN is nil when SENTRY_DSN is whitespace only")
    func sentryDSNWhitespaceIsNil() {
        let info: [String: Any] = ["SENTRY_DSN": "   "]
        let config = readConfiguration(from: info)
        #expect(config.sentryDSN == nil)
    }

    @Test("sentryDSN is non-nil and trimmed for a real value")
    func sentryDSNTrimmedNonNil() {
        let info: [String: Any] = ["SENTRY_DSN": "  https://key@o0.ingest.sentry.io/0  "]
        let config = readConfiguration(from: info)
        #expect(config.sentryDSN == "https://key@o0.ingest.sentry.io/0")
    }

    @Test("appEnvironment falls back to 'production' when key is missing")
    func appEnvironmentFallback() {
        let config = readConfiguration(from: nil)
        #expect(config.appEnvironment == "production")
    }

    @Test("readConfiguration reads all duration keys correctly")
    func durationKeys() {
        let info: [String: Any] = [
            "CACHE_DURATION": "30",
            "SESSION_TIMEOUT": "300",
            "BACKGROUND_REFRESH": "60",
            "LOG_FLUSH_INTERVAL": "15"
        ]
        let config = readConfiguration(from: info)
        #expect(config.cacheDuration == 30)
        #expect(config.sessionTimeout == 300)
        #expect(config.backgroundRefreshThreshold == 60)
        #expect(config.logFlushInterval == 15)
    }
}
