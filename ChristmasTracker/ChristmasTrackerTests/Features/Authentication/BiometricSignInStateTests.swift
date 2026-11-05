//
//  BiometricSignInStateTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story R1 of I2b-2a: BiometricSignInState enum and the pure mapping
//  function biometricSignInOutcome(for:biometryTypeName:).
//
//  These tests will FAIL until the implementer creates:
//    - ChristmasTracker/Features/Authentication/Services/BiometricSignInState.swift
//      containing BiometricSignInState enum, biometricSignInOutcome overloads, and
//      isCredentialFailure(_:) moved from LoginView.swift.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - BiometricSignInState mapping tests

@Suite("BiometricSignInState Mapping Tests")
struct BiometricSignInStateTests {

    // MARK: - BiometricCredentialError mappings

    @Test("userCancelled maps to idle, no deletion, no snapshot refresh")
    func userCancelledMapsToIdle() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.userCancelled, biometryTypeName: "Face ID")
        #expect(result.state == .idle)
        #expect(result.deleteEnrollment == false)
        #expect(result.refreshSnapshot == false)
    }

    @Test("biometricFailed maps to retryHint, no deletion, no snapshot refresh")
    func biometricFailedMapsToRetryHint() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.biometricFailed, biometryTypeName: "Face ID")
        #expect(result.state == .retryHint("Face ID didn't recognize you. Try again or use your password."))
        #expect(result.deleteEnrollment == false)
        #expect(result.refreshSnapshot == false)
    }

    @Test("lockedOut maps to passwordOnly, no deletion, no snapshot refresh")
    func lockedOutMapsToPasswordOnly() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.lockedOut, biometryTypeName: "Face ID")
        #expect(result.state == .passwordOnly("Biometrics are locked. Use your password to continue."))
        #expect(result.deleteEnrollment == false)
        #expect(result.refreshSnapshot == false)
    }

    @Test("itemNotFound maps to idle, deleteEnrollment true, refreshSnapshot true")
    func itemNotFoundMapsToIdleAndDeletesEnrollment() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.itemNotFound, biometryTypeName: "Face ID")
        #expect(result.state == .idle)
        #expect(result.deleteEnrollment == true)
        #expect(result.refreshSnapshot == true)
    }

    @Test("itemInvalidated maps to idle, deleteEnrollment true, refreshSnapshot true")
    func itemInvalidatedMapsToIdleAndDeletesEnrollment() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.itemInvalidated, biometryTypeName: "Face ID")
        #expect(result.state == .idle)
        #expect(result.deleteEnrollment == true)
        #expect(result.refreshSnapshot == true)
    }

    @Test("other credential error maps to neutralError, no deletion, no snapshot refresh")
    func otherMapsToNeutralError() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.other, biometryTypeName: "Face ID")
        #expect(result.state == .neutralError("Couldn't sign in. Try again or use your password."))
        #expect(result.deleteEnrollment == false)
        #expect(result.refreshSnapshot == false)
    }

    // MARK: - AuthenticationError mappings

    @Test("AuthenticationError with isCredentialFailure true maps to passwordRequired, deletes, refreshes")
    func credentialFailureAuthErrorMapsToPasswordRequired() {
        let result = biometricSignInOutcome(for: AuthenticationError.invalidCredentials, biometryTypeName: "Face ID")
        #expect(result.state == .passwordRequired)
        #expect(result.deleteEnrollment == true)
        #expect(result.refreshSnapshot == true)
    }

    @Test("AuthenticationError with isCredentialFailure false maps to neutralError, no deletion, no refresh")
    func nonCredentialFailureAuthErrorMapsToNeutralError() {
        let result = biometricSignInOutcome(for: AuthenticationError.networkError, biometryTypeName: "Face ID")
        #expect(result.state == .neutralError("Couldn't sign in. Try again or use your password."))
        #expect(result.deleteEnrollment == false)
        #expect(result.refreshSnapshot == false)
    }

    // MARK: - retryHint uses biometryTypeName

    @Test("retryHint message contains Face ID when biometryTypeName is Face ID")
    func retryHintContainsFaceID() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.biometricFailed, biometryTypeName: "Face ID")
        if case .retryHint(let message) = result.state {
            #expect(message.contains("Face ID"))
        } else {
            Issue.record("Expected retryHint state, got \(result.state)")
        }
    }

    @Test("retryHint message contains Touch ID when biometryTypeName is Touch ID")
    func retryHintContainsTouchID() {
        let result = biometricSignInOutcome(for: BiometricCredentialError.biometricFailed, biometryTypeName: "Touch ID")
        if case .retryHint(let message) = result.state {
            #expect(message.contains("Touch ID"))
        } else {
            Issue.record("Expected retryHint state, got \(result.state)")
        }
    }

    @Test("lockedOut message does NOT contain biometryTypeName")
    func lockedOutMessageDoesNotContainBiometryTypeName() {
        let biometryName = "Face ID"
        let result = biometricSignInOutcome(for: BiometricCredentialError.lockedOut, biometryTypeName: biometryName)
        if case .passwordOnly(let message) = result.state {
            #expect(!message.contains(biometryName))
        } else {
            Issue.record("Expected passwordOnly state, got \(result.state)")
        }
    }

    // MARK: - isCredentialFailure

    @Test("isCredentialFailure returns true for invalidCredentials")
    func isCredentialFailureTrueForInvalidCredentials() {
        #expect(isCredentialFailure(AuthenticationError.invalidCredentials) == true)
    }

    @Test("isCredentialFailure returns true for sessionExpired")
    func isCredentialFailureTrueForSessionExpired() {
        #expect(isCredentialFailure(AuthenticationError.sessionExpired) == true)
    }

    @Test("isCredentialFailure returns true for invalidRefreshToken")
    func isCredentialFailureTrueForInvalidRefreshToken() {
        #expect(isCredentialFailure(AuthenticationError.invalidRefreshToken) == true)
    }

    @Test("isCredentialFailure returns false for networkError")
    func isCredentialFailureFalseForNetworkError() {
        #expect(isCredentialFailure(AuthenticationError.networkError) == false)
    }
}
