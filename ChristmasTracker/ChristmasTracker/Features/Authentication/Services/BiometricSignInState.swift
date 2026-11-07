//
//  BiometricSignInState.swift
//  ChristmasTracker
//
//  Enum and pure mapping functions for biometric sign-in outcome state.
//  isCredentialFailure(_:context:) is defined here (moved from LoginView.swift;
//  I2b-2c U3 added the context).
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

// MARK: - AuthErrorContext

/// The call in which an `AuthenticationError` arrived. A 403 ACCOUNT_DISABLED means the stored
/// credential is dead on a refresh, but on a login it only shows the administrator message (D-c).
/// `nonisolated` because the target defaults to MainActor isolation and the classification
/// below is a pure nonisolated function that compares contexts.
nonisolated internal enum AuthErrorContext: Sendable, Equatable {
    case login
    case refresh
}

// MARK: - isCredentialFailure

/// True when the error means the credential can no longer be used and the user must sign in
/// with a password. Exhaustive with no `default`, so a new case forces a decision here.
internal nonisolated func isCredentialFailure(_ error: AuthenticationError, context: AuthErrorContext) -> Bool {
    switch error {
    case .invalidRefreshToken, .sessionExpired, .invalidCredentials, .credentialExpired:
        return true
    case .accountDisabled:
        return context == .refresh
    case .emailAlreadyExists,
         .userNotFound,
         .biometricFailed,
         .biometricNotAvailable,
         .networkError,
         .invalidResponse,
         .updateRequired,
         .rateLimited,
         .serverError,
         .invalidRegistrationCode,
         .validation:
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
    if isCredentialFailure(error, context: .refresh) {
        return (.passwordRequired, true, true)
    } else {
        return (.neutralError("Couldn't sign in. Try again or use your password."), false, false)
    }
}
