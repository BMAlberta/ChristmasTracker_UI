//
//  StatsScreenStateTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: StatsScreenState kinds, summary, budget card choice, empty strings.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenState")
struct StatsScreenStateTests {

    private let locale = BudgetFixtures.enUS

    private func make(year: Int = 2026, stats: StatsYear, budget: Budget? = nil) -> StatsScreenState {
        StatsScreenState.make(year: year, stats: stats, budget: budget, currencyCode: "USD", locale: locale)
    }

    private let spendRows = [
        BudgetFixtures.spend(id: "r2", name: "Mike", spent: "20.00", items: 1),
        BudgetFixtures.spend(id: "r1", name: "Tommy", spent: "59.99", items: 4)
    ]

    // MARK: - Nothing

    @Test func noPurchasesAndNoBudgetIsNothing() {
        let state = make(stats: BudgetFixtures.statsYear())
        #expect(state.kind == .nothing)
        #expect(state.year == 2026)
        #expect(state.summary == nil)
        #expect(state.emptyMessage == "Nothing spent in 2026 yet. Create a budget to plan your spending.")
        #expect(state.noBudgetTitle == nil)
        #expect(state.budgetCard == nil)
        #expect(state.spendRows.isEmpty)
        #expect(state.showsCreateBudget)
    }

    @Test func nothingMessageUsesTheRequestedYear() {
        let state = make(year: 2031, stats: BudgetFixtures.statsYear(year: 2031))
        #expect(state.emptyMessage == "Nothing spent in 2031 yet. Create a budget to plan your spending.")
    }

    // MARK: - Purchases without a budget

    @Test func purchasesWithoutABudget() throws {
        let stats = BudgetFixtures.statsYear(
            totalSpent: "79.99", itemsPurchased: 5, purchaseCount: 3, spend: spendRows
        )
        let state = make(stats: stats)
        #expect(state.kind == .purchasesWithoutBudget)
        let summary = try #require(state.summary)
        #expect(summary.totalSpentText == "$79.99")
        #expect(summary.itemsPurchasedText == "5")
        #expect(summary.purchaseCountText == "3")
        #expect(state.noBudgetTitle == "No budget for 2026")
        #expect(state.emptyMessage == nil)
        #expect(state.budgetCard == nil)
        #expect(state.showsCreateBudget)
    }

    @Test func noBudgetTitleUsesTheRequestedYear() {
        let state = make(year: 2024, stats: BudgetFixtures.statsYear(year: 2024, totalSpent: "5", purchaseCount: 1))
        #expect(state.noBudgetTitle == "No budget for 2024")
    }

    // MARK: - Budgeted

    @Test func budgetedFromStatsBudget() throws {
        let stats = BudgetFixtures.statsYear(
            totalSpent: "79.99", itemsPurchased: 5, purchaseCount: 3, spend: spendRows,
            budget: BudgetFixtures.statsBudget(total: "500", spent: "79.99")
        )
        let state = make(stats: stats)
        #expect(state.kind == .budgeted)
        #expect(state.summary != nil)
        #expect(state.emptyMessage == nil)
        #expect(state.noBudgetTitle == nil)
        #expect(!state.showsCreateBudget)
        let card = try #require(state.budgetCard)
        #expect(card.year == 2026)
        #expect(card.totalText == "$500.00")
        #expect(card.spentText == "$79.99")
    }

    @Test func budgetedFromTheBudgetParameterWhenStatsHasNone() throws {
        let stats = BudgetFixtures.statsYear(totalSpent: "10", purchaseCount: 1)
        let state = make(stats: stats, budget: BudgetFixtures.budget(total: "250", spent: "10"))
        #expect(state.kind == .budgeted)
        let card = try #require(state.budgetCard)
        #expect(card.totalText == "$250.00")
        #expect(!state.showsCreateBudget)
    }

    @Test func theBudgetParameterWinsOverStatsBudget() throws {
        let stats = BudgetFixtures.statsYear(
            totalSpent: "10", purchaseCount: 1,
            budget: BudgetFixtures.statsBudget(total: "100", spent: "10")
        )
        let state = make(stats: stats, budget: BudgetFixtures.budget(total: "999", spent: "10"))
        let card = try #require(state.budgetCard)
        #expect(card.totalText == "$999.00")
    }

