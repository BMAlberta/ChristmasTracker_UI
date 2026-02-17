//
//  ItemRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//

import Foundation

protocol ItemRepository: Repository {
    /// Fetch all items for a given list.
    /// - Parameter listId: String representing the list id.
    /// - Returns: Array of GiftItems.
    func fetchItems(listId: String) async throws -> [GiftItem]
    
    /// Adds a new item to a list.
    /// - Parameters:
    ///   - listId: String representing the list into which the item will be added.
    ///   - request: CreateItemRequest
    /// - Returns: GiftItem for the new item.
    func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem
    
    /// Update an existing item.
    /// - Parameters:
    ///   - id: String represented the list on which to update an item.
    ///   - request: UpdateItem details
    /// - Returns: Updated GiftItem
    func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem
    
    /// Delete an item by Id.
    /// - Parameter id: String representing the Id of the item to delete.
    func deleteItem(id: String) async throws
    
    func fetchItemDetail(id: String) async throws -> GiftItem
}
