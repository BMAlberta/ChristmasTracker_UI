//
//  ChildFormValidationTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: the add-child form rules and request builder. First and last name are
//  required (1...100 after trimming); the display name is optional (blank after trimming means
//  absent and valid, otherwise 1...200). Fake names only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child form validation Tests")
struct ChildFormValidationTests {

    private func text(_ count: Int) -> String {
        String(repeating: "a", count: count)
    }

    // MARK: - First name

    @Test("First name boundaries", arguments: [(0, false), (1, true), (100, true), (101, false)])
    func firstNameBoundaries(length: Int, valid: Bool) {
        let result = ChildFormValidation.validate(firstName: text(length), lastName: "Child", displayName: "")
        #expect(result.firstNameInvalid == !valid)
        #expect(!result.lastNameInvalid)
        #expect(result.isValid == valid)
    }

    @Test("A whitespace-only first name is invalid")
    func firstNameWhitespace() {
        let result = ChildFormValidation.validate(firstName: " \n\t ", lastName: "Child", displayName: "")
        #expect(result.firstNameInvalid)
        #expect(!result.isValid)
    }

    @Test("First name length is measured after trimming")
    func firstNameTrimmed() {
        #expect(ChildFormValidation.validate(firstName: "  " + text(100) + "  ", lastName: "Child", displayName: "").isValid)
        #expect(ChildFormValidation.validate(firstName: "  " + text(101) + "  ", lastName: "Child", displayName: "").firstNameInvalid)
    }

    // MARK: - Last name

    @Test("Last name boundaries", arguments: [(0, false), (1, true), (100, true), (101, false)])
    func lastNameBoundaries(length: Int, valid: Bool) {
        let result = ChildFormValidation.validate(firstName: "Charlie", lastName: text(length), displayName: "")
        #expect(result.lastNameInvalid == !valid)
        #expect(!result.firstNameInvalid)
        #expect(result.isValid == valid)
    }

    @Test("A whitespace-only last name is invalid")
    func lastNameWhitespace() {
        let result = ChildFormValidation.validate(firstName: "Charlie", lastName: "   ", displayName: "")
        #expect(result.lastNameInvalid)
        #expect(!result.isValid)
    }

    @Test("Last name length is measured after trimming")
    func lastNameTrimmed() {
        #expect(ChildFormValidation.validate(firstName: "Charlie", lastName: " " + text(100) + " ", displayName: "").isValid)
        #expect(ChildFormValidation.validate(firstName: "Charlie", lastName: " " + text(101) + " ", displayName: "").lastNameInvalid)
    }

    // MARK: - Display name (optional)

    @Test("A blank display name is absent and valid", arguments: ["", " ", "   \n\t "])
    func blankDisplayNameValid(display: String) {
        let result = ChildFormValidation.validate(firstName: "Charlie", lastName: "Child", displayName: display)
        #expect(!result.displayNameInvalid)
        #expect(result.isValid)
    }

    @Test("Display name boundaries", arguments: [(1, true), (200, true), (201, false)])
    func displayNameBoundaries(length: Int, valid: Bool) {
        let result = ChildFormValidation.validate(firstName: "Charlie", lastName: "Child", displayName: text(length))
        #expect(result.displayNameInvalid == !valid)
        #expect(result.isValid == valid)
    }

    @Test("Display name length is measured after trimming")
    func displayNameTrimmed() {
        #expect(ChildFormValidation.validate(firstName: "Charlie", lastName: "Child", displayName: "  " + text(200) + "  ").isValid)
        #expect(ChildFormValidation.validate(firstName: "Charlie", lastName: "Child", displayName: "  " + text(201) + "  ").displayNameInvalid)
    }

    // MARK: - Combined

    @Test("Every problem is reported together")
    func everyProblem() {
        let result = ChildFormValidation.validate(firstName: "", lastName: text(101), displayName: text(201))
        #expect(result.firstNameInvalid)
        #expect(result.lastNameInvalid)
        #expect(result.displayNameInvalid)
        #expect(!result.isValid)
    }

    @Test("A fully valid form has no problems")
    func allGood() {
        let result = ChildFormValidation.validate(firstName: "Charlie", lastName: "Child", displayName: "Charlie C")
        #expect(!result.firstNameInvalid)
        #expect(!result.lastNameInvalid)
        #expect(!result.displayNameInvalid)
        #expect(result.isValid)
    }

    // MARK: - makeInput

    @Test("makeInput trims every field and carries the relationship", arguments: ChildRelationship.allCases)
    func makeInputTrims(relationship: ChildRelationship) {
        let input = ChildFormValidation.makeInput(
            firstName: "  Charlie ", lastName: " Child\n", displayName: "  Charlie C  ", relationship: relationship
        )
        #expect(input == CreateChildInput(
            firstName: "Charlie", lastName: "Child", displayName: "Charlie C", relationship: relationship
        ))
    }

    @Test("makeInput makes a blank display name nil", arguments: ["", "  ", " \n\t "])
    func makeInputBlankDisplayName(display: String) {
        let input = ChildFormValidation.makeInput(
            firstName: "Charlie", lastName: "Child", displayName: display, relationship: .parent
        )
        #expect(input.displayName == nil)
    }
}
