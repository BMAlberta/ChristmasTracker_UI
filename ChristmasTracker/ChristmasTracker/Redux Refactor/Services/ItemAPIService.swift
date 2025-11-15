//
//  ItemAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ItemDataProviding {
    
    func addNewItem(toList listInContext: String, newItem: NewItemDetails) async throws -> AddItemResponse
    func markItemPurchased(listId: String, itemInContext: String, quantityPurchased: Int, purchasePrice: Double) async throws -> ItemPurchaseResponse
    func markItemRetracted(listId: String, itemId: String) async throws
    func updateItem(listInContext: String, updatedItem: NewItemDetails) async throws -> AddItemResponse
    func deleteItem(listId: String, itemId: String) async throws
    
}

actor ItemAPIService: ItemDataProviding {
    func addNewItem(toList listInContext: String, newItem: NewItemDetails) async throws -> AddItemResponse {
        let urlString = Configuration.getUrl(forKey: .addItem)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = ["name": newItem.itemName,
                                             "description": newItem.itemDescription,
                                             "link": newItem.itemLink,
                                             "price": newItem.itemPrice,
                                             "quantity": newItem.itemQuantity,
                                             "priority": newItem.itemPriority,
                                             "listId": listInContext,
                                             "imageUrl": newItem.itemImageUrl]
        
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let itemResponse = try JSONDecoder().decode(NetworkResponse<AddItemResponse>.self, from: data)
        
        return itemResponse.payload
    }
    
    
    func markItemPurchased(listId: String, itemInContext: String, quantityPurchased: Int, purchasePrice: Double) async throws -> ItemPurchaseResponse {
        let urlString = Configuration.getUrl(forKey: .markPurchased)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = ["listId": listId,
                                             "itemId": itemInContext,
                                             "quantityPurchased": quantityPurchased,
                                             "purchasePrice": purchasePrice]
        
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let purchaseResponse = try JSONDecoder().decode(NetworkResponse<ItemPurchaseResponse>.self, from: data)
        
        return purchaseResponse.payload
        
    }
    
    func markItemRetracted(listId: String, itemId: String) async throws {
        let urlString = Configuration.getUrl(forKey: .markRetracted)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = ["listId": listId,
                                             "itemId": itemId]
        
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        return
    }
    
    func updateItem(listInContext: String, updatedItem: NewItemDetails) async throws -> AddItemResponse {
        
        let urlString = Configuration.getUrl(forKey: .updateItem)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = ["name": updatedItem.itemName,
                                             "description": updatedItem.itemDescription,
                                             "link": updatedItem.itemLink,
                                             "price": updatedItem.itemPrice,
                                             "quantity": updatedItem.itemQuantity,
                                             "priority": updatedItem.itemPriority,
                                             "listId": listInContext,
                                             "imageUrl": updatedItem.itemImageUrl]
        
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let itemResponse = try JSONDecoder().decode(NetworkResponse<AddItemResponse>.self, from: data)
        
        return itemResponse.payload
        
        
    }
    
    func deleteItem(listId: String, itemId: String) async throws {
        
        let baseUrlString = Configuration.getUrl(forKey: .deleteItem)
        let finalUrlString = baseUrlString + listId
        
        guard let url = URL(string: finalUrlString)?.appending(queryItems: [URLQueryItem(name: "itemId", value: itemId)]) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .delete)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let _ = try JSONDecoder().decode(NetworkResponse<ItemPurchaseResponse>.self, from: data)
        
        return
    }
    
    
}
