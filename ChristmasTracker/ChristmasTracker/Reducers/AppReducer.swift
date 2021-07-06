//
//  AppReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/17/21.
//

import Foundation

typealias Reducer<State, Action> = (inout State, Action) -> Void

func appReducer(state: inout AppState, action: AppAction) -> Void {
   
    switch action {
    
    case .auth(let action):
        authReducer(state: &state.auth, action: action)
        
    case .list(action: let action):
        ownedListReducer(state: &state.ownedList, action: action)
    }
}
