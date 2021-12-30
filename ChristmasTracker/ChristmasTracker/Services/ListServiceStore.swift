//
//  ListServiceStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation
import Combine
import os

enum ListServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
}

actor ListServiceStore {
    static func getOwnedItems(_ token: String) async throws -> AllItemsResponse {
        let urlString = Configuration.getUrl(forKey: .ownedItems)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "ListService.getOwnedItems",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<AllItemsResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "ListService.getOwnedItems",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func getListOverviewByUser(_ token: String) async throws -> UserListOverviewResponse {
        let urlString = Configuration.getUrl(forKey: .itemsGroupedByUser)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.getListOverviewByUser",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<UserListOverviewResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.getListOverviewByUser",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
 
    static func getListForUser(_ token: String, userId: String) async throws -> AllItemsResponse {
        let baseUrlString = Configuration.getUrl(forKey: .itemsForUser)
        let finalUrlString = baseUrlString + userId
        
        guard let url = URL(string: finalUrlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "ListService.getListForUser",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<AllItemsResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.getListForUser",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
        
    }
    
    static func addNewItem(token: String, newItem: NewItemModel) async throws -> NewItemResponse {
        let urlString = Configuration.getUrl(forKey: .addItem)
        
        let params: [String: String] = ["name": newItem.name,
                                        "description": newItem.description,
                                        "link": newItem.link,
                                        "price": newItem.price,
                                        "quantity": newItem.quantity]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .post,
                                                       token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.addNewItem",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<NewItemResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "ListService.addNewItem",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func markItemPurchased(token: String, item: Item) async throws -> UpdatedItemResponse {
        let urlString = Configuration.getUrl(forKey: .markPurchased)
        
        let params: [String: String] = ["itemId": item.id]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "ListService.markItemPurchased",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<UpdatedItemResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.markItemPurchased",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func markItemRetracted(_ token: String, item: Item) async throws -> UpdatedItemResponse {
        let urlString = Configuration.getUrl(forKey: .markRetracted)
        
        let params: [String: String] = ["itemId": item.id]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.markItemRetracted",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<UpdatedItemResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.markItemRetracted",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func updateItem(token: String, item: Item) async throws -> UpdatedItemResponse {
        let baseUrlString = Configuration.getUrl(forKey: .updateItem)
        let finalUrlString = baseUrlString + item.id
        
        guard let url = URL(string: finalUrlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = [
            "name" : item.name,
            "description": item.description,
            "link": item.link,
            "price": item.price,
            "quantity": item.quantity
        ]
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .patch,
                                                       token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.updateItem",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<UpdatedItemResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.updateItem",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func deleteItem(_ token: String, item: Item) async throws -> DeletedItemResponse {
        let baseUrlString = Configuration.getUrl(forKey: .updateItem)
        let finalUrlString = baseUrlString + item.id
        
        guard let url = URL(string: finalUrlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .delete,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.deleteItem",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<DeletedItemResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.deleteItem",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
}
