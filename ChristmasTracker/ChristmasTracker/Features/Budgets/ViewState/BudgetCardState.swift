//
//  BudgetCardState.swift
//  ChristmasTracker
//
//  I5a Story A: presentation state for the budget card and its person rows. Over is decided in
//  Decimal (spent > limit), never from a server flag.
//

import Foundation

nonisolated struct BudgetPersonRowState: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let limitText: String
    let spentText: String
    let statusText: String
    let level: BudgetLevel
    let accessibilityLabel: String

    var isOver: Bool { level == .over }

    fileprivate init(id: String, name: String, limit: Decimal, spent: Decimal, code: String, locale: Locale) {
        let limitText = MoneyText.currency(limit, code: code, locale: locale)
        let spentText = MoneyText.currency(spent, code: code, locale: locale)
        let statusText = BudgetCardState.status(spent: spent, limit: limit, code: code, locale: locale)
        self.id = id
        self.name = name
        self.limitText = limitText
        self.spentText = spentText
        self.statusText = statusText
        self.level = BudgetStateStyle.level(spent: spent, limit: limit)
        self.accessibilityLabel = "\(name), limit \(limitText), spent \(spentText), \(statusText)"
    }
}

nonisolated struct BudgetCardState: Equatable, Sendable {
    let year: Int
    let totalText: String
    let spentText: String
    let statusText: String
    let level: BudgetLevel
    /// 0...1: spent over total computed in Decimal, capped at 1.
    let progress: Double
    let progressAccessibilityLabel: String
    let rows: [BudgetPersonRowState]

    var isOver: Bool { level == .over }

    static func make(from budget: Budget, currencyCode: String, locale: Locale) -> BudgetCardState {
        let rows = budget.recipients.map {
            BudgetPersonRowState(
                id: $0.recipientId, name: $0.recipientName, limit: $0.maxSpend, spent: $0.spent,
                code: currencyCode, locale: locale
            )
        }
        return card(
            year: budget.year, total: budget.totalBudget, spent: budget.totalSpent,
            rows: rows, code: currencyCode, locale: locale
        )
    }

    static func make(from budget: StatsBudget, year: Int, currencyCode: String, locale: Locale) -> BudgetCardState {
        let rows = budget.recipients.map {
            BudgetPersonRowState(
                id: $0.recipientId, name: $0.displayName, limit: $0.budget, spent: $0.spent,
                code: currencyCode, locale: locale
            )
        }
        return card(
            year: year, total: budget.totalBudget, spent: budget.totalSpent,
            rows: rows, code: currencyCode, locale: locale
        )
    }

    // MARK: - Shared

    fileprivate static func status(spent: Decimal, limit: Decimal, code: String, locale: Locale) -> String {
        let remaining = "\(MoneyText.currency(limit - spent, code: code, locale: locale)) remaining"
        switch BudgetStateStyle.level(spent: spent, limit: limit) {
        case .over: return "Over by \(MoneyText.currency(spent - limit, code: code, locale: locale))"
        case .nearLimit: return "Near limit. \(remaining)"
        case .under: return remaining
        }
    }

    private static func card(
        year: Int,
        total: Decimal,
        spent: Decimal,
        rows: [BudgetPersonRowState],
        code: String,
        locale: Locale
    ) -> BudgetCardState {
        let totalText = MoneyText.currency(total, code: code, locale: locale)
        let spentText = MoneyText.currency(spent, code: code, locale: locale)
        return BudgetCardState(
            year: year,
            totalText: totalText,
            spentText: spentText,
            statusText: status(spent: spent, limit: total, code: code, locale: locale),
            level: BudgetStateStyle.level(spent: spent, limit: total),
            progress: progress(spent: spent, total: total),
            progressAccessibilityLabel: "Spent \(spentText) of \(totalText)",
            rows: rows
        )
    }

    private static func progress(spent: Decimal, total: Decimal) -> Double {
        if total <= 0 { return spent > 0 ? 1 : 0 }
        if spent <= 0 { return 0 }
        if spent >= total { return 1 }
        return NSDecimalNumber(decimal: spent / total).doubleValue
    }
}
