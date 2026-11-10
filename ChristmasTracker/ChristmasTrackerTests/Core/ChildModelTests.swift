//
//  ChildModelTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: Child, ChildRelationship and CreateChildInput. Pure value types; fake data.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child model Tests")
struct ChildModelTests {

    // MARK: - ChildRelationship

    @Test("ChildRelationship wire values are the documented uppercase strings",
          arguments: [
            (ChildRelationship.parent, "PARENT", "Parent"),
            (ChildRelationship.guardian, "GUARDIAN", "Guardian"),
            (ChildRelationship.caretaker, "CARETAKER", "Caretaker")
          ])
    func relationshipValuesAndTitles(relationship: ChildRelationship, raw: String, title: String) {
        #expect(relationship.rawValue == raw)
        #expect(relationship.title == title)
        #expect(ChildRelationship(rawValue: raw) == relationship)
    }

    @Test("ChildRelationship has exactly three cases in a stable order")
    func relationshipCases() {
        #expect(ChildRelationship.allCases == [.parent, .guardian, .caretaker])
    }

    @Test("An unknown relationship raw value does not construct")
    func unknownRelationship() {
        #expect(ChildRelationship(rawValue: "UNCLE") == nil)
        #expect(ChildRelationship(rawValue: "") == nil)
    }

    // MARK: - Child.shownName

    @Test("shownName is the display name when it is not blank")
    func shownNameUsesDisplayName() {
        let child = ChildFixtures.child(firstName: "Charlie", lastName: "Child", displayName: "Charlie C")
        #expect(child.shownName == "Charlie C")
    }

    @Test("shownName falls back to first and last name when the display name is nil")
    func shownNameNil() {
        let child = ChildFixtures.child(firstName: "Charlie", lastName: "Child", displayName: nil)
        #expect(child.shownName == "Charlie Child")
    }

    @Test("shownName falls back when the display name is empty or whitespace only", arguments: ["", "   ", " \n\t "])
    func shownNameBlank(display: String) {
        let child = ChildFixtures.child(firstName: "Dana", lastName: "Dependent", displayName: display)
        #expect(child.shownName == "Dana Dependent")
    }

    @Test("A Child is Identifiable by its id and Equatable")
    func identity() {
        let child = ChildFixtures.child(id: "child-9")
        #expect(child.id == "child-9")
        #expect(child == ChildFixtures.child(id: "child-9"))
        #expect(child != ChildFixtures.child(id: "child-10"))
        #expect(child != ChildFixtures.child(id: "child-9", relationship: .caretaker))
    }

    // MARK: - CreateChildInput

    @Test("CreateChildInput carries its fields and is Equatable")
    func createInput() {
        let input = CreateChildInput(firstName: "Dana", lastName: "Dependent", displayName: nil, relationship: .guardian)
        #expect(input.firstName == "Dana")
        #expect(input.lastName == "Dependent")
        #expect(input.displayName == nil)
        #expect(input.relationship == .guardian)
        #expect(input == CreateChildInput(firstName: "Dana", lastName: "Dependent", displayName: nil, relationship: .guardian))
        #expect(input != CreateChildInput(firstName: "Dana", lastName: "Dependent", displayName: "D", relationship: .guardian))
    }
}
