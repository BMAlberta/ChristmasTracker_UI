//
//  ChildSubmitGateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the add-child form cannot be submitted twice while a mutation is in flight.
//  `canSubmit` is true if and only if the input is valid and no mutation is running.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child submit gate Tests")
struct ChildSubmitGateTests {

    private func makeSUT(
        firstName: String = "Charlie",
        lastName: String = "Child",
        displayName: String = "",
        isMutating: Bool = false
    ) -> Bool {
        ChildFormValidation.canSubmit(
            firstName: firstName, lastName: lastName, displayName: displayName, isMutating: isMutating
        )
    }

    @Test("Valid names and an idle service can submit")
    func validIdle() {
        #expect(makeSUT())
        #expect(makeSUT(displayName: "Charlie C"))
    }

    @Test("A mutation in flight blocks every otherwise valid submission")
    func mutatingBlocks() {
        #expect(!makeSUT(isMutating: true))
        #expect(!makeSUT(displayName: "Charlie C", isMutating: true))
    }

    @Test("Invalid input blocks whether or not a mutation runs", arguments: [false, true])
    func invalidBlocks(isMutating: Bool) {
        #expect(!makeSUT(firstName: "", isMutating: isMutating))
        #expect(!makeSUT(firstName: "   ", isMutating: isMutating))
        #expect(!makeSUT(lastName: "", isMutating: isMutating))
        #expect(!makeSUT(lastName: "\n", isMutating: isMutating))
        #expect(!makeSUT(displayName: String(repeating: "d", count: 201), isMutating: isMutating))
    }

    @Test("Boundaries: 100 and 200 characters submit, one more does not")
    func boundaries() {
        #expect(makeSUT(firstName: String(repeating: "f", count: 100)))
        #expect(!makeSUT(firstName: String(repeating: "f", count: 101)))
        #expect(makeSUT(lastName: String(repeating: "l", count: 100)))
        #expect(!makeSUT(lastName: String(repeating: "l", count: 101)))
        #expect(makeSUT(displayName: String(repeating: "d", count: 200)))
        #expect(!makeSUT(displayName: String(repeating: "d", count: 201)))
    }

    @Test("A blank optional display name does not block")
    func blankDisplayNameOk() {
        #expect(makeSUT(displayName: "   "))
    }

    @Test("It agrees with validate when idle")
    func agreesWithValidate() {
        let cases = [("A", "B", ""), ("", "B", ""), ("A", "", "x"), ("A", "B", String(repeating: "d", count: 201))]
        for (first, last, display) in cases {
            let valid = ChildFormValidation.validate(firstName: first, lastName: last, displayName: display).isValid
            #expect(makeSUT(firstName: first, lastName: last, displayName: display) == valid)
        }
    }
}
