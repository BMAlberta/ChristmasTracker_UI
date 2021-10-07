//
//  MyListReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation

func ownedListReducer(state: inout ListState, action: ListAction) -> Void {
    
    switch action {
    
    case .fetchOwnedList(_):
        state.isFetchError = false
        state.fetchInProgess = true
        
    case .fetchOwnedListComplete(res: let res):
        state.items = res.items
        state.fetchInProgess = false
        state.isFetchError = false
        
    case .fetchUserList(_,_):
        state.isFetchError = false
        state.fetchInProgess = true
        
    case .fetchUserListComplete(res: let res):
        state.userItems = res.items
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
    
    case .fetchListOverview(token:_):
        state.isFetchError = false
        state.fetchInProgess = true
        
    case .fetchListOverviewComplete(res: let res):
        state.isFetchError = false
        state.fetchInProgess = false
        state.overviews = res.listOverviews
    }
}
