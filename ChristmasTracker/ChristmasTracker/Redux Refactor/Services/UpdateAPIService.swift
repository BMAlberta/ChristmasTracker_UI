//
//  UpdateAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation
protocol UpdateDataProviding {
    static func fetchUpdateInfo() async throws -> UpdateInfoModelResponse
}


actor UpdateAPIService: UpdateDataProviding {
    static func fetchUpdateInfo() async throws -> UpdateInfoModelResponse {
        let urlString = Configuration.configUrl
        
        guard let url = URL(string: urlString) else {
            throw UpdateServiceError.invalidURL
        }
        
        var request = NetworkUtility.createBaseRequest(url: url, method: .get)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        
        let updateResponse = try JSONDecoder().decode(NetworkResponse<UpdateInfoModelResponse>.self, from: data)
        
        return updateResponse.payload
    }
    
    
}
