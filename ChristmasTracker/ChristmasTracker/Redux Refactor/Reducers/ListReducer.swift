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
            newState.listSummaries = data.listSummaries
        case .loadListOverviews:
            fatalError("listReducer: \(listAction) not implemented")
        case .overviewsLoaded:
            fatalError("listReducer: \(listAction) not implemented")
        case .overviewError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .addList:
            fatalError("listReducer: \(listAction) not implemented")
        case .addListSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .addListError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .deleteList:
            fatalError("listReducer: \(listAction) not implemented")
        case .deleteListSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .updateList:
            fatalError("listReducer: \(listAction) not implemented")
        case .updateListSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .updateListError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .addItem:
            fatalError("listReducer: \(listAction) not implemented")
        case .addItemSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .addItemError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .purchaseItem:
            fatalError("listReducer: \(listAction) not implemented")
        case .purchaseItemSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .purchaseItemError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .retractItem:
            fatalError("listReducer: \(listAction) not implemented")
        case .retractItemSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .retractItemError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .deleteItem:
            fatalError("listReducer: \(listAction) not implemented")
        case .deleteItemSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .deleteItemError(_):
            fatalError("listReducer: \(listAction) not implemented")
        case .updateItem:
            fatalError("listReducer: \(listAction) not implemented")
        case .updateItemSuccess:
            fatalError("listReducer: \(listAction) not implemented")
        case .updateItemError:
            fatalError("listReducer: \(listAction) not implemented")
        case .loadActivity:
            fatalError("listReducer: \(listAction) not implemented")
        case .activityLoaded:
            fatalError("listReducer: \(listAction) not implemented")
        case .activityError(_):
            fatalError("listReducer: \(listAction) not implemented")
        }
    default:
        break
    }
    
    return newState
}
