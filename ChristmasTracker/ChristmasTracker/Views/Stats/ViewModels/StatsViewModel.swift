//
//  StatsViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/21.
//

import Foundation
import Combine

//class StatsViewModel: ObservableObject {
//    @Published var spentModel = PieChartViewModel()
////    @Published var purchasedModel = BarChartViewModel()
//    @Published var totalAmountSpent = 0.0
//    @Published var isErrorState = false
//    @Published var hasStats = false
//    @Published var isLoading = false
//    private var rawStatsResponse: PurchaseStatsResponse? = nil
//    
//    enum FilterValue: String, CaseIterable, Identifiable {
//        var id: Self { self }
//        
//        case all = "all"
//        case twentyFour = "2024"
//        case twentyThree = "2023"
//        case twentyTwo = "2022"
//        
//        var displayText: String {
//            switch self {
//            case .all:
//                return "All"
//            case .twentyTwo:
//                return "2022"
//            case .twentyThree:
//                return "2023"
//            case .twentyFour:
//                return "2024"
//            }
//        }
//    }
//    
//    private var _session: SessionManaging
//    
//    init(_ session: SessionManaging) {
//        _session = session
//    }
//    
//    @MainActor
//    func getStats(selectedFilterValue: FilterValue) async {
//        self.isLoading = true
//        do {
//            let purchaseStatsResponse: PurchaseStatsResponse = try await StatsServiceStore.getPurchasedStats()
//            self.rawStatsResponse = purchaseStatsResponse
//            processStats(filterValue: selectedFilterValue)
//            self.isLoading = false
//            
//        } catch {
//            self.isLoading = false
//            self.isErrorState = true
//        }
//    }
//    
//    func processStats(filterValue: FilterValue) {
//        guard let model = self.rawStatsResponse else {
//            return
//        }
//        let filteredModel = Self.applyYearFilter(model: model.purchaseStats, filter: filterValue)
//        let spentModel: PieChartViewModel = self.generateStatModel(model: filteredModel)
////        let purchasedModel: BarChartViewModel = self.generateStatModel(model: filteredModel)
//        let totalSpent = self.generateTotalSpent(model: filteredModel)
//        self.spentModel = spentModel
////        self.purchasedModel = purchasedModel
//        self.totalAmountSpent = totalSpent
//        
////        self.hasStats = spentModel.detail.count > 0 && self.purchasedModel.detail.count > 0
//    }
//    
//    private static func applyYearFilter(model: [PurchaseStat], filter: FilterValue) -> [PurchaseStat] {
//        switch filter {
//        case .all:
//            return model
//        default:
//            return model.filter { $0.purchaseYear == filter.rawValue }
//        }
//    }
//    
//    private func generateStatModel(model: [PurchaseStat]) -> PieChartViewModel {
//        
//        let viewModel = PieChartViewModel()
//        for item in model {
//            var tempModel = viewModel.detail[item.ownerInfo.firstName] ?? 0.0
//            tempModel += item.totalSpent
//            viewModel.detail[item.ownerInfo.firstName] = tempModel
//        }
//        return viewModel
//    }
//    
//    private func generateStatModel(model: [PurchaseStat]) -> BarChartViewModel {
//        let viewModel = BarChartViewModel()
//        for item in model {
//            var tempModel = viewModel.detail[item.ownerInfo.firstName] ?? 0
//            tempModel += Double(item.purchasedItems)
//            viewModel.detail[item.ownerInfo.firstName] = tempModel
//        }
//        return viewModel
//    }
//    
//    private func generateTotalSpent(model: [PurchaseStat]) -> Double {
//        var runningTotal = 0.0
//        
//        for item in model {
//            runningTotal += item.totalSpent
//        }
//        
//        return runningTotal
//    }
//}



