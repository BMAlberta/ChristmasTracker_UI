// AuthErrorMappingTests.swift
// ChristmasTrackerTests
//
// Story C2 — Group A: AuthenticationError message mapping tests.
// Tests the nonisolated free function:
//   func userMessage(for error: AuthenticationError) -> String

import Testing
import Foundation
@testable import ChristmasTracker

/// The administrator-contact text for a disabled account (client guide 3.2).
private let accountDisabledAdministratorMessage = "This account has been disabled. Contact your administrator."

@Suite("AuthenticationError user message mapping")
struct AuthErrorMappingTests {

    // A1
    @Test("invalidCredentials maps to expected message")
    func invalidCredentialsMapsToExpectedMessage() {
        #expect(userMessage(for: .invalidCredentials) == "The email or password is incorrect.")
    }

    // A2
    @Test("accountDisabled maps to expected message")
    func accountDisabledMapsToExpectedMessage() {
        #expect(userMessage(for: .accountDisabled) == accountDisabledAdministratorMessage)
    }

    // I2b-2c U3 (D-d): LoginView's error alert shows `error.localizedDescription`
    // (LoginView.swift:85), so a login 403 must show the same administrator text.
    @Test("accountDisabled localizedDescription (shown by LoginView) is the administrator message")
    func accountDisabledLocalizedDescriptionIsAdministratorMessage() {
        let shown = AuthenticationError.accountDisabled.localizedDescription
        #expect(shown == userMessage(for: .accountDisabled))
        #expect(shown == accountDisabledAdministratorMessage)
    }

    // A3
    @Test("invalidRegistrationCode maps to expected message")
    func invalidRegistrationCodeMapsToExpectedMessage() {
        #expect(userMessage(for: .invalidRegistrationCode) == "The registration code is invalid.")
    }

    // A4
    @Test("emailAlreadyExists maps to expected message")
    func emailAlreadyExistsMapsToExpectedMessage() {
        #expect(userMessage(for: .emailAlreadyExists) == "An account with this email address already exists.")
    }

    // A5 (updated for fix pass: validation(message:) replaces validationFailed)
    @Test("validation(message:) userMessage returns the server message directly")
    func validationMessageReturnsServerMessage() {
        #expect(userMessage(for: .validation(message: "Password does not meet requirements")) == "Password does not meet requirements")
    }

    // A6
    @Test("credentialExpired maps to expected message")
    func credentialExpiredMapsToExpectedMessage() {
        #expect(userMessage(for: .credentialExpired) == "Your session has expired. Please sign in again.")
    }

    // A7
    @Test("invalidRefreshToken maps to expected message")
    func invalidRefreshTokenMapsToExpectedMessage() {
        #expect(userMessage(for: .invalidRefreshToken) == "Your session is no longer valid. Please sign in again.")
    }

    // A8
    @Test("updateRequired maps to expected message")
    func updateRequiredMapsToExpectedMessage() {
        #expect(userMessage(for: .updateRequired) == "A required update is available. Please update the app.")
    }

    // A9 (updated for fix pass: rateLimited now carries retryAfter)
    @Test("rateLimited maps to expected message")
    func rateLimitedMapsToExpectedMessage() {
        #expect(userMessage(for: .rateLimited(retryAfter: 60)) == "Too many attempts. Please wait a moment and try again.")
    }

    // A10
    @Test("serverError maps to expected message")
    func serverErrorMapsToExpectedMessage() {
        #expect(userMessage(for: .serverError) == "A server error occurred. Please try again later.")
    }

    // A11
    @Test("networkError maps to expected message")
    func networkErrorMapsToExpectedMessage() {
        #expect(userMessage(for: .networkError) == "A network error occurred. Please check your connection.")
    }

    // A12
    @Test("invalidResponse maps to expected message")
    func invalidResponseMapsToExpectedMessage() {
        #expect(userMessage(for: .invalidResponse) == "An unexpected error occurred. Please try again.")
    }
}
