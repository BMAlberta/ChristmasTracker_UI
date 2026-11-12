//
//  GiftItem.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//
import SwiftUI
import Foundation

// LEGACY: this type exists only because the legacy purchase screens still take it. It is deleted
// in package I4b. New code uses `ListItem`.
nonisolated struct GiftItem: Identifiable, Codable, Sendable, Hashable {

    // MARK: - Basic Info
    let id: String
    let listId: String
    let name: String
    let description: String?
    let url: String?
    let imageUrl: String?
    
    // MARK: - Pricing
    let expectedUnitPrice: Double?
    let quantityRequested: Int
    let priority: Int
    
    // MARK: - Status
    let status: ItemStatus
    let offList: Bool
    
    // MARK: - Creation
    let createdBy: ItemPerson
    
    // MARK: - Metadata
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Purchases
    let purchases: [PurchaseSummary]?
    let totalQuantityPurchased: Int?
    
    // The purchase screens read only id, listId, name, quantityRequested, totalQuantityPurchased
    // and expectedUnitPrice. The computed members the old item screens used are deleted.
}
struct PurchaseSummary: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let quantity: Int
    let totalCost: Double
    let purchaser: PurchasePerson
    let shippingStatus: ShippingStatus
    let purchasedAt: Date
}

// MARK: - ItemPerson

nonisolated struct ItemPerson: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let displayName: String
}

// MARK: ItemStatus

enum ItemStatus: String, Codable, Sendable, Hashable {
    case available = "AVAILABLE"
    case partial = "PARTIAL"
    case purchased = "PURCHASED"
    case wrapped = "WRAPPED"
    case gifted = "GIFTED"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .partial: return "Partially Purchased"
        case .purchased: return "Purchased"
        case .wrapped: return "Wrapped"
        case .gifted: return "Gifted"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "circle"
        case .partial: return "circle.lefthalf.filled"
        case .purchased: return "checkmark.circle.fill"
        case .wrapped: return "gift.fill"
        case .gifted: return "hand.thumbsup.fill"
        }
    }
    
    @MainActor var color: Color {
        switch self {
        case .available: return .gray
        case .partial: return .orange
        case .purchased: return .green
        case .wrapped: return .blue
        case .gifted: return .purple
        }
    }

}
