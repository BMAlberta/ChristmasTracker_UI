//
//  StatsReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation

func statsReducer(state: StatsState, action: any Action) -> StatsState {
    var newState = state
    
    switch action {
    case let statsAction as StatsActions:
        switch statsAction {
        case .loadStats:
            fatalError("statsReducer: \(statsAction) not implemented")
        case .loadStatsSuccess:
            fatalError("statsReducer: \(statsAction) not implemented")
        case .loadStatsError:
            fatalError("statsReducer: \(statsAction) not implemented")
        }
        default :
        break
    }
    
    
    return newState
}
