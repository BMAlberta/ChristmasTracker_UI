//
//  StatsActionHandler.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/10/25.
//

import Foundation

protocol StatsActionHandling {
    func process(_ action: StatsActions, dispatch: @escaping (any Action) -> Void)
}


struct StatsActionHandler: StatsActionHandling {
    let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding) {
        self.apiService = apiService
    }
    
    func process(_ action: StatsActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
        case .loadStats:
            fatalError("StatsActionHandling: \(action) not implemented")
        case .loadStatsSuccess:
            fatalError("StatsActionHandling: \(action) not implemented")
        case .loadStatsError:
            fatalError("StatsActionHandling: \(action) not implemented")
        }
    }
}
