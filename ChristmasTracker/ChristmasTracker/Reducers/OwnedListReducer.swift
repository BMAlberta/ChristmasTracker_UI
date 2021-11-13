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
        state.userItems = res.items.sorted { !$0.purchased && $1.purchased } 
        state.userIdContext = res.items.first?.createdBy ?? ""
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
        state.overviews = res.listOverviews.sorted{ $0.user.firstName < $1.user.firstName }
        
    case .purchaseItem(_):
        state.isFetchError = false
        state.fetchInProgess = true
        state.purchaseComplete = false
        
    case .purchaseComplete, .retractComplete:
        state.purchaseComplete = true
        state.isFetchError = false
        
    case .retractPurchase(_):
        state.isFetchError = false
        state.purchaseComplete = false
        
    case .updateItem(_,_):
        state.updateInProgress = true
        state.fetchInProgess = false
        state.updateComplete = false
        
    case .updateComplete:
        state.updateInProgress = false
        state.fetchInProgess = false
        state.updateComplete = true
        
    case .deleteItem(_,_):
        state.deleteComplete = false
        state.deleteInProgress = true

    case .deleteComplete:
        state.deleteComplete = true
        state.deleteInProgress = false
    }
}
