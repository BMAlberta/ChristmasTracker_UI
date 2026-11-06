//
//  BiometricSignInState.swift
//  ChristmasTracker
//
//  Enum and pure mapping functions for biometric sign-in outcome state.
//  isCredentialFailure(_:) is defined here (moved from LoginView.swift).
//

import Foundation

// MARK: - BiometricSignInState

internal enum BiometricSignInState: Equatable {
    case idle
    case retryHint(String)
    case passwordOnly(String)
    case passwordRequired
    case neutralError(String)
}

// MARK: - isCredentialFailure

internal nonisolated func isCredentialFailure(_ error: AuthenticationError) -> Bool {
    switch error {
    case .invalidRefreshToken, .sessionExpired, .invalidCredentials, .credentialExpired:
        return true
    default:
        return false
    }
}

// MARK: - biometricSignInOutcome (BiometricCredentialError)

internal nonisolated func biometricSignInOutcome(
    for error: BiometricCredentialError,
    biometryTypeName: String
) -> (state: BiometricSignInState, deleteEnrollment: Bool, refreshSnapshot: Bool) {
    switch error {
    case .userCancelled:
        return (.idle, false, false)
    case .biometricFailed:
        return (
            .retryHint("\(biometryTypeName) didn't recognize you. Try again or use your password."),
            false,
            false
        )
    case .lockedOut:
        return (.passwordOnly("Biometrics are locked. Use your password to continue."), false, false)
    case .itemNotFound:
        return (.idle, true, true)
    case .itemInvalidated:
        return (.idle, true, true)
    case .other:
        return (.neutralError("Couldn't sign in. Try again or use your password."), false, false)
    }
}

// MARK: - biometricSignInOutcome (AuthenticationError)

internal nonisolated func biometricSignInOutcome(
    for error: AuthenticationError,
    biometryTypeName: String
) -> (state: BiometricSignInState, deleteEnrollment: Bool, refreshSnapshot: Bool) {
    if isCredentialFailure(error) {
        return (.passwordRequired, true, true)
    } else {
        return (.neutralError("Couldn't sign in. Try again or use your password."), false, false)
    }
}
