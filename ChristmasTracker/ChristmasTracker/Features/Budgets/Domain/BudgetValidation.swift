//
//  BudgetValidation.swift
//  ChristmasTracker
//
//  I5a Story A: the budget draft and its client-side validation (Decimal only).
//

import Foundation

nonisolated struct BudgetRecipientDraft: Identifiable, Equatable, Sendable {
    let recipientId: String
    var name: String
    var limitText: String

    var id: String { recipientId }
}

nonisolated struct BudgetDraft: Equatable, Sendable {
    var year: Int
    var totalText: String
    var recipients: [BudgetRecipientDraft]
}

nonisolated struct BudgetValidation: Equatable, Sendable {

    enum Issue: Equatable, Sendable {
        case totalInvalid
        case limitInvalid(recipientId: String)
        case duplicateRecipient(recipientId: String)
        case limitsExceedTotal
    }

    let issues: [Issue]
    let total: Decimal?
    /// Sum of the parseable limits.
    let limitsSum: Decimal
    /// total - limitsSum when the total is valid, otherwise nil.
    let unallocated: Decimal?

    var isValid: Bool { issues.isEmpty }

    static func validate(_ draft: BudgetDraft, locale: Locale) -> BudgetValidation {
        var issues: [Issue] = []
        let total = BudgetAmountParser.parse(draft.totalText, locale: locale)
        if total == nil { issues.append(.totalInvalid) }

        var sum = Decimal.zero
        var seen = Set<String>()
        var reported = Set<String>()
        var duplicates: [Issue] = []
        for recipient in draft.recipients {
            if let limit = BudgetAmountParser.parse(recipient.limitText, locale: locale) {
                sum += limit
            } else {
                issues.append(.limitInvalid(recipientId: recipient.recipientId))
            }
            if !seen.insert(recipient.recipientId).inserted, reported.insert(recipient.recipientId).inserted {
                duplicates.append(.duplicateRecipient(recipientId: recipient.recipientId))
            }
        }
        issues.append(contentsOf: duplicates)

        if let total, sum > total { issues.append(.limitsExceedTotal) }
        return BudgetValidation(
            issues: issues,
            total: total,
            limitsSum: sum,
            unallocated: total.map { $0 - sum }
        )
    }

    func summaryLine(currencyCode: String, locale: Locale) -> String? {
        guard let total, let unallocated else { return nil }
        if issues.contains(.limitsExceedTotal) { return "Limits add up to more than the total" }
        let sumText = MoneyText.currency(limitsSum, code: currencyCode, locale: locale)
        let totalText = MoneyText.currency(total, code: currencyCode, locale: locale)
        let freeText = MoneyText.currency(unallocated, code: currencyCode, locale: locale)
        return "Limits \(sumText) of \(totalText); \(freeText) unallocated"
    }
}
