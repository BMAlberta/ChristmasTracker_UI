//
//  PurchaseHistoryFixtures.swift
//  ChristmasTrackerTests
//
//  PH1-H1: domain and generated-schema fixtures for the purchase history tests. All fake.
//

import Foundation
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum PurchaseHistoryFix {

    static func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    static let baseDate = Date(timeIntervalSince1970: 1_767_600_000)

    /// A domain row; the defaults are one fixed fake purchase.
    static func row(
        id: String = "purchase-1",
        itemId: String = "item-1",
        itemName: String = "Fake Lamp",
        listId: String = "list-1",
        recipientId: String = "user-r1",
        recipientName: String = "Pat Recipient",
        purchasedAt: Date = baseDate,
        quantity: Int = 1,
        totalCost: Decimal = dec("19.99"),
        shippingStatus: PurchaseShippingStatus = .notTracked
    ) -> PurchaseHistoryRow {
        PurchaseHistoryRow(
            id: id, itemId: itemId, itemName: itemName, listId: listId,
            recipientId: recipientId, recipientName: recipientName,
            purchasedAt: purchasedAt, quantity: quantity, totalCost: totalCost,
            shippingStatus: shippingStatus
        )
    }

    /// A generated-schema row (what the server sends), with item.imageUrl and list.name set so a test can
    /// prove they are not carried.
    static func apiRow(
        id: String = "purchase-1",
        itemId: String = "item-1",
        itemName: String = "Fake Lamp",
        listId: String = "list-1",
        recipientId: String = "user-r1",
        recipientName: String = "Pat Recipient",
        purchasedAt: Date = baseDate,
        quantity: Int = 1,
        totalCost: Double = 19.99,
        shippingStatus: Components.Schemas.ShippingStatus = .notTracked
    ) -> Components.Schemas.PurchaseHistoryRow {
        Components.Schemas.PurchaseHistoryRow(
            id: id,
            item: .init(id: itemId, name: itemName, imageUrl: "https://img.example.com/lamp.png"),
            list: .init(id: listId, name: "Fake List", year: 2026),
            recipient: .init(id: recipientId, displayName: recipientName),
            quantity: quantity,
            totalCost: totalCost,
            purchasedAt: purchasedAt,
            shippingStatus: shippingStatus
        )
    }

    static func page(_ rows: [PurchaseHistoryRow] = [row()], nextCursor: String? = nil) -> PurchaseHistoryPage {
        PurchaseHistoryPage(rows: rows, nextCursor: nextCursor)
    }

    /// Every combination of (year, recipient, shipping), each either unset or set: 8 filters.
    static let allFilterCombinations: [PurchaseHistoryFilter] = {
        var result: [PurchaseHistoryFilter] = []
        for year in [Int?.none, 2025] {
            for recipient in [String?.none, "user-r1"] {
                for shipping in [PurchaseShippingStatus?.none, .shipped] {
                    result.append(PurchaseHistoryFilter(year: year, recipientId: recipient, shippingStatus: shipping))
                }
            }
        }
        return result
    }()

    /// The four statuses with their wire (generated) counterparts and wire text.
    static let shippingPairs: [(PurchaseShippingStatus, Components.Schemas.ShippingStatus, String)] = [
        (.notTracked, .notTracked, "NOT_TRACKED"), (.notShipped, .notShipped, "NOT_SHIPPED"),
        (.shipped, .shipped, "SHIPPED"), (.delivered, .delivered, "DELIVERED")
    ]
}
