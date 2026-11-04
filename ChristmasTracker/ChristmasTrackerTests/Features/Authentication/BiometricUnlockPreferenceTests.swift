//
//  BiometricUnlockPreferenceTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 (Story 3): BiometricUnlockPreference persistence and defaults.
//
//  These tests will fail to compile until:
//    - BiometricUnlockPreference.swift is added (struct + BiometricUnlockPreferring protocol)
//
//  Compile-time failures ARE the expected "failing for the right reason".
//
//  Each test uses an isolated UserDefaults suite so tests are independent and
//  do not pollute .standard. The suite is removed in a defer block each test.
//
//  FakeBiometricUnlockPreference lives in this test target (not the production
//  module) because it has no Preview use case — unlike FakeBiometricAuthenticator.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Test-only fake

/// In-test fake conforming to BiometricUnlockPreferring.
/// Lives in the test target only — no Preview use case.
internal final class FakeBiometricUnlockPreference: BiometricUnlockPreferring {
    var biometricUnlockEnabled: Bool = false
    var biometricSetupOfferShown: Bool = false
}

// MARK: - Suite

@Suite("BiometricUnlockPreference Tests")
struct BiometricUnlockPreferenceTests {

    // MARK: - Constants

    private static let suiteName = "com.christmastracker.test.BiometricUnlockPreferenceTests"

    // MARK: - Factory

    /// Returns a fresh BiometricUnlockPreference backed by an isolated UserDefaults suite.
    /// The returned suite is owned by the caller and must be removed via removeSuite after use.
    private func makeSUT() -> (pref: BiometricUnlockPreference, defaults: UserDefaults) {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        // Start from a clean slate each time.
        defaults.removePersistentDomain(forName: Self.suiteName)
        let pref = BiometricUnlockPreference(defaults: defaults)
        return (pref, defaults)
    }

    // MARK: - BiometricUnlockPreference: Defaults

    @Test("biometricUnlockEnabled defaults to false on a fresh suite")
    func biometricUnlockEnabledDefaultsToFalse() {
        let (pref, defaults) = makeSUT()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        #expect(pref.biometricUnlockEnabled == false)
    }

    @Test("biometricSetupOfferShown defaults to false on a fresh suite")
    func biometricSetupOfferShownDefaultsToFalse() {
        let (pref, defaults) = makeSUT()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        #expect(pref.biometricSetupOfferShown == false)
    }

    // MARK: - BiometricUnlockPreference: Persistence

    @Test("biometricUnlockEnabled persists across instances using the same suite")
    func biometricUnlockEnabledPersistsAcrossInstances() {
        let result = makeSUT()
        var pref = result.pref
        let defaults = result.defaults
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        pref.biometricUnlockEnabled = true
        // Create a second instance backed by the same defaults suite.
        let pref2 = BiometricUnlockPreference(defaults: defaults)
        #expect(pref2.biometricUnlockEnabled == true)
    }

    @Test("biometricSetupOfferShown persists across instances using the same suite")
    func biometricSetupOfferShownPersistsAcrossInstances() {
        let result = makeSUT()
        var pref = result.pref
        let defaults = result.defaults
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        pref.biometricSetupOfferShown = true
        let pref2 = BiometricUnlockPreference(defaults: defaults)
        #expect(pref2.biometricSetupOfferShown == true)
    }

    @Test("Setting biometricUnlockEnabled = true then creating a new instance reads true")
    func biometricUnlockEnabledRoundTrip() {
        let result = makeSUT()
        var pref = result.pref
        let defaults = result.defaults
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        pref.biometricUnlockEnabled = true
        let pref2 = BiometricUnlockPreference(defaults: defaults)
        #expect(pref2.biometricUnlockEnabled == true,
                "New instance with same suite must read back the value written by prior instance")
    }

    // MARK: - Key Independence

    @Test("enabledKey and offerShownKey are distinct — writing one does not affect the other")
    func enabledKeyAndOfferShownKeyAreDistinct() {
        let result = makeSUT()
        var pref = result.pref
        let defaults = result.defaults
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        // Write only the enabled flag.
        pref.biometricUnlockEnabled = true
        // offerShown must remain false.
        let pref2 = BiometricUnlockPreference(defaults: defaults)
        #expect(pref2.biometricUnlockEnabled == true)
        #expect(pref2.biometricSetupOfferShown == false,
                "Writing biometricUnlockEnabled must not change biometricSetupOfferShown")
    }

    @Test("Static key constants are non-empty and distinct strings")
    func staticKeyConstantsAreDistinct() {
        #expect(BiometricUnlockPreference.enabledKey.isEmpty == false)
        #expect(BiometricUnlockPreference.offerShownKey.isEmpty == false)
        #expect(BiometricUnlockPreference.enabledKey != BiometricUnlockPreference.offerShownKey,
                "enabledKey and offerShownKey must be distinct UserDefaults keys")
    }

    // MARK: - FakeBiometricUnlockPreference

    @Test("FakeBiometricUnlockPreference: biometricUnlockEnabled defaults to false")
    func fakeUnlockEnabledDefaultsToFalse() {
        let fake = FakeBiometricUnlockPreference()
        #expect(fake.biometricUnlockEnabled == false)
    }

    @Test("FakeBiometricUnlockPreference: biometricSetupOfferShown defaults to false")
    func fakeOfferShownDefaultsToFalse() {
        let fake = FakeBiometricUnlockPreference()
        #expect(fake.biometricSetupOfferShown == false)
    }

    @Test("FakeBiometricUnlockPreference: setting and reading biometricUnlockEnabled")
    func fakeUnlockEnabledCanBeSet() {
        let fake = FakeBiometricUnlockPreference()
        fake.biometricUnlockEnabled = true
        #expect(fake.biometricUnlockEnabled == true)
    }

    @Test("FakeBiometricUnlockPreference: setting and reading biometricSetupOfferShown")
    func fakeOfferShownCanBeSet() {
        let fake = FakeBiometricUnlockPreference()
        fake.biometricSetupOfferShown = true
        #expect(fake.biometricSetupOfferShown == true)
    }
}
