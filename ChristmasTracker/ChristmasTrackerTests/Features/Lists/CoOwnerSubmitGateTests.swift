//
//  CoOwnerSubmitGateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the co-owner change cannot be submitted twice while a mutation is in flight.
//  `canSubmit` is true if and only if the email is valid and no mutation is running.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Co-owner submit gate Tests")
struct CoOwnerSubmitGateTests {

    private func makeSUT(email: String, isMutating: Bool) -> Bool {
        CoOwnerFormValidation.canSubmit(email: email, isMutating: isMutating)
    }

    @Test("Truth table: valid and idle is the only true row",
          arguments: [
            ("cody@example.com", false, true),
            ("cody@example.com", true, false),
            ("  cody@example.com\n", false, true),
            ("  cody@example.com\n", true, false),
            ("cody", false, false),
            ("cody", true, false),
            ("", false, false),
            ("", true, false),
            ("   ", false, false)
          ])
    func truthTable(email: String, isMutating: Bool, expected: Bool) {
        #expect(makeSUT(email: email, isMutating: isMutating) == expected)
    }

    @Test("It agrees with isValidEmail when idle", arguments: ["", "a@b.co", "plain", "x@nodot", " a@b.co "])
    func agreesWithIsValidEmail(email: String) {
        #expect(makeSUT(email: email, isMutating: false) == CoOwnerFormValidation.isValidEmail(email))
    }
}
