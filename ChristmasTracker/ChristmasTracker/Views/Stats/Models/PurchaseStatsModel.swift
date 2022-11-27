//
//  PurchaseStatsModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation

struct PurchaseStat: Decodable {
    let totalSpent: Double
    let purchasedItems: Int
    let listId: String
    let listName: String
    let ownerInfo: SlimUserModel
    
    init() {
        self.totalSpent = 0.0
        self.purchasedItems = 0
        self.listId = ""
        self.listName = ""
        self.ownerInfo = SlimUserModel()
    }
}

struct PurchaseStatsResponse: Decodable {
    let purchaseStats: [PurchaseStat]
}
