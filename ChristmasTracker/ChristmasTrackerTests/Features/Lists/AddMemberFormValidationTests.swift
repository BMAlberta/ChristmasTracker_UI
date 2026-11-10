//
//  AddMemberFormValidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the add-member form rule and request builder. The email is trimmed, checked
//  with the project's existing email semantics (contains "@" and "."), and capped at 254
//  characters. Fake addresses only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Add member form validation Tests")
struct AddMemberFormValidationTests {

    /// An address of exactly `length` characters ("aaa...@example.com").
    private func email(ofLength length: Int) -> String {
        let domain = "@example.com"
        return String(repeating: "a", count: length - domain.count) + domain
    }

    @Test("A well-formed address with either role is valid", arguments: MemberRole.allCases)
    func validEmail(role: MemberRole) {
        let result = AddMemberFormValidation.validate(email: "casey@example.com", role: role)
        #expect(!result.emailInvalid)
        #expect(result.isValid)
    }

    @Test("Malformed addresses are invalid", arguments: ["", "   ", "plain", "no-at.example.com", "casey@nodot", "\n\t"])
    func invalidEmail(email: String) {
        let result = AddMemberFormValidation.validate(email: email, role: .member)
        #expect(result.emailInvalid)
        #expect(!result.isValid)
    }

    @Test("Surrounding whitespace is ignored")
    func trimmedBeforeChecking() {
        #expect(AddMemberFormValidation.validate(email: "  casey@example.com \n", role: .viewer).isValid)
    }

    @Test("Length boundary: 254 characters is valid, 255 is not", arguments: [(253, true), (254, true), (255, false), (300, false)])
    func lengthBoundary(length: Int, valid: Bool) {
        let result = AddMemberFormValidation.validate(email: email(ofLength: length), role: .member)
        #expect(result.isValid == valid)
        #expect(result.emailInvalid == !valid)
    }

    @Test("Length is measured after trimming")
    func lengthAfterTrim() {
        let padded = "  " + email(ofLength: 254) + "  "
        #expect(AddMemberFormValidation.validate(email: padded, role: .member).isValid)
        let tooLong = "  " + email(ofLength: 255) + "  "
        #expect(AddMemberFormValidation.validate(email: tooLong, role: .member).emailInvalid)
    }

    @Test("isValid is the opposite of emailInvalid")
    func validityIsConsistent() {
        for text in ["casey@example.com", "", "plain"] {
            let result = AddMemberFormValidation.validate(email: text, role: .member)
            #expect(result.isValid == !result.emailInvalid)
        }
    }

    @Test("makeInput trims the email and carries the role", arguments: MemberRole.allCases)
    func makeInputTrims(role: MemberRole) {
        let input = AddMemberFormValidation.makeInput(email: "  casey@example.com\n", role: role)
        #expect(input == AddMemberInput(email: "casey@example.com", role: role))
    }
}
