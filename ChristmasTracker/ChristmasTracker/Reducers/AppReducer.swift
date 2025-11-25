//
//  AppReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

func appReducer(state: AppState, action: any Action) -> AppState {
    var newState = state
    
    newState.user = userReducer(state: state.user, action: action)
    newState.list = listReducer(state: state.list, action: action)
    newState.ui = uiReducer(state: state.ui, action: action)
    newState.activity = activityReducer(state: state.activity, action: action)
    newState.ui = uiReducer(state: state.ui, action: action)
    
    return newState
}
