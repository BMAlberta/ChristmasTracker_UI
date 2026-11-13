//
//  BudgetFixtures.swift
//  ChristmasTrackerTests
//
//  I5a Story A: shared fake-data fixtures for the budget and statistics pure-rule tests.
//  All names and ids are fake. Money is Decimal built from text, never from a Double.
//

import Foundation
@testable import ChristmasTracker

nonisolated enum BudgetFixtures {

    // MARK: - Locales

    static let enUS = Locale(identifier: "en_US")
    static let deDE = Locale(identifier: "de_DE")

    // MARK: - Decimal

    /// Exact Decimal from a plain "1234.50" style string.
    static func dec(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal.nan
    }

    static let fixedDate = Date(timeIntervalSince1970: 1_767_600_000)

    // MARK: - Drafts

    /// A draft whose recipients are (id, limitText) pairs; the name is derived from the id.
    static func draft(
        year: Int = 2026,
        total: String,
        limits: [(id: String, limit: String)] = []
    ) -> BudgetDraft {
        BudgetDraft(
            year: year,
            totalText: total,
            recipients: limits.map {
                BudgetRecipientDraft(recipientId: $0.id, name: "Person \($0.id)", limitText: $0.limit)
            }
        )
    }

    // MARK: - Domain budgets

    /// A consistent recipient row: remaining and overage follow from the amounts.
    static func recipientBudget(
        id: String,
        name: String,
        max: String,
        spent: String,
        isOverBudget: Bool? = nil
    ) -> RecipientBudget {
        let maxValue = dec(max)
        let spentValue = dec(spent)
        let over = spentValue > maxValue
        return RecipientBudget(
            id: "rb-\(id)",
            recipientId: id,
            recipientName: name,
            maxSpend: maxValue,
            spent: spentValue,
            remaining: maxValue - spentValue,
            overage: over ? spentValue - maxValue : 0,
            isOverBudget: isOverBudget ?? over
        )
    }

    /// A consistent budget unless `isOverBudget` is given.
    static func budget(
        year: Int = 2026,
        total: String,
        spent: String = "0",
        recipients: [RecipientBudget] = [],
        isOverBudget: Bool? = nil
    ) -> Budget {
        let totalValue = dec(total)
        let spentValue = dec(spent)
        return Budget(
            id: "budget-\(year)",
            year: year,
            totalBudget: totalValue,
            totalSpent: spentValue,
            remaining: totalValue - spentValue,
            isOverBudget: isOverBudget ?? (spentValue > totalValue),
            recipients: recipients,
            createdAt: fixedDate,
            updatedAt: fixedDate
        )
    }

    /// Original budget for the diff tests: total 500, r1 limit 200, r2 limit 250.
    static func originalBudget() -> Budget {
        budget(
            year: 2026,
            total: "500.00",
            spent: "100.00",
            recipients: [
                recipientBudget(id: "r1", name: "Tommy", max: "200.00", spent: "50.00"),
                recipientBudget(id: "r2", name: "Mike", max: "250.00", spent: "50.00")
            ]
        )
    }

    /// A draft equal to `originalBudget()`.
    static func matchingDraft() -> BudgetDraft {
        draft(year: 2026, total: "500.00", limits: [(id: "r1", limit: "200.00"), (id: "r2", limit: "250.00")])
    }

    // MARK: - Stats

    static func statsRecipientBudget(
        id: String,
        name: String,
        budget: String,
        spent: String
    ) -> StatsRecipientBudget {
        StatsRecipientBudget(
            recipientId: id,
            displayName: name,
            budget: dec(budget),
            spent: dec(spent),
            remaining: dec(budget) - dec(spent)
        )
    }

    static func statsBudget(
        total: String,
        spent: String,
        recipients: [StatsRecipientBudget] = []
    ) -> StatsBudget {
        StatsBudget(
            totalBudget: dec(total),
            totalSpent: dec(spent),
            remaining: dec(total) - dec(spent),
            recipients: recipients
        )
    }

    static func spend(id: String, name: String, spent: String, items: Int) -> RecipientSpend {
        RecipientSpend(recipientId: id, displayName: name, spent: dec(spent), itemsPurchased: items)
    }

    static func statsYear(
        year: Int = 2026,
        totalSpent: String = "0",
        itemsPurchased: Int = 0,
        purchaseCount: Int = 0,
        spend: [RecipientSpend] = [],
        budget: StatsBudget? = nil,
        availableYears: [Int] = []
    ) -> StatsYear {
        StatsYear(
            year: year,
            totalSpent: dec(totalSpent),
            itemsPurchased: itemsPurchased,
            purchaseCount: purchaseCount,
            spendByRecipient: spend,
            budget: budget,
            availableYears: availableYears
        )
    }

    // MARK: - Lists

    /// A list whose recipient is (id, name), with the given canPurchase and isRecipient flags.
    static func list(
        id: String,
        recipientId: String,
        recipientName: String,
        canPurchase: Bool,
        isRecipient: Bool = false
    ) -> GiftList {
        ListFixtures.giftList(
            id: id,
            flags: ListFixtures.Flags(isRecipient: isRecipient, canPurchase: canPurchase),
            recipient: ListPerson(id: recipientId, displayName: recipientName)
        )
    }
}
