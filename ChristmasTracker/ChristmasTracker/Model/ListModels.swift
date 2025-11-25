//
//  ListModels.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/15/25.
//

import Foundation
import SwiftUI

// MARK: - Items
// MARK: Details
struct ItemDetails: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let link: String
    let price: Double
    var quantity: Int
    let imageUrl: String
    let createdBy: String
    let creationDate: String
    let lastEditDate: String
    let offListItem: Bool
    let priority: PriorityLevel?
    let retractablePurchase: Bool
    var purchaseState: PurchaseState
    let quantityPurchased: Int
    let deleteAllowed: Bool
    let editAllowed: Bool
    let canViewMetadata: Bool
   
    enum CodingKeys: String, CodingKey {
        case id = "itemId"
        case name
        case description
        case link
        case price
        case quantity
        case imageUrl
        case createdBy
        case creationDate
        case lastEditDate
        case offListItem
        case priority
        case retractablePurchase
        case purchaseState
        case quantityPurchased
        case deleteAllowed
        case editAllowed
        case canViewMetadata
    }
    
    static func defaultItem() -> Self {
        return ItemDetails(id: "", name: "",
                           description: "",
                           link: "",
                           price: 0,
                           quantity: 0,
                           imageUrl: "",
                           createdBy: "",
                           creationDate: "",
                           lastEditDate: "",
                           offListItem: false,
                           priority: nil,
                           retractablePurchase: false,
                           purchaseState: .unavailable,
                           quantityPurchased: 0,
                           deleteAllowed: false,
                           editAllowed: false,
                           canViewMetadata: false)
    }
}


enum PriorityLevel: Int, Codable, CaseIterable {
    case low = 2
    case medium = 1
    case high = 0
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
    
    var tintColor: Color {
        switch self {
        case .low:
            return .primaryGreen
        case .medium:
            return .brandWarning
        case .high:
            return .primaryRed
        }
    }
    
    
    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var subtitle: String {
        switch self {
        case .low: return "Nice to have"
        case .medium: return "Would be nice"
        case .high: return "Really want"
        }
    }
}

struct NewItemDetails: Codable {
    let itemName: String
    let itemDescription: String
    let itemLink: String
    let itemPrice: Double
    let itemQuantity: Int
    let itemPriority: Int
    var itemImageUrl: String?
    let itemId: String?
}

struct NewListDetails: Codable {
    let listName: String
    let listTheme: String
}

struct AddItemResponse: Decodable {
    let itemInfo: AddItemInfo
}

struct AddItemInfo: Decodable {
    let itemId: String
}

// MARK: Purchases

enum PurchaseState:String, Codable, Comparable, CaseIterable {
    static func minimum(lhs: Self, rhs: Self) -> Self {
      switch (lhs, rhs) {
      case (.available,  _), (_, .available) : return .available
      case (.partial, _), (_, .partial): return .partial
      case (.purchased,   _), (_, .purchased)  : return .purchased
      case (.unavailable,   _), (_, .unavailable)  : return .unavailable
      }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return (lhs != rhs) && (lhs == minimum(lhs: lhs, rhs: rhs))
    }
    
    case available
    case partial
    case purchased
    case unavailable
    
    var description: String {
        switch self {
        case .available:
            return "Available"
        case .partial:
            return "Partial"
        case .purchased:
            return "Purchased"
        case .unavailable:
            return "Unavailable"
        }
    }
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .partial:
            return .yellow
        case .purchased:
            return .red
        case .unavailable:
            return .gray
        }
    }
}

struct ItemPurchaseResponse: Decodable {
    let purchaseInfo: PurchaseInfo
}

struct PurchaseInfo: Decodable {
    let id: String
}

// MARK: - Lists
// MARK: Summaries
struct ListSummary: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let listTheme: String
    let ownerInfo: LWUserModel
    let status: ListStatus
    let creationDate: String
    let lastUpdateDate: String
    var totalItems: Int
    var purchasedItems: Int
    let members: [LWUserModel]
    var items: [ItemDetails]
    let canViewMetadata: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "listId"
        case name
        case listTheme
        case ownerInfo
        case status
        case creationDate
        case lastUpdateDate
        case totalItems
        case purchasedItems
        case members
        case items
        case canViewMetadata
    }
    
    static var defaultObject: ListSummary {
        return ListSummary(id: "NaN",
                           name: "Empty List",
                           listTheme: "No Theme",
                           ownerInfo: LWUserModel(id: "NaN",
                                                  firstName: "Default",
                                                  lastName: "User"),
                           status: .expired,
                           creationDate: "NaN",
                           lastUpdateDate: "NaN",
                           totalItems: 0,
                           purchasedItems: 0,
                           members: [],
                           items: [],
                           canViewMetadata: false)
    }
}
enum ListStatus: String, Codable {
    case active = "active"
    case archive = "archive"
    case expired = "expired"
    case draft = "draft"
}

struct AddListResponse: Decodable {
    let listInfo: AddListInfo
}

struct AddListInfo: Decodable {
    let listId: String
}

// MARK: Members
struct MemberDetail: Decodable {
    
    /// User's first name.
    let firstName: String
    
    /// User's last name.
    let lastName: String
    
    /// User identifier.
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case userId
    }
}







