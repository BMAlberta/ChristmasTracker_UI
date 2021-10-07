//
//  ListAction.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation

enum ListAction {
    // Owned List
    case fetchOwnedList(token: String)
    case fetchOwnedListComplete(res: AllItemsResponse)
    
    // List for User
    case fetchUserList(token: String, userId: String)
    case fetchUserListComplete(res: AllItemsResponse)
    
    case fetchError(error: ListMiddlewareError?)
    
    // List Overview
    case fetchListOverview(token: String)
    case fetchListOverviewComplete(res: UserListOverviewResponse)
    
    // Item Creation
    case createItem(item: NewItemModel)
    case createComplete(newItem: Item)
    case createError(error: ListMiddlewareError)
}
