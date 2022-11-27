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
    static func getOwnedItems() async throws -> OwnedListResponse {
        let urlString = Configuration.getUrl(forKey: .ownedLists)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get)
        
        do {
            let (data, response) = try await ServiceCache.shared.fetchNetworkResponse(request: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "ListService.getOwnedItems",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<OwnedListResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "ListService.getOwnedItems",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func getListOverviewByUser() async throws -> ListOverviewResponse {
        let urlString = Configuration.getUrl(forKey: .itemsGroupedByUser)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get)
        
        do {
            let (data, response) = try await ServiceCache.shared.fetchNetworkResponse(request: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.getListOverviewByUser",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<ListOverviewResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.getListOverviewByUser",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
 
    static func getList(listId: String) async throws -> ListDetailModel {
        let baseUrlString = Configuration.getUrl(forKey: .listForId)
        let finalUrlString = baseUrlString + listId
        
        guard let url = URL(string: finalUrlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get)
        
        do {
            let (data, response) = try await ServiceCache.shared.fetchNetworkResponse(request: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            LogUtility.logNetworkDetails(message: "ListService.getListbyId",
                                         rawData: data)
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<ListDetailResponse>.self, from: data)
            return rawData.payload.detail
            
        } catch {
            LogUtility.logServiceError(message: "ListService.getListbyId",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
        
    }
    
    static func addNewItem(toList listInContext: String, newItem: NewItemModel) async throws -> ListDetailResponse {
        let urlString = Configuration.getUrl(forKey: .addItem)
        
        let params: [String: String] = ["name": newItem.name,
                                        "description": newItem.description,
                                        "link": newItem.link,
                                        "price": newItem.price,
                                        "quantity": newItem.quantity,
                                        "listId": listInContext]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.addNewItem",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<ListDetailResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "ListService.addNewItem",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func addNewList(newList: String) async throws -> ListDetailResponse {
        let urlString = Configuration.getUrl(forKey: .addList)
        
        let params: [String: String] = ["listName": newList]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.addNewList",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<ListDetailResponse>.self, from: data)
            return rawData.payload
        } catch {
            LogUtility.logServiceError(message: "ListService.addNewList",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func markItemPurchased(listId: String, itemInContext: Item) async throws -> ListDetailResponse {
        let urlString = Configuration.getUrl(forKey: .markPurchased)
        
        let params: [String: String] = ["listId" : listId,
                                        "itemId": itemInContext.id]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post)
        
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
            let model = try decoder.decode(NetworkResponse<ListDetailResponse>.self, from: data)
            return model.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.markItemPurchased",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func markItemRetracted(listId: String, itemInContext: Item) async throws -> ListDetailResponse  {
        let urlString = Configuration.getUrl(forKey: .markRetracted)
        
        let params: [String: String] = ["listId" : listId,
                                        "itemId": itemInContext.id]
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post)
        
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
            let rawData = try decoder.decode(NetworkResponse<ListDetailResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "ListService.markItemRetracted",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func updateItem(item: Item) async throws -> UpdatedItemResponse {
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
                                                       method: .patch)
        
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
    
    static func deleteItem(fromList listId: String, item: Item) async throws -> Void {
        let baseUrlString = Configuration.getUrl(forKey: .deleteItem)
        let finalUrlString = baseUrlString + listId
        
        guard let url = URL(string: finalUrlString)?.appending(queryItems: [URLQueryItem(name: "itemId", value: item.id)]) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .delete)
                
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.deleteItem",
                                         rawData: data)
            return
            
        } catch {
            LogUtility.logServiceError(message: "ListService.deleteItem",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
    
    static func deleteList(listId: String) async throws -> Void {
        let baseUrlString = Configuration.getUrl(forKey: .listForId)
        let finalUrlString = baseUrlString + listId
        
        guard let url = URL(string: finalUrlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .delete)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ListServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "ListService.deleteList",
                                         rawData: data)
            return
            
        } catch {
            LogUtility.logServiceError(message: "ListService.deleteList",
                                       error: ListServiceError.decoder(error: error))
            throw ListServiceError.decoder(error: error)
        }
    }
}
