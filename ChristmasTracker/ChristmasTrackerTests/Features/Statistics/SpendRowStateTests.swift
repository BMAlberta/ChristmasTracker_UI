//
//  SpendRowStateTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: SpendRowState, built through StatsScreenState.make.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("SpendRowState")
struct SpendRowStateTests {

    private func rows(_ spend: [RecipientSpend]) -> [SpendRowState] {
        let stats = BudgetFixtures.statsYear(totalSpent: "100", itemsPurchased: 9, purchaseCount: 4, spend: spend)
        return StatsScreenState.make(
            year: 2026, stats: stats, budget: nil, currencyCode: "USD", locale: BudgetFixtures.enUS
        ).spendRows
    }

    @Test func rowCarriesIdNameAndSpentText() throws {
        let row = try #require(rows([BudgetFixtures.spend(id: "r1", name: "Tommy", spent: "59.99", items: 4)]).first)
        #expect(row.id == "r1")
        #expect(row.name == "Tommy")
        #expect(row.spentText == "$59.99")
    }

    @Test(arguments: [(1, "1 item"), (2, "2 items"), (4, "4 items"), (0, "0 items"), (12, "12 items")])
    func itemsTextIsSingularOnlyForOne(_ count: Int, _ expected: String) throws {
        let row = try #require(rows([BudgetFixtures.spend(id: "r1", name: "Tommy", spent: "5", items: count)]).first)
        #expect(row.itemsText == expected)
    }

    @Test func accessibilityLabelNamesThePersonAndTheAmount() throws {
        let row = try #require(rows([BudgetFixtures.spend(id: "r1", name: "Tommy", spent: "59.99", items: 4)]).first)
        #expect(row.accessibilityLabel.contains("Tommy"))
        #expect(row.accessibilityLabel.contains("$59.99"))
    }

    @Test func rowsKeepTheGivenOrder() {
        let result = rows([
            BudgetFixtures.spend(id: "b", name: "Zed", spent: "1", items: 1),
            BudgetFixtures.spend(id: "a", name: "Amy", spent: "9", items: 1)
        ])
        #expect(result.map(\.id) == ["b", "a"])
    }

    @Test func noSpendGivesNoRows() {
        #expect(rows([]).isEmpty)
    }
}
