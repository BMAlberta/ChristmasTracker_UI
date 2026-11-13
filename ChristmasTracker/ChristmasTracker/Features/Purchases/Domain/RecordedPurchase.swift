//
//  RecordedPurchase.swift
//  ChristmasTracker
//
//  The domain model of a purchase the server has recorded. Money is Decimal. Built from the
//  generated Purchase in PurchaseMapping.swift; nothing past the repository boundary sees a
//  generated type.
//

import Foundation

nonisolated enum PurchaseShippingStatus: CaseIterable, Equatable, Hashable, Sendable {
    case notTracked
    case notShipped
    case shipped
    case delivered

    var displayName: String {
        switch self {
        case .notTracked: return "Not tracked"
        case .notShipped: return "Not shipped"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        }
    }
}

/// The item a purchase belongs to, as the server reports it on the purchase.
nonisolated struct PurchaseItemReference: Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let listId: String
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
    let shippingStatus: PurchaseShippingStatus
    let shippedAt: Date?
    let deliveredAt: Date?
    let purchaser: ListItemPerson
    let recipient: ListItemPerson
    let item: PurchaseItemReference?
    let purchasedAt: Date
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        itemId: String,
        quantity: Int,
        totalCost: Decimal,
        storeName: String?,
        notes: String?,
        confirmationNumber: String?,
        trackingNumber: String?,
        shippingStatus: PurchaseShippingStatus,
        shippedAt: Date?,
        deliveredAt: Date?,
        purchaser: ListItemPerson,
        recipient: ListItemPerson,
        item: PurchaseItemReference? = nil,
        purchasedAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.totalCost = totalCost
        self.storeName = storeName
        self.notes = notes
        self.confirmationNumber = confirmationNumber
        self.trackingNumber = trackingNumber
        self.shippingStatus = shippingStatus
        self.shippedAt = shippedAt
        self.deliveredAt = deliveredAt
        self.purchaser = purchaser
        self.recipient = recipient
        self.item = item
        self.purchasedAt = purchasedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
