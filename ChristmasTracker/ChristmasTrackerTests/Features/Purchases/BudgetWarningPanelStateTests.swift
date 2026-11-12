//
//  BudgetWarningPanelStateTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the pure state of the inline budget warning panel. One row per warning in the
//  same order, plain labels, Decimal amounts formatted with the user's currency, the optional
//  notice, the three button titles, and an announcement that carries no amounts and no names.
//
//  Fails today because BudgetWarningPanelState, BudgetWarningRowState and RecordPurchaseCopy do
//  not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Budget warning panel state Tests")
struct BudgetWarningPanelStateTests {

    private func makeSUT(
        _ warnings: [BudgetWarning],
        notice: String? = nil,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) -> BudgetWarningPanelState {
        BudgetWarningPanelState(warnings: warnings, notice: notice, currencyCode: currencyCode, locale: locale)
    }

    // MARK: - Rows

    @Test("One recipient warning gives one row with the recipient name and formatted amounts")
    func oneRecipientWarning() throws {
        let sut = makeSUT([PurchaseFixtures.recipientWarning()])
        #expect(sut.rows.count == 1)
        let row = try #require(sut.rows.first)
        #expect(row.label == "Over the budget for Pat Recipient")
        #expect(row.budgetLimitText == "$100.00")
        #expect(row.alreadySpentText == "$90.00")
        #expect(row.thisPurchaseText == "$25.50")
        #expect(row.overByText == "$15.50")
    }

    @Test("One total warning gives the total label and formatted amounts")
    func oneTotalWarning() throws {
        let sut = makeSUT([PurchaseFixtures.totalWarning()])
        let row = try #require(sut.rows.first)
        #expect(sut.rows.count == 1)
        #expect(row.label == "Over your total budget")
        #expect(row.budgetLimitText == "$1,500.00")
        #expect(row.alreadySpentText == "$1,490.00")
        #expect(row.thisPurchaseText == "$25.50")
        #expect(row.overByText == "$15.50")
    }

    @Test("Both warnings give two rows in the same order")
    func bothWarningsKeepOrder() {
        let sut = makeSUT([PurchaseFixtures.totalWarning(), PurchaseFixtures.recipientWarning()])
        #expect(sut.rows.map(\.label) == ["Over your total budget", "Over the budget for Pat Recipient"])
        let reversed = makeSUT([PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()])
        #expect(reversed.rows.map(\.label) == ["Over the budget for Pat Recipient", "Over your total budget"])
    }

    @Test("A recipient warning with a nil or blank name uses the neutral label", arguments: [nil, "", "   ", "\n\t"])
    func blankRecipientName(name: String?) throws {
        let sut = makeSUT([PurchaseFixtures.recipientWarning(name: name)])
        let row = try #require(sut.rows.first)
        #expect(row.label == "Over the budget for this recipient")
    }

    @Test("Amounts keep two decimals and the grouping, including small and large values")
    func amountFormatting() throws {
        let warning = PurchaseFixtures.recipientWarning(
            limit: "0.10", spent: "1234.50", amount: "999999.99", overage: "1000000.00"
        )
        let row = try #require(makeSUT([warning]).rows.first)
        #expect(row.budgetLimitText == "$0.10")
        #expect(row.alreadySpentText == "$1,234.50")
        #expect(row.thisPurchaseText == "$999,999.99")
        #expect(row.overByText == "$1,000,000.00")
    }

    @Test("Amounts use the injected currency and locale")
    func injectedCurrency() throws {
        let row = try #require(makeSUT([PurchaseFixtures.recipientWarning()], currencyCode: "EUR",
                                       locale: Locale(identifier: "de_DE")).rows.first)
        #expect(row.budgetLimitText.contains("100,00"))
        #expect(row.budgetLimitText.contains("€"))
        #expect(row.overByText.contains("15,50"))
    }

    @Test("No warnings gives no rows")
    func noWarnings() {
        #expect(makeSUT([]).rows.isEmpty)
    }

    // MARK: - Notice and titles

    @Test("The notice is passed through when present and nil when absent")
    func notice() {
        #expect(makeSUT([PurchaseFixtures.totalWarning()]).noticeText == nil)
        let sut = makeSUT([PurchaseFixtures.totalWarning()], notice: RecordPurchaseCopy.budgetChangedNotice)
        #expect(sut.noticeText == "The amounts changed since the last warning. Review them and confirm again.")
    }

    @Test("The copy constants are exactly the specified sentences")
    func copyConstants() {
        #expect(RecordPurchaseCopy.budgetChangedNotice
                == "The amounts changed since the last warning. Review them and confirm again.")
        #expect(RecordPurchaseCopy.expiredMessage
                == "This confirmation has expired. Review the details and record again.")
    }

    @Test("The three button titles are fixed")
    func buttonTitles() {
        let sut = makeSUT([PurchaseFixtures.totalWarning()])
        #expect(sut.cancelTitle == "Cancel")
        #expect(sut.confirmTitle == "Record Anyway")
        #expect(sut.editTitle == "Edit Details")
    }

    // MARK: - Announcement

    @Test("The announcement mentions the budget warning and the row count but no amounts or names")
    func announcement() {
        let one = makeSUT([PurchaseFixtures.recipientWarning()]).announcement
        let two = makeSUT([PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()]).announcement
        #expect(one.contains("Budget warning"))
        #expect(two.contains("Budget warning"))
        #expect(one.contains("1"))
        #expect(two.contains("2"))
        #expect(one != two)
        for text in [one, two] {
            #expect(text.contains("Pat Recipient") == false)
            #expect(text.contains("$") == false)
            #expect(text.contains("100") == false)
            #expect(text.contains("25.50") == false)
        }
    }
}
