//
//  StatsServiceStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/21.
//

import Foundation
import Combine
import os

enum StatsServiceError: Error {
    case networkError
    case unknown
    case invalidURL
    case decoder(error: Error)
    case url(error: URLError)
}

actor StatsServiceStore {
    static func getPurchasedStats(_ token: String) async throws -> PurchaseStatsResponse {
        
        guard token.count > 0 else {
            throw StatsServiceError.unknown
        }
        
        let urlString = Configuration.getUrl(forKey: .stats)
        
        guard let url = URL(string: urlString) else {
            throw StatsServiceError.invalidURL
        }
                
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw StatsServiceError.networkError
            }
            
            LogUtility.logNetworkDetails(message: "StatsServiceStore.getPurchaseStats",
                                         rawData: data)
            
            let decoder = JSONDecoder()
            let rawData = try decoder.decode(NetworkResponse<PurchaseStatsResponse>.self, from: data)
            return rawData.payload
            
        } catch {
            LogUtility.logServiceError(message: "StatsServiceStore.getPurchaseStats",
                                       error: StatsServiceError.decoder(error: error))
            throw StatsServiceError.decoder(error: error)
        }
    }
}
