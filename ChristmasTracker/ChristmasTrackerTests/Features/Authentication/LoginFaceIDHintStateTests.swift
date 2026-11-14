//
//  LoginFaceIDHintStateTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B4: OLD behavior: no hint state existed, so nothing survived the error alert's
//  dismissal. LoginFaceIDHintState holds the hint text between sign-in attempts.
//

import Testing
@testable import ChristmasTracker

@Suite("Login Face ID hint state Tests")
struct LoginFaceIDHintStateTests {

    private let enrolled = LoginBiometricButtonState.showEnrolled(firstName: "Sam")
    private let hintText = "You can also sign in with Face ID."

    private func shown() -> LoginFaceIDHintState {
        LoginFaceIDHintState.none.signInFailed(error: .invalidCredentials, buttonState: enrolled, biometricName: "Face ID")
    }

    @Test("none has no text")
    func noneHasNoText() {
        #expect(LoginFaceIDHintState.none.text == nil)
    }

    @Test("a credentials failure with an enrolled button shows the hint")
    func credentialsShows() {
        #expect(shown().text == hintText)
    }

    @Test("a credentials failure with a non-enrolled button shows nothing")
    func credentialsNotEnrolled() {
        let state = LoginFaceIDHintState.none.signInFailed(error: .invalidCredentials, buttonState: .showNotEnrolled, biometricName: "Face ID")
        #expect(state == .none)
    }

    @Test("network, server, rate-limit and disabled failures show nothing",
          arguments: [
            AuthenticationError.networkError,
            .serverError,
            .rateLimited(retryAfter: 10),
            .accountDisabled
          ])
    func otherFailuresShowNothing(error: AuthenticationError) {
        let state = LoginFaceIDHintState.none.signInFailed(error: error, buttonState: enrolled, biometricName: "Face ID")
        #expect(state.text == nil)
    }

    @Test("a later non-credentials failure replaces a shown hint with none")
    func laterFailureReplaces() {
        let next = shown().signInFailed(error: .networkError, buttonState: enrolled, biometricName: "Face ID")
        #expect(next == .none)
    }

    @Test("a nil error replaces a shown hint with none")
    func nilErrorReplaces() {
        let next = shown().signInFailed(error: nil, buttonState: enrolled, biometricName: "Face ID")
        #expect(next == .none)
    }

    @Test("editing a field clears the hint")
    func fieldEditedClears() {
        #expect(shown().fieldEdited() == .none)
    }

    @Test("starting a sign-in clears the hint")
    func signInStartedClears() {
        #expect(shown().signInStarted() == .none)
    }

    @Test("reset clears the hint")
    func resetClears() {
        #expect(shown().reset() == .none)
    }

    @Test("clearing from none stays none")
    func clearingFromNone() {
        let state = LoginFaceIDHintState.none
        #expect(state.fieldEdited() == .none)
        #expect(state.signInStarted() == .none)
        #expect(state.reset() == .none)
    }
}
