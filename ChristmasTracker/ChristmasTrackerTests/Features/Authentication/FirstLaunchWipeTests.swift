//
//  FirstLaunchWipeTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2a-3: first-launch wipe of 4.4 legacy data.
//
//  Expected failure state BEFORE Story 3 implementation:
//  All tests fail at compile time because FirstLaunchWipe, KeychainWiping, and
//  LiveKeychainWiper do not yet exist in the production target.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - MockKeychainWiper

/// Spy that records call counts for both wipe methods and can be configured to throw.
final class MockKeychainWiper: KeychainWiping, @unchecked Sendable {

    private let lock = NSLock()
    private var _genericPasswordDeleteCallCount: Int = 0
    private var _internetPasswordDeleteCallCount: Int = 0
    private var _shouldThrowOnGenericPassword: Bool = false
    private var _shouldThrowOnInternetPassword: Bool = false

    var genericPasswordDeleteCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _genericPasswordDeleteCallCount
    }

    var internetPasswordDeleteCallCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _internetPasswordDeleteCallCount
    }

    var wasGenericPasswordDeleteCalled: Bool { genericPasswordDeleteCallCount > 0 }
    var wasInternetPasswordDeleteCalled: Bool { internetPasswordDeleteCallCount > 0 }

    func configureToThrowOnGenericPassword(_ shouldThrow: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        _shouldThrowOnGenericPassword = shouldThrow
    }

    func configureToThrowOnInternetPassword(_ shouldThrow: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        _shouldThrowOnInternetPassword = shouldThrow
    }

    func resetCallCounts() {
        lock.lock(); defer { lock.unlock() }
        _genericPasswordDeleteCallCount = 0
        _internetPasswordDeleteCallCount = 0
    }

    // MARK: - KeychainWiping

    func deleteAllGenericPasswords() throws {
        lock.lock()
        let shouldThrow = _shouldThrowOnGenericPassword
        _genericPasswordDeleteCallCount += 1
        lock.unlock()

        if shouldThrow {
            throw MockKeychainWiperError.simulatedGenericPasswordFailure
        }
    }

    func deleteAllInternetPasswords() throws {
        lock.lock()
        let shouldThrow = _shouldThrowOnInternetPassword
        _internetPasswordDeleteCallCount += 1
        lock.unlock()

        if shouldThrow {
            throw MockKeychainWiperError.simulatedInternetPasswordFailure
        }
    }
}

enum MockKeychainWiperError: Error {
    case simulatedGenericPasswordFailure
    case simulatedInternetPasswordFailure
}

// MARK: - Suite

@Suite("FirstLaunchWipe Tests")
struct FirstLaunchWipeTests {

    // MARK: - Factory

