//
//  PurchaseStatsModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct PurchaseStat: Decodable {
    /// Total amount, in dollars, spent on purchases.
    let totalSpent: Double
    
    /// Number of items purchased.
    let purchasedItems: Int
    
    /// List identifier.
    let listId: String
    
    /// List name.
    let listName: String
    
    /// Year in which purchases were made.
    let purchaseYear: String
    
    /// Trimmed down user model for owner.
    let ownerInfo: SlimUserModel
    
    init() {
        self.totalSpent = 0.0
        self.purchasedItems = 0
        self.listId = ""
        self.listName = ""
        self.purchaseYear = ""
        self.ownerInfo = SlimUserModel()
    }
}

struct PurchaseStatsResponse: Decodable {
    let purchaseStats: [PurchaseStat]
}
