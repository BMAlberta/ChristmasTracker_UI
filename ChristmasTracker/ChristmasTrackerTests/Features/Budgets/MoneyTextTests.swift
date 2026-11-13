//
//  MoneyTextTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: the shared pure currency formatter.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MoneyText")
struct MoneyTextTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    @Test func usdInEnUS() {
        #expect(MoneyText.currency(dec("79.99"), code: "USD", locale: BudgetFixtures.enUS) == "$79.99")
        #expect(MoneyText.currency(dec("0"), code: "USD", locale: BudgetFixtures.enUS) == "$0.00")
        #expect(MoneyText.currency(dec("1234.5"), code: "USD", locale: BudgetFixtures.enUS) == "$1,234.50")
        #expect(MoneyText.currency(dec("999999.99"), code: "USD", locale: BudgetFixtures.enUS) == "$999,999.99")
    }

    @Test func alwaysShowsTwoFractionDigits() {
        #expect(MoneyText.currency(dec("5"), code: "USD", locale: BudgetFixtures.enUS) == "$5.00")
        #expect(MoneyText.currency(dec("0.1"), code: "USD", locale: BudgetFixtures.enUS) == "$0.10")
    }

    @Test func commaDecimalLocaleUsesCommaAndItsOwnGrouping() {
        let text = MoneyText.currency(dec("1234.50"), code: "EUR", locale: BudgetFixtures.deDE)
        #expect(text.contains("1.234,50"))
        #expect(text.contains("\u{20AC}"))
    }

    @Test func commaDecimalLocaleWithADollarCode() {
        let text = MoneyText.currency(dec("12.50"), code: "USD", locale: BudgetFixtures.deDE)
        #expect(text.contains("12,50"))
        #expect(text.contains("$"))
    }
}
