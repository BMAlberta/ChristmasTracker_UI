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
//  I2b-2c U3: isCredentialFailure(_:) is replaced by isCredentialFailure(_:context:).
//  DELETED (subsumed by isCredentialFailureMatchesTruthTable, which covers every case in
//  both contexts): isCredentialFailureTrueForInvalidCredentials,
//  isCredentialFailureTrueForSessionExpired, isCredentialFailureTrueForInvalidRefreshToken,
//  isCredentialFailureFalseForNetworkError.
//  ADDED: accountDisabledAuthErrorMapsToPasswordRequired, isCredentialFailureMatchesTruthTable,
//  truthTableCoversEveryCaseOnce.
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

    // MARK: - biometricSignInOutcome: refresh 403 (I2b-2c U3)

    @Test("AuthenticationError.accountDisabled (refresh 403) maps to passwordRequired, deletes enrollment, refreshes snapshot")
    func accountDisabledAuthErrorMapsToPasswordRequired() {
        let result = biometricSignInOutcome(for: AuthenticationError.accountDisabled, biometryTypeName: "Face ID")
        #expect(result.state == .passwordRequired)
        #expect(result.deleteEnrollment == true)
        #expect(result.refreshSnapshot == true)
    }

    // MARK: - isCredentialFailure(_:context:) truth table (I2b-2c U3)
    //
    // Replaces the one-argument isCredentialFailure tests that lived here and in
    // LoginBiometricButtonTests.swift. Every AuthenticationError case is listed once in
    // credentialFailureTruthTable; caseName(_:) is an exhaustive switch, so adding a case to
    // AuthenticationError stops this file compiling until a row is added.

    @Test(
        "isCredentialFailure(_:context:) matches the U3 truth table for every case in both contexts",
        arguments: credentialFailureTruthTable, [AuthErrorContext.login, AuthErrorContext.refresh]
    )
    func isCredentialFailureMatchesTruthTable(row: CredentialFailureRow, context: AuthErrorContext) {
        let expected = context == .login ? row.login : row.refresh
        #expect(
            isCredentialFailure(row.error, context: context) == expected,
            "\(row.name) in \(context) must be \(expected)"
        )
    }

    @Test("the truth table has exactly one row per AuthenticationError case")
    func truthTableCoversEveryCaseOnce() {
        let names = credentialFailureTruthTable.map { caseName($0.error) }
        #expect(Set(names).count == names.count, "Each case must appear once")
        #expect(names.count == 16, "AuthenticationError has 16 cases; update the table when one is added")
    }
}

// MARK: - Truth table fixtures

/// One row of the U3 classification truth table.
struct CredentialFailureRow: Sendable, CustomTestStringConvertible {
    let error: AuthenticationError
    let login: Bool
    let refresh: Bool

    var name: String { caseName(error) }
    var testDescription: String { name }
}

/// invalidRefreshToken, sessionExpired, invalidCredentials, credentialExpired: true in both.
/// accountDisabled: true for .refresh, false for .login. Every other case: false in both.
private let credentialFailureTruthTable: [CredentialFailureRow] = [
    CredentialFailureRow(error: .invalidRefreshToken, login: true, refresh: true),
    CredentialFailureRow(error: .sessionExpired, login: true, refresh: true),
    CredentialFailureRow(error: .invalidCredentials, login: true, refresh: true),
    CredentialFailureRow(error: .credentialExpired, login: true, refresh: true),
    CredentialFailureRow(error: .accountDisabled, login: false, refresh: true),
    CredentialFailureRow(error: .emailAlreadyExists, login: false, refresh: false),
    CredentialFailureRow(error: .userNotFound, login: false, refresh: false),
    CredentialFailureRow(error: .biometricFailed, login: false, refresh: false),
    CredentialFailureRow(error: .biometricNotAvailable, login: false, refresh: false),
    CredentialFailureRow(error: .networkError, login: false, refresh: false),
    CredentialFailureRow(error: .invalidResponse, login: false, refresh: false),
    CredentialFailureRow(error: .updateRequired, login: false, refresh: false),
    CredentialFailureRow(error: .rateLimited(retryAfter: 30), login: false, refresh: false),
    CredentialFailureRow(error: .serverError, login: false, refresh: false),
    CredentialFailureRow(error: .invalidRegistrationCode, login: false, refresh: false),
    CredentialFailureRow(error: .validation(message: "Validation error"), login: false, refresh: false),
]

/// Exhaustive (no default): a new AuthenticationError case is a compile error here.
private func caseName(_ error: AuthenticationError) -> String {
    switch error {
    case .invalidCredentials: return "invalidCredentials"
    case .emailAlreadyExists: return "emailAlreadyExists"
    case .userNotFound: return "userNotFound"
    case .biometricFailed: return "biometricFailed"
    case .biometricNotAvailable: return "biometricNotAvailable"
    case .invalidRefreshToken: return "invalidRefreshToken"
    case .sessionExpired: return "sessionExpired"
    case .networkError: return "networkError"
    case .invalidResponse: return "invalidResponse"
    case .accountDisabled: return "accountDisabled"
    case .updateRequired: return "updateRequired"
    case .rateLimited: return "rateLimited(retryAfter:)"
    case .serverError: return "serverError"
    case .invalidRegistrationCode: return "invalidRegistrationCode"
    case .validation: return "validation(message:)"
    case .credentialExpired: return "credentialExpired"
    }
}
