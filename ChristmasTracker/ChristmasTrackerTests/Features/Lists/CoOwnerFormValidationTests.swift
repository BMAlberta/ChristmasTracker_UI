//
//  CoOwnerFormValidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the co-owner email rule and request builder. The email rule keeps the
//  project's existing semantics (RegistrationFormValidator.isValidEmail: contains "@" and "."),
//  applied after trimming. Fake addresses only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Co-owner form validation Tests")
struct CoOwnerFormValidationTests {

    @Test("Well-formed addresses are valid", arguments: [
        "casey@example.com", "casey.member+gifts@example.com", "a@b.co", "  casey@example.com  ", "\tcasey@example.com\n"
    ])
    func validEmails(email: String) {
        #expect(CoOwnerFormValidation.isValidEmail(email))
    }

    @Test("Malformed addresses are invalid", arguments: [
        "", "   ", "plain", "no-at.example.com", "casey@nodot", "casey.example.com", "\n"
    ])
    func invalidEmails(email: String) {
        #expect(!CoOwnerFormValidation.isValidEmail(email))
    }

    @Test("The rule agrees with the registration form on ordinary addresses", arguments: [
        "casey@example.com", "plain", "casey@nodot", "no-at.example.com"
    ])
    func agreesWithRegistration(email: String) {
        #expect(CoOwnerFormValidation.isValidEmail(email) == RegistrationFormValidator.isValidEmail(email))
    }

    @Test("makeChange returns set(email:) with the trimmed address")
    func makeChangeTrims() {
        #expect(CoOwnerFormValidation.makeChange(email: "  casey@example.com \n") == .set(email: "casey@example.com"))
        #expect(CoOwnerFormValidation.makeChange(email: "casey@example.com") == .set(email: "casey@example.com"))
    }

    @Test("makeChange is nil for an invalid address", arguments: ["", "  ", "plain", "casey@nodot"])
    func makeChangeInvalid(email: String) {
        #expect(CoOwnerFormValidation.makeChange(email: email) == nil)
    }

    @Test("makeChange never produces clear or unchanged")
    func makeChangeOnlySets() {
        let change = CoOwnerFormValidation.makeChange(email: "casey@example.com")
        #expect(change != .clear)
        #expect(change != .unchanged)
    }
}
