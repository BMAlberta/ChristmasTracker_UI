//
//  UpdateAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation
protocol UpdateDataProviding {
    func fetchUpdateInfo() async throws -> UpdateInfoModelResponse
}


actor UpdateAPIService: UpdateDataProviding {
    func fetchUpdateInfo() async throws -> UpdateInfoModelResponse {
        let urlString = Configuration.configUrl
        
        guard let url = URL(string: urlString) else {
            throw UpdateServiceError.invalidURL
        }
        
        let request = NetworkUtility.createBaseRequest(url: url, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        let updateResponse = try JSONDecoder().decode(UpdateInfoModelResponse.self, from: data)
        
        return updateResponse
    }
}
