//
//  LockPolicyTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1: inactivity lock — LockPolicy resolution and clamping.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("LockPolicy Tests")
struct LockPolicyTests {

    // MARK: - Factory

    private func makeSUT(
        defaults: UserDefaults,
        infoDictionary: [String: Any]?
    ) -> LockPolicy {
        LockPolicy(defaults: defaults, infoDictionary: infoDictionary)
    }

    // MARK: - Helpers

    /// Returns an isolated UserDefaults suite for each test to prevent cross-test pollution.
    private func makeDefaults() -> UserDefaults {
        let suite = "com.christmastracker.tests.lockpolicy.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - Resolution Order Tests

    @Test("Default 10 when no override and no infoDictionary")
    func defaultTenWhenNoOverrideAndNoInfoDictionary() {
        let defaults = makeDefaults()
        let sut = makeSUT(defaults: defaults, infoDictionary: nil)
        #expect(sut.timeoutMinutes == 10)
    }

    @Test("Info.plist value 15 wins when no override")
    func infoPlistValueWinsWhenNoOverride() {
        let defaults = makeDefaults()
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 15)
    }

    @Test("Valid override (5) wins over info.plist value (15)")
    func validOverrideWinsOverInfoPlist() {
        let defaults = makeDefaults()
        defaults.set("5", forKey: "inactivityLockMinutesOverride")
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 5)
    }

    @Test("Override 0 is ignored, falls back to info.plist")
    func overrideZeroIgnoredFallsBackToInfoPlist() {
        let defaults = makeDefaults()
        defaults.set("0", forKey: "inactivityLockMinutesOverride")
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 15)
    }

    @Test("Override -3 is ignored, falls back to info.plist")
    func overrideNegativeIgnoredFallsBackToInfoPlist() {
        let defaults = makeDefaults()
        defaults.set("-3", forKey: "inactivityLockMinutesOverride")
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 15)
    }

    @Test("Override 99 is ignored (>30), falls back to info.plist")
    func overrideAboveMaxIgnoredFallsBackToInfoPlist() {
        let defaults = makeDefaults()
        defaults.set("99", forKey: "inactivityLockMinutesOverride")
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 15)
    }

    @Test("Override 'abc' is ignored, falls back to info.plist")
    func overrideNonNumericIgnoredFallsBackToInfoPlist() {
        let defaults = makeDefaults()
        defaults.set("abc", forKey: "inactivityLockMinutesOverride")
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "15"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 15)
    }

    @Test("Info.plist 0 ignored, falls back to hardcoded 10")
    func infoPlistZeroIgnoredFallsBackToDefault() {
        let defaults = makeDefaults()
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "0"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 10)
    }

    @Test("Info.plist 99 ignored, falls back to hardcoded 10")
    func infoPlistAboveMaxIgnoredFallsBackToDefault() {
        let defaults = makeDefaults()
        let info: [String: Any] = ["INACTIVITY_LOCK_MINUTES": "99"]
        let sut = makeSUT(defaults: defaults, infoDictionary: info)
        #expect(sut.timeoutMinutes == 10)
    }

    // MARK: - Clamp Tests

    @Test("Clamp boundaries: clamp(1) == 1, clamp(30) == 30")
    func clampBoundaries() {
        #expect(LockPolicy.clamp(1) == 1)
        #expect(LockPolicy.clamp(30) == 30)
    }

    @Test("Clamp out-of-range: clamp(0) == 1, clamp(31) == 30, clamp(-5) == 1")
    func clampOutOfRange() {
        #expect(LockPolicy.clamp(0) == 1)
        #expect(LockPolicy.clamp(31) == 30)
        #expect(LockPolicy.clamp(-5) == 1)
    }

    // MARK: - Parse Tests

    @Test("parse returns expected values for valid, boundary, and invalid inputs")
    func parseVariousInputs() {
        #expect(LockPolicy.parse("10") == 10)
        #expect(LockPolicy.parse("0") == nil)
        #expect(LockPolicy.parse("-1") == nil)
        #expect(LockPolicy.parse("abc") == nil)
        #expect(LockPolicy.parse(nil) == nil)
        #expect(LockPolicy.parse("99") == nil)
    }

    @Test("parse handles leading and trailing whitespace")
    func parseTrimsWhitespace() {
        #expect(LockPolicy.parse("  10  ") == 10)
        #expect(LockPolicy.parse("  1") == 1)
        #expect(LockPolicy.parse("30  ") == 30)
        #expect(LockPolicy.parse("   ") == nil)
    }
}
