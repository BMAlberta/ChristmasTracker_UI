//
//  ItemModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation
import Combine

class Item: Decodable, Identifiable, ObservableObject {
    
    var id: String
    var createdBy: String
    var creationDate: String
    var description: String
    var lastEditDate: String
    var link: String
    var name: String
    var price: Double
    @Published var purchased: Bool
    var purchaseDate: String?
    var purchasedBy: String?
    var quantity: Int
    var retractablePurchase: Bool = false
    
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
        self.purchased = false
        self.purchaseDate = ""
        self.purchasedBy = ""
        self.quantity = 0
    }
    
    init(id: String,
         createdBy: String,
         creationDate: String,
         description: String,
         lastEditDate: String,
         link: String,
         name: String,
         price: Double,
         purchased: Bool,
         purchaseDate: String?,
         quantity: Int) {
        self.id = id
        self.createdBy = createdBy
        self.creationDate = creationDate
        self.description = description
        self.lastEditDate = lastEditDate
        self.link = link
        self.name = name
        self.price = price
        self.purchased = purchased
        self.purchaseDate = purchaseDate
        self.quantity = quantity
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
        purchased = try container.decodeIfPresent(Bool.self, forKey: .purchased) ?? false
        purchaseDate = try container.decodeIfPresent(String.self, forKey: .purchaseDate)
        quantity = try container.decode(Int.self, forKey: .quantity)
        if let rawValue = try container.decodeIfPresent(Bool.self, forKey: .retractablePurchase) {
            retractablePurchase = rawValue
        }
        id = try container.decode(String.self, forKey: .id)
    }
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
