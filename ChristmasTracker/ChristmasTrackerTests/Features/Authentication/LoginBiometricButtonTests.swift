//
//  LoginBiometricButtonTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S2):
//    - isCredentialFailure(_:) free function (I2b-2c U3: its eight tests are deleted;
//      the function is replaced by isCredentialFailure(_:context:) and every case in both
//      contexts is covered by BiometricSignInStateTests.isCredentialFailureMatchesTruthTable.
//      Deleted: isCredentialFailureTrueForInvalidRefreshToken, isCredentialFailureTrueForSessionExpired,
//      isCredentialFailureTrueForInvalidCredentials, isCredentialFailureFalseForBiometricFailed,
//      isCredentialFailureFalseForBiometricNotAvailable, isCredentialFailureFalseForNetworkError,
//      isCredentialFailureFalseForEmailAlreadyExists, isCredentialFailureFalseForUserNotFound.)
//    - LoginBiometricButtonState enum
//    - loginBiometricButtonState(readiness:enrolledUser:biometryTypeName:) free function
//    - shouldAutoAttemptBiometricLogin(readiness:hasEnrolledUser:alreadyAttemptedThisLaunch:appIsActive:) free function
//
//  Will fail to compile until the implementer adds these symbols to the production module.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("LoginBiometricButton Tests")
struct LoginBiometricButtonTests {

    // MARK: - loginBiometricButtonState: .noHardware

    @Test("noHardware readiness returns .hidden regardless of enrolled user")
    func noHardwareWithNoEnrolledUserReturnsHidden() {
        let result = loginBiometricButtonState(
            readiness: .noHardware,
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        #expect(result == .hidden)
    }

    @Test("noHardware readiness returns .hidden even when enrolled user is present")
    func noHardwareWithEnrolledUserReturnsHidden() {
        let result = loginBiometricButtonState(
            readiness: .noHardware,
            enrolledUser: (userId: "u1", firstName: "Alice"),
            biometryTypeName: "Face ID"
        )
        #expect(result == .hidden)
    }

    // MARK: - loginBiometricButtonState: .ready

    @Test("ready readiness with no enrolled user returns .showNotEnrolled")
    func readyWithNoEnrolledUserReturnsShowNotEnrolled() {
        let result = loginBiometricButtonState(
            readiness: .ready,
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        #expect(result == .showNotEnrolled)
    }

    @Test("ready readiness with enrolled user returns .showEnrolled with firstName")
    func readyWithEnrolledUserReturnsShowEnrolledWithFirstName() {
        let result = loginBiometricButtonState(
            readiness: .ready,
            enrolledUser: (userId: "u1", firstName: "Alice"),
            biometryTypeName: "Face ID"
        )
        #expect(result == .showEnrolled(firstName: "Alice"))
    }

    @Test("ready readiness with enrolled user uses enrolledUser firstName not biometryTypeName")
    func readyWithEnrolledUserUsesEnrolledFirstName() {
        let result = loginBiometricButtonState(
            readiness: .ready,
            enrolledUser: (userId: "u2", firstName: "Bob"),
            biometryTypeName: "Touch ID"
        )
        if case .showEnrolled(let firstName) = result {
            #expect(firstName == "Bob")
        } else {
            Issue.record("Expected .showEnrolled but got \(result)")
        }
    }

    // MARK: - loginBiometricButtonState: .needsSetup

    @Test("needsSetup(notEnrolled) returns .showNeedsSetup with message and opensSettings true")
    func needsSetupNotEnrolledReturnsShowNeedsSetupWithSettings() {
        let result = loginBiometricButtonState(
            readiness: .needsSetup(reason: .notEnrolled),
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        if case .showNeedsSetup(let message, let opensSettings) = result {
            #expect(opensSettings == true)
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected .showNeedsSetup but got \(result)")
        }
    }

    @Test("needsSetup(passcodeNotSet) returns .showNeedsSetup")
    func needsSetupPasscodeNotSetReturnsShowNeedsSetup() {
        let result = loginBiometricButtonState(
            readiness: .needsSetup(reason: .passcodeNotSet),
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        if case .showNeedsSetup = result {
            // expected
        } else {
            Issue.record("Expected .showNeedsSetup but got \(result)")
        }
    }

    @Test("needsSetup(disabledForApp) returns .showNeedsSetup with biometryTypeName in message")
    func needsSetupDisabledForAppIncludesBiometryTypeNameInMessage() {
        let result = loginBiometricButtonState(
            readiness: .needsSetup(reason: .disabledForApp),
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        if case .showNeedsSetup(let message, _) = result {
            #expect(message.contains("Face ID"))
        } else {
            Issue.record("Expected .showNeedsSetup but got \(result)")
        }
    }

    @Test("needsSetup(lockedOut) returns .showNeedsSetup")
    func needsSetupLockedOutReturnsShowNeedsSetup() {
        let result = loginBiometricButtonState(
            readiness: .needsSetup(reason: .lockedOut),
            enrolledUser: nil,
            biometryTypeName: "Face ID"
        )
        if case .showNeedsSetup = result {
            // expected
        } else {
            Issue.record("Expected .showNeedsSetup but got \(result)")
        }
    }

    @Test("needsSetup ignores enrolled user — still returns .showNeedsSetup")
    func needsSetupWithEnrolledUserStillReturnsShowNeedsSetup() {
        let result = loginBiometricButtonState(
            readiness: .needsSetup(reason: .notEnrolled),
            enrolledUser: (userId: "u1", firstName: "Alice"),
            biometryTypeName: "Face ID"
        )
        if case .showNeedsSetup = result {
            // expected
        } else {
            Issue.record("Expected .showNeedsSetup but got \(result)")
        }
    }

    // MARK: - shouldAutoAttemptBiometricLogin

    @Test("returns true when all conditions met: ready, enrolled, not attempted, app active")
    func returnsTrueWhenAllConditionsMet() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .ready,
            hasEnrolledUser: true,
            alreadyAttemptedThisLaunch: false,
            appIsActive: true
        )
        #expect(result == true)
    }

    @Test("returns false when readiness is .noHardware")
    func returnsFalseWhenNoHardware() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .noHardware,
            hasEnrolledUser: true,
            alreadyAttemptedThisLaunch: false,
            appIsActive: true
        )
        #expect(result == false)
    }

    @Test("returns false when readiness is .needsSetup")
    func returnsFalseWhenNeedsSetup() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .needsSetup(reason: .notEnrolled),
            hasEnrolledUser: true,
            alreadyAttemptedThisLaunch: false,
            appIsActive: true
        )
        #expect(result == false)
    }

    @Test("returns false when no enrolled user")
    func returnsFalseWhenNoEnrolledUser() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .ready,
            hasEnrolledUser: false,
            alreadyAttemptedThisLaunch: false,
            appIsActive: true
        )
        #expect(result == false)
    }

    @Test("returns false when already attempted this launch")
    func returnsFalseWhenAlreadyAttempted() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .ready,
            hasEnrolledUser: true,
            alreadyAttemptedThisLaunch: true,
            appIsActive: true
        )
        #expect(result == false)
    }

    @Test("returns false when app is not active")
    func returnsFalseWhenAppIsNotActive() {
        let result = shouldAutoAttemptBiometricLogin(
            readiness: .ready,
            hasEnrolledUser: true,
            alreadyAttemptedThisLaunch: false,
            appIsActive: false
        )
        #expect(result == false)
    }
}
