//
//  Models.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/15/21.
//

import Foundation
import SwiftUI
import Combine

enum ListError: Error {
    case invalidURL
    case url(error: URLError)
    case decoder(error: Error)
}

struct User: Codable {
    let pwd: String
    let role: Int
    let lastLogInLocation: String
    let _id: String
    let email: String
    let firstName: String
    let lastName: String
    let creationDate: String //Date
    let lastLogInDate: String
    let __v: Int
}

struct SlimUser: Decodable {
    let firstName: String
    let lastName: String
    let rawId: String
}

struct LoginResponse: Decodable {
    let token: String
}

struct Credentials: Codable {
    let username: String
    let password: String
}

struct AllUsersResponse: Decodable {
    let users: [User]
}

struct AllItemsResponse: Decodable {
    let items: [Item]
}

struct NewItemResponse: Decodable {
    let newItem: Item
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

struct Item: Codable, Identifiable {
    
    var id: String
    let createdBy: String
    let creationDate: String
    let description: String
    var lastEditDate: String
    let link: String
    let name: String
    let price: Double
    let purchased: Bool
    let purchaseDate: String?
    let quantity: Int
    let retractablePurchase: Bool = false
    let __v: Int
    
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
        case id = "_id"
        case __v
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
        print("Saving the item")
        print("Name: \(name)\nDescription: \(description)\nLink: \(link)\nPrice: \(price)\nQuantity: \(quantity)\nCategory: \(category)")
    }
}
