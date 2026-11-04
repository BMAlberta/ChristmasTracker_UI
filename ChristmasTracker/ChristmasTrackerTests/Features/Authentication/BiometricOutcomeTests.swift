//
//  BiometricOutcomeTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R2: BiometricOutcome enum and biometricOutcome(for:biometryTypeName:) mapping.
//  Also tests showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:).
//
//  Compile failures expected until the implementer:
//    - Creates `BiometricOutcome` enum in LockView.swift (or a new file)
//    - Creates `biometricOutcome(for:biometryTypeName:) -> BiometricOutcome` free function
//    - Creates `showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:) -> Bool`
//    - Fixes LockView.attemptBiometricUnlock() to use BiometricOutcome instead of inline logic
//
//  Contract (from Gate 1 spec, R2):
//
//    enum BiometricOutcome: Equatable {
//        case unlock
//        case keepBiometric(hint: String?)  // hint is nil for cancel; non-nil for .failed
//        case passwordOnly
//    }
//
//    func biometricOutcome(for result: BiometricResult, biometryTypeName: String) -> BiometricOutcome
//    func showBiometricButton(isAvailable: Bool, preferenceEnabled: Bool, isPasswordOnly: Bool) -> Bool
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("BiometricOutcome Mapping Tests")
struct BiometricOutcomeTests {

    // MARK: - biometricOutcome(for:biometryTypeName:) mapping

