//
//  BudgetCardStateTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: BudgetCardState and BudgetPersonRowState (via the card rows).
//  Over is decided in Decimal; "Over by ..." text is present in every over case.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetCardState")
struct BudgetCardStateTests {

    private let locale = BudgetFixtures.enUS

    private func card(_ budget: Budget) -> BudgetCardState {
        BudgetCardState.make(from: budget, currencyCode: "USD", locale: locale)
    }

    private func card(_ budget: StatsBudget, year: Int = 2026) -> BudgetCardState {
        BudgetCardState.make(from: budget, year: year, currencyCode: "USD", locale: locale)
    }

    // MARK: - Budget form: under, at, over

    @Test func budgetUnderTotal() {
        let state = card(BudgetFixtures.budget(year: 2026, total: "500", spent: "300"))
        #expect(state.year == 2026)
        #expect(state.totalText == "$500.00")
        #expect(state.spentText == "$300.00")
        #expect(state.statusText == "$200.00 remaining")
        #expect(!state.isOver)
        #expect(abs(state.progress - 0.6) < 0.000_001)
        #expect(state.progressAccessibilityLabel == "Spent $300.00 of $500.00")
        #expect(!state.statusText.contains("Over by"))
    }

    @Test func budgetExactlyAtTotalIsNotOver() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "500"))
        #expect(!state.isOver)
        #expect(state.statusText == "$0.00 remaining")
        #expect(state.progress == 1)
    }

    @Test func budgetOneCentOverTotalIsOverWithText() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "500.01"))
        #expect(state.isOver)
        #expect(state.statusText == "Over by $0.01")
        #expect(state.progress == 1)
    }

    @Test func budgetWellOverTotalCapsProgressAtOne() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "1050.50"))
        #expect(state.isOver)
        #expect(state.statusText == "Over by $550.50")
        #expect(state.progress == 1)
        #expect(state.progressAccessibilityLabel == "Spent $1,050.50 of $500.00")
    }

    @Test func budgetNothingSpentHasZeroProgress() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "0"))
        #expect(state.progress == 0)
        #expect(state.statusText == "$500.00 remaining")
        #expect(!state.isOver)
    }

    @Test func overIsDecidedInDecimalNotFromTheServerFlag() {
        let flaggedWrongly = card(BudgetFixtures.budget(total: "100", spent: "150", isOverBudget: false))
        #expect(flaggedWrongly.isOver)
        #expect(flaggedWrongly.statusText == "Over by $50.00")
        let flaggedOverButUnder = card(BudgetFixtures.budget(total: "100", spent: "50", isOverBudget: true))
        #expect(!flaggedOverButUnder.isOver)
        #expect(flaggedOverButUnder.statusText == "$50.00 remaining")
    }

    @Test func progressDoesNotLosePrecisionForCentAmounts() {
        let state = card(BudgetFixtures.budget(total: "999999.99", spent: "0.01"))
        #expect(state.progress > 0)
        #expect(state.progress < 0.000_001)
    }

    // MARK: - Zero-total budget

    @Test func zeroTotalWithNothingSpent() {
        let state = card(BudgetFixtures.budget(total: "0", spent: "0"))
        #expect(state.progress == 0)
        #expect(!state.isOver)
        #expect(state.totalText == "$0.00")
        #expect(state.statusText == "$0.00 remaining")
        #expect(state.progressAccessibilityLabel == "Spent $0.00 of $0.00")
    }

    @Test func zeroTotalWithSpendingIsFullyOver() {
        let state = card(BudgetFixtures.budget(total: "0", spent: "12.34"))
        #expect(state.progress == 1)
        #expect(state.isOver)
        #expect(state.statusText == "Over by $12.34")
    }

    @Test func statsBudgetZeroTotalWithNothingSpent() {
        let state = card(BudgetFixtures.statsBudget(total: "0", spent: "0"))
        #expect(state.progress == 0)
        #expect(!state.isOver)
        #expect(state.statusText == "$0.00 remaining")
    }

    @Test func statsBudgetZeroTotalWithSpending() {
        let state = card(BudgetFixtures.statsBudget(total: "0", spent: "5"))
        #expect(state.progress == 1)
        #expect(state.isOver)
        #expect(state.statusText == "Over by $5.00")
    }

    // MARK: - Stats form: under, at, over

    @Test func statsBudgetUnderTotal() {
        let state = card(BudgetFixtures.statsBudget(total: "1000", spent: "250"), year: 2025)
        #expect(state.year == 2025)
        #expect(state.totalText == "$1,000.00")
        #expect(state.spentText == "$250.00")
        #expect(state.statusText == "$750.00 remaining")
        #expect(!state.isOver)
        #expect(abs(state.progress - 0.25) < 0.000_001)
        #expect(state.progressAccessibilityLabel == "Spent $250.00 of $1,000.00")
    }

    @Test func statsBudgetAtTotal() {
        let state = card(BudgetFixtures.statsBudget(total: "600", spent: "600"))
        #expect(!state.isOver)
        #expect(state.statusText == "$0.00 remaining")
        #expect(state.progress == 1)
    }

    @Test func statsBudgetOverTotalIgnoresTheServerRemaining() {
        let inconsistent = StatsBudget(
            totalBudget: BudgetFixtures.dec("600"),
            totalSpent: BudgetFixtures.dec("619.98"),
            remaining: BudgetFixtures.dec("0"),
            recipients: []
        )
        let state = card(inconsistent)
        #expect(state.isOver)
        #expect(state.statusText == "Over by $19.98")
        #expect(state.progress == 1)
    }

    // MARK: - Person rows

    @Test func personRowUnderLimit() throws {
        let budget = BudgetFixtures.budget(
            total: "500", spent: "150",
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "200", spent: "150")]
        )
        let row = try #require(card(budget).rows.first)
        #expect(row.id == "r1")
        #expect(row.name == "Tommy")
        #expect(row.limitText == "$200.00")
        #expect(row.spentText == "$150.00")
        #expect(row.statusText == "$50.00 remaining")
        #expect(!row.isOver)
        #expect(!row.statusText.contains("Over by"))
        #expect(row.accessibilityLabel.contains("Tommy"))
    }

    @Test func personRowExactlyAtLimitIsNotOver() throws {
        let budget = BudgetFixtures.budget(
            total: "500", spent: "200",
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "200", spent: "200")]
        )
        let row = try #require(card(budget).rows.first)
        #expect(!row.isOver)
        #expect(row.statusText == "$0.00 remaining")
    }

    @Test func personOverTheirLimitWhileBudgetIsNotOver() throws {
        let budget = BudgetFixtures.budget(
            total: "1000", spent: "619.98",
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "600", spent: "619.98")]
        )
        let state = card(budget)
        let row = try #require(state.rows.first)
        #expect(!state.isOver)
        #expect(row.isOver)
        #expect(row.statusText == "Over by $19.98")
        #expect(row.limitText == "$600.00")
        #expect(row.spentText == "$619.98")
        #expect(row.accessibilityLabel.contains("Tommy"))
        #expect(row.accessibilityLabel.contains("Over by $19.98"))
    }

    @Test func personRowOverIsDecidedInDecimalNotFromTheServerFlag() throws {
        let wrongFlag = BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "130", isOverBudget: false)
        let budget = BudgetFixtures.budget(total: "500", spent: "130", recipients: [wrongFlag])
        let row = try #require(card(budget).rows.first)
        #expect(row.isOver)
        #expect(row.statusText == "Over by $30.00")
    }

    @Test func rowsKeepOrderAndOneRowPerPerson() {
        let budget = BudgetFixtures.budget(
            total: "500", spent: "0",
            recipients: [
                BudgetFixtures.recipientBudget(id: "r2", name: "Mike", max: "100", spent: "0"),
                BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "200", spent: "0")
            ]
        )
        #expect(card(budget).rows.map(\.id) == ["r2", "r1"])
    }

    @Test func budgetWithoutRecipientsHasNoRows() {
        #expect(card(BudgetFixtures.budget(total: "500", spent: "0")).rows.isEmpty)
    }

    @Test func statsBudgetRowsUseDecimalOver() throws {
        let stats = BudgetFixtures.statsBudget(
            total: "700", spent: "350",
            recipients: [
                BudgetFixtures.statsRecipientBudget(id: "r1", name: "Tommy", budget: "300", spent: "250"),
                BudgetFixtures.statsRecipientBudget(id: "r2", name: "Mike", budget: "100", spent: "100.01")
            ]
        )
        let rows = card(stats).rows
        let tommy = try #require(rows.first)
        let mike = try #require(rows.last)
        #expect(tommy.statusText == "$50.00 remaining")
        #expect(!tommy.isOver)
        #expect(mike.isOver)
        #expect(mike.statusText == "Over by $0.01")
        #expect(mike.limitText == "$100.00")
        #expect(mike.spentText == "$100.01")
    }

    // MARK: - "Over by" present in every over case, absent otherwise

    @Test func overByTextIsPresentInEveryOverCase() {
        let overStates: [BudgetCardState] = [
            card(BudgetFixtures.budget(total: "10", spent: "10.01")),
            card(BudgetFixtures.budget(total: "0", spent: "1")),
            card(BudgetFixtures.statsBudget(total: "10", spent: "11")),
            card(BudgetFixtures.statsBudget(total: "0", spent: "1"))
        ]
        for state in overStates {
            #expect(state.isOver)
            #expect(state.statusText.hasPrefix("Over by "))
        }
    }

    @Test func overByTextIsAbsentInEveryNotOverCase() {
        let notOver: [BudgetCardState] = [
            card(BudgetFixtures.budget(total: "10", spent: "10")),
            card(BudgetFixtures.budget(total: "0", spent: "0")),
            card(BudgetFixtures.statsBudget(total: "10", spent: "9.99")),
            card(BudgetFixtures.statsBudget(total: "0", spent: "0"))
        ]
        for state in notOver {
            #expect(!state.isOver)
            #expect(!state.statusText.contains("Over by"))
            #expect(state.statusText.hasSuffix("remaining"))
        }
    }
}
