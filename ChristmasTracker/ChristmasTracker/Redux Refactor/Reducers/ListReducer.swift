//
//  ListReducer.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

func listReducer(state: ListState, action: any Action) -> ListState {
    var newState = state
    
    switch action {
    case let listAction as ListActions:
        switch listAction {
        case .loadHomeFeed:
            newState.isLoading = true
            newState.error = nil
            break
            
        case .homeFeedLoaded(let data):
            newState.isLoading = false
            newState.error = nil
            newState.listSummaries = data.listOverviews

        case .addList:
            newState.isLoading = true
            newState.error = nil
            newState.addListInProgress = true
            newState.addListSuccess = false
            
        case .addListSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.addListSuccess = true
            newState.addListInProgress = false
            
        case .addListError(let error):
            newState.isLoading = false
            newState.error = error
            newState.addListSuccess = false
            newState.addListSuccess = false
            
        case .addListFlowComplete:
            newState.isLoading = false
            newState.addListSuccess = false
            newState.addListInProgress = false
            newState.error = nil
            
        case .deleteList:
            newState.isLoading = true
            newState.error = nil
            newState.deleteListSuccess = false
            
        case .deleteListSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.deleteListSuccess = true
            
        case .viewListDetails(let list):
            newState.listIdInContext = list
            
        case .resetListDetails:
            newState.listIdInContext = ""
            
        case .addItem(_,_):
            newState.isLoading = true
            newState.error = nil
            newState.addItemInProgress = true
            
        case .addItemSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.addItemSuccess = true
            newState.addItemInProgress = false
            
        case .addItemError(let error):
            newState.isLoading = false
            newState.error = error
            newState.addItemSuccess = false
            newState.addItemInProgress = false
            
        case .addItemFlowComplete:
            newState.isLoading = false
            newState.addItemSuccess = false
            newState.addItemInProgress = false
            newState.error = nil
            
        case .purchaseItem(_, _, _, _):
            newState.isLoading = true
            newState.purchaseSuccess = false
            newState.error = nil
            
        case .purchaseItemSuccess:
            newState.isLoading = false
            newState.purchaseSuccess = true
            newState.error = nil
            
        case .purchaseItemError(let error):
            newState.isLoading = false
            newState.purchaseSuccess = false
            newState.error = error
            
        case .purchaseFlowComplete:
            newState.isLoading = false
            newState.purchaseSuccess = false
            newState.retractedPurchaseSuccess = false
            newState.error = nil
            
        case .retractItem(_,_):
            newState.isLoading = true
            newState.retractedPurchaseSuccess = false
            newState.error = nil
            
        case .retractItemSuccess:
            newState.isLoading = false
            newState.retractedPurchaseSuccess = true
            newState.error = nil
            
        case .retractItemError(let error):
            newState.isLoading = false
            newState.retractedPurchaseSuccess = false
            newState.error = error
            
        case .deleteItem:
            newState.isLoading = true
            newState.error = nil
            
        case .deleteItemSuccess:
            newState.isLoading = false
            newState.error = nil
            
        case .deleteItemError(let error):
            newState.isLoading = false
            newState.error = error
            
        case .updateItem:
            newState.isLoading = true
            newState.error = nil
            
        case .updateItemSuccess:
            newState.isLoading = false
            newState.error = nil
            newState.updateItemSuccess = true
            
        case .updateItemError(let error):
            newState.isLoading = false
            newState.error = error
            newState.updateItemSuccess = false
            
        case .updateItemFlowComplete:
            newState.isLoading = false
            newState.updateItemSuccess = false
            newState.error = nil
            
        case .loadActivity:
            newState.isLoading = true
            newState.error = nil
            
        case .activityLoaded:
            newState.isLoading = false
            newState.error = nil
            
        case .activityError(let error):
            newState.isLoading = false
            newState.error = error
        }
    default:
        break
    }
    
    return newState
}
