//
//  ListActions.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

enum ListActions: ListAction {
    
    // List Details
    case addList(newListDetails: NewListDetails)
    case addListSuccess
    case addListError(ListError)
    case addListFlowComplete
    case deleteList
    case deleteListSuccess
    case viewListDetails(String)
    case resetListDetails
    case addItem(newItemDetails: NewItemDetails, listInContext: String)
    case addItemSuccess
    case addItemError(ListError)
    case addItemFlowComplete
    case purchaseItem(listInContext: String, itemId: String, quantityPurchased: Int, purchasePrice: Double)
    case purchaseItemSuccess
    case purchaseItemError(ListError)
    case purchaseFlowComplete
    case retractItem(listId: String, itemId: String)
    case retractItemSuccess
    case retractItemError(ListError)
    case deleteItem(itemId: String, listId: String)
    case deleteItemSuccess
    case deleteItemError(ListError)
    case updateItem(itemDetails: NewItemDetails, listInContext: String)
    case updateItemSuccess
    case updateItemError(ListError)
    case updateItemFlowComplete
    
    case loadActivity
    case activityLoaded
    case activityError(ListError)
    
    case loadHomeFeed
    case homeFeedLoaded(AppData)
    
    
    var type: String {
        switch self {
        case .loadHomeFeed: "LIST_LOAD_HOME_FEED"
        case .homeFeedLoaded: "LIST_HOME_FEED_LOADED"
        case .addList: "LIST_ADD"
        case .addListSuccess: "LIST_ADD_SUCCESS"
        case .addListError: "LIST_ADD_ERROR"
        case .addListFlowComplete: "LIST_ADD_FLOW_COMPLETE"
        case .deleteList: "LIST_DELETE"
        case .deleteListSuccess: "LIST_DELETE_SUCCESS"
        case .viewListDetails: "LIST_VIEW_DETAILS"
        case .resetListDetails: "LIST_RESET_DETAILS"
        case .addItem: "LIST_ADD_ITEM"
        case .addItemSuccess: "LIST_ADD_ITEM_SUCCESS"
        case .addItemError: "LIST_ADD_ITEM_ERROR"
        case .addItemFlowComplete: "LIST_ADD_FLOW_COMPLETE"
        case .purchaseItem: "LIST_PURCHASE_ITEM"
        case .purchaseItemSuccess: "LIST_PURCHASE_ITEM_SUCCESS"
        case .purchaseItemError: "LIST_PURCHASE_ITEM_ERROR"
        case .purchaseFlowComplete: "LIST_PURCHASE_FLOW_COMPLETE"
        case .retractItem: "LIST_RETRACT_ITEM"
        case .retractItemSuccess: "LIST_RETRACT_ITEM_SUCCESS"
        case .retractItemError: "LIST_RETRACT_ITEM_ERROR"
        case .deleteItem: "LIST_DELETE_ITEM"
        case .deleteItemSuccess: "LIST_DELETE_ITEM_SUCCESS"
        case .deleteItemError: "LIST_DELETE_ITEM_ERROR"
        case .updateItem: "LIST_UPDATE_ITEM"
        case .updateItemSuccess: "LIST_UPDATE_ITEM_SUCCESS"
        case .updateItemError: "LIST_UPDATE_ITEM_ERROR"
        case .updateItemFlowComplete: "LIST_UPDATE_FLOW_COMPLETE"
        case .loadActivity: "LIST_LOAD_ACTIVITY"
        case .activityLoaded: "LIST_ACTIVITY_LOADED"
        case .activityError: "LIST_ACTIVITY_ERROR"
        }
    }
}
