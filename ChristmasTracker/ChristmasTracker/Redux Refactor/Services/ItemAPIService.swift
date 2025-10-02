//
//  ItemAPIService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/1/25.
//

import Foundation

protocol ItemDataProviding {

    func addNewItem(toList listInContext: String, newItem: NewItemModel) async throws -> ListDetailResponse
    func markItemPurchased(listId: String, itemInContext: Item, quantity: Int) async throws -> ListDetailResponse
    func markItemRetracted(listId: String, itemInContext: Item) async throws -> ListDetailResponse
    func updateItem(listInContext: String, updatedItem: NewItemModel) async throws -> ListDetailResponse
    func deleteItem(fromList listId: String, item: Item) async throws
    
}
