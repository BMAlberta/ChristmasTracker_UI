//
//  BudgetCardStateLevelTests.swift
//  ChristmasTrackerTests
//
//  TH1-T3: BudgetCardState and BudgetPersonRowState carry a BudgetLevel and the near-limit wording.
//  Over stays "Over by <money>", under stays "<money> remaining", near is
//  "Near limit. <money> remaining". isOver equals (level == .over).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetCardState level")
struct BudgetCardStateLevelTests {

    private let locale = BudgetFixtures.enUS

    private func card(_ budget: Budget) -> BudgetCardState {
        BudgetCardState.make(from: budget, currencyCode: "USD", locale: locale)
    }

    private func card(_ budget: StatsBudget) -> BudgetCardState {
        BudgetCardState.make(from: budget, year: 2026, currencyCode: "USD", locale: locale)
    }

    private func personRow(max: String, spent: String) throws -> BudgetPersonRowState {
        let budget = BudgetFixtures.budget(
            total: "1000", spent: spent,
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: max, spent: spent)]
        )
        return try #require(card(budget).rows.first)
    }

    // MARK: - Card

    @Test func cardUnderHasUnderLevelAndRemainingWording() {
        let state = card(BudgetFixtures.budget(total: "100", spent: "50"))
        #expect(state.level == .under)
        #expect(state.statusText == "$50.00 remaining")
        #expect(!state.isOver)
    }

    @Test func cardJustUnderNinetyPercentIsUnder() {
        let state = card(BudgetFixtures.budget(total: "100", spent: "89.99"))
        #expect(state.level == .under)
        #expect(state.statusText == "$10.01 remaining")
    }

    @Test func cardAtNinetyPercentIsNearWithNearWording() {
        let state = card(BudgetFixtures.budget(total: "100", spent: "90"))
        #expect(state.level == .nearLimit)
        #expect(state.statusText == "Near limit. $10.00 remaining")
        #expect(!state.isOver)
    }

    @Test func cardBetweenNinetyAndLimitIsNear() {
        let state = card(BudgetFixtures.budget(total: "100", spent: "95"))
        #expect(state.level == .nearLimit)
        #expect(state.statusText == "Near limit. $5.00 remaining")
    }

    @Test func cardExactlyAtLimitIsNearNotOver() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "500"))
        #expect(state.level == .nearLimit)
        #expect(state.statusText == "Near limit. $0.00 remaining")
        #expect(!state.isOver)
    }

    @Test func cardOneCentOverIsOverWithOverWording() {
        let state = card(BudgetFixtures.budget(total: "500", spent: "500.01"))
        #expect(state.level == .over)
        #expect(state.statusText == "Over by $0.01")
        #expect(state.isOver)
    }

    @Test func cardOverByNineteenNinetyEight() {
        let state = card(BudgetFixtures.statsBudget(total: "600", spent: "619.98"))
        #expect(state.level == .over)
        #expect(state.statusText == "Over by $19.98")
    }

    @Test func cardZeroTotalNothingSpentIsUnder() {
        let state = card(BudgetFixtures.budget(total: "0", spent: "0"))
        #expect(state.level == .under)
        #expect(state.statusText == "$0.00 remaining")
    }

    @Test func cardZeroTotalWithSpendingIsOver() {
        let state = card(BudgetFixtures.budget(total: "0", spent: "12.34"))
        #expect(state.level == .over)
        #expect(state.statusText == "Over by $12.34")
    }

    @Test func statsCardLevelsMatchTheBudgetForm() {
        #expect(card(BudgetFixtures.statsBudget(total: "100", spent: "50")).level == .under)
        #expect(card(BudgetFixtures.statsBudget(total: "100", spent: "90")).level == .nearLimit)
        #expect(card(BudgetFixtures.statsBudget(total: "100", spent: "100")).level == .nearLimit)
        #expect(card(BudgetFixtures.statsBudget(total: "100", spent: "100.01")).level == .over)
    }

    @Test func cardLevelIgnoresTheServerOverFlag() {
        let flaggedWrongly = card(BudgetFixtures.budget(total: "100", spent: "150", isOverBudget: false))
        #expect(flaggedWrongly.level == .over)
        let flaggedOverButUnder = card(BudgetFixtures.budget(total: "100", spent: "50", isOverBudget: true))
        #expect(flaggedOverButUnder.level == .under)
    }

    @Test func cardIsOverEqualsLevelIsOver() {
        let cases: [(String, String)] = [
            ("100", "0"), ("100", "50"), ("100", "89.99"), ("100", "90"), ("100", "100"),
            ("100", "100.01"), ("0", "0"), ("0", "1")
        ]
        for (total, spent) in cases {
            let state = card(BudgetFixtures.budget(total: total, spent: spent))
            #expect(state.isOver == (state.level == .over), "total \(total) spent \(spent)")
        }
    }

    // MARK: - Person rows

    @Test func personRowUnderLimit() throws {
        let row = try personRow(max: "200", spent: "150")
        #expect(row.level == .under)
        #expect(row.statusText == "$50.00 remaining")
        #expect(!row.isOver)
    }

    @Test func personRowNearLimitHasNearWording() throws {
        let row = try personRow(max: "200", spent: "190")
        #expect(row.level == .nearLimit)
        #expect(row.statusText == "Near limit. $10.00 remaining")
        #expect(!row.isOver)
    }

    @Test func personRowExactlyNinetyPercentIsNear() throws {
        let row = try personRow(max: "200", spent: "180")
        #expect(row.level == .nearLimit)
        #expect(row.statusText == "Near limit. $20.00 remaining")
    }

    @Test func personRowJustUnderNinetyPercentIsUnder() throws {
        let row = try personRow(max: "200", spent: "179.99")
        #expect(row.level == .under)
    }

    @Test func personRowExactlyAtLimitIsNearNotOver() throws {
        let row = try personRow(max: "200", spent: "200")
        #expect(row.level == .nearLimit)
        #expect(row.statusText == "Near limit. $0.00 remaining")
        #expect(!row.isOver)
    }

    @Test func personRowOverTheirLimitWhileTheCardIsNot() throws {
        let budget = BudgetFixtures.budget(
            total: "1000", spent: "619.98",
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "600", spent: "619.98")]
        )
        let state = card(budget)
        let row = try #require(state.rows.first)
        #expect(state.level == .under)
        #expect(row.level == .over)
        #expect(row.statusText == "Over by $19.98")
        #expect(row.isOver)
    }

    @Test func personRowLevelUsesPersonSpentAgainstPersonLimitNotTheCardTotals() throws {
        let budget = BudgetFixtures.budget(
            total: "1000", spent: "100",
            recipients: [BudgetFixtures.recipientBudget(id: "r1", name: "Tommy", max: "100", spent: "95")]
        )
        let state = card(budget)
        #expect(state.level == .under)
        #expect(try #require(state.rows.first).level == .nearLimit)
    }

    @Test func statsPersonRowsCarryLevels() throws {
        let stats = BudgetFixtures.statsBudget(
            total: "700", spent: "350",
            recipients: [
                BudgetFixtures.statsRecipientBudget(id: "r1", name: "Tommy", budget: "300", spent: "250"),
                BudgetFixtures.statsRecipientBudget(id: "r2", name: "Mike", budget: "100", spent: "100.01"),
                BudgetFixtures.statsRecipientBudget(id: "r3", name: "Anna", budget: "100", spent: "92")
            ]
        )
        let rows = card(stats).rows
        #expect(rows.map(\.level) == [.under, .over, .nearLimit])
    }

    @Test func personRowAccessibilityLabelIncludesTheStatusText() throws {
        for (max, spent) in [("200", "150"), ("200", "190"), ("200", "200"), ("200", "230")] {
            let row = try personRow(max: max, spent: spent)
            #expect(row.accessibilityLabel.contains(row.statusText), "max \(max) spent \(spent)")
            #expect(row.accessibilityLabel.contains("Tommy"))
        }
    }

    @Test func personRowIsOverEqualsLevelIsOver() throws {
        for spent in ["0", "50", "179.99", "180", "200", "200.01", "500"] {
            let row = try personRow(max: "200", spent: spent)
            #expect(row.isOver == (row.level == .over), "spent \(spent)")
        }
    }

    @Test func nearWordingNeverAppearsOutsideTheNearRange() throws {
        let under = try personRow(max: "200", spent: "10")
        let over = try personRow(max: "200", spent: "300")
        #expect(!under.statusText.contains("Near limit"))
        #expect(!over.statusText.contains("Near limit"))
        #expect(over.statusText.hasPrefix("Over by "))
    }
}
