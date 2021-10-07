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

struct Utilities {
    
    enum RequestType: String {
        case get = "GET"
        case post = "POST"
    }
    
    static func createBaseRequest(url: URL, method: RequestType, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "auth-token")
        request.httpMethod = method.rawValue
        
        return request
    }
}

struct ListService {
    
    func getOwnedItems(_ token: String) -> AnyPublisher<AllItemsResponse, ListServiceError> {
        
        let urlString = "http://127.0.0.1:3000/tracker/items/owned"
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = Utilities.createBaseRequest(url: url,
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
        let urlString = "http://127.0.0.1:3000/tracker/items/groupedByUser"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = Utilities.createBaseRequest(url: url,
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
        let baseUrlString = "http://127.0.0.1:3000/tracker/items/user/"
        let finalUrlString = baseUrlString + userId
        
        guard let url = URL(string: finalUrlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = Utilities.createBaseRequest(url: url,
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
        
        let urlString = "http://127.0.0.1:3000/tracker/items"
        
        let params: [String: String] = ["name": newItem.name,
                                        "description": newItem.description,
                                        "link": newItem.link,
                                        "price": newItem.price,
                                        "category": newItem.category]
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = Utilities.createBaseRequest(url: url,
                                                  method: .get,
                                                  token: token)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map {
                print($0)
                return $0.data }
            .decode(type: NetworkResponse<NewItemResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload.newItem }
            .eraseToAnyPublisher()
    }
}