    /// Creates an isolated `UserDefaults` suite and a fresh `MockKeychainWiper`.
    /// The suite name is randomized to prevent cross-test contamination.
    private func makeSUT(
        mock mockOverride: MockKeychainWiper? = nil
    ) -> (sut: FirstLaunchWipe, defaults: UserDefaults, mock: MockKeychainWiper) {
        // Built here, not as a default argument: default arguments are evaluated nonisolated.
        let mock = mockOverride ?? MockKeychainWiper()
        let suiteName = "com.christmastracker.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = FirstLaunchWipe(
            defaults: defaults,
            fileManager: .default,
            keychainWiper: mock
        )
        return (sut, defaults, mock)
    }

    // MARK: - Test 1: savedEmail removed after wipe

    /// Pre-populate the isolated UserDefaults with "savedEmail". After performIfNeeded(),
    /// the key must be absent.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("savedEmail is removed from UserDefaults after first launch wipe")
    func savedEmailRemovedAfterWipe() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("test@example.com", forKey: "savedEmail")

        sut.performIfNeeded()

        #expect(
            defaults.string(forKey: "savedEmail") == nil,
            "savedEmail must be nil after the first-launch wipe"
        )
    }

    // MARK: - Test 2: generic passwords deleted

    /// After performIfNeeded(), deleteAllGenericPasswords() must have been called on the
    /// keychain wiper.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("deleteAllGenericPasswords() is called during first launch wipe")
    func genericPasswordsDeletedAfterWipe() {
        let mock = MockKeychainWiper()
        let (sut, _, _) = makeSUT(mock: mock)

        sut.performIfNeeded()

        #expect(
            mock.wasGenericPasswordDeleteCalled,
            "deleteAllGenericPasswords() must be called during performIfNeeded()"
        )
    }

    // MARK: - Test 3: internet passwords deleted

    /// After performIfNeeded(), deleteAllInternetPasswords() must have been called on the
    /// keychain wiper.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("deleteAllInternetPasswords() is called during first launch wipe")
    func internetPasswordsDeletedAfterWipe() {
        let mock = MockKeychainWiper()
        let (sut, _, _) = makeSUT(mock: mock)

        sut.performIfNeeded()

        #expect(
            mock.wasInternetPasswordDeleteCalled,
            "deleteAllInternetPasswords() must be called during performIfNeeded()"
        )
    }

    // MARK: - Test 4: marker written after successful wipe

    /// After a successful performIfNeeded(), the marker key must equal markerVersion (1).
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("Marker version 1 is written to UserDefaults after a successful wipe")
    func markerWrittenAfterSuccessfulWipe() {
        let (sut, defaults, _) = makeSUT()

        sut.performIfNeeded()

        #expect(
            defaults.integer(forKey: FirstLaunchWipe.markerKey) == FirstLaunchWipe.markerVersion,
            "Marker key must equal markerVersion after a successful wipe"
        )
    }

    // MARK: - Test 5: second launch is a no-op

    /// After the first successful wipe (marker written), re-writing "savedEmail" and
    /// calling performIfNeeded() again must leave "savedEmail" intact.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("Second call to performIfNeeded() is a no-op when marker is already at version 1")
    func secondLaunchIsNoOp() {
        let (sut, defaults, _) = makeSUT()

        // First wipe
        defaults.set("original@example.com", forKey: "savedEmail")
        sut.performIfNeeded()
        #expect(
            defaults.integer(forKey: FirstLaunchWipe.markerKey) == FirstLaunchWipe.markerVersion,
            "Precondition: marker must be written after first wipe"
        )

        // Write legacy key back, simulate re-launch
        defaults.set("returned@example.com", forKey: "savedEmail")
        sut.performIfNeeded()

        // Key must survive because the marker was already at version 1
        #expect(
            defaults.string(forKey: "savedEmail") == "returned@example.com",
            "savedEmail must still be present on second launch — wipe is a no-op when marker is set"
        )
    }

    // MARK: - Test 6: marker not written when Keychain wipe fails

    /// When deleteAllGenericPasswords() throws, the marker must NOT be written.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("Marker is not written when the Keychain wipe step fails")
    func markerNotWrittenWhenKeychainWipeFails() {
        let mock = MockKeychainWiper()
        mock.configureToThrowOnGenericPassword(true)
        let (sut, defaults, _) = makeSUT(mock: mock)

        sut.performIfNeeded()

        let storedVersion = defaults.integer(forKey: FirstLaunchWipe.markerKey)
        #expect(
            storedVersion != FirstLaunchWipe.markerVersion,
            "Marker must NOT be written when a wipe step throws — stored value was \(storedVersion)"
        )
    }

    // MARK: - Test 7: retry after failure completes

    /// First call: mock throws; marker not written. Second call: mock succeeds;
    /// "savedEmail" must be nil and the marker must be written.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("A retry after a failed wipe completes successfully")
    func retryAfterFailureCompletes() {
        let mock = MockKeychainWiper()
        mock.configureToThrowOnGenericPassword(true)
        let (sut, defaults, _) = makeSUT(mock: mock)

        // First attempt: fails
        defaults.set("retry@example.com", forKey: "savedEmail")
        sut.performIfNeeded()
        #expect(
            defaults.integer(forKey: FirstLaunchWipe.markerKey) != FirstLaunchWipe.markerVersion,
            "Precondition: marker must not be written after a failed attempt"
        )

        // Second attempt: succeeds
        mock.configureToThrowOnGenericPassword(false)
        defaults.set("retry@example.com", forKey: "savedEmail")
        sut.performIfNeeded()

        #expect(
            defaults.string(forKey: "savedEmail") == nil,
            "savedEmail must be nil after a successful retry"
        )
        #expect(
            defaults.integer(forKey: FirstLaunchWipe.markerKey) == FirstLaunchWipe.markerVersion,
            "Marker must be written after a successful retry"
        )
    }

    // MARK: - Test 8: device-level defaults survive the wipe

    /// A key that is NOT in the wipe list must still be present after performIfNeeded().
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("Keys outside the wipe list survive the wipe")
    func deviceLevelDefaultsSurviveWipe() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("system", forKey: "deviceSetting.appearance")

        sut.performIfNeeded()

        #expect(
            defaults.string(forKey: "deviceSetting.appearance") == "system",
            "Keys not in the wipe list must not be removed"
        )
    }

    // MARK: - Test 9: fresh install with no legacy data

    /// On a fresh install (no legacy keys, no marker), performIfNeeded() must write the
    /// marker and not crash.
    ///
    /// FAILS before implementation: FirstLaunchWipe does not exist.
    @Test("Fresh install with no legacy data writes the marker without crashing")
    func freshInstallNoOpWithMarker() {
        let (sut, defaults, _) = makeSUT()

        // Precondition: no marker, no legacy keys
        #expect(defaults.object(forKey: FirstLaunchWipe.markerKey) == nil)
        #expect(defaults.object(forKey: "savedEmail") == nil)

        sut.performIfNeeded()

        #expect(
            defaults.integer(forKey: FirstLaunchWipe.markerKey) == FirstLaunchWipe.markerVersion,
            "Marker must be written even when there are no legacy keys to remove"
        )
    }
}
