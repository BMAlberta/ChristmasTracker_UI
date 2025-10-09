//
//  ListActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

enum ListActions: ListAction {
    // Overviews
    case loadListOverviews
//    case filterListOverviews
    case overviewsLoaded
    case overviewError(Error)
    
    // List Details
    case addList
    case addListSuccess
    case addListError(Error)
    case deleteList
    case deleteListSuccess
    case updateList
    case updateListSuccess
    case updateListError(Error)
    case addItem
    case addItemSuccess
    case addItemError(Error)
    case purchaseItem
    case purchaseItemSuccess
    case purchaseItemError(Error)
    case retractItem
    case retractItemSuccess
    case retractItemError(Error)
    case deleteItem
    case deleteItemSuccess
    case deleteItemError(Error)
    case updateItem
    case updateItemSuccess
    case updateItemError
    
    case loadActivity
    case activityLoaded
    case activityError(Error)
    
    case loadHomeFeed
    case homeFeedLoaded(HomeOverview)
    
    
    var type: String {
        switch self {
        case .loadHomeFeed: "LIST_LOAD_HOME_FEED"
        case .homeFeedLoaded: "LIST_HOME_FEED_LOADED"
        case .loadListOverviews: "LIST_LOAD_OVERVIEWS"
        case .overviewsLoaded: "LIST_OVERVIEWS_LOADED"
        case .overviewError: "LIST_OVERVIEWS_ERROR"
        case .addList: "LIST_ADD"
        case .addListSuccess: "LIST_ADD_SUCCESS"
        case .addListError: "LIST_ADD_ERROR"
        case .deleteList: "LIST_DELETE"
        case .deleteListSuccess: "LIST_DELETE_SUCCESS"
        case .updateList: "LIST_UPDATE"
        case .updateListSuccess: "LIST_UPDATE_SUCCESS"
        case .updateListError: "LIST_UPDATE_ERROR"
        case .addItem: "LIST_ADD_ITEM"
        case .addItemSuccess: "LIST_ADD_ITEM_SUCCESS"
        case .addItemError: "LIST_ADD_ITEM_ERROR"
        case .purchaseItem: "LIST_PURCHASE_ITEM"
        case .purchaseItemSuccess: "LIST_PURCHASE_ITEM_SUCCESS"
        case .purchaseItemError: "LIST_PURCHASE_ITEM_ERROR"
        case .retractItem: "LIST_RETRACT_ITEM"
        case .retractItemSuccess: "LIST_RETRACT_ITEM_SUCCESS"
        case .retractItemError: "LIST_RETRACT_ITEM_ERROR"
        case .deleteItem: "LIST_DELETE_ITEM"
        case .deleteItemSuccess: "LIST_DELETE_ITEM_SUCCESS"
        case .deleteItemError: "LIST_DELETE_ITEM_ERROR"
        case .updateItem: "LIST_UPDATE_ITEM"
        case .updateItemSuccess: "LIST_UPDATE_ITEM_SUCCESS"
        case .updateItemError: "LIST_UPDATE_ITEM_ERROR"
        case .loadActivity: "LIST_LOAD_ACTIVITY"
        case .activityLoaded: "LIST_ACTIVITY_LOADED"
        case .activityError: "LIST_ACTIVITY_ERROR"
        }
    }
}
