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

    // MARK: - I4a-B follow-up (decision 2): a leading or trailing decimal separator is accepted

    @Test("en_US accepts a leading separator (.50 is 0.50) and a trailing separator (12. is 12)",
          arguments: [(".50", "0.50"), (".5", "0.5"), (".05", "0.05"), ("12.", "12"), ("999999.", "999999"),
                      ("  .50  ", "0.50"), ("  12.  ", "12")])
    func enUSAcceptsLeadingAndTrailingSeparator(text: String, expected: String) {
        #expect(parse(text, enUS) == PurchaseFixtures.decimal(expected), "\(text)")
    }

    @Test("de_DE accepts a leading comma (,50 is 0.50) and a trailing comma (12, is 12)",
          arguments: [(",50", "0.50"), (",5", "0.5"), (",05", "0.05"), ("12,", "12"), ("999999,", "999999"),
                      ("  ,50  ", "0.50"), ("  12,  ", "12")])
    func deDEAcceptsLeadingAndTrailingSeparator(text: String, expected: String) {
        #expect(parse(text, deDE) == PurchaseFixtures.decimal(expected), "\(text)")
    }

    @Test("The lone separator is rejected in both locales")
    func loneSeparatorIsRejected() {
        #expect(parse(".", enUS) == nil)
        #expect(parse(",", deDE) == nil)
        #expect(parse("  .  ", enUS) == nil)
        #expect(parse("  ,  ", deDE) == nil)
    }

    @Test("Zero still fails the greater-than-0 rule, with a leading or trailing separator",
          arguments: [".00", "0.", "0.0", ".0", "0.00", "00."])
    func enUSZeroVariantsAreRejected(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("Zero still fails the greater-than-0 rule in de_DE, with a leading or trailing comma",
          arguments: [",00", "0,", "0,0", ",0", "0,00", "00,"])
    func deDEZeroVariantsAreRejected(text: String) {
        #expect(parse(text, deDE) == nil, "\(text)")
    }

    @Test("Multiple separators are rejected, whichever separator they are",
          arguments: ["1.2.3", "1.2.", "..5", "5..", ".5.", "1,2,3", "1,2.3", "1.2,3"])
    func multipleSeparatorsAreRejectedEnUS(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("Multiple separators are rejected in de_DE as well",
          arguments: ["1,2,3", "1,2,", ",,5", "5,,", ",5,", "1.2.3", "1.2,3", "1,2.3"])
    func multipleSeparatorsAreRejectedDeDE(text: String) {
        #expect(parse(text, deDE) == nil, "\(text)")
    }

    @Test("The other locale's separator is still rejected, also as a leading or trailing separator",
          arguments: [(".50", false), ("12.", false), (",50", true), ("12,", true)])
    func foreignSeparatorIsRejected(text: String, isGerman: Bool) {
        // ".50" and "12." belong to en_US, so de_DE rejects them; ",50" and "12," belong to de_DE.
        let rejectingLocale = isGerman ? enUS : deDE
        #expect(parse(text, rejectingLocale) == nil, "\(text)")
    }

    @Test("Three decimals are still rejected with a leading separator", arguments: [".505", ".001", ".999"])
    func threeDecimalsStillRejectedEnUS(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("Three decimals are still rejected with a leading comma in de_DE", arguments: [",505", ",001", ",999"])
    func threeDecimalsStillRejectedDeDE(text: String) {
        #expect(parse(text, deDE) == nil, "\(text)")
    }

    @Test("Signs, exponents and symbols are still rejected next to a leading or trailing separator",
          arguments: ["-.50", "+.50", "-12.", ".5e1", "1e2.", "$.50", "$12.", ".50$", "12.USD"])
    func signsExponentsAndSymbolsStillRejected(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("Grouping separators are still rejected next to a leading or trailing separator",
          arguments: ["1,234.", ",234.50", "1,234.50", "1 234.50", "1_234."])
    func groupingStillRejectedEnUS(text: String) {
        #expect(parse(text, enUS) == nil, "\(text)")
    }

    @Test("Grouping separators are still rejected in de_DE",
          arguments: ["1.234,", ".234,50", "1.234,50", "1 234,50", "1_234,"])
    func groupingStillRejectedDeDE(text: String) {
        #expect(parse(text, deDE) == nil, "\(text)")
    }

    @Test("The bounds still hold with the relaxed forms: 999999. passes, 1000000. fails")
    func boundsWithRelaxedForms() {
        #expect(parse("999999.", enUS) == PurchaseFixtures.decimal("999999"))
        #expect(parse("1000000.", enUS) == nil)
        #expect(parse("999999,", deDE) == PurchaseFixtures.decimal("999999"))
        #expect(parse("1000000,", deDE) == nil)
    }

    @Test("The form state accepts .50 and 12. and builds the draft with the exact Decimal",
          arguments: [(".50", "0.50"), ("12.", "12")])
    func formStateAcceptsRelaxedForms(text: String, expected: String) throws {
        let input = RecordPurchaseFormInput(
            quantity: 1, totalCostText: text, storeName: "", notes: "", confirmationNumber: "", trackingNumber: ""
        )
        let state = RecordPurchaseFormState(input: input, quantityRemaining: nil, currencyCode: "USD", locale: enUS)

        #expect(state.totalCostInvalid == false, "\(text)")
        #expect(state.isValid)
        #expect(state.draft?.totalCost == PurchaseFixtures.decimal(expected))
    }

    @Test("The form state flags the lone separator and the relaxed zero forms as an invalid cost",
          arguments: [".", ".00", "0.", "0.0"])
    func formStateRejectsLoneSeparatorAndZeroForms(text: String) {
        let input = RecordPurchaseFormInput(
            quantity: 1, totalCostText: text, storeName: "", notes: "", confirmationNumber: "", trackingNumber: ""
        )
        let state = RecordPurchaseFormState(input: input, quantityRemaining: nil, currencyCode: "USD", locale: enUS)

        #expect(state.totalCostInvalid, "\(text)")
        #expect(state.draft == nil)
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
