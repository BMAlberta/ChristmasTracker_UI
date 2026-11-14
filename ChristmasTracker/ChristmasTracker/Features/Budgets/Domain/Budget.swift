//
//  Budget.swift
//  ChristmasTracker
//
//  I5a Story A: domain types for budgets. Money is Decimal end to end.
//

import Foundation

nonisolated struct RecipientBudget: Identifiable, Equatable, Sendable {
    let id: String
    let recipientId: String
    let recipientName: String
    let maxSpend: Decimal
    let spent: Decimal
    let remaining: Decimal
    let overage: Decimal
    let isOverBudget: Bool
}

nonisolated struct Budget: Identifiable, Equatable, Sendable {
    let id: String
    let year: Int
    let totalBudget: Decimal
    let totalSpent: Decimal
    let remaining: Decimal
    let isOverBudget: Bool
    let recipients: [RecipientBudget]
    let createdAt: Date
    let updatedAt: Date
}

nonisolated struct BudgetLimit: Equatable, Sendable {
    let recipientId: String
    let maxSpend: Decimal
}

nonisolated struct CreateBudgetRequest: Equatable, Sendable {
    let year: Int
    let totalBudget: Decimal
    let recipients: [BudgetLimit]
}

nonisolated struct UpdateBudgetRequest: Equatable, Sendable {
    let year: Int
    let totalBudget: Decimal?
    let recipients: [BudgetLimit]?
}

nonisolated struct DuplicateBudgetRequest: Equatable, Sendable {
    let fromYear: Int
    let toYear: Int
}
