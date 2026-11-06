// AuthErrorMappingTests.swift
// ChristmasTrackerTests
//
// Story C2 — Group A: AuthenticationError message mapping tests.
// Tests the nonisolated free function:
//   func userMessage(for error: AuthenticationError) -> String

import Testing
import Foundation
@testable import ChristmasTracker

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
        #expect(userMessage(for: .accountDisabled) == "This account has been disabled. Contact your administrator.")
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

    // A5
    @Test("validationFailed maps to expected message")
    func validationFailedMapsToExpectedMessage() {
        #expect(userMessage(for: .validationFailed) == "Please check your entries and try again.")
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

    // A9
    @Test("rateLimited maps to expected message")
    func rateLimitedMapsToExpectedMessage() {
        #expect(userMessage(for: .rateLimited) == "Too many attempts. Please wait a moment and try again.")
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
