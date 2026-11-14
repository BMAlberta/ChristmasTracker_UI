//
//  StatsYear.swift
//  ChristmasTracker
//
//  I5a Story A: domain types for the year statistics. Money is Decimal.
//

import Foundation

nonisolated struct RecipientSpend: Identifiable, Equatable, Sendable {
    let recipientId: String
    let displayName: String
    let spent: Decimal
    let itemsPurchased: Int

    var id: String { recipientId }
}

nonisolated struct StatsRecipientBudget: Equatable, Sendable {
    let recipientId: String
    let displayName: String
    let budget: Decimal
    let spent: Decimal
    let remaining: Decimal
}

nonisolated struct StatsBudget: Equatable, Sendable {
    let totalBudget: Decimal
    let totalSpent: Decimal
    let remaining: Decimal
    let recipients: [StatsRecipientBudget]
}

nonisolated struct StatsYear: Equatable, Sendable {
    let year: Int
    let totalSpent: Decimal
    let itemsPurchased: Int
    let purchaseCount: Int
    let spendByRecipient: [RecipientSpend]
    let budget: StatsBudget?
    let availableYears: [Int]
}
