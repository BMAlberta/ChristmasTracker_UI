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
        
//        let urlString = "http://webdev01.ad.bmalberta.com:3000/xmasList/items/owned"
        let urlString = "http://192.168.0.184:3000/tracker/items/all"
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "auth-token")
        request.httpMethod = "GET"
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ListServiceError.url(error: $0) }
            .map { $0.data }
            .decode(type: NetworkResponse<AllItemsResponse>.self, decoder: JSONDecoder())
            .mapError { ListServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
    }
    
    func addNewItem(token: String, newItem: NewItemModel) -> AnyPublisher<Item, ListServiceError> {
        
//        let urlString = "http://webdev01.ad.bmalberta.com:3000/xmasList/items"
        let urlString = "http://192.168.0.184:3000/tracker/items"
        
        let params: [String: String] = ["name": newItem.name,
                                        "description": newItem.description,
                                        "link": newItem.link,
                                        "price": newItem.price,
                                        "category": newItem.category]
        
        guard let url = URL(string : urlString) else {
            return Fail(error: ListServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "auth-token")
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        
        request.httpBody = jsonData
        request.httpMethod = "POST"
        
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

