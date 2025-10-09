//
//  StatsActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/6/25.
//

import Foundation
enum StatsActions: Action {
    case loadStats
    case loadStatsSuccess
    case loadStatsError
    
    
    var type: String {
        switch self {
        case .loadStats: "STATS_LOAD"
        case .loadStatsSuccess: "STATS_LOAD_SUCCESS"
        case .loadStatsError: "STATS_LOAD_ERROR"
        }
    }
}
