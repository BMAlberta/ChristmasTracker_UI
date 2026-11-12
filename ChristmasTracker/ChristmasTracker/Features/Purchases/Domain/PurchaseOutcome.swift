//
//  PurchaseOutcome.swift
//  ChristmasTracker
//
//  The two successful answers of the create-purchase call.
//

import Foundation

/// What a type that holds a confirmation token prints in the token's place (descriptions, debug
/// descriptions and Mirror children). The real token is never rendered.
nonisolated enum RedactedToken {
    static let placeholder = "<redacted token>"
}

nonisolated enum PurchaseOutcome: Equatable, Sendable {
    case created(RecordedPurchase)
    /// `warnings` is never empty and `token` is never empty.
    case confirmationRequired(warnings: [BudgetWarning], token: String)
}

// The confirmation token never appears in a description, a debug description or a Mirror dump.
nonisolated extension PurchaseOutcome: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        switch self {
        case .created:
            return "PurchaseOutcome.created"
        case .confirmationRequired(let warnings, _):
            return "PurchaseOutcome.confirmationRequired(warnings: \(warnings.count), token: \(RedactedToken.placeholder))"
        }
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        switch self {
        case .created(let purchase):
            return Mirror(self, children: ["created": purchase], displayStyle: .enum)
        case .confirmationRequired(let warnings, _):
            return Mirror(
                self,
                children: ["confirmationRequired": warnings, "token": RedactedToken.placeholder],
                displayStyle: .enum
            )
        }
    }
}
