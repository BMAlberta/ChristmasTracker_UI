//
//  StatsYearMappingTests.swift
//  ChristmasTrackerTests
//
//  I5a Story A: mapStatsYear from literal generated payloads (fake data only).
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("mapStatsYear")
struct StatsYearMappingTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    private func spendRow(
        id: String = "r1",
        name: String = "Tommy",
        spent: Double = 79.99,
        items: Int = 2
    ) -> Components.Schemas.SpendByRecipient {
        Components.Schemas.SpendByRecipient(recipientId: id, displayName: name, spent: spent, itemsPurchased: items)
    }

    private func recipientStat(
        budget: Double = 200,
        spent: Double = 79.99,
        remaining: Double = 120.01
    ) -> Components.Schemas.BudgetRecipientStat {
        Components.Schemas.BudgetRecipientStat(
            recipientId: "r1", displayName: "Tommy", budget: budget, spent: spent, remaining: remaining
        )
    }

    private func year(
        totalSpent: Double = 79.99,
        spend: [Components.Schemas.SpendByRecipient] = [],
        budget: Components.Schemas.BudgetStats? = nil,
        availableYears: [Int] = [2025, 2026]
    ) -> Components.Schemas.StatsResponse {
        .year(Components.Schemas.StatsYearResponse(
            scope: .year,
            year: 2026,
            totalSpent: totalSpent,
            itemsPurchased: 5,
            purchaseCount: 3,
            spendByRecipient: spend,
            budget: budget,
            availableYears: availableYears
        ))
    }

    @Test func mapsAYearWithoutABudget() throws {
        let stats = try mapStatsYear(year(spend: [spendRow()]))
        #expect(stats.year == 2026)
        #expect(stats.totalSpent == dec("79.99"))
        #expect(stats.itemsPurchased == 5)
        #expect(stats.purchaseCount == 3)
        #expect(stats.budget == nil)
        #expect(stats.availableYears == [2025, 2026])
        #expect(stats.spendByRecipient == [
            RecipientSpend(recipientId: "r1", displayName: "Tommy", spent: dec("79.99"), itemsPurchased: 2)
        ])
    }

    @Test func mapsAYearWithABudgetAndRecipients() throws {
        let budget = Components.Schemas.BudgetStats(
            totalBudget: 500, totalSpent: 79.99, remaining: 420.01, recipients: [recipientStat()]
        )
        let stats = try mapStatsYear(year(spend: [spendRow()], budget: budget))
        let mapped = try #require(stats.budget)
        #expect(mapped.totalBudget == dec("500"))
        #expect(mapped.totalSpent == dec("79.99"))
        #expect(mapped.remaining == dec("420.01"))
        #expect(mapped.recipients == [
            StatsRecipientBudget(
                recipientId: "r1", displayName: "Tommy",
                budget: dec("200"), spent: dec("79.99"), remaining: dec("120.01")
            )
        ])
    }

    @Test func mapsAYearWithABudgetWithoutRecipients() throws {
        let budget = Components.Schemas.BudgetStats(totalBudget: 300, totalSpent: 0, remaining: 300, recipients: [])
        let stats = try mapStatsYear(year(totalSpent: 0, budget: budget))
        let mapped = try #require(stats.budget)
        #expect(mapped.recipients.isEmpty)
        #expect(mapped.totalBudget == dec("300"))
        #expect(stats.spendByRecipient.isEmpty)
    }

    @Test func spendRowsKeepTheServerOrder() throws {
        let stats = try mapStatsYear(year(spend: [
            spendRow(id: "r2", name: "Mike", spent: 10, items: 1),
            spendRow(id: "r1", name: "Tommy", spent: 20, items: 3)
        ]))
        #expect(stats.spendByRecipient.map(\.recipientId) == ["r2", "r1"])
        #expect(stats.spendByRecipient.map(\.itemsPurchased) == [1, 3])
    }

    @Test func moneyIsExactlyDecimal() throws {
        let stats = try mapStatsYear(year(totalSpent: 79.99, spend: [spendRow(spent: 0.3)]))
        #expect(stats.totalSpent == dec("79.99"))
        #expect(stats.spendByRecipient.first?.spent == dec("0.30"))
    }

    @Test func theAllScopeThrowsInvalidResponse() {
        let all = Components.Schemas.StatsResponse.all(Components.Schemas.StatsAllResponse(
            scope: .all, totalSpent: 10, itemsPurchased: 1, purchaseCount: 1, byYear: [], availableYears: [2026]
        ))
        #expect(throws: BudgetError.invalidResponse) { try mapStatsYear(all) }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func nonFiniteTotalSpentThrowsInvalidResponse(_ value: Double) {
        #expect(throws: BudgetError.invalidResponse) { try mapStatsYear(year(totalSpent: value)) }
    }

    @Test func nonFiniteSpendRowThrowsInvalidResponse() {
        #expect(throws: BudgetError.invalidResponse) {
            try mapStatsYear(year(spend: [spendRow(spent: .infinity)]))
        }
    }

    @Test func nonFiniteBudgetMoneyThrowsInvalidResponse() {
        let badTotal = Components.Schemas.BudgetStats(totalBudget: .nan, totalSpent: 0, remaining: 0, recipients: [])
        let badSpent = Components.Schemas.BudgetStats(totalBudget: 1, totalSpent: .nan, remaining: 0, recipients: [])
        let badRemaining = Components.Schemas.BudgetStats(
            totalBudget: 1, totalSpent: 0, remaining: .infinity, recipients: []
        )
        let badRecipient = Components.Schemas.BudgetStats(
            totalBudget: 1, totalSpent: 0, remaining: 1, recipients: [recipientStat(budget: .nan)]
        )
        for budget in [badTotal, badSpent, badRemaining, badRecipient] {
            #expect(throws: BudgetError.invalidResponse) { try mapStatsYear(year(budget: budget)) }
        }
    }
}
