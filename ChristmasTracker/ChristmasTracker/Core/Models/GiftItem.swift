//
//  GiftItem.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//
import SwiftUI
import Foundation

struct GiftItem: Identifiable, Codable, Sendable, Hashable {
    
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
    
    // MARK: - Computed Properties
    var totalPrice: Double? {
        guard let price = expectedUnitPrice else { return nil }
        return price * Double(quantityRequested)
    }
    
    var isPurchased: Bool {
        status == .purchased || status == .wrapped || status == .gifted
    }
    
    var isAvailable: Bool {
        status == .available
    }
    
    var canEdit: Bool {
        // Can edit if available or partial
        status == .available || status == .partial
    }
    
//    var totalPurchasedQuantity: Int {
//        purchases?.reduce(0) { $0 + $1.quantity } ?? 0
//    }
    
    var totalSpent: Double {
        purchases?.reduce(0) { $0 + $1.totalCost } ?? 0
    }
    
    var remainingQuantity: Int {
        quantityRequested - (totalQuantityPurchased ?? 0)
    }
    
    var isPartiallyPurchased: Bool {
        guard let totalQuantityPurchased else {
            return false
        }
        return totalQuantityPurchased > 0 && totalQuantityPurchased < quantityRequested
    }
    
    var isFullyPurchased: Bool {
        guard let totalQuantityPurchased else {
            return false
        }
        return totalQuantityPurchased >= quantityRequested
    }
    
    var purchaseProgress: Double {
        
        guard quantityRequested > 0, let totalQuantityPurchased else { return 0 }
        return Double(totalQuantityPurchased) / Double(quantityRequested)
    }
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

struct ItemPerson: Codable, Sendable, Identifiable, Hashable {
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
    
    var color: Color {
        switch self {
        case .available: return .gray
        case .partial: return .orange
        case .purchased: return .green
        case .wrapped: return .blue
        case .gifted: return .purple
        }
    }
    
}

// MARK: - Request Types

nonisolated struct CreateItemRequest: Codable, Sendable {
    let name: String
    let description: String
    let url: String?
    let expectedUnitPrice: Double?
    let quantityRequested: Int
    let priority: Int
    let offList: Bool
    let imageUrl: String?
}

nonisolated struct UpdateItemRequest: Codable, Sendable {
    let name: String?
    let description: String?
    let url: String?
    let expectedUnitPrice: Double?
    let quantityRequested: Int?
    let priority: Int?
    let imageUrl: String?
}

// MARK: - Response Types

nonisolated struct ItemsResponse: Codable, Sendable {
    let success: Bool
    let data: ItemData
}

struct ItemData: Codable, Sendable {
    let items: [GiftItem]
}

nonisolated struct ItemResponse: Codable, Sendable {
    let success: Bool
    let data: GiftItem
}
