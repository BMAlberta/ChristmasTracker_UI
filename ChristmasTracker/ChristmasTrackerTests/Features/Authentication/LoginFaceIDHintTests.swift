//
//  LoginFaceIDHintTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B4: OLD behavior: no Face ID hint existed after a wrong password; the login screen
//  showed only the error alert. LoginFaceIDHint.text(for:buttonState:biometricName:) is the pure
//  presenter: a hint only for invalidCredentials with an enrolled biometric button.
//

import Testing
@testable import ChristmasTracker

@Suite("Login Face ID hint presenter Tests")
struct LoginFaceIDHintTests {

    private let enrolled = LoginBiometricButtonState.showEnrolled(firstName: "Sam")
    private let hintText = "You can also sign in with Face ID."

    private func makeText(
        error: AuthenticationError?,
        state: LoginBiometricButtonState? = nil,
        name: String = "Face ID"
    ) -> String? {
        LoginFaceIDHint.text(for: error, buttonState: state ?? enrolled, biometricName: name)
    }

    /// Every AuthenticationError case, enumerated explicitly (the enum is not CaseIterable).
    nonisolated static let nonCredentialErrors: [AuthenticationError] = [
        .emailAlreadyExists,
        .userNotFound,
        .biometricFailed,
        .biometricNotAvailable,
        .invalidRefreshToken,
        .sessionExpired,
        .networkError,
        .invalidResponse,
        .accountDisabled,
        .updateRequired,
        .rateLimited(retryAfter: 30),
        .serverError,
        .invalidRegistrationCode,
        .validation(message: "Bad input"),
        .credentialExpired
    ]

    @Test("invalidCredentials with an enrolled button shows the Face ID sentence")
    func credentialsShowsHint() {
        #expect(makeText(error: .invalidCredentials) == hintText)
    }

    @Test("every other error case with an enrolled button gives no hint", arguments: LoginFaceIDHintTests.nonCredentialErrors)
    func otherErrorsGiveNoHint(error: AuthenticationError) {
        #expect(makeText(error: error) == nil)
    }

    @Test("the explicit error list plus invalidCredentials covers all 16 cases")
    func listCoversAllCases() {
        #expect(Self.nonCredentialErrors.count + 1 == 16)
    }

    @Test("invalidCredentials with a hidden button gives no hint")
    func hiddenGivesNoHint() {
        #expect(makeText(error: .invalidCredentials, state: .hidden) == nil)
    }

    @Test("invalidCredentials with a not-enrolled button gives no hint")
    func notEnrolledGivesNoHint() {
        #expect(makeText(error: .invalidCredentials, state: .showNotEnrolled) == nil)
    }

    @Test("invalidCredentials with a needs-setup button gives no hint", arguments: [true, false])
    func needsSetupGivesNoHint(opensSettings: Bool) {
        let state = LoginBiometricButtonState.showNeedsSetup(message: "Set up first", opensSettings: opensSettings)
        #expect(makeText(error: .invalidCredentials, state: state) == nil)
    }

    @Test("a nil error gives no hint")
    func nilErrorGivesNoHint() {
        #expect(makeText(error: nil) == nil)
    }

    @Test("the sentence uses the biometric name",
          arguments: [
            ("Face ID", "You can also sign in with Face ID."),
            ("Touch ID", "You can also sign in with Touch ID."),
            ("Face ID or Touch ID", "You can also sign in with Face ID or Touch ID.")
          ])
    func nameIsUsed(name: String, expected: String) {
        #expect(makeText(error: .invalidCredentials, name: name) == expected)
    }
}
