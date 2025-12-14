//
//  StatsAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/2/25.
//

import Foundation

protocol StatsDataProviding {
    func getPurchaseStats() async throws -> PurchaseStatsResponse
}

actor StatsAPIService: StatsDataProviding {
    func getPurchaseStats() async throws -> PurchaseStatsResponse {
        let urlString = Configuration.getUrl(forKey: .stats)
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidRequest
        }
        
        let request = NetworkUtility.createBaseRequest(url: url, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try APIService.validateResponse(response)
        do {
            let statsResponse = try JSONDecoder().decode(NetworkResponse<PurchaseStatsResponse>.self, from: data)
            return statsResponse.payload
        } catch (let error) {
            print(error)
            throw APIError.badRequest
        }
        
        
        
        
    }
}
