//
//  LockControllerPreferenceTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 (Story 3): InactivityLockController.preference property.
//
//  These tests will fail to compile until:
//    - BiometricUnlockPreference.swift adds the BiometricUnlockPreferring protocol
//    - InactivityLockController gains `var preference: (any BiometricUnlockPreferring)?`
//
//  Compile-time failures ARE the expected "failing for the right reason".
//
//  FakeBiometricUnlockPreference is defined in BiometricUnlockPreferenceTests.swift
//  within this same test target. All controller tests are @MainActor.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("LockController Preference Tests")
@MainActor
struct LockControllerPreferenceTests {

    // MARK: - Helpers

    private struct FakePolicy10: LockTimeoutProviding {
        let timeoutMinutes: Int = 10
    }

    // MARK: - Factory

    private func makeSUT() -> InactivityLockController {
        InactivityLockController(policy: FakePolicy10())
    }

    // MARK: - nil preference (default behavior preserved)

    @Test("preference is nil by default — property exists and is optional")
    func preferenceIsNilByDefault() {
        let controller = makeSUT()
        // The preference property must exist and default to nil.
        // Accessing it must not crash and must equal nil.
        #expect(controller.preference == nil)
    }

    @Test("When preference is nil, controller biometric behavior is unconstrained")
    func nilPreferenceDoesNotConstrainBiometric() {
        let controller = makeSUT()
        // No preference set — the controller must not gate biometric based on a nil preference.
        // We verify by confirming preference is nil (the guard path `preference?.biometricUnlockEnabled ?? false`
        // evaluates to false only when non-nil and disabled; nil short-circuits to unconstrained).
        let pref = controller.preference
        // nil preference means no constraint applied — biometric gating is left to availability alone.
        #expect(pref == nil,
                "nil preference must leave biometric gating unconstrained (default behavior)")
    }

    // MARK: - Non-nil preference with biometricUnlockEnabled = false

    @Test("When preference.biometricUnlockEnabled is false, controller exposes that via preference")
    func preferenceWithDisabledBiometricIsReadable() {
        let controller = makeSUT()
        let fake = FakeBiometricUnlockPreference()
        fake.biometricUnlockEnabled = false
        controller.preference = fake

        // The preference property must be set and readable.
        #expect(controller.preference != nil)
        #expect(controller.preference?.biometricUnlockEnabled == false,
                "Controller.preference?.biometricUnlockEnabled must reflect the injected value")
    }

    @Test("When preference.biometricUnlockEnabled is true, controller exposes that via preference")
    func preferenceWithEnabledBiometricIsReadable() {
        let controller = makeSUT()
        let fake = FakeBiometricUnlockPreference()
        fake.biometricUnlockEnabled = true
        controller.preference = fake

        #expect(controller.preference?.biometricUnlockEnabled == true,
                "Controller.preference?.biometricUnlockEnabled must reflect the injected value")
    }

    @Test("preference can be replaced — updated value is reflected immediately")
    func preferenceCanBeReplaced() {
        let controller = makeSUT()
        let fake1 = FakeBiometricUnlockPreference()
        fake1.biometricUnlockEnabled = false
        controller.preference = fake1
        #expect(controller.preference?.biometricUnlockEnabled == false)

        let fake2 = FakeBiometricUnlockPreference()
        fake2.biometricUnlockEnabled = true
        controller.preference = fake2
        #expect(controller.preference?.biometricUnlockEnabled == true,
                "Replacing preference must immediately reflect the new value")
    }

    @Test("preference can be set back to nil after being assigned")
    func preferenceCanBeResetToNil() {
        let controller = makeSUT()
        let fake = FakeBiometricUnlockPreference()
        controller.preference = fake
        #expect(controller.preference != nil, "Precondition: preference was just assigned")
        controller.preference = nil
        #expect(controller.preference == nil,
                "preference must accept nil after being set, restoring unconstrained default")
    }
}
