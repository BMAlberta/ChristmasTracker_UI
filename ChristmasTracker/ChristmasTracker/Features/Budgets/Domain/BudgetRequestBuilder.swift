//
//  BudgetRequestBuilder.swift
//  ChristmasTracker
//
//  I5a Story A: builds the create, edit (changed fields only) and duplicate requests.
//

import Foundation

nonisolated enum BudgetRequestBuilder {

    static func create(draft: BudgetDraft, locale: Locale) -> CreateBudgetRequest? {
        guard let parsed = parse(draft, locale: locale) else { return nil }
        return CreateBudgetRequest(year: draft.year, totalBudget: parsed.total, recipients: parsed.limits)
    }

    static func update(draft: BudgetDraft, original: Budget, locale: Locale) -> UpdateBudgetRequest? {
        guard let parsed = parse(draft, locale: locale) else { return nil }
        let totalChanged = parsed.total != original.totalBudget
        let limitsChanged = limitsDiffer(parsed.limits, original.recipients)
        guard totalChanged || limitsChanged else { return nil }
        return UpdateBudgetRequest(
            year: original.year,
            totalBudget: totalChanged ? parsed.total : nil,
            recipients: limitsChanged ? parsed.limits : nil
        )
    }

    static func duplicate(fromYear: Int, toYear: Int) -> DuplicateBudgetRequest {
        DuplicateBudgetRequest(fromYear: fromYear, toYear: toYear)
    }

    /// True when the draft differs from the original. A draft with unparseable amounts counts as changed.
    static func hasChanges(draft: BudgetDraft, original: Budget, locale: Locale) -> Bool {
        guard let total = BudgetAmountParser.parse(draft.totalText, locale: locale) else { return true }
        if total != original.totalBudget { return true }
        var limits: [BudgetLimit] = []
        for recipient in draft.recipients {
            guard let limit = BudgetAmountParser.parse(recipient.limitText, locale: locale) else { return true }
            limits.append(BudgetLimit(recipientId: recipient.recipientId, maxSpend: limit))
        }
        return limitsDiffer(limits, original.recipients)
    }

    // MARK: - Private

    private struct Parsed {
        let total: Decimal
        let limits: [BudgetLimit]
    }

    private static func parse(_ draft: BudgetDraft, locale: Locale) -> Parsed? {
        let validation = BudgetValidation.validate(draft, locale: locale)
        guard validation.isValid, let total = validation.total else { return nil }
        var limits: [BudgetLimit] = []
        for recipient in draft.recipients {
            guard let limit = BudgetAmountParser.parse(recipient.limitText, locale: locale) else { return nil }
            limits.append(BudgetLimit(recipientId: recipient.recipientId, maxSpend: limit))
        }
        return Parsed(total: total, limits: limits)
    }

    /// Order-insensitive comparison of the set of people and every limit.
    private static func limitsDiffer(_ limits: [BudgetLimit], _ original: [RecipientBudget]) -> Bool {
        let draftMap = Dictionary(limits.map { ($0.recipientId, $0.maxSpend) }, uniquingKeysWith: { first, _ in first })
        let originalMap = Dictionary(
            original.map { ($0.recipientId, $0.maxSpend) },
            uniquingKeysWith: { first, _ in first }
        )
        return limits.count != original.count || draftMap != originalMap
    }
}
