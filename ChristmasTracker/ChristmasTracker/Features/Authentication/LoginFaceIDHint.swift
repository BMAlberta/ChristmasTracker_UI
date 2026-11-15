//
//  LoginFaceIDHint.swift
//  ChristmasTracker
//
//  UX1b Story B4: after a wrong password, remind the user that biometric sign-in is available.
//

import Foundation

/// Pure presenter for the Face ID hint shown below the Sign In button.
internal nonisolated enum LoginFaceIDHint {
    static func text(
        for error: AuthenticationError?,
        buttonState: LoginBiometricButtonState,
        biometricName: String
    ) -> String? {
        guard case .invalidCredentials? = error else { return nil }
        guard case .showEnrolled = buttonState else { return nil }
        return "You can also sign in with \(biometricName)."
    }
}

/// Holds the hint text between sign-in attempts.
internal nonisolated struct LoginFaceIDHintState: Equatable, Sendable {
    private(set) var text: String?

    static let none = LoginFaceIDHintState(text: nil)

    func signInStarted() -> LoginFaceIDHintState { .none }

    func fieldEdited() -> LoginFaceIDHintState { .none }

    func reset() -> LoginFaceIDHintState { .none }

    func signInFailed(
        error: AuthenticationError?,
        buttonState: LoginBiometricButtonState,
        biometricName: String
    ) -> LoginFaceIDHintState {
        LoginFaceIDHintState(
            text: LoginFaceIDHint.text(for: error, buttonState: buttonState, biometricName: biometricName)
        )
    }
}
