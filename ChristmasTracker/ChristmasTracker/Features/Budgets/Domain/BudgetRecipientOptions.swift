//
//  BudgetRecipientOptions.swift
//  ChristmasTracker
//
//  I5a Story A: the people a user can set a budget limit for, derived from lists, existing
//  allocations and the year's spend.
//

import Foundation

nonisolated struct BudgetRecipientOption: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
}

nonisolated enum BudgetRecipientOptions {

    /// Sources in order: purchasable lists, existing allocations, spend rows. De-duplicated by id; the name
    /// is the first non-blank one in that order; sorted by name case-insensitively, ties by id.
    static func build(
        lists: [GiftList],
        existing: [RecipientBudget],
        spend: [RecipientSpend]
    ) -> [BudgetRecipientOption] {
        var candidates: [(id: String, name: String)] = []
        for list in lists where list.capabilities.canPurchase {
            candidates.append((list.recipient.id, list.recipient.displayName))
        }
        for item in existing { candidates.append((item.recipientId, item.recipientName)) }
        for item in spend { candidates.append((item.recipientId, item.displayName)) }

        var order: [String] = []
        var names: [String: String] = [:]
        for candidate in candidates {
            let trimmed = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if names[candidate.id] == nil {
                order.append(candidate.id)
                names[candidate.id] = trimmed
            } else if names[candidate.id]?.isEmpty == true, !trimmed.isEmpty {
                names[candidate.id] = trimmed
            }
        }
        let options = order.map { BudgetRecipientOption(id: $0, displayName: names[$0] ?? "") }
        return options.sorted { lhs, rhs in
            let comparison = lhs.displayName.caseInsensitiveCompare(rhs.displayName)
            if comparison == .orderedSame { return lhs.id < rhs.id }
            return comparison == .orderedAscending
        }
    }

    /// Options not yet used in the draft, original order kept.
    static func unused(_ options: [BudgetRecipientOption], in draft: BudgetDraft) -> [BudgetRecipientOption] {
        let used = Set(draft.recipients.map(\.recipientId))
        return options.filter { !used.contains($0.id) }
    }
}
