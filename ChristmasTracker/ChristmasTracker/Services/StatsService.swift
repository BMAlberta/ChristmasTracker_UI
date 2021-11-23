//
//  StatsService.swift
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

struct StatsService {
    
    static func getPurchaseStats(_ token: String) -> AnyPublisher<PurchaseStatsResponse, StatsServiceError> {
        
        guard token.count > 0 else {
            return Fail(error: StatsServiceError.unknown)
                .eraseToAnyPublisher()
        }
        
        
        let urlString = Configuration.getUrl(forKey: .stats)
        
        guard let url = URL(string : urlString) else {
            return Fail(error: StatsServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let request = NetworkUtility.createBaseRequest(url: url,
                                                       method: .get,
                                                       token: token)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { StatsServiceError.url(error: $0) }
            .tryMap { element -> Data in
                guard let httpResponse = element.response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return element.data
            }
            .decode(type: NetworkResponse<PurchaseStatsResponse>.self, decoder: JSONDecoder())
            .mapError { StatsServiceError.decoder(error: $0) }
            .map { $0.payload }
            .eraseToAnyPublisher()
    }
}
