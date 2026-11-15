//
//  PurchaseHistoryRow.swift
//  ChristmasTracker
//
//  One purchase of the caller in the history. The list name, the item image and the page totals of
//  the response are not carried. `id` is the purchase id.
//

import Foundation

nonisolated struct PurchaseHistoryRow: Identifiable, Equatable, Sendable {
    let id: String
    let itemId: String
    let itemName: String
    let listId: String
    let recipientId: String
    let recipientName: String
    let purchasedAt: Date
    let quantity: Int
    let totalCost: Decimal
    let shippingStatus: PurchaseShippingStatus
}
