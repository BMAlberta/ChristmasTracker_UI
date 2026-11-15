//
//  PurchaseHistoryScreenState.swift
//  ChristmasTracker
//
//  PH1-H3: the pure text of the purchase history screen: the option lists and titles of the three
//  filter menus, their accessibility labels and values, and the route from the Statistics screen.
//  Foundation only, so it is tested without a view.
//

import Foundation

/// One entry of a filter menu. `value == nil` is the "all" entry.
nonisolated struct PurchaseHistoryOption<Value: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    let id: String
    let value: Value?
    let title: String
}

nonisolated enum PurchaseHistoryScreenState {

    // MARK: - Words

    static let allYearsTitle = "All years"
    static let allShippingMenuTitle = "All shipping"
    static let allShippingOptionTitle = "All"
    static let allPeopleTitle = "All people"
    static let unknownPersonTitle = "Person"

    static let yearAccessibilityLabel = "Year"
    static let shippingAccessibilityLabel = "Shipping"
    static let recipientAccessibilityLabel = "Recipient"

    private static let allId = "all"

    // MARK: - Option lists

    /// All years, then the choices in the given order. The selected year is always listed; when the
    /// choices lack it, it is added at the end.
    static func yearOptions(choices: [Int], selected: Int?) -> [PurchaseHistoryOption<Int>] {
        var years = choices
        if let selected, !years.contains(selected) { years.append(selected) }
        let all = PurchaseHistoryOption<Int>(id: allId, value: nil, title: allYearsTitle)
        return [all] + years.map { PurchaseHistoryOption(id: String($0), value: $0, title: String($0)) }
    }

    /// All, then the four shipping statuses in their declared order.
    static func shippingOptions() -> [PurchaseHistoryOption<PurchaseShippingStatus>] {
        let all = PurchaseHistoryOption<PurchaseShippingStatus>(id: allId, value: nil, title: allShippingOptionTitle)
        return [all] + PurchaseShippingStatus.allCases.map {
            PurchaseHistoryOption(id: $0.displayName, value: $0, title: $0.displayName)
        }
    }

    /// All people, then the people the model knows, in the model's order.
    static func recipientOptions(
        _ people: [PurchaseHistoryRecipient]
    ) -> [PurchaseHistoryOption<PurchaseHistoryRecipient>] {
        let all = PurchaseHistoryOption<PurchaseHistoryRecipient>(id: allId, value: nil, title: allPeopleTitle)
        return [all] + people.map { PurchaseHistoryOption(id: $0.id, value: $0, title: $0.name) }
    }

    // MARK: - Menu titles (the current selection on the menu button)

    static func yearTitle(_ year: Int?) -> String {
        year.map { String($0) } ?? allYearsTitle
    }

    static func shippingTitle(_ status: PurchaseShippingStatus?) -> String {
        status?.displayName ?? allShippingMenuTitle
    }

    static func recipientTitle(recipientId: String?, people: [PurchaseHistoryRecipient]) -> String {
        guard let recipientId else { return allPeopleTitle }
        return people.first { $0.id == recipientId }?.name ?? unknownPersonTitle
    }

    // MARK: - Accessibility values (the current selection in words)

    static func yearAccessibilityValue(_ year: Int?) -> String {
        yearTitle(year)
    }

    static func shippingAccessibilityValue(_ status: PurchaseShippingStatus?) -> String {
        status?.displayName ?? allShippingOptionTitle
    }

    static func recipientAccessibilityValue(recipientId: String?, people: [PurchaseHistoryRecipient]) -> String {
        recipientTitle(recipientId: recipientId, people: people)
    }
}

/// Where the Statistics screen sends the user: the year to show, the year choices of the Statistics
/// screen, and the person the history starts on (nil for all people).
nonisolated struct PurchaseHistoryRoute: Hashable, Sendable {
    let year: Int
    let yearChoices: [Int]
    let recipient: PurchaseHistoryRecipient?

    /// From the "Purchase History" row: everyone, in the selected year.
    static func fromHistoryRow(year: Int, yearChoices: [Int]) -> PurchaseHistoryRoute {
        PurchaseHistoryRoute(year: year, yearChoices: yearChoices, recipient: nil)
    }

    /// From a "Spend by person" row. The row id is the recipient id.
    static func fromSpendRow(_ row: SpendRowState, year: Int, yearChoices: [Int]) -> PurchaseHistoryRoute {
        PurchaseHistoryRoute(
            year: year,
            yearChoices: yearChoices,
            recipient: PurchaseHistoryRecipient(id: row.id, name: row.name)
        )
    }
}
