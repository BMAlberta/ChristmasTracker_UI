//
//  RecordPurchaseTotalCostParsingTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: RecordPurchaseFormState.parseTotalCost(_:locale:). The text is trimmed; only the
//  locale's decimal separator is accepted; grouping separators, signs, exponents, currency
//  symbols and any other character are rejected; at most two fraction digits; the value must be
//  above 0 and at most 999999.99. The result is an exact Decimal (no Double on the way).
//
//  Fails today because RecordPurchaseFormState does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase total cost parsing Tests")
struct RecordPurchaseTotalCostParsingTests {

    private let enUS = Locale(identifier: "en_US")
    private let deDE = Locale(identifier: "de_DE")

    private func parse(_ text: String, _ locale: Locale) -> Decimal? {
        RecordPurchaseFormState.parseTotalCost(text, locale: locale)
    }

    // MARK: - en_US

    @Test("en_US parses a dot-decimal amount exactly",
          arguments: [("12.50", "12.50"), ("0.01", "0.01"), ("19.99", "19.99"), ("999999.99", "999999.99"),
                      ("12", "12"), ("0.10", "0.10"), ("  12.50  ", "12.50")])
    func enUSParses(text: String, expected: String) {
        #expect(parse(text, enUS) == PurchaseFixtures.decimal(expected), "\(text)")
    }

    @Test("en_US rejects the comma decimal, grouping, signs, exponents, symbols and junk",
          arguments: ["12,50", "1,234.50", "-5", "-5.00", "+5", "1e2", "$12.50", "12.50 USD", "12.5.0", "abc", "", "  ", "."])
    func enUSRejectsFormats(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("en_US enforces greater than 0, at most 999999.99 and at most two decimals",
          arguments: ["0", "0.00", "0.000", "1000000.00", "1000000", "999999.995", "12.345", "0.001"])
    func enUSRejectsRange(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    // MARK: - de_DE

    @Test("de_DE parses a comma-decimal amount exactly",
          arguments: [("12,50", "12.50"), ("0,01", "0.01"), ("999999,99", "999999.99"), ("12", "12")])
    func deDEParses(text: String, expected: String) {
        #expect(parse(text, deDE) == PurchaseFixtures.decimal(expected), "\(text)")
    }

    @Test("de_DE rejects the dot decimal, grouping, signs and three decimals",
          arguments: ["12.50", "1.234,50", "-5,00", "12,345", "0,00", "1000000,00", "999999,995", "$12,50"])
    func deDERejects(text: String) {
        #expect(parse(text, deDE) == nil, "\(text)")
    }

    @Test("The same text can mean different things per locale: 12,50 is only valid in de_DE")
    func localeDecidesSeparator() {
        #expect(parse("12,50", enUS) == nil)
        #expect(parse("12,50", deDE) == PurchaseFixtures.decimal("12.50"))
        #expect(parse("12.50", deDE) == nil)
        #expect(parse("12.50", enUS) == PurchaseFixtures.decimal("12.50"))
    }

    @Test("The form state uses the injected locale for the cost text")
    func formStateUsesLocale() throws {
        let input = RecordPurchaseFormInput(
            quantity: 1, totalCostText: "12,50", storeName: "", notes: "", confirmationNumber: "", trackingNumber: ""
        )
        let german = RecordPurchaseFormState(input: input, quantityRemaining: nil, currencyCode: "EUR", locale: deDE)
        #expect(german.isValid)
        #expect(german.draft?.totalCost == PurchaseFixtures.decimal("12.50"))
        let english = RecordPurchaseFormState(input: input, quantityRemaining: nil, currencyCode: "USD", locale: enUS)
        #expect(english.totalCostInvalid)
        #expect(english.draft == nil)
    }
}
