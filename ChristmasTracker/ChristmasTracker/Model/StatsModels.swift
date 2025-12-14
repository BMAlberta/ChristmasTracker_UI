//
//  PurchaseStatsModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

// MARK: - Purchase Stat Models

struct PurchaseStat: Codable {
    /// Total amount, in dollars, spent on purchases.
    let totalSpent: Double
    
    /// Number of items purchased.
    let itemPurchased: Int
    
    /// List identifier.
    let listId: String
    
    /// List name.
    let listName: String
    
    /// Year in which purchases were made.
    let purchaseYear: String
    
    /// Trimmed down user model for owner.
    let ownerInfo: LWUserModel
    
    init() {
        self.totalSpent = 0.0
        self.itemPurchased = 0
        self.listId = ""
        self.listName = ""
        self.purchaseYear = ""
        self.ownerInfo = LWUserModel(id: "", firstName: "", lastName: "")
    }
}

struct PurchaseStatsResponse: Decodable {
    let purchaseStats: [PurchaseStat]
}
