//
//  AppConfigurationTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/4/26.
//

import Testing
import Foundation

@testable import ChristmasTracker

@Suite("AppConfiguration Tests")
struct AppConfigurationTests {

    @Test("Cache duration is configured correctly")
    func testCacheDuration() {
        #expect(AppConfiguration.cacheDuration > 0)
#if DEBUG
        #expect(AppConfiguration.cacheDuration == 30)
#else
        #expect(AppConfiguration.cacheDuration == 900)
#endif
    }

    @Test("Session timeout is configured correctly")
    func testSessionTimeout() {
        #expect(AppConfiguration.sessionTimeout > 0)
#if DEBUG
        #expect(AppConfiguration.sessionTimeout == 300)
#else
        #expect(AppConfiguration.sessionTimeout == 7200)
#endif
    }

    @Test("Environment detection works")
    func testEnvironment() {
#if DEBUG
        #expect(AppConfiguration.environment == "debug")
        #expect(AppConfiguration.isDebug == true)
#else
        #expect(AppConfiguration.environment == "production")
        #expect(AppConfiguration.isDebug == false)
#endif
    }
}

// MARK: - validateBaseURL tests

@Suite("AppConfiguration.validateBaseURL")
struct ValidateBaseURLTests {

    // MARK: Accepted inputs

    @Test("http localhost with explicit port is accepted")
    func httpLocalhostWithPort() throws {
        let result = AppConfiguration.validateBaseURL("http://localhost:3010")
        let url = try #require(try result.get())
        #expect(url.scheme == "http")
        #expect(url.host == "localhost")
        #expect(url.port == 3010)
    }

    @Test("https domain without trailing slash is accepted")
    func httpsDomainNoSlash() throws {
        let result = AppConfiguration.validateBaseURL("https://api.bmalberta.com")
        let url = try #require(try result.get())
        #expect(url.scheme == "https")
        #expect(url.host == "api.bmalberta.com")
    }

    @Test("https domain with trailing slash only is accepted")
    func httpsDomainTrailingSlash() throws {
        let result = AppConfiguration.validateBaseURL("https://api.bmalberta.com/")
        let url = try #require(try result.get())
        #expect(url.scheme == "https")
        #expect(url.host == "api.bmalberta.com")
    }

    // MARK: Rejected inputs — non-empty path

    @Test("URL with a non-trivial path is rejected")
    func urlWithPath() {
        let result = AppConfiguration.validateBaseURL("https://api.bmalberta.com/tracker/v2")
        switch result {
        case .success:
            Issue.record("Expected failure for URL with path, but got success")
        case .failure:
            break
        }
    }

    // MARK: Rejected inputs — empty or missing host

    @Test("Bare scheme with no host is rejected")
    func bareSchemeNoHost() {
        let result = AppConfiguration.validateBaseURL("https:")
        switch result {
        case .success:
            Issue.record("Expected failure for bare scheme, but got success")
        case .failure:
            break
        }
    }

    @Test("Empty string is rejected")
    func emptyString() {
        let result = AppConfiguration.validateBaseURL("")
        switch result {
        case .success:
            Issue.record("Expected failure for empty string, but got success")
        case .failure:
            break
        }
    }

    // MARK: Rejected inputs — unparseable URL

    @Test("URL with a literal space is rejected")
    func urlWithLiteralSpace() {
        let result = AppConfiguration.validateBaseURL("https:/ /api.bmalberta.com")
        switch result {
        case .success:
            Issue.record("Expected failure for URL with literal space, but got success")
        case .failure:
            break
        }
    }

    // MARK: Rejected inputs — wrong scheme

    @Test("ftp scheme is rejected")
    func ftpScheme() {
        let result = AppConfiguration.validateBaseURL("ftp://x")
        switch result {
        case .success:
            Issue.record("Expected failure for ftp scheme, but got success")
        case .failure:
            break
        }
    }

    // MARK: Rejected inputs — nil

    @Test("nil input is rejected")
    func nilInput() {
        let result = AppConfiguration.validateBaseURL(nil)
        switch result {
        case .success:
            Issue.record("Expected failure for nil input, but got success")
        case .failure:
            break
        }
    }

    // MARK: Rejected inputs — query string

    @Test("URL with a query string is rejected")
    func urlWithQueryString() {
        let result = AppConfiguration.validateBaseURL("https://api.bmalberta.com?foo=bar")
        switch result {
        case .success:
            Issue.record("Expected failure for URL with query string, but got success")
        case .failure:
            break
        }
    }
}

// MARK: - readConfiguration API_BASE_URL tests

@Suite("readConfiguration apiBaseURL field")
struct ReadConfigurationBaseURLTests {

    @Test("Valid API_BASE_URL produces a non-nil apiBaseURL")
    func validURLProducesNonNil() {
        let config = readConfiguration(from: ["API_BASE_URL": "https://api.bmalberta.com"], apiModeOverride: nil)
        #expect(config.apiBaseURL != nil)
        #expect(config.apiBaseURL?.scheme == "https")
        #expect(config.apiBaseURL?.host == "api.bmalberta.com")
    }

    @Test("Missing API_BASE_URL key produces nil apiBaseURL")
    func missingKeyProducesNil() {
        let config = readConfiguration(from: [:], apiModeOverride: nil)
        #expect(config.apiBaseURL == nil)
    }

    @Test("Invalid API_BASE_URL produces nil apiBaseURL")
    func invalidURLProducesNil() {
        let config = readConfiguration(from: ["API_BASE_URL": "ftp://x"], apiModeOverride: nil)
        #expect(config.apiBaseURL == nil)
    }
}
