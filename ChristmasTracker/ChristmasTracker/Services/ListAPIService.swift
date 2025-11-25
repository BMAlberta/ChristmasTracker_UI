//
//  ListAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ListDataProviding {
    func createList(newList: NewListDetails) async throws -> AddListResponse
    func deleteList(listId: String) async throws
    func getHomeFeed() async throws -> AppDataResponse
}


actor ListAPIService: ListDataProviding {
    func getHomeFeed() async throws -> AppDataResponse {
        let urlString = Configuration.getUrl(forKey: .homeFeed)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
//        LogUtility.logNetworkDetails(message: "ListAPIService.getHomeFeed",
//                                     rawData: data)
        let feedResponse = try JSONDecoder().decode(NetworkResponse<AppDataResponse>.self, from: data)
        
        return feedResponse.payload
    }
    
    func createList(newList: NewListDetails) async throws -> AddListResponse {
        let urlString = Configuration.getUrl(forKey: .addList)
        
        guard let url = URL(string: urlString) else {
            throw ListServiceError.invalidURL
        }
        
        let params: [String: AnyHashable] = ["listName": newList.listName,
                                             "listTheme": newList.listTheme]
        
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .post)
        
        let json: [AnyHashable: AnyHashable] = params
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let addListResponse = try JSONDecoder().decode(NetworkResponse<AddListResponse>.self, from: data)
        
        return addListResponse.payload
    }
    
    func deleteList(listId: String) async throws {
        fatalError("ListAPIService: not implemented")
    }
    
    
}