    @Test func aBudgetWithNoPurchasesIsStillBudgetedWithASummary() throws {
        let state = make(stats: BudgetFixtures.statsYear(), budget: BudgetFixtures.budget(total: "300"))
        #expect(state.kind == .budgeted)
        let summary = try #require(state.summary)
        #expect(summary.totalSpentText == "$0.00")
        #expect(summary.itemsPurchasedText == "0")
        #expect(summary.purchaseCountText == "0")
        #expect(state.budgetCard != nil)
        #expect(state.emptyMessage == nil)
    }

    // MARK: - Budget card through the screen state

    @Test func budgetUnderAtAndOverThroughTheScreen() throws {
        let under = make(stats: BudgetFixtures.statsYear(totalSpent: "1", purchaseCount: 1), budget: BudgetFixtures.budget(total: "100", spent: "1"))
        let at = make(stats: BudgetFixtures.statsYear(totalSpent: "100", purchaseCount: 1), budget: BudgetFixtures.budget(total: "100", spent: "100"))
        let over = make(stats: BudgetFixtures.statsYear(totalSpent: "130", purchaseCount: 1), budget: BudgetFixtures.budget(total: "100", spent: "130"))
        #expect(try #require(under.budgetCard).isOver == false)
        #expect(try #require(at.budgetCard).isOver == false)
        #expect(try #require(at.budgetCard).statusText == "$0.00 remaining")
        let overCard = try #require(over.budgetCard)
        #expect(overCard.isOver)
        #expect(overCard.statusText == "Over by $30.00")
        #expect(overCard.progress == 1)
    }

    @Test func overFromStatsBudgetHasOverByText() throws {
        let stats = BudgetFixtures.statsYear(
            totalSpent: "130", purchaseCount: 2,
            budget: BudgetFixtures.statsBudget(total: "100", spent: "130")
        )
        let card = try #require(make(stats: stats).budgetCard)
        #expect(card.isOver)
        #expect(card.statusText == "Over by $30.00")
    }

    @Test func zeroTotalBudgetThroughTheScreen() throws {
        let clean = make(stats: BudgetFixtures.statsYear(), budget: BudgetFixtures.budget(total: "0", spent: "0"))
        let spent = make(
            stats: BudgetFixtures.statsYear(totalSpent: "4", purchaseCount: 1),
            budget: BudgetFixtures.budget(total: "0", spent: "4")
        )
        #expect(try #require(clean.budgetCard).progress == 0)
        #expect(try #require(clean.budgetCard).isOver == false)
        #expect(try #require(spent.budgetCard).progress == 1)
        #expect(try #require(spent.budgetCard).statusText == "Over by $4.00")
    }

    @Test func personOverTheirLimitShowsOverByInTheCardRow() throws {
        let stats = BudgetFixtures.statsYear(
            totalSpent: "619.98", purchaseCount: 3,
            budget: BudgetFixtures.statsBudget(
                total: "1000", spent: "619.98",
                recipients: [BudgetFixtures.statsRecipientBudget(id: "r1", name: "Tommy", budget: "600", spent: "619.98")]
            )
        )
        let card = try #require(make(stats: stats).budgetCard)
        let row = try #require(card.rows.first)
        #expect(!card.isOver)
        #expect(row.isOver)
        #expect(row.statusText == "Over by $19.98")
    }

    // MARK: - Spend rows

    @Test(arguments: [0, 1, 2])
    func spendRowsKeepTheGivenOrderForEveryKind(_ kindIndex: Int) {
        let stats: StatsYear
        let budget: Budget?
        switch kindIndex {
        case 0:
            stats = BudgetFixtures.statsYear(spend: spendRows)
            budget = nil
        case 1:
            stats = BudgetFixtures.statsYear(totalSpent: "79.99", purchaseCount: 2, spend: spendRows)
            budget = nil
        default:
            stats = BudgetFixtures.statsYear(totalSpent: "79.99", purchaseCount: 2, spend: spendRows)
            budget = BudgetFixtures.budget(total: "100", spent: "79.99")
        }
        let state = make(stats: stats, budget: budget)
        #expect(state.spendRows.map(\.id) == ["r2", "r1"])
        #expect(state.spendRows.map(\.name) == ["Mike", "Tommy"])
    }

    @Test func kindShowsCreateBudgetOnlyWhenNotBudgeted() {
        #expect(make(stats: BudgetFixtures.statsYear()).showsCreateBudget)
        #expect(make(stats: BudgetFixtures.statsYear(totalSpent: "1", purchaseCount: 1)).showsCreateBudget)
        #expect(!make(stats: BudgetFixtures.statsYear(), budget: BudgetFixtures.budget(total: "1")).showsCreateBudget)
    }
}
