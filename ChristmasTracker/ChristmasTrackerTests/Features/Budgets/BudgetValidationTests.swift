//
//  BudgetValidationTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: truth table for BudgetValidation.validate and summaryLine.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetValidation")
struct BudgetValidationTests {

    private let locale = BudgetFixtures.enUS

    private func validate(total: String, limits: [(id: String, limit: String)] = []) -> BudgetValidation {
        BudgetValidation.validate(BudgetFixtures.draft(total: total, limits: limits), locale: locale)
    }

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    // MARK: - Valid

    @Test func validDraftHasNoIssuesAndCorrectArithmetic() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        #expect(result.isValid)
        #expect(result.issues.isEmpty)
        #expect(result.total == dec("500"))
        #expect(result.limitsSum == dec("450"))
        #expect(result.unallocated == dec("50"))
    }

    @Test func emptyRecipientsIsValidWithEverythingUnallocated() {
        let result = validate(total: "300.00")
        #expect(result.isValid)
        #expect(result.limitsSum == 0)
        #expect(result.unallocated == dec("300"))
    }

    // MARK: - Total

    @Test(arguments: ["0", "0.00", "0.01", "999999.99", "12.5", ".50", "12."])
    func validTotals(_ text: String) {
        let result = validate(total: text)
        #expect(result.isValid)
        #expect(result.total != nil)
    }

    @Test func zeroTotalIsValid() {
        let result = validate(total: "0")
        #expect(result.isValid)
        #expect(result.total == 0)
        #expect(result.unallocated == 0)
    }

    @Test(arguments: ["-1", "-0.01", "1.234", "1000000.00", "1000000", "", "   ", ".", "abc", "1,000.00", "$5"])
    func invalidTotals(_ text: String) {
        let result = validate(total: text)
        #expect(!result.isValid)
        #expect(result.issues.contains(.totalInvalid))
        #expect(result.total == nil)
        #expect(result.unallocated == nil)
    }

    @Test func invalidTotalNeverReportsLimitsExceedTotal() {
        let result = validate(total: "abc", limits: [(id: "r1", limit: "100")])
        #expect(result.issues.contains(.totalInvalid))
        #expect(!result.issues.contains(.limitsExceedTotal))
    }

    // MARK: - Limits

    @Test(arguments: ["abc", "", "-5", "1.234", "1000000", ".", "$5"])
    func invalidLimitIsReportedForThatRecipient(_ text: String) {
        let result = validate(total: "500", limits: [(id: "r1", limit: "100"), (id: "r2", limit: text)])
        #expect(!result.isValid)
        #expect(result.issues.contains(.limitInvalid(recipientId: "r2")))
        #expect(!result.issues.contains(.limitInvalid(recipientId: "r1")))
    }

    @Test func limitsSumCountsOnlyParseableLimits() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "100"), (id: "r2", limit: "abc")])
        #expect(result.limitsSum == dec("100"))
        #expect(result.unallocated == dec("400"))
    }

    @Test func zeroLimitIsValid() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "0")])
        #expect(result.isValid)
    }

    // MARK: - Sum rule

    @Test func limitsEqualToTotalAreValid() {
        let result = validate(total: "500.00", limits: [(id: "r1", limit: "200.00"), (id: "r2", limit: "300.00")])
        #expect(result.isValid)
        #expect(result.unallocated == 0)
        #expect(!result.issues.contains(.limitsExceedTotal))
    }

    @Test func limitsOneCentOverTotalExceed() {
        let result = validate(total: "500.00", limits: [(id: "r1", limit: "200.00"), (id: "r2", limit: "300.01")])
        #expect(!result.isValid)
        #expect(result.issues == [.limitsExceedTotal])
        #expect(result.limitsSum == dec("500.01"))
        #expect(result.unallocated == dec("-0.01"))
    }

    @Test func singleLimitOverTotalExceeds() {
        let result = validate(total: "100", limits: [(id: "r1", limit: "150")])
        #expect(!result.isValid)
        #expect(result.issues.contains(.limitsExceedTotal))
        #expect(!result.issues.contains(.limitInvalid(recipientId: "r1")))
    }

    @Test func smallFractionalLimitsSumExactly() {
        let result = validate(total: "0.30", limits: [(id: "r1", limit: "0.10"), (id: "r2", limit: "0.20")])
        #expect(result.isValid)
        #expect(result.limitsSum == dec("0.30"))
    }

    @Test func zeroTotalWithPositiveLimitExceeds() {
        let result = validate(total: "0", limits: [(id: "r1", limit: "0.01")])
        #expect(result.issues.contains(.limitsExceedTotal))
    }

    // MARK: - Duplicates

    @Test func personTwiceIsReportedOnce() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "100"), (id: "r1", limit: "50")])
        #expect(!result.isValid)
        #expect(result.issues.filter { $0 == .duplicateRecipient(recipientId: "r1") }.count == 1)
    }

    @Test func personThreeTimesIsStillReportedOnce() {
        let result = validate(
            total: "500",
            limits: [(id: "r1", limit: "10"), (id: "r1", limit: "10"), (id: "r1", limit: "10")]
        )
        #expect(result.issues.filter { $0 == .duplicateRecipient(recipientId: "r1") }.count == 1)
    }

    @Test func twoRepeatedPeopleYieldOneIssueEach() {
        let result = validate(
            total: "500",
            limits: [(id: "r1", limit: "10"), (id: "r2", limit: "10"), (id: "r1", limit: "10"), (id: "r2", limit: "10")]
        )
        #expect(result.issues.filter { $0 == .duplicateRecipient(recipientId: "r1") }.count == 1)
        #expect(result.issues.filter { $0 == .duplicateRecipient(recipientId: "r2") }.count == 1)
    }

    // MARK: - Summary line

    @Test func summaryLineWhenUnderTotal() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "200"), (id: "r2", limit: "250")])
        #expect(result.summaryLine(currencyCode: "USD", locale: locale)
                == "Limits $450.00 of $500.00; $50.00 unallocated")
    }

    @Test func summaryLineWhenEqualToTotal() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "500")])
        #expect(result.summaryLine(currencyCode: "USD", locale: locale)
                == "Limits $500.00 of $500.00; $0.00 unallocated")
    }

    @Test func summaryLineWithNoLimits() {
        let result = validate(total: "500")
        #expect(result.summaryLine(currencyCode: "USD", locale: locale)
                == "Limits $0.00 of $500.00; $500.00 unallocated")
    }

    @Test func summaryLineWhenOverTotal() {
        let result = validate(total: "500", limits: [(id: "r1", limit: "500.01")])
        #expect(result.summaryLine(currencyCode: "USD", locale: locale) == "Limits add up to more than the total")
    }

    @Test(arguments: ["", "abc", "-1", "1000000"])
    func summaryLineIsNilWhenTotalInvalid(_ text: String) {
        let result = validate(total: text, limits: [(id: "r1", limit: "10")])
        #expect(result.summaryLine(currencyCode: "USD", locale: locale) == nil)
    }
}
