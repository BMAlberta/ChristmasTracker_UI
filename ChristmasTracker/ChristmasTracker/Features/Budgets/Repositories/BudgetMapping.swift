//
//  BudgetMapping.swift
//  ChristmasTracker
//
//  I5a Story A: pure mapping from generated payloads to domain types at the repository boundary.
//  Money goes through the package helper; a non-finite value is an invalid response.
//

import Foundation
import TrackerAPI

nonisolated private func budgetMoney(_ value: Double) throws -> Decimal {
    guard let decimal = doubleToDecimal(value) else { throw BudgetError.invalidResponse }
    return decimal
}

nonisolated func mapBudget(_ payload: Components.Schemas.Budget) throws -> Budget {
    let recipients = try payload.recipients.map { recipient in
        RecipientBudget(
            id: recipient.id,
            recipientId: recipient.recipientId,
            recipientName: recipient.recipientName,
            maxSpend: try budgetMoney(recipient.maxSpend),
            spent: try budgetMoney(recipient.spent),
            remaining: try budgetMoney(recipient.remaining),
            overage: try budgetMoney(recipient.overage),
            isOverBudget: recipient.isOverBudget
        )
    }
    return Budget(
        id: payload.id,
        year: payload.year,
        totalBudget: try budgetMoney(payload.totalBudget),
        totalSpent: try budgetMoney(payload.totalSpent),
        remaining: try budgetMoney(payload.remaining),
        isOverBudget: payload.isOverBudget,
        recipients: recipients,
        createdAt: payload.createdAt,
        updatedAt: payload.updatedAt
    )
}

nonisolated func mapStatsYear(_ payload: Components.Schemas.StatsResponse) throws -> StatsYear {
    switch payload {
    case .all:
        throw BudgetError.invalidResponse
    case .year(let year):
        let spend = try year.spendByRecipient.map { row in
            RecipientSpend(
                recipientId: row.recipientId,
                displayName: row.displayName,
                spent: try budgetMoney(row.spent),
                itemsPurchased: row.itemsPurchased
            )
        }
        return StatsYear(
            year: year.year,
            totalSpent: try budgetMoney(year.totalSpent),
            itemsPurchased: year.itemsPurchased,
            purchaseCount: year.purchaseCount,
            spendByRecipient: spend,
            budget: try year.budget.map(mapStatsBudget),
            availableYears: year.availableYears
        )
    }
}

nonisolated private func mapStatsBudget(_ payload: Components.Schemas.BudgetStats) throws -> StatsBudget {
    let recipients = try payload.recipients.map { row in
        StatsRecipientBudget(
            recipientId: row.recipientId,
            displayName: row.displayName,
            budget: try budgetMoney(row.budget),
            spent: try budgetMoney(row.spent),
            remaining: try budgetMoney(row.remaining)
        )
    }
    return StatsBudget(
        totalBudget: try budgetMoney(payload.totalBudget),
        totalSpent: try budgetMoney(payload.totalSpent),
        remaining: try budgetMoney(payload.remaining),
        recipients: recipients
    )
}
