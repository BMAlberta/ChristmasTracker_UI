//
//  ListAction.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/18/21.
//

import Foundation

enum ListAction {
    case fetchData(token: String)
    case fetchComplete(res: AllItemsResponse)
    case fetchError(error: ListMiddlewareError?)
    case createItem(item: NewItemModel)
    case createComplete(newItem: Item)
    case createError(error: ListMiddlewareError)
}
