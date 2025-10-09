//
//  ActivityReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation

func activityReducer(state: ActivityState, action: any Action) -> ActivityState {
    var newState = state
    
    switch action {
    case let activityAction as ActivityActions:
        switch activityAction {
        
        case .loadActivity:
            fatalError("activityReducer: \(activityAction) not implemented")
        case .activityLoaded:
            fatalError("activityReducer: \(activityAction) not implemented")
        case .activityError(_):
            fatalError("activityReducer: \(activityAction) not implemented")
        }
    default:
        break
    }
    
    return newState
    
    
}
