//
//  MyListReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation

func ownedListReducer(state: inout OwnedListState, action: ListAction) -> Void {
    
    switch action {
    
    case .fetchData(_):
        state.isFetchError = false
        state.fetchInProgess = true
        
    case .fetchComplete(res: let res):
        state.items = res.items
        state.fetchInProgess = false
        state.isFetchError = false
        
    case .fetchError(_):
        state.fetchInProgess = false
        state.isFetchError = true
        
    case .createItem:
        state.createInProgrees = true
        state.isCreateError = false
        
    case .createComplete:
        state.createInProgrees = false
        state.isCreateError = false
        
    case .createError(_):
        state.createInProgrees = false
        state.isCreateError = true
    }
}
