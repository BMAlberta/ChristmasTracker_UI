//
//  StatsViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/13/25.
//

import Foundation
import Combine

typealias StatsTotals = (totalItems: Int, totalSpend: Double)

struct SpendingListDetails: Identifiable, Equatable {
    let id: String
    let listName: String
    let totalSpend: Double
    let totalItems: Int
    let percentageSpend: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "listId"
        case listName
        case totalSpend
        case totalItems
        case percentageSpend
    }
}

class StatsViewModel: ObservableObject {
    @Published var totalAmountSpent = 0.0
    @Published var numberOfPurchases: Int = 0
    @Published var averageSpend: Double = 0.0
    @Published var isErrorState = false
    @Published var hasStats = false
    @Published var isLoading = false
    @Published var listSpendDetails: [SpendingListDetails] = []
    private var rawStatsResponse: PurchaseStatsResponse? = nil
    
    enum FilterValue: String, CaseIterable, Identifiable {
        var id: Self { self }
        
        case all = "all"
        case twentyFive = "2025"
        case twentyFour = "2024"
        case twentyThree = "2023"
        case twentyTwo = "2022"
        
        var displayText: String {
            switch self {
            case .all:
                return "All"
            case .twentyTwo:
                return "2022"
            case .twentyThree:
                return "2023"
            case .twentyFour:
                return "2024"
            case .twentyFive:
                return "2024"
            }
        }
    }
    
    @MainActor
    func getStats() async {
        self.isLoading = true
        do {
            let purchaseStatsResponse: PurchaseStatsResponse = try await StatsAPIService().getPurchaseStats()
            self.rawStatsResponse = purchaseStatsResponse
            processStats()
            self.isLoading = false
            
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    func processStats(filterValue: FilterValue = .twentyFive) {
        guard let model = self.rawStatsResponse else {
            return
        }
        let filteredModel = Self.applyYearFilter(model: model.purchaseStats, filter: filterValue)
        
        let totals = Self.generateTotals(model: filteredModel)
        self.totalAmountSpent = totals.totalSpend
        self.numberOfPurchases = totals.totalItems
        self.averageSpend = Self.generateAverageSpend(statsTotals: totals)
        self.listSpendDetails = Self.generateSpendingDetails(model: filteredModel, statsTotals: totals)
        self.hasStats = self.listSpendDetails.count > 0
        
    }
    
    private static func applyYearFilter(model: [PurchaseStat], filter: FilterValue) -> [PurchaseStat] {
        switch filter {
        case .all:
            return model
        default:
            return model.filter { $0.purchaseYear == filter.rawValue }
        }
    }
    
    private func generateTotalSpent(model: [PurchaseStat]) -> Double {
        var runningTotal = 0.0
        
        for item in model {
            runningTotal += item.totalSpent
        }
        
        return runningTotal
    }
    
    private static func generateTotals(model: [PurchaseStat]) -> StatsTotals {
        var runningTotalSpent = 0.0
        var runningTotalPurchases = 0
        
        for item in model {
            runningTotalSpent += item.totalSpent
            runningTotalPurchases += item.itemPurchased
        }
        return StatsTotals(totalItems: runningTotalPurchases, totalSpend: runningTotalSpent)
    }
    
    private static func generateAverageSpend(statsTotals: StatsTotals) -> Double {
        return statsTotals.totalSpend / Double(statsTotals.totalItems)
    }
    
    private static func generateSpendingDetails(model: [PurchaseStat], statsTotals: StatsTotals) -> [SpendingListDetails] {
        var details: [SpendingListDetails] = []
        
        for stat in model {
            let percentageSpend = (stat.totalSpent / statsTotals.totalSpend)
            let detail = SpendingListDetails(id: stat.listId,
                                             listName: stat.listName,
                                             totalSpend: stat.totalSpent,
                                             totalItems: stat.itemPurchased,
                                             percentageSpend: percentageSpend)
            details.append(detail)
        }
        return details
    }
}
