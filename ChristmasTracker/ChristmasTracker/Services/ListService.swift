//
//  ListService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation
import Combine

enum ListServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
}

struct ListService {
    
    func getOwnedItems(_ token: String) -> AnyPublisher<AllItemsResponse, ListServiceError> {
        
        guard token.count > 0 else {
            return Fail(error: ListServiceError.unknown)
                .eraseToAnyPublisher()
        }
        
        
//        let urlString = "http://127.0.0.1:3000/tracker/items/owned"
        let urlString = Configuration.getUrl(forKey: .ownedItems)
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .get,
                                                  token: token)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map {
                let stringData: String = String(data: $0.data, encoding: String.Encoding.utf8)!
                print(stringData)
                return $0.data }
            .decode(type: NetworkResponse<AllItemsResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
    }
    
    
    func getListOverviewByUser(_ token: String) -> AnyPublisher<UserListOverviewResponse, ListServiceError> {
//        let urlString = "http://127.0.0.1:3000/tracker/items/groupedByUser"
        let urlString = Configuration.getUrl(forKey: .itemsGroupedByUser)
        
        guard let url = URL(string: urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .get,
                                                  token: token)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map {
                let stringData: String = String(data: $0.data, encoding: String.Encoding.utf8)!
                print(stringData)
                return $0.data
            }
            .decode(type: NetworkResponse<UserListOverviewResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
    }
    
    func getListForUser(_ token: String, userId: String) -> AnyPublisher<AllItemsResponse, ListServiceError> {
//        let baseUrlString = "http://127.0.0.1:3000/tracker/items/user/"
        let baseUrlString = Configuration.getUrl(forKey: .itemsForUser)
        let finalUrlString = baseUrlString + userId
        
        guard let url = URL(string: finalUrlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .get,
                                                  token: token)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map {
                let stringData: String = String(data: $0.data, encoding: String.Encoding.utf8)!
                print(stringData)
                return $0.data
            }
            .decode(type: NetworkResponse<AllItemsResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
        
    }
 
    func addNewItem(token: String, newItem: NewItemModel) -> AnyPublisher<Item, ListServiceError> {
        
//        let urlString = "http://127.0.0.1:3000/tracker/items"
        let urlString = Configuration.getUrl(forKey: .addItem)
        
        let params: [String: String] = ["name": newItem.name,
                                        "description": newItem.description,
                                        "link": newItem.link,
                                        "price": newItem.price]
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<NewItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.newItem }
            .eraseToAnyPublisher()
    }
    
    
    func markItemPurchased(token: String, item: Item) -> AnyPublisher<Item, ListServiceError> {
        
//        let urlString = "http://127.0.0.1:3000/tracker/purchases"
        let urlString = Configuration.getUrl(forKey: .markPurchased)
        
        let params: [String: String] = ["itemId": item.id]
        
        guard let url = URL(string: urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<UpdatedItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.updatedItem }
            .eraseToAnyPublisher()
    }
    
    func markItemRetracted(token: String, item: Item) -> AnyPublisher<Item, ListServiceError> {
        
//        let urlString = "http://127.0.0.1:3000/tracker/purchases/retract"
        let urlString = Configuration.getUrl(forKey: .markRetracted)
        
        let params: [String: String] = ["itemId": item.id]
        
        guard let url = URL(string: urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        
        var request = NetworkUtility.createBaseRequest(url: url,
                                                  method: .post,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<UpdatedItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.updatedItem }
            .eraseToAnyPublisher()
    }
    
    func updateItem(token: String, item: Item) -> AnyPublisher<Item, ListServiceError> {
        let baseUrlString = Configuration.getUrl(forKey: .updateItem)
        let finalUrlString = baseUrlString + item.id
        
        guard let url = URL(string: finalUrlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
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
        
        return URLSession.shared
            .dataTaskPublisher(for: url)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<UpdatedItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.updatedItem }
            .eraseToAnyPublisher()
    }
    
    func deleteItem(token: String, item: Item) -> AnyPublisher<Item, ListServiceError> {
        let baseUrlString = Configuration.getUrl(forKey: .updateItem)
        let finalUrlString = baseUrlString + item.id
        
        guard let url = URL(string: finalUrlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .delete,
                                                       token: token)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<DeletedItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.item }
            .eraseToAnyPublisher()
    }
}