    // R2-6: .success maps to .unlock
    @Test(".success maps to .unlock")
    func successMapsToUnlock() {
        let outcome = biometricOutcome(for: .success, biometryTypeName: "Face ID")
        #expect(outcome == .unlock,
                ".success must map to .unlock")
    }

    // R2-7: .userCancelled maps to .keepBiometric(hint: nil)
    @Test(".userCancelled maps to .keepBiometric(hint: nil)")
    func userCancelledMapsToKeepBiometricNoHint() {
        let outcome = biometricOutcome(for: .userCancelled, biometryTypeName: "Face ID")
        #expect(outcome == .keepBiometric(hint: nil),
                ".userCancelled must map to .keepBiometric(hint: nil) — user dismissed dialog, no error message needed")
    }

    // R2-8: .systemCancelled maps to .keepBiometric(hint: nil)
    @Test(".systemCancelled maps to .keepBiometric(hint: nil)")
    func systemCancelledMapsToKeepBiometricNoHint() {
        let outcome = biometricOutcome(for: .systemCancelled, biometryTypeName: "Face ID")
        #expect(outcome == .keepBiometric(hint: nil),
                ".systemCancelled must map to .keepBiometric(hint: nil) — system cancelled, biometric button stays")
    }

    // R2-9: .failed maps to .keepBiometric with a non-nil hint (D5 fix)
    // The hint must contain "try again" (case-insensitive) to communicate retryability.
    @Test(".failed maps to .keepBiometric with non-nil hint containing 'try again'")
    func failedMapsToKeepBiometricWithRetryHint() throws {
        let outcome = biometricOutcome(for: .failed, biometryTypeName: "Face ID")
        switch outcome {
        case .keepBiometric(let hint):
            let unwrapped = try #require(hint,
                                         ".failed must produce a non-nil hint — transient failure should instruct the user to retry")
            let lowercased = unwrapped.lowercased()
            #expect(lowercased.contains("try again"),
                    "Hint for .failed must contain 'try again' (got: \"\(unwrapped)\")")
        default:
            Issue.record(".failed must map to .keepBiometric(hint:), got \(outcome)")
        }
    }

    // R2-9b: the hint for .failed must include the biometryTypeName passed in
    @Test(".failed hint references the biometryTypeName")
    func failedHintIncludesBiometryTypeName() throws {
        let typeName = "Touch ID"
        let outcome = biometricOutcome(for: .failed, biometryTypeName: typeName)
        switch outcome {
        case .keepBiometric(let hint):
            let unwrapped = try #require(hint,
                                         ".failed hint must not be nil")
            #expect(unwrapped.contains(typeName),
                    "Hint for .failed must reference biometryTypeName '\(typeName)' (got: \"\(unwrapped)\")")
        default:
            Issue.record(".failed must map to .keepBiometric(hint:)")
        }
    }

    // R2-10: .userFallback maps to .passwordOnly
    @Test(".userFallback maps to .passwordOnly")
    func userFallbackMapsToPasswordOnly() {
        let outcome = biometricOutcome(for: .userFallback, biometryTypeName: "Face ID")
        #expect(outcome == .passwordOnly,
                ".userFallback (user chose system 'Use Password') must map to .passwordOnly")
    }

    // R2-11: .lockedOut maps to .passwordOnly
    @Test(".lockedOut maps to .passwordOnly")
    func lockedOutMapsToPasswordOnly() {
        let outcome = biometricOutcome(for: .lockedOut, biometryTypeName: "Face ID")
        #expect(outcome == .passwordOnly,
                ".lockedOut must map to .passwordOnly — biometrics locked by the system")
    }

    // R2-12: .unavailable maps to .passwordOnly
    @Test(".unavailable maps to .passwordOnly")
    func unavailableMapsToPasswordOnly() {
        let outcome = biometricOutcome(for: .unavailable, biometryTypeName: "Face ID")
        #expect(outcome == .passwordOnly,
                ".unavailable must map to .passwordOnly — no biometrics on device or not enrolled")
    }

    // R2-extra: .failed must NOT map to .passwordOnly (D5 regression guard)
    // This is the core D5 fix: a transient failure must not permanently hide the biometric button.
    @Test(".failed must NOT map to .passwordOnly (D5 regression guard)")
    func failedMustNotMapToPasswordOnly() {
        let outcome = biometricOutcome(for: .failed, biometryTypeName: "Face ID")
        #expect(outcome != .passwordOnly,
                ".failed must NOT map to .passwordOnly — a transient failure should allow retry, not force password login")
    }

    // R2-extra: all 7 BiometricResult cases are handled without crash or unexpected default
    @Test("All BiometricResult cases are covered by biometricOutcome(for:biometryTypeName:)")
    func allCasesAreCovered() {
        let cases: [BiometricResult] = [
            .success,
            .userCancelled,
            .systemCancelled,
            .userFallback,
            .lockedOut,
            .unavailable,
            .failed
        ]
        for result in cases {
            // If any case falls through to an unexpected fatalError/crash, the test runner
            // will surface it. We simply verify each produces a valid BiometricOutcome value.
            let outcome = biometricOutcome(for: result, biometryTypeName: "Face ID")
            switch outcome {
            case .unlock, .keepBiometric, .passwordOnly:
                break // valid
            }
        }
        #expect(Bool(true), "All 7 cases mapped without crash")
    }

    // MARK: - showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:)

    // R2-13: all three conditions met → show button
    @Test("showBiometricButton is true when isAvailable, preferenceEnabled, and not passwordOnly")
    func showBiometricButtonAllTrue() {
        let show = showBiometricButton(isAvailable: true, preferenceEnabled: true, isPasswordOnly: false)
        #expect(show == true,
                "Button must be shown when isAvailable=true, preferenceEnabled=true, isPasswordOnly=false")
    }

    // R2-14: biometrics not available → hide button
    @Test("showBiometricButton is false when isAvailable is false")
    func showBiometricButtonHiddenWhenUnavailable() {
        let show = showBiometricButton(isAvailable: false, preferenceEnabled: true, isPasswordOnly: false)
        #expect(show == false,
                "Button must be hidden when isAvailable=false")
    }

    // R2-15: preference disabled → hide button
    @Test("showBiometricButton is false when preferenceEnabled is false")
    func showBiometricButtonHiddenWhenPreferenceDisabled() {
        let show = showBiometricButton(isAvailable: true, preferenceEnabled: false, isPasswordOnly: false)
        #expect(show == false,
                "Button must be hidden when preferenceEnabled=false")
    }

    // R2-16: passwordOnly mode → hide button
    @Test("showBiometricButton is false when isPasswordOnly is true")
    func showBiometricButtonHiddenWhenPasswordOnly() {
        let show = showBiometricButton(isAvailable: true, preferenceEnabled: true, isPasswordOnly: true)
        #expect(show == false,
                "Button must be hidden when isPasswordOnly=true (e.g., after userFallback/lockedOut/unavailable)")
    }
}
