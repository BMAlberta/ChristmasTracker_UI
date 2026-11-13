//
//  BudgetAmountParserTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: truth table for BudgetAmountParser (zero allowed, 0...999999.99, two decimals).
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated struct ParserCase: Sendable, CustomTestStringConvertible {
    let text: String
    /// Expected value as a plain decimal string, nil when the parser must reject the text.
    let expected: String?

    var testDescription: String { "\"\(text)\" -> \(expected ?? "nil")" }
}

@Suite("BudgetAmountParser")
struct BudgetAmountParserTests {

    private static let enUS = Locale(identifier: "en_US")
    private static let deDE = Locale(identifier: "de_DE")

    private func check(_ testCase: ParserCase, locale: Locale) {
        let expected = testCase.expected.map { BudgetFixtures.dec($0) }
        #expect(BudgetAmountParser.parse(testCase.text, locale: locale) == expected)
    }

    @Test func maximumIsNineNinesPointNineNine() {
        #expect(BudgetAmountParser.maximum == BudgetFixtures.dec("999999.99"))
    }

    @Test(arguments: [
        ParserCase(text: "12.50", expected: "12.50"),
        ParserCase(text: "12.5", expected: "12.5"),
        ParserCase(text: "12", expected: "12"),
        ParserCase(text: "0", expected: "0"),
        ParserCase(text: "0.00", expected: "0"),
        ParserCase(text: "0.01", expected: "0.01"),
        ParserCase(text: "999999.99", expected: "999999.99"),
        ParserCase(text: "999999", expected: "999999"),
        ParserCase(text: ".50", expected: "0.50"),
        ParserCase(text: "12.", expected: "12"),
        ParserCase(text: "  12.50  ", expected: "12.50"),
        ParserCase(text: "79.99", expected: "79.99")
    ])
    func acceptsValidTextInDotLocale(_ testCase: ParserCase) {
        check(testCase, locale: Self.enUS)
    }

    @Test(arguments: [
        ParserCase(text: "-1", expected: nil),
        ParserCase(text: "-0.01", expected: nil),
        ParserCase(text: "+5", expected: nil),
        ParserCase(text: "1000000.00", expected: nil),
        ParserCase(text: "1000000", expected: nil),
        ParserCase(text: "999999.995", expected: nil),
        ParserCase(text: "1.234", expected: nil),
        ParserCase(text: "12.505", expected: nil),
        ParserCase(text: "", expected: nil),
        ParserCase(text: "   ", expected: nil),
        ParserCase(text: ".", expected: nil),
        ParserCase(text: "1,234.50", expected: nil),
        ParserCase(text: "1,234", expected: nil),
        ParserCase(text: "12,5", expected: nil),
        ParserCase(text: "abc", expected: nil),
        ParserCase(text: "12a", expected: nil),
        ParserCase(text: "1e3", expected: nil),
        ParserCase(text: "$12.50", expected: nil),
        ParserCase(text: "12.50$", expected: nil),
        ParserCase(text: "1 2", expected: nil),
        ParserCase(text: "12.5.0", expected: nil),
        ParserCase(text: "\u{0661}\u{0662}", expected: nil)
    ])
    func rejectsInvalidTextInDotLocale(_ testCase: ParserCase) {
        check(testCase, locale: Self.enUS)
    }

    @Test(arguments: [
        ParserCase(text: "12,5", expected: "12.5"),
        ParserCase(text: "12,50", expected: "12.50"),
        ParserCase(text: "0,01", expected: "0.01"),
        ParserCase(text: "999999,99", expected: "999999.99"),
        ParserCase(text: ",50", expected: "0.50"),
        ParserCase(text: "12,", expected: "12"),
        ParserCase(text: "0", expected: "0"),
        ParserCase(text: "12", expected: "12")
    ])
    func acceptsValidTextInCommaLocale(_ testCase: ParserCase) {
        check(testCase, locale: Self.deDE)
    }

    @Test(arguments: [
        ParserCase(text: "12.5", expected: nil),
        ParserCase(text: "1.234,50", expected: nil),
        ParserCase(text: ",", expected: nil),
        ParserCase(text: "12,505", expected: nil),
        ParserCase(text: "1000000,00", expected: nil),
        ParserCase(text: "-1,00", expected: nil),
        ParserCase(text: "12,50 \u{20AC}", expected: nil)
    ])
    func rejectsInvalidTextInCommaLocale(_ testCase: ParserCase) {
        check(testCase, locale: Self.deDE)
    }

    @Test func zeroIsAcceptedUnlikeThePurchaseTotal() {
        #expect(BudgetAmountParser.parse("0", locale: Self.enUS) == 0)
        #expect(BudgetAmountParser.parse("0.00", locale: Self.enUS) == 0)
    }
}
