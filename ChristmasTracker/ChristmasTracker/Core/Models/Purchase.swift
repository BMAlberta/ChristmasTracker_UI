//
//  Purchase.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation
import SwiftUI

/// Purchase record for an item (based on backend Swagger schema)
struct Purchase: Codable, Identifiable, Sendable, Equatable, Hashable {
    // MARK: - Basic Info
    let id: String
    let itemId: String
    let quantity: Int
    let totalCost: Double
    
    // MARK: - Store & Order Details
    let storeName: String?
    let notes: String?
    let confirmationNumber: String?
    
    // MARK: - Shipping Tracking
    let trackingNumber: String?
    let shippingStatus: ShippingStatus
    let shippedAt: Date?
    let deliveredAt: Date?
    
    // MARK: - People (Nested Objects)
    let purchaser: PurchasePerson
    let recipient: PurchasePerson
    
    // MARK: - Metadata
    let purchasedAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Computed Properties
    
    var isDelivered: Bool {
        shippingStatus == .delivered
    }
    
    var isShipped: Bool {
        shippingStatus == .shipped || shippingStatus == .delivered
    }
    
    var unitCost: Double {
        guard quantity > 0 else { return 0 }
        return totalCost / Double(quantity)
    }
    
    var statusDescription: String {
        if isDelivered {
            return "Delivered"
        } else if isShipped {
            return "Shipped"
        } else {
            return "Not shipped yet"
        }
    }
}

// MARK: - PurchasePerson (Nested Object)

struct PurchasePerson: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
}

// MARK: - ShippingStatus Enum

enum ShippingStatus: String, Codable, Sendable, Hashable {
    case notShipped = "NOT_SHIPPED"
    case shipped = "SHIPPED"
    case delivered = "DELIVERED"
    
    var displayName: String {
        switch self {
        case .notShipped: return "Not Shipped"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        }
    }
    
    var icon: String {
        switch self {
        case .notShipped: return "shippingbox"
        case .shipped: return "truck.box"
        case .delivered: return "checkmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notShipped: return .gray
        case .shipped: return .blue
        case .delivered: return .green
        }
    }
}

// MARK: - Request Types

nonisolated struct CreatePurchaseRequest: Codable, Sendable {
    let quantity: Int
    let totalCost: Double
    let storeName: String?
    let notes: String?
    let confirmationNumber: String?
    let trackingNumber: String?
    let confirmationToken: String?
}

nonisolated struct UpdatePurchaseRequest: Codable, Sendable {
    let quantity: Int?
    let totalCost: Double?
    let storeName: String?
    let notes: String?
    let confirmationNumber: String?
    let trackingNumber: String?
    let shippingStatus: ShippingStatus?
}

// MARK: - Response Types

nonisolated struct PurchaseResponse: Codable, Sendable {
    let success: Bool
    let data: Purchase
}

nonisolated struct PurchasesResponse: Codable, Sendable {
    let success: Bool
    let data: PurchasesData
}

struct PurchasesData: Codable, Sendable {
    let purchases: [Purchase]
}

// MARK: - Warning Response Types

/// Response when creating a purchase (may include warnings)
nonisolated struct CreatePurchaseResponse: Codable, Sendable {
    let success: Bool
    let data: CreatePurchaseData
    let warnings: [PurchaseWarning]?
}

/// Data returned when creating purchase
nonisolated struct CreatePurchaseData: Codable, Sendable {
    let purchaseId: String?  // null if requiresConfirmation
    let requiresConfirmation: Bool
    let purchase: Purchase?  // Present when purchase succeeds
}

/// Warning about purchase (e.g., budget overage)
nonisolated struct PurchaseWarning: Codable, Sendable {
    let code: Int
    let warningCode: String
    let message: String
    let severity: String
    let requiresConfirmation: Bool
    let details: WarningDetails?
    let confirmationToken: String?
}

/// Details about the warning
nonisolated struct WarningDetails: Codable, Sendable {
    let recipientId: String?
    let recipientName: String?
    let budgetLimit: Double?
    let currentSpent: Double?
    let purchaseAmount: Double?
    let overage: Double?
    
    // Computed for display
    var overageDisplay: String? {
        guard let overage = overage else { return nil }
        return String(format: "$%.2f", overage)
    }
    
    var budgetSummary: String? {
        guard let spent = currentSpent,
              let limit = budgetLimit,
              let amount = purchaseAmount else {
            return nil
        }
        return String(format: "$%.2f spent of $%.2f limit (adding $%.2f)",
                     spent, limit, amount)
    }
}
