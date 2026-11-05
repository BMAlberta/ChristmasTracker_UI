//
//  LockAutoAttemptTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R6: shouldAutoAttemptBiometrics(isAvailable:preferenceEnabled:isPasswordOnly:alreadyAttempted:appIsActive:)
//  Parameterized 32-case truth table added in Story R10 (C3).
//
//  Also contains the 8-case parameterized table for
//  showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:) added in Story R10 (C3).
//
//  Contract (from Gate 1 spec, R6):
//
//    internal nonisolated func shouldAutoAttemptBiometrics(
//        isAvailable: Bool,
//        preferenceEnabled: Bool,
//        isPasswordOnly: Bool,
//        alreadyAttempted: Bool,
//        appIsActive: Bool
//    ) -> Bool
//    // Returns true iff ALL conditions satisfied:
//    //   isAvailable && preferenceEnabled && !isPasswordOnly && !alreadyAttempted && appIsActive
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Suite

@Suite("shouldAutoAttemptBiometrics Tests")
struct LockAutoAttemptTests {

    // R6-1: all favorable conditions → true
    @Test("All favorable conditions return true")
    func allFavorableConditionsReturnTrue() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        )
        #expect(result == true,
                "shouldAutoAttemptBiometrics must return true when all conditions are favorable")
    }

    // R6-2: biometrics not available → false
    @Test("isAvailable false returns false")
    func unavailableReturnsFalse() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: false,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        )
        #expect(result == false,
                "shouldAutoAttemptBiometrics must return false when isAvailable is false")
    }

    // R6-3: preference disabled → false
    @Test("preferenceEnabled false returns false")
    func preferenceDisabledReturnsFalse() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: false,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: true
        )
        #expect(result == false,
                "shouldAutoAttemptBiometrics must return false when preferenceEnabled is false")
    }

    // R6-4: password-only mode → false
    @Test("isPasswordOnly true returns false")
    func passwordOnlyReturnsFalse() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: true,
            alreadyAttempted: false,
            appIsActive: true
        )
        #expect(result == false,
                "shouldAutoAttemptBiometrics must return false when isPasswordOnly is true")
    }

    // R6-5: already attempted this lock session → false
    @Test("alreadyAttempted true returns false")
    func alreadyAttemptedReturnsFalse() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: true,
            appIsActive: true
        )
        #expect(result == false,
                "shouldAutoAttemptBiometrics must return false when alreadyAttempted is true")
    }

    // R6-6: app is not in the active scene phase → false
    @Test("appIsActive false returns false")
    func appNotActiveReturnsFalse() {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: true,
            preferenceEnabled: true,
            isPasswordOnly: false,
            alreadyAttempted: false,
            appIsActive: false
        )
        #expect(result == false,
                "shouldAutoAttemptBiometrics must return false when appIsActive is false")
    }

    // MARK: - R10 C3: 32-case parameterized truth table for shouldAutoAttemptBiometrics

    // Each tuple: (isAvailable, preferenceEnabled, isPasswordOnly, alreadyAttempted, appIsActive, expectedResult)
    // Expected result is true iff ALL of: isAvailable=T, preferenceEnabled=T,
    //   isPasswordOnly=F, alreadyAttempted=F, appIsActive=T
    private static let autoAttemptCases: [(Bool, Bool, Bool, Bool, Bool, Bool)] = [
        // isAvailable, prefEnabled, pwdOnly, alreadyAttempted, appIsActive, expected
        (false, false, false, false, false, false),
        (false, false, false, false, true,  false),
        (false, false, false, true,  false, false),
        (false, false, false, true,  true,  false),
        (false, false, true,  false, false, false),
        (false, false, true,  false, true,  false),
        (false, false, true,  true,  false, false),
        (false, false, true,  true,  true,  false),
        (false, true,  false, false, false, false),
        (false, true,  false, false, true,  false),
        (false, true,  false, true,  false, false),
        (false, true,  false, true,  true,  false),
        (false, true,  true,  false, false, false),
        (false, true,  true,  false, true,  false),
        (false, true,  true,  true,  false, false),
        (false, true,  true,  true,  true,  false),
        (true,  false, false, false, false, false),
        (true,  false, false, false, true,  false),
        (true,  false, false, true,  false, false),
        (true,  false, false, true,  true,  false),
        (true,  false, true,  false, false, false),
        (true,  false, true,  false, true,  false),
        (true,  false, true,  true,  false, false),
        (true,  false, true,  true,  true,  false),
        (true,  true,  false, false, false, false),
        (true,  true,  false, false, true,  true),  // <-- only true case
        (true,  true,  false, true,  false, false),
        (true,  true,  false, true,  true,  false),
        (true,  true,  true,  false, false, false),
        (true,  true,  true,  false, true,  false),
        (true,  true,  true,  true,  false, false),
        (true,  true,  true,  true,  true,  false),
    ]

    @Test("shouldAutoAttemptBiometrics 32-case truth table", arguments: autoAttemptCases)
    func shouldAutoAttemptBiometricsTruthTable(
        isAvailable: Bool,
        preferenceEnabled: Bool,
        isPasswordOnly: Bool,
        alreadyAttempted: Bool,
        appIsActive: Bool,
        expected: Bool
    ) {
        let result = shouldAutoAttemptBiometrics(
            isAvailable: isAvailable,
            preferenceEnabled: preferenceEnabled,
            isPasswordOnly: isPasswordOnly,
            alreadyAttempted: alreadyAttempted,
            appIsActive: appIsActive
        )
        #expect(result == expected,
                "shouldAutoAttemptBiometrics(\(isAvailable), \(preferenceEnabled), \(isPasswordOnly), \(alreadyAttempted), \(appIsActive)) → expected \(expected), got \(result)")
    }

    // MARK: - R10 C3: 8-case parameterized table for showBiometricButton

    // Each tuple: (isAvailable, preferenceEnabled, isPasswordOnly, expectedResult)
    // Expected result is true iff: isAvailable=T, preferenceEnabled=T, isPasswordOnly=F
    private static let showButtonCases: [(Bool, Bool, Bool, Bool)] = [
        (false, false, false, false),
        (false, false, true,  false),
        (false, true,  false, false),
        (false, true,  true,  false),
        (true,  false, false, false),
        (true,  false, true,  false),
        (true,  true,  false, true),   // <-- only true case
        (true,  true,  true,  false),
    ]

    @Test("showBiometricButton 8-case truth table", arguments: showButtonCases)
    func showBiometricButtonTruthTable(
        isAvailable: Bool,
        preferenceEnabled: Bool,
        isPasswordOnly: Bool,
        expected: Bool
    ) {
        let result = showBiometricButton(
            isAvailable: isAvailable,
            preferenceEnabled: preferenceEnabled,
            isPasswordOnly: isPasswordOnly
        )
        #expect(result == expected,
                "showBiometricButton(\(isAvailable), \(preferenceEnabled), \(isPasswordOnly)) → expected \(expected), got \(result)")
    }
}
