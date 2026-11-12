//
//  PurchaseOutcome.swift
//  ChristmasTracker
//
//  The two successful answers of the create-purchase call.
//

import Foundation

nonisolated enum PurchaseOutcome: Equatable, Sendable {
    case created(RecordedPurchase)
    /// `warnings` is never empty and `token` is never empty.
    case confirmationRequired(warnings: [BudgetWarning], token: String)
}
