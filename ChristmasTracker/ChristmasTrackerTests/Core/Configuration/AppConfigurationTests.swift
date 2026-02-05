//
//  AppConfigurationTests.swift
//  ChristmasTrackerTests
//
//  Created by Brian Alberta on 2/4/26.
//

import Testing

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
