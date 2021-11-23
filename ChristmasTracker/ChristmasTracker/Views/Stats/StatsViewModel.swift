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
    @Published var isErrorState = false
    @Published var hasStats = false
    @Published var isLoading = false
    private var subscriptions = Set<AnyCancellable>()
    private var _store: AppStore
    
    init(_ store: AppStore) {
        _store = store
    }
    
    func getStats() {
        self.isLoading = true
        StatsService.getPurchaseStats(_store.state.auth.token)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error.localizedDescription)
                    self.isErrorState = true
                    self.isLoading = false
                default: break
                }
            }, receiveValue: { response in
                print(response)
                self.spentModel = self.generateStatModel(model: response.spentOverviews)
                self.purchasedModel = self.generateStatModel(model: response.spentOverviews)
                self.hasStats = self.spentModel.detail.count > 0 && self.purchasedModel.detail.count > 0
                self.isLoading = false
            })
            .store(in: &subscriptions)
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
}



