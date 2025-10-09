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
        return PurchaseStatsResponse(purchaseStats: [PurchaseStat()])
    }
}
