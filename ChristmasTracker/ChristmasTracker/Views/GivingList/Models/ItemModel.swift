//
//  ItemModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation
import Combine

class Item: Decodable, Identifiable, ObservableObject {
    
    /// Identifier of the list
    var id: String
    
    /// Id of the user that created the item.
    var createdBy: String
    
    /// Date on which the item was created.
    var creationDate: String
    
    /// Description/details of the item.
    var description: String
    
    /// Date on which the item was last edited.
    var lastEditDate: String
    
    /// Hyperlink to the item website.
    var link: String
    
    /// Name of the item.
    var name: String
    
    /// Price, in dollars, of the item.
    var price: Double
    
    /// Number of items requested.
    var quantity: Int
    
    /// Date on which the item was purchased.
    var purchaseDate: String?
    
    /// Indicates if the current user can retract the purchase.
    var retractablePurchase: Bool = false
    
    /// Indicates if the item was added by a non-list owner.
    var offListItem: Bool
    
    /// Enum representing the purchase state of the item,
    var purchaseState: PurchaseState
    
    /// Indicates if the item can be purchased by the current user.
    var purchasesAllowed: Bool
    
    /// Number of items purchased.
    var quantityPurchased: Int
    
    /// Indicates whether the current user can delete the item.
    var deleteAllowed: Bool
    
    /// Indicates if the current user can edit the item.
    var editAllowed: Bool
    
    enum CodingKeys: String, CodingKey {
        case createdBy
        case creationDate
        case description
        case lastEditDate
        case link
        case name
        case price
        case purchased
        case purchaseDate
        case quantity
        case retractablePurchase
        case purchasedBy
        case id = "_id"
        case offListItem
        case purchaseState
        case purchasesAllowed
        case quantityPurchased
        case deleteAllowed
        case editAllowed
    }
    
    init() {
        self.id = ""
        self.createdBy = ""
        self.creationDate = ""
        self.description = ""
        self.lastEditDate = ""
        self.link = ""
        self.name = ""
        self.price = 0.0
        self.purchaseDate = ""
        self.quantity = 0
        self.retractablePurchase = false
        self.offListItem = false
        self.purchaseState = .unavailable
        self.purchasesAllowed = false
        self.quantityPurchased = 0
        self.deleteAllowed = false
        self.editAllowed = false
    }
    
    init(id: String,
         createdBy: String,
         creationDate: String,
         description: String,
         lastEditDate: String,
         link: String,
         name: String,
         price: Double,
         purchaseDate: String?,
         quantity: Int,
         retractablePurchase: Bool,
         offListItem: Bool,
         purchaseState: PurchaseState,
         purchasesAllowed: Bool,
         quantityPurchased: Int,
         deleteAllowed: Bool,
         editAllowed: Bool) {
        self.id = id
        self.createdBy = createdBy
        self.creationDate = creationDate
        self.description = description
        self.lastEditDate = lastEditDate
        self.link = link
        self.name = name
        self.price = price
        self.purchaseDate = purchaseDate
        self.quantity = quantity
        self.retractablePurchase = retractablePurchase
        self.offListItem = offListItem
        self.purchaseState = purchaseState
        self.purchasesAllowed = purchasesAllowed
        self.quantityPurchased = quantityPurchased
        self.deleteAllowed = deleteAllowed
        self.editAllowed = editAllowed
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        creationDate = try container.decode(String.self, forKey: .creationDate)
        description = try container.decode(String.self, forKey: .description)
        lastEditDate = try container.decode(String.self, forKey: .lastEditDate)
        link = try container.decode(String.self, forKey: .link)
        name = try container.decode(String.self, forKey: .name)
        price = try container.decode(Double.self, forKey: .price)
        purchaseDate = try container.decodeIfPresent(String.self, forKey: .purchaseDate)
        quantity = try container.decode(Int.self, forKey: .quantity)
        offListItem = try container.decode(Bool.self, forKey: .offListItem)
        purchaseState = try container.decode(PurchaseState.self, forKey: .purchaseState)
        purchasesAllowed = try container.decode(Bool.self, forKey: .purchasesAllowed)
        quantityPurchased = try container.decode(Int.self, forKey: .quantityPurchased)
        deleteAllowed = try container.decode(Bool.self, forKey: .deleteAllowed)
        editAllowed = try container.decode(Bool.self, forKey: .editAllowed)
        
        if let rawValue = try container.decodeIfPresent(Bool.self, forKey: .retractablePurchase) {
            retractablePurchase = rawValue
        }
        id = try container.decode(String.self, forKey: .id)
    }
}

enum PurchaseState:String, Decodable, Comparable {
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
}


struct AllItemsResponse: Decodable {
    let items: [Item]
}

struct UpdatedItemResponse: Decodable {
    let updatedItem: Item
}

struct DeletedItemResponse: Decodable {
    let item: Item
}
