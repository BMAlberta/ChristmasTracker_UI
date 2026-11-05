// URLSessionConfigurationTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import TrackerAPI

@Suite("TrackerURLSessionConfiguration")
struct URLSessionConfigurationTests {

    // MARK: - SUT

    private func makeSUT() -> URLSessionConfiguration {
        TrackerURLSessionConfiguration.make()
    }

    // MARK: - Cookie settings

    @Test("httpShouldSetCookies is false")
    func httpShouldSetCookiesIsFalse() {
        let config = makeSUT()
        #expect(config.httpShouldSetCookies == false)
    }

    @Test("httpCookieStorage is nil")
    func httpCookieStorageIsNil() {
        let config = makeSUT()
        #expect(config.httpCookieStorage == nil)
    }

    @Test("httpCookieAcceptPolicy is never")
    func httpCookieAcceptPolicyIsNever() {
        let config = makeSUT()
        #expect(config.httpCookieAcceptPolicy == .never)
    }

    // MARK: - Credential storage

    @Test("urlCredentialStorage is nil")
    func urlCredentialStorageIsNil() {
        let config = makeSUT()
        #expect(config.urlCredentialStorage == nil)
    }

    // MARK: - Timeout intervals

    @Test("timeoutIntervalForRequest is 30 seconds")
    func timeoutIntervalForRequestIs30() {
        let config = makeSUT()
        #expect(config.timeoutIntervalForRequest == 30)
    }

    @Test("timeoutIntervalForResource is 60 seconds")
    func timeoutIntervalForResourceIs60() {
        let config = makeSUT()
        #expect(config.timeoutIntervalForResource == 60)
    }

    // MARK: - Connectivity

    @Test("waitsForConnectivity is false")
    func waitsForConnectivityIsFalse() {
        let config = makeSUT()
        #expect(config.waitsForConnectivity == false)
    }
}
