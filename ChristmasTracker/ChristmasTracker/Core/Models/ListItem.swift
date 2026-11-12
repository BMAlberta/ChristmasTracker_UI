//
//  ListItem.swift
//  ChristmasTracker
//
//  The item domain model built from the generated client types (mapped in ItemMapping.swift),
//  plus the request inputs. Money is Decimal end to end. Fields that the server omits for
//  viewers who cannot see gift activity (updatedAt, purchases, totalQuantityPurchased) are
//  optional and stay nil: nothing is invented.
//

import Foundation

nonisolated struct ListItemPerson: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
}

nonisolated struct ListItemPurchaseSummary: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let quantity: Int
    let totalCost: Decimal
    let purchaser: ListItemPerson
    let purchasedAt: Date
}

nonisolated struct ListItem: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let listId: String
    let name: String
    let description: String
    let url: String?
    let imageUrl: String?
    let expectedUnitPrice: Decimal?
    let quantityRequested: Int
    let priority: Int
    let status: ItemStatus
    let offList: Bool
    let createdBy: ListItemPerson
    let createdAt: Date
    let updatedAt: Date?
    let purchases: [ListItemPurchaseSummary]?
    let totalQuantityPurchased: Int?
    /// The server's own counts; nil when the server omits them (viewers who cannot see activity).
    let quantityPurchased: Int?
    let quantityRemaining: Int?

    init(
        id: String,
        listId: String,
        name: String,
        description: String,
        url: String? = nil,
        imageUrl: String? = nil,
        expectedUnitPrice: Decimal? = nil,
        quantityRequested: Int,
        priority: Int,
        status: ItemStatus,
        offList: Bool,
        createdBy: ListItemPerson,
        createdAt: Date,
        updatedAt: Date? = nil,
        purchases: [ListItemPurchaseSummary]? = nil,
        totalQuantityPurchased: Int? = nil,
        quantityPurchased: Int? = nil,
        quantityRemaining: Int? = nil
    ) {
        self.id = id
        self.listId = listId
        self.name = name
        self.description = description
        self.url = url
        self.imageUrl = imageUrl
        self.expectedUnitPrice = expectedUnitPrice
        self.quantityRequested = quantityRequested
        self.priority = priority
        self.status = status
        self.offList = offList
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.purchases = purchases
        self.totalQuantityPurchased = totalQuantityPurchased
        self.quantityPurchased = quantityPurchased
        self.quantityRemaining = quantityRemaining
    }
}

// MARK: - Request inputs

/// What the add form sends. The server derives the item type from the caller, so this
/// type carries no list-type member at all.
nonisolated struct CreateItemInput: Equatable, Sendable {
    let name: String
    let description: String
    let url: String?
    let imageUrl: String?
    let expectedUnitPrice: Decimal?
    let quantityRequested: Int
    let priority: Int
}

/// What the edit form sends: only the changed fields are non-nil. A nil field is not sent,
/// so an optional field cannot be cleared through the generated update body.
nonisolated struct UpdateItemInput: Equatable, Sendable {
    let name: String?
    let description: String?
    let url: String?
    let imageUrl: String?
    let expectedUnitPrice: Decimal?
    let quantityRequested: Int?
    let priority: Int?

    init(
        name: String? = nil,
        description: String? = nil,
        url: String? = nil,
        imageUrl: String? = nil,
        expectedUnitPrice: Decimal? = nil,
        quantityRequested: Int? = nil,
        priority: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.url = url
        self.imageUrl = imageUrl
        self.expectedUnitPrice = expectedUnitPrice
        self.quantityRequested = quantityRequested
        self.priority = priority
    }

    var isEmpty: Bool {
        name == nil && description == nil && url == nil && imageUrl == nil
            && expectedUnitPrice == nil && quantityRequested == nil && priority == nil
    }
}
