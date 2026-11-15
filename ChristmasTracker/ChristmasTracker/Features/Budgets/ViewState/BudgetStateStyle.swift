//
//  BudgetStateStyle.swift
//  ChristmasTracker
//
//  TH1-T3: the pure budget level rule and its style. Over when spent > limit; near when spent is at
//  least `nearLimitThreshold` of a positive limit and not over; otherwise under. All in Decimal.
//

import Foundation

nonisolated enum BudgetLevel: CaseIterable, Equatable, Hashable, Sendable {
    case under
    case nearLimit
    case over
}

nonisolated struct BudgetStyle: Equatable, Sendable {
    let level: BudgetLevel
    let token: ThemeToken
    let label: String
    let accessibilityLabel: String
}

nonisolated enum BudgetStateStyle {

    /// The share of a limit at which spending counts as near the limit (90 percent).
    static let nearLimitThreshold: Decimal = 0.9

    static func level(spent: Decimal, limit: Decimal) -> BudgetLevel {
        if spent > limit { return .over }
        if limit <= 0 { return .under }
        if spent >= limit * nearLimitThreshold { return .nearLimit }
        return .under
    }

    static func style(for level: BudgetLevel) -> BudgetStyle {
        let token: ThemeToken
        let label: String
        switch level {
        case .under: (token, label) = (.budgetSafe, "Under budget")
        case .nearLimit: (token, label) = (.budgetWarningBar, "Near limit")
        case .over: (token, label) = (.budgetOver, "Over budget")
        }
        return BudgetStyle(level: level, token: token, label: label, accessibilityLabel: "Budget: \(label)")
    }

    static func style(spent: Decimal, limit: Decimal) -> BudgetStyle {
        style(for: level(spent: spent, limit: limit))
    }
}
