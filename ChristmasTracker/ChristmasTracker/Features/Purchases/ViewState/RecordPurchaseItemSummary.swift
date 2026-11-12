//
//  RecordPurchaseItemSummary.swift
//  ChristmasTracker
//
//  The item summary at the top of the Record Purchase form. The remaining text is the server's
//  quantityRemaining and only for a caller who can see gift activity; it is never computed.
//  There is deliberately no "already purchased" member.
//

import Foundation

nonisolated struct RecordPurchaseItemSummary: Equatable, Sendable {
    let name: String
    let requestedText: String
    let remainingText: String?
    let expectedPriceText: String?

    init(item: ListItem, capabilities: ListCapabilities, currencyCode: String, locale: Locale) {
        name = item.name
        requestedText = "Requested: \(item.quantityRequested)"
        if capabilities.canSeeGiftActivity, let remaining = item.quantityRemaining {
            remainingText = "\(remaining) remaining"
        } else {
            remainingText = nil
        }
        expectedPriceText = item.expectedUnitPrice.map {
            $0.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale))
        }
    }
}
