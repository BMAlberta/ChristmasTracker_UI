//
//  RecordedPurchase.swift
//  ChristmasTracker
//
//  The domain model of a purchase the server has recorded. Money is Decimal. Built from the
//  generated Purchase in PurchaseMapping.swift; nothing past the repository boundary sees a
//  generated type.
//

import Foundation

nonisolated enum RecordedShippingStatus: Equatable, Hashable, Sendable {
    case notTracked
    case notShipped
    case shipped
    case delivered
}

nonisolated struct RecordedPurchase: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let itemId: String
    let quantity: Int
    let totalCost: Decimal
    let storeName: String?
    let notes: String?
    let confirmationNumber: String?
    let trackingNumber: String?
    let shippingStatus: RecordedShippingStatus
    let shippedAt: Date?
    let deliveredAt: Date?
    let purchaser: ListItemPerson
    let recipient: ListItemPerson
    let purchasedAt: Date
    let createdAt: Date
    let updatedAt: Date
}
