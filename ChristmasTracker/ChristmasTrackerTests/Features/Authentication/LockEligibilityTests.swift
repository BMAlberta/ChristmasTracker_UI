//
//  LockEligibilityTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a S3: LockView pure functions and InactivityLockController
//  biometricEligibility closure.
//
//  Tests L1–L5 cover:
//    - showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:) (unchanged signature)
//    - InactivityLockController.biometricEligibility — the new (() -> Bool)? closure
//    - shouldAutoAttemptBiometrics(isAvailable:preferenceEnabled:isPasswordOnly:alreadyAttempted:appIsActive:)
//
//  RED-phase: L2–L4 will fail to compile until InactivityLockController gains
//    var biometricEligibility: (() -> Bool)?
//  (replacing the old `preference` property).
//
//  Concurrency: showBiometricButton and shouldAutoAttemptBiometrics are nonisolated free
//  functions — they need no actor. L2–L4 require @MainActor because
//  InactivityLockController is @MainActor.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - L1: showBiometricButton unchanged signature still works

@Suite("LockView showBiometricButton Tests")
struct LockShowBiometricButtonTests {

    // L1: all conditions true → true
    @Test("L1: showBiometricButton returns true when all conditions are met")
    func showBiometricButtonAllTrueReturnsTrue() {
        let result = showBiometricButton(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false
        )
        #expect(result == true,
                "showBiometricButton must return true when isAvailable && preferenceEnabled && !isPasswordOnly")
    }

    @Test("showBiometricButton returns false when isAvailable is false")
    func showBiometricButtonUnavailableReturnsFalse() {
        let result = showBiometricButton(isAvailable: false, preferenceEnabled: true, isPasswordOnly: false)
        #expect(result == false)
    }

    @Test("showBiometricButton returns false when preferenceEnabled is false")
    func showBiometricButtonPreferenceDisabledReturnsFalse() {
        let result = showBiometricButton(isAvailable: true, preferenceEnabled: false, isPasswordOnly: false)
        #expect(result == false)
    }

    @Test("showBiometricButton returns false when isPasswordOnly is true")
    func showBiometricButtonPasswordOnlyReturnsFalse() {
        let result = showBiometricButton(isAvailable: true, preferenceEnabled: true, isPasswordOnly: true)
        #expect(result == false)
    }
}

// MARK: - L2–L4: biometricEligibility closure on InactivityLockController

private struct FakeLockPolicy10: LockTimeoutProviding {
    let timeoutMinutes: Int = 10
}

@Suite("LockController biometricEligibility Tests")
@MainActor
struct LockControllerBiometricEligibilityTests {

    private func makeController() -> InactivityLockController {
        InactivityLockController(policy: FakeLockPolicy10())
    }

    // L2: closure returning true → preferenceEnabled argument is true
    @Test("L2: biometricEligibility returning true evaluates to true for showBiometricButton")
    func biometricEligibilityTrueYieldsTruePreferenceEnabled() {
        let controller = makeController()
        controller.biometricEligibility = { true }

        let preferenceEnabled = controller.biometricEligibility?() ?? false
        let result = showBiometricButton(
            isAvailable: true,
            preferenceEnabled: preferenceEnabled,
            isPasswordOnly: false
        )
        #expect(preferenceEnabled == true,
                "biometricEligibility() must return true when the closure returns true")
        #expect(result == true,
                "showBiometricButton must be true when biometricEligibility() == true and button is otherwise visible")
    }

    // L3: closure returning false → preferenceEnabled argument is false
    @Test("L3: biometricEligibility returning false evaluates to false for showBiometricButton")
    func biometricEligibilityFalseYieldsFalsePreferenceEnabled() {
        let controller = makeController()
        controller.biometricEligibility = { false }

        let preferenceEnabled = controller.biometricEligibility?() ?? false
        let result = showBiometricButton(
            isAvailable: true,
            preferenceEnabled: preferenceEnabled,
            isPasswordOnly: false
        )
        #expect(preferenceEnabled == false,
                "biometricEligibility() must return false when the closure returns false")
        #expect(result == false,
                "showBiometricButton must be false when biometricEligibility() == false")
    }

    // L4: nil closure → fallback is false
    @Test("L4: nil biometricEligibility falls back to false")
    func nilBiometricEligibilityFallsBackToFalse() {
        let controller = makeController()
        // biometricEligibility is nil by default after the rework
        controller.biometricEligibility = nil

        let preferenceEnabled = controller.biometricEligibility?() ?? false
        #expect(preferenceEnabled == false,
                "nil biometricEligibility must fall back to false (the nil-coalescing ?? false path)")
    }
}

// MARK: - L5: shouldAutoAttemptBiometrics — all false-condition sub-cases

@Suite("shouldAutoAttemptBiometrics False-Conditions Tests")
struct ShouldAutoAttemptFalseConditionTests {

    // L5a: isAvailable false → false
    @Test("L5: isAvailable false returns false")
    func isAvailableFalseReturnsFalse() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: false,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        ) == false)
    }

    // L5b: preferenceEnabled false → false
    @Test("L5: preferenceEnabled false returns false")
    func preferenceEnabledFalseReturnsFalse() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: false,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        ) == false)
    }

    // L5c: isPasswordOnly true → false
    @Test("L5: isPasswordOnly true returns false")
    func isPasswordOnlyTrueReturnsFalse() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: true,
            alreadyAttempted: false,
            appIsActive: true
        ) == false)
    }

    // L5d: alreadyAttempted true → false
    @Test("L5: alreadyAttempted true returns false")
    func alreadyAttemptedTrueReturnsFalse() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: true,
            appIsActive: true
        ) == false)
    }

    // L5e: appIsActive false → false
    @Test("L5: appIsActive false returns false")
    func appIsActiveFalseReturnsFalse() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: false
        ) == false)
    }

    // L5f: all conditions favorable → true (confirms the happy path still holds)
    @Test("L5: all conditions favorable returns true")
    func allFavorableReturnsTrue() {
        #expect(shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        ) == true)
    }
}
