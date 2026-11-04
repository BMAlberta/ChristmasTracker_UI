//
//  LockAutoAttemptTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R6: shouldAutoAttemptBiometrics(isAvailable:preferenceEnabled:isPasswordOnly:alreadyAttempted:appIsActive:)
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
}
