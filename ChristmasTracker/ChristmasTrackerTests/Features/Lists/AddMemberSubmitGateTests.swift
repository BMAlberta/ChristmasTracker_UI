//
//  AddMemberSubmitGateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the add-member form cannot be submitted twice while a mutation is in flight.
//  `canSubmit` is true if and only if the input is valid and no mutation is running.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Add member submit gate Tests")
struct AddMemberSubmitGateTests {

    private func makeSUT(email: String, role: MemberRole = .member, isMutating: Bool) -> Bool {
        AddMemberFormValidation.canSubmit(email: email, role: role, isMutating: isMutating)
    }

    @Test("Truth table: valid and idle is the only true row",
          arguments: [
            ("casey@example.com", false, true),
            ("casey@example.com", true, false),
            ("not-an-email", false, false),
            ("not-an-email", true, false),
            ("", false, false),
            ("", true, false),
            ("  casey@example.com  ", false, true),
            ("  casey@example.com  ", true, false)
          ])
    func truthTable(email: String, isMutating: Bool, expected: Bool) {
        #expect(makeSUT(email: email, isMutating: isMutating) == expected)
    }

    @Test("Either role gives the same answer", arguments: MemberRole.allCases)
    func roleDoesNotMatter(role: MemberRole) {
        #expect(makeSUT(email: "casey@example.com", role: role, isMutating: false))
        #expect(!makeSUT(email: "casey@example.com", role: role, isMutating: true))
        #expect(!makeSUT(email: "nope", role: role, isMutating: false))
    }

    @Test("It agrees with validate when idle", arguments: ["", "  ", "a@b.co", "plain", "x@nodot"])
    func agreesWithValidate(email: String) {
        let valid = AddMemberFormValidation.validate(email: email, role: .member).isValid
        #expect(makeSUT(email: email, isMutating: false) == valid)
    }

    @Test("The length boundary still applies: 254 submits, 255 does not")
    func lengthBoundary() {
        let domain = "@example.com"
        let ok = String(repeating: "a", count: 254 - domain.count) + domain
        let tooLong = String(repeating: "a", count: 255 - domain.count) + domain
        #expect(makeSUT(email: ok, isMutating: false))
        #expect(!makeSUT(email: tooLong, isMutating: false))
    }
}
