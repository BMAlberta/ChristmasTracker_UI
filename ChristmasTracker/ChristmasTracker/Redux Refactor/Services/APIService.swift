//
//  APIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/2/25.
//

import Foundation

protocol APIServiceProviding {
    var userAPI: UserDataProviding { get }
    var listAPI: ListDataProviding { get }
    var itemAPI: ItemDataProviding { get }
    var statsAPI: StatsDataProviding { get }
    var updateAPI: UpdateDataProviding { get }
}

final class APIService: APIServiceProviding {
    var userAPI: any UserDataProviding
    var listAPI: any ListDataProviding
    var itemAPI: any ItemDataProviding
    var statsAPI: any StatsDataProviding
    var updateAPI: any UpdateDataProviding
    
    init() {
        self.userAPI = UserAPIService()
        self.itemAPI = ItemAPIService()
        self.listAPI = ListAPIService()
        self.statsAPI = StatsAPIService()
        self.updateAPI = UpdateAPIService()
    }
    
    static func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 400:
            throw APIError.badRequest
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.generic(httpResponse.statusCode)
        }
    }
}
