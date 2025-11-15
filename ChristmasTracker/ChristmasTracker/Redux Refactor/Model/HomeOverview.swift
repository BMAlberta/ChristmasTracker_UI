//
//  HomeListData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation
import SwiftUI


struct AppDataResponse: Codable, Equatable {
    var appData: AppData
}

struct AppData: Codable, Equatable {
    let userMetadata: UserMetadata
    var listOverviews: [ListSummary]
    let activity: [ActivityItem]
}

struct HomeOverview: Codable, Equatable {
    let listOverviews: [ListSummary]
    let recentActivity: [ActivityItem]
}

struct AuthResponse: Codable, Equatable {
    let userInfo: AuthModel
}

struct AuthModel: Codable, Equatable {
    let userId: String
    let firstName: String
    let lastName: String
    let pcr: Bool
}

struct UserMetadataResponse: Codable, Equatable {
    let userMetadata: UserMetadata
}

struct ChangePasswordResponse: Codable, Equatable {
    let passwordInfo: ChangePasswordInfo
}

struct ChangePasswordInfo: Codable, Equatable {
    let id: String
}

struct UserMetadata: Codable, Equatable {
    let userId: String
    let email: String
    let firstName: String
    let lastName: String
    let creationDate: String
    let lastLogInDate: String
    let lastLogInLocation: String
    let lastPasswordChange: String
    
    static func defaultMetadata() -> UserMetadata {
        return UserMetadata(userId: "NaN",
                            email: "NaN",
                            firstName: "NaN",
                            lastName: "NaN",
                            creationDate: "NaN",
                            lastLogInDate: "NaN",
                            lastLogInLocation: "NaN",
                            lastPasswordChange: "NaN")
    }
}

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

struct LWUserModel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case firstName
        case lastName
    }
}

struct HomeFeedResponse: Decodable {
    let feed: HomeOverview
}

struct ItemPurchaseResponse: Decodable {
    let purchaseInfo: PurchaseInfo
}

struct PurchaseInfo: Decodable {
    let id: String
}

struct AddItemResponse: Decodable {
    let itemInfo: AddItemInfo
}

struct AddItemInfo: Decodable {
    let itemId: String
}

struct AddListResponse: Decodable {
    let listInfo: AddListInfo
}

struct AddListInfo: Decodable {
    let listId: String
}

struct UpdateProfileResponse: Decodable {
    let updateInfo: UpdateProfileInfo
}

struct UpdateProfileInfo: Decodable {
    let userId: String
}

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
    let priority: PriorityEntry?
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
    
    enum PriorityEntry: Int, Codable, Equatable {
        case notSet = 0
        case low = 1
        case medium = 2
        case high = 3
        
        var tintColor: Color {
            switch self {
            case .low:
                return .primaryGreen
            case .medium:
                return .brandWarning
            case .high:
                return .primaryRed
            case .notSet:
                return .buttonText
            }
        }
    }
}

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

struct NewItemDetails: Codable {
    let itemName: String
    let itemDescription: String
    let itemLink: String
    let itemPrice: Double
    let itemQuantity: Int
    let itemPriority: Int
    var itemImageUrl: String?
}

struct NewListDetails: Codable {
    let listName: String
    let listTheme: String
}

