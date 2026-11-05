//
//  BiometricTypeDisplayNameTests.swift
//  ChristmasTrackerTests
//
//  Story I2b-2a F3 / Defect E7:
//  `BiometricType.none.displayName` must return "Face ID or Touch ID" (not "None").
//
//  Test 5 FAILS on the current code (returns "None").
//  Tests 6–7 are regression guards that PASS on the current code and must continue to PASS.
//
//  E3 (ChristmasTrackerApp.body sheet driver) is not unit-testable; a placeholder
//  comment below documents the required invariant for the acceptance reviewer.
//

import Testing
@testable import ChristmasTracker

// MARK: - E3 invariant (not unit-testable)
//
// ChristmasTrackerApp.body must present BiometricSetupView from:
//   .onChange(of: authService.biometricOfferAction) { _, new in
//       showBiometricSetup = (new == .showEnablementScreen)
//   }
//
// The OLD driver `shouldShowBiometricEnablementAfterLogin` must NOT be used.
// This cannot be asserted with a unit test; it must be verified by code review
// or an XCUITest that confirms the sheet appears after biometricOfferAction
// transitions to .showEnablementScreen.

// MARK: - Suite

// @MainActor required because BiometricType.displayName is computed inside
// AuthenticationService which is @MainActor-isolated, so the enum's var
// is implicitly @MainActor.
@Suite("BiometricType.displayName — E7 fix and regressions")
@MainActor
struct BiometricTypeDisplayNameTests {

    // MARK: - Test 5: .none returns "Face ID or Touch ID"

    /// FAILS on current code: `BiometricType.none.displayName` currently returns "None".
    @Test("BiometricType.none.displayName returns 'Face ID or Touch ID'")
    func noneDisplayNameIsFaceIDOrTouchID() {
        #expect(BiometricType.none.displayName == "Face ID or Touch ID",
                "BiometricType.none.displayName must return 'Face ID or Touch ID' after the E7 fix")
    }

    // MARK: - Test 6: .touchID regression guard

    /// PASSES on current code and must continue to PASS after the fix.
    @Test("BiometricType.touchID.displayName returns 'Touch ID'")
    func touchIDDisplayNameIsTouchID() {
        #expect(BiometricType.touchID.displayName == "Touch ID")
    }

    // MARK: - Test 7: .faceID regression guard

    /// PASSES on current code and must continue to PASS after the fix.
    @Test("BiometricType.faceID.displayName returns 'Face ID'")
    func faceIDDisplayNameIsFaceID() {
        #expect(BiometricType.faceID.displayName == "Face ID")
    }
}
