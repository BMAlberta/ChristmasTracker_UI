//
//  BudgetWarning.swift
//  ChristmasTracker
//
//  One budget overage the server reports before it records a purchase. Money is Decimal.
//

import Foundation

nonisolated enum BudgetWarningLevel: Equatable, Sendable {
    case recipient
    case total
}

nonisolated struct BudgetWarning: Equatable, Sendable {
    let level: BudgetWarningLevel
    /// From the warning details; nil for level total.
    let recipientName: String?
    let budgetLimit: Decimal
    let currentSpent: Decimal
    let purchaseAmount: Decimal
    let overage: Decimal
}
