//
//  APIModeTests.swift
//  ChristmasTrackerTests
//

import Foundation
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

    @Test("parse 'mock' with trailing newline returns mock")
    func parseMockWithTrailingNewline() {
        #expect(APIMode.parse("mock\n") == .mock)
    }
}

@Suite("readConfiguration Tests")
struct ReadConfigurationTests {
    @Test("apiMode from info dictionary with 'mock'")
    func apiModeFromDictMock() {
        let info: [String: Any] = ["API_MODE": "mock", "APP_ENVIRONMENT": "development",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.apiMode == .mock)
    }

    @Test("apiMode from info dictionary with 'real'")
    func apiModeFromDictReal() {
        let info: [String: Any] = ["API_MODE": "real", "APP_ENVIRONMENT": "production",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.apiMode == .real)
    }

    @Test("apiMode from info dictionary missing API_MODE key defaults to real")
    func apiModeMissingKeyDefaultsReal() {
        let info: [String: Any] = ["APP_ENVIRONMENT": "production",
                                   "API_BASE_URL": "https://example.com"]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.apiMode == .real)
    }

    @Test("sentryDSN is nil when SENTRY_DSN is empty")
    func sentryDSNEmptyIsNil() {
        let info: [String: Any] = ["SENTRY_DSN": ""]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.sentryDSN == nil)
    }

    @Test("sentryDSN is nil when SENTRY_DSN is whitespace only")
    func sentryDSNWhitespaceIsNil() {
        let info: [String: Any] = ["SENTRY_DSN": "   "]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.sentryDSN == nil)
    }

    @Test("sentryDSN is non-nil and trimmed for a real value")
    func sentryDSNTrimmedNonNil() {
        let info: [String: Any] = ["SENTRY_DSN": "  https://key@o0.ingest.sentry.io/0  "]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.sentryDSN == "https://key@o0.ingest.sentry.io/0")
    }

    @Test("appEnvironment falls back to 'production' when key is missing")
    func appEnvironmentFallback() {
        let config = readConfiguration(from: nil, apiModeOverride: nil)
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
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.cacheDuration == 30)
        #expect(config.sessionTimeout == 300)
        #expect(config.backgroundRefreshThreshold == 60)
        #expect(config.logFlushInterval == 15)
    }

    @Test("sentryDSN with trailing newline is trimmed and non-nil")
    func sentryDSNTrailingNewline() {
        let info: [String: Any] = ["SENTRY_DSN": "https://key@o0.ingest.sentry.io/0\n"]
        let config = readConfiguration(from: info, apiModeOverride: nil)
        #expect(config.sentryDSN == "https://key@o0.ingest.sentry.io/0")
    }
}

// Mutates UserDefaults.standard, so the suite must not run in parallel with itself.
@Suite("readConfiguration hermeticity", .serialized)
struct ReadConfigurationHermeticityTests {
    private static let key = "apiModeOverride"

    private func makeInfo(apiMode: String?, environment: String) -> [String: Any] {
        var info: [String: Any] = ["APP_ENVIRONMENT": environment,
                                   "API_BASE_URL": "https://example.com"]
        if let apiMode { info["API_MODE"] = apiMode }
        return info
    }

    /// Runs `body` with UserDefaults.standard[apiModeOverride] set to `value` (or removed
    /// when nil), restoring any previous value afterwards.
    private func withStandardOverride(_ value: String?, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Self.key)
        defer {
            if let previous {
                defaults.set(previous, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
        if let value {
            defaults.set(value, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
        body()
    }

    @Test("UserDefaults 'mock' is ignored when apiModeOverride is nil")
    func standardDefaultsMockIgnored() {
        let info = makeInfo(apiMode: "real", environment: "development")
        withStandardOverride("mock") {
            let config = readConfiguration(from: info, apiModeOverride: nil)
            #expect(config.apiMode == .real)
        }
    }

    @Test("UserDefaults 'real' is ignored when apiModeOverride is nil")
    func standardDefaultsRealIgnored() {
        let info = makeInfo(apiMode: "mock", environment: "development")
        withStandardOverride("real") {
            let config = readConfiguration(from: info, apiModeOverride: nil)
            #expect(config.apiMode == .mock)
        }
    }

    @Test("Result is identical with the UserDefaults key present or absent")
    func identicalWithKeyAbsent() {
        let info = makeInfo(apiMode: "mock", environment: "qa")
        var absent: APIMode?
        var presentMock: APIMode?
        var presentReal: APIMode?
        withStandardOverride(nil) { absent = readConfiguration(from: info, apiModeOverride: nil).apiMode }
        withStandardOverride("mock") { presentMock = readConfiguration(from: info, apiModeOverride: nil).apiMode }
        withStandardOverride("real") { presentReal = readConfiguration(from: info, apiModeOverride: nil).apiMode }
        #expect(absent == .mock)
        #expect(presentMock == absent)
        #expect(presentReal == absent)
    }

    @Test("Explicit override 'mock' wins over info 'real' in non-production")
    func explicitMockWinsNonProduction() {
        let config = readConfiguration(from: makeInfo(apiMode: "real", environment: "development"),
                                       apiModeOverride: "mock")
        #expect(config.apiMode == .mock)
    }

    @Test("Explicit override 'real' wins over info 'mock' in non-production")
    func explicitRealWinsNonProduction() {
        let config = readConfiguration(from: makeInfo(apiMode: "mock", environment: "qa"),
                                       apiModeOverride: "real")
        #expect(config.apiMode == .real)
    }

    @Test("Explicit override 'mock' is ignored in production")
    func explicitMockIgnoredInProduction() {
        let config = readConfiguration(from: makeInfo(apiMode: "real", environment: "production"),
                                       apiModeOverride: "mock")
        #expect(config.apiMode == .real)
    }

    @Test("Explicit override 'real' is ignored in production")
    func explicitRealIgnoredInProduction() {
        let config = readConfiguration(from: makeInfo(apiMode: "mock", environment: "production"),
                                       apiModeOverride: "real")
        #expect(config.apiMode == .mock)
    }

    @Test("Explicit override is ignored when APP_ENVIRONMENT is missing (defaults to production)")
    func explicitOverrideIgnoredWhenEnvironmentMissing() {
        let info: [String: Any] = ["API_MODE": "real"]
        let config = readConfiguration(from: info, apiModeOverride: "mock")
        #expect(config.apiMode == .real)
    }

    @Test("Garbage override falls back to the info value (mock)")
    func garbageOverrideFallsBackToInfoMock() {
        let config = readConfiguration(from: makeInfo(apiMode: "mock", environment: "development"),
                                       apiModeOverride: "banana")
        #expect(config.apiMode == .mock)
    }

    @Test("Garbage override falls back to the info value (real)")
    func garbageOverrideFallsBackToInfoReal() {
        let config = readConfiguration(from: makeInfo(apiMode: "real", environment: "development"),
                                       apiModeOverride: "banana")
        #expect(config.apiMode == .real)
    }
}
