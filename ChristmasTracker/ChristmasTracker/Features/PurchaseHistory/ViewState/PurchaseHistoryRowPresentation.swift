//
//  PurchaseHistoryRowPresentation.swift
//  ChristmasTracker
//
//  PH1-H3: how one history row reads. Pure and Foundation only: the item name (with the "Item"
//  fallback for a blank name), who it is for, the medium date, the quantity above 1, the money from
//  the Decimal total and the one combined accessibility label.
//

import Foundation

nonisolated struct PurchaseHistoryRowPresentation: Equatable, Sendable {
    let itemName: String
    let recipientText: String
    let dateText: String
    let quantityText: String?
    let totalText: String
    let shippingWords: String
    let accessibilityLabel: String

    static let fallbackItemName = "Item"
    static let currencyCode = "USD"

    static func make(
        _ row: PurchaseHistoryRow,
        locale: Locale,
        calendar: Calendar
    ) -> PurchaseHistoryRowPresentation {
        let trimmed = row.itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemName = trimmed.isEmpty ? fallbackItemName : row.itemName
        let dateText = row.purchasedAt.formatted(
            Date.FormatStyle(
                date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone
            )
        )
        let totalText = MoneyText.currency(row.totalCost, code: currencyCode, locale: locale)
        let shipping = ShippingStatusStyle.style(for: row.shippingStatus)
        let quantityText: String? = row.quantity > 1 ? "Qty \(row.quantity)" : nil

        var parts = [itemName, "for \(row.recipientName)", dateText]
        if row.quantity > 1 { parts.append("quantity \(row.quantity)") }
        parts += [totalText, shipping.accessibilityLabel]

        return PurchaseHistoryRowPresentation(
            itemName: itemName,
            recipientText: "For \(row.recipientName)",
            dateText: dateText,
            quantityText: quantityText,
            totalText: totalText,
            shippingWords: shipping.shortLabel,
            accessibilityLabel: parts.joined(separator: ", ")
        )
    }
}
