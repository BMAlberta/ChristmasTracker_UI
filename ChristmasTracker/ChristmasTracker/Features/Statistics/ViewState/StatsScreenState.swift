//
//  StatsScreenState.swift
//  ChristmasTracker
//
//  I5a Story A: pure presentation state for the Statistics screen.
//

import Foundation

nonisolated struct StatsSummaryState: Equatable, Sendable {
    let totalSpentText: String
    let itemsPurchasedText: String
    let purchaseCountText: String
}

nonisolated struct SpendRowState: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let spentText: String
    let itemsText: String
    let accessibilityLabel: String
}

nonisolated struct StatsScreenState: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        case nothing
        case purchasesWithoutBudget
        case budgeted
    }

    let year: Int
    let kind: Kind
    let summary: StatsSummaryState?
    let emptyMessage: String?
    let noBudgetTitle: String?
    let budgetCard: BudgetCardState?
    let spendRows: [SpendRowState]

    var showsCreateBudget: Bool { kind != .budgeted }

    static func make(
        year: Int,
        stats: StatsYear,
        budget: Budget?,
        currencyCode: String,
        locale: Locale
    ) -> StatsScreenState {
        let rows = stats.spendByRecipient.map { spend -> SpendRowState in
            let spentText = MoneyText.currency(spend.spent, code: currencyCode, locale: locale)
            let itemsText = spend.itemsPurchased == 1 ? "1 item" : "\(spend.itemsPurchased) items"
            return SpendRowState(
                id: spend.recipientId,
                name: spend.displayName,
                spentText: spentText,
                itemsText: itemsText,
                accessibilityLabel: "\(spend.displayName), \(spentText), \(itemsText)"
            )
        }

        let kind: Kind
        let card: BudgetCardState?
        if let budget {
            kind = .budgeted
            card = BudgetCardState.make(from: budget, currencyCode: currencyCode, locale: locale)
        } else if let statsBudget = stats.budget {
            kind = .budgeted
            card = BudgetCardState.make(from: statsBudget, year: year, currencyCode: currencyCode, locale: locale)
        } else {
            kind = stats.purchaseCount > 0 ? .purchasesWithoutBudget : .nothing
            card = nil
        }

        let summary: StatsSummaryState? = kind == .nothing ? nil : StatsSummaryState(
            totalSpentText: MoneyText.currency(stats.totalSpent, code: currencyCode, locale: locale),
            itemsPurchasedText: "\(stats.itemsPurchased)",
            purchaseCountText: "\(stats.purchaseCount)"
        )

        return StatsScreenState(
            year: year,
            kind: kind,
            summary: summary,
            emptyMessage: kind == .nothing
                ? "Nothing spent in \(year) yet. Create a budget to plan your spending." : nil,
            noBudgetTitle: kind == .purchasesWithoutBudget ? "No budget for \(year)" : nil,
            budgetCard: card,
            spendRows: rows
        )
    }
}
