//
//  BudgetWarningPanelState.swift
//  ChristmasTracker
//
//  The pure state of the inline budget warning panel: one row per warning in the same order,
//  plain labels, amounts formatted from Decimal, an optional notice and fixed button titles.
//  The announcement carries no amounts and no names.
//

import Foundation

nonisolated struct BudgetWarningRowState: Equatable, Sendable {
    let label: String
    let budgetLimitText: String
    let alreadySpentText: String
    let thisPurchaseText: String
    let overByText: String
}

nonisolated enum RecordPurchaseCopy {
    static let budgetChangedNotice = "The amounts changed since the last warning. Review them and confirm again."
    static let expiredMessage = "This confirmation has expired. Review the details and record again."
}

nonisolated struct BudgetWarningPanelState: Equatable, Sendable {
    let rows: [BudgetWarningRowState]
    let noticeText: String?
    let cancelTitle = "Cancel"
    let confirmTitle = "Record Anyway"
    let editTitle = "Edit Details"
    let announcement: String

    init(
        warnings: [BudgetWarning],
        notice: String?,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) {
        func money(_ amount: Decimal) -> String {
            amount.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale))
        }
        rows = warnings.map { warning in
            BudgetWarningRowState(
                label: Self.label(for: warning),
                budgetLimitText: money(warning.budgetLimit),
                alreadySpentText: money(warning.currentSpent),
                thisPurchaseText: money(warning.purchaseAmount),
                overByText: money(warning.overage)
            )
        }
        noticeText = notice
        let count = warnings.count
        announcement = "Budget warning. \(count) \(count == 1 ? "item" : "items") over budget."
    }

    private static func label(for warning: BudgetWarning) -> String {
        switch warning.level {
        case .total:
            return "Over your total budget"
        case .recipient:
            let name = warning.recipientName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Over the budget for this recipient" : "Over the budget for \(name)"
        }
    }
}
