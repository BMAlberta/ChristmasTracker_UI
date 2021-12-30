//
//  StatsViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/21.
//

import Foundation
import Combine

class StatsViewModel: ObservableObject {
    @Published var spentModel = PieChartViewModel()
    @Published var purchasedModel = BarChartViewModel()
    @Published var totalAmountSpent = 0.0
    @Published var isErrorState = false
    @Published var hasStats = true
    @Published var isLoading = false
    
    private var _session: SessionManaging
    
    init(_ session: SessionManaging) {
        _session = session
    }
    
    @MainActor
    func getStats() async {
        self.isLoading = true
        do {
            let purchaseStatsResponse: PurchaseStatsResponse = try await StatsServiceStore.getPurchasedStats(_session.token)
        
            let spentModel: PieChartViewModel = self.generateStatModel(model: purchaseStatsResponse.spentOverviews)
            let purchasedModel: BarChartViewModel = self.generateStatModel(model: purchaseStatsResponse.spentOverviews)
            let totalSpent = self.generateTotalSpent(model: purchaseStatsResponse.spentOverviews)
            self.spentModel = spentModel
            self.purchasedModel = purchasedModel
            self.totalAmountSpent = totalSpent
            
            self.hasStats = spentModel.detail.count > 0 && self.purchasedModel.detail.count > 0
            self.isLoading = false
            
        } catch {
            self.isLoading = false
            self.isErrorState = true
        }
    }
    
    
    private func generateStatModel(model: [PurchaseStat]) -> PieChartViewModel {
        
        let viewModel = PieChartViewModel()
        for item in model {
            viewModel.detail[item.user.firstName] = item.totalSpent
        }
        return viewModel
    }
    
    private func generateStatModel(model: [PurchaseStat]) -> BarChartViewModel {
        let viewModel = BarChartViewModel()
        for item in model {
            viewModel.detail[item.user.firstName] = Double(item.purchasedItems)
        }
        return viewModel
    }
    
    private func generateTotalSpent(model: [PurchaseStat]) -> Double {
        var runningTotal = 0.0
        
        for item in model {
            runningTotal += item.totalSpent
        }
        
        return runningTotal
    }
}



