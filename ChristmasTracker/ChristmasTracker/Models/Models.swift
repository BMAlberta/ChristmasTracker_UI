//
//  Models.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import SwiftUI
import Combine
import os

enum ListError: Error {
    case invalidURL
    case url(error: URLError)
    case decoder(error: Error)
}

struct User: Codable {
    let _id: String
    let lastLogInLocation: String
    let email: String
    let firstName: String
    let lastName: String
    let creationDate: String //Date
    let lastLogInDate: String
    let lastPasswordChange: String
}

struct ChangePasswordModel: Codable {
    var oldPassword: String = ""
    var newPassword: String = ""
    var newPasswordConfirmation: String = ""
}

struct SlimUser: Decodable {
    let firstName: String
    let lastName: String
    let rawId: String
}

struct LoginResponse: Decodable {
    let token: String
}

struct PasswordResetResponse: Decodable {
    let userId: String
}

struct Credentials: Codable {
    let username: String
    let password: String
}

struct AllUsersResponse: Decodable {
    let users: [User]
}

struct CurrentUserResponse: Decodable {
    let user: User
}

struct AllItemsResponse: Decodable {
    let items: [Item]
}

struct NewItemResponse: Decodable {
    let newItem: Item
}

struct UpdatedItemResponse: Decodable {
    let updatedItem: Item
}

struct DeletedItemResponse: Decodable {
    let item: Item
}

struct UserListOverviewResponse: Decodable {
    let listOverviews: [ListOverview]
}

struct ListOverview: Decodable, Identifiable {
    let user: SlimUser
    let totalItems: Int
    let purchasedItems: Int
    var id: String
    
    enum CodingKeys: String, CodingKey {
        case user
        case totalItems
        case purchasedItems
        case id = "_id"
    }
}

struct NetworkResponse<T: Decodable>: Decodable {
    let error: ErrorResponse
    let payload: T
    
}
struct ErrorResponse: Decodable {
    let message: String?
}

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
    var __v: Int
    
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
        case __v
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
        self.__v = 0
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
         quantity: Int,
         v: Int) {
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
        self.__v = v
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
        purchased = try container.decode(Bool.self, forKey: .purchased)
        purchaseDate = try container.decode(String.self, forKey: .purchaseDate)
        quantity = try container.decode(Int.self, forKey: .quantity)
        retractablePurchase = ((try? container.decode(Bool.self, forKey: .retractablePurchase)) != nil)
        id = try container.decode(String.self, forKey: .id)
        __v = try container.decode(Int.self, forKey: .__v)
    }
}

class NewItemModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var link: String = ""
    @Published var price: String = ""
    @Published var quantity: String = ""
    @Published var category: String = ""
    
    
    func saveItem() {
        os_log("Saving the item")
        os_log("Name: \(self.name)\nDescription: \(self.description)\nLink: \(self.link)\nPrice: \(self.price)\nQuantity: \(self.quantity)\nCategory: \(self.category)")
    }
}
