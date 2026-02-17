//
//  ItemService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ItemService {
    
    // MARK: - Dependencies
    
    private let itemRepository: ItemRepository
    private let dataStore: ItemDataStore
    
    // MARK: - Published State
    
    private(set) var items: [GiftItem] = []
    private(set) var currentListId: String?
    private(set) var isLoading: Bool = false
    private(set) var error: ItemError?
    private(set) var currentItem: GiftItem?
    
    // MARK: - Filtering
    
    var showPurchased: Bool = true
    var showOffList: Bool = false
    
    var filteredItems: [GiftItem] {
        items.filter { item in
            
            if !showPurchased && item.isPurchased {
                return false
            }
            
            if item.offList && !showOffList {
                return false
            }
            
            return true
        }
    }
    
    var purchasedItems: [GiftItem] {
        items.filter { $0.isPurchased }
    }
    
    var availableItems: [GiftItem] {
        items.filter { $0.isAvailable }
    }
    
    var partialItems: [GiftItem] {
        items.filter { $0.status == .partial }
    }
    
    // MARK: - Initialization
    
    init(repository: ItemRepository, dataStore: ItemDataStore) {
        self.itemRepository = repository
        self.dataStore = dataStore
    }
    
    // MARK: - Public Methods
    
    func loadItems(listId: String) async {
        guard !isLoading else { return }
        
        if currentListId != listId {
            items = []
            error = nil
        }
        
        currentListId = listId
        isLoading = true
        error = nil
        
        do {
            let cached = await dataStore.getItems(listId: listId)
            if !cached.isEmpty {
                items = cached
                isLoading = false
                
                if await dataStore.shouldRefresh(listId: listId) {
                    await refreshItems()
                }
                return
            }
            
            let fetchedItems = try await itemRepository.fetchItems(listId: listId)
            
            await dataStore.setItems(fetchedItems, listId: listId)
            
            items = fetchedItems
            
            LogInfo("Loaded \(fetchedItems.count) items for list \(listId)", category: .business)
            
        } catch let itemError as ItemError {
            error = itemError
            LogError("Failed to load items: \(itemError)", category: .business)
        } catch {
            self.error = .fetchFailed
            LogError("Failed to load items: \(error)", category: .business)
        }
        
        isLoading = false
    }
    
    func refreshItems() async {
        guard let listId = currentListId else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedItems = try await itemRepository.fetchItems(listId: listId)
            await dataStore.setItems(fetchedItems, listId: listId)
            items = fetchedItems
            
            LogInfo("Refreshed \(fetchedItems.count) items", category: .business)
        } catch let itemError as ItemError {
            error = itemError
            LogError("Failed to refresh items: \(itemError)", category: .business)
        } catch {
            self.error = .fetchFailed
            LogError("Failed to refresh items: \(error)", category: .business)
        }
        
        isLoading = false
        
    }
    
    func createItem(listId: String, _ request: CreateItemRequest) async throws {
        
        defer {
            isLoading = false
        }
        isLoading = true
        error = nil
        
        do {
            let newItem = try await itemRepository.createItem(listId: listId, request)
            
            await dataStore.addItem(newItem)
            
            items.append(newItem)
            
            LogInfo("Created item '\(newItem.name)", category: .business)
        } catch {
            self.error = .createFailed
            LogError("Failed to create item: \(error)", category: .business)
            throw error
        }
    }
    
    func updateItem(id: String, _ request: UpdateItemRequest) async throws {
        
        defer {
            isLoading = false
        }
        
        isLoading = true
        error = nil
        
        do {
            let updatedItem = try await itemRepository.updateItem(id: id, request)
            
            await dataStore.updateItem(updatedItem)
            
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updatedItem
            }
            
            LogInfo("Updated item '\(updatedItem)'", category: .business)
        } catch {
            self.error = .updateFailed
            isLoading = false
            LogError("Failed to update item: \(error)", category: .business)
            throw error
        }
    }
    
    func deleteItem(id: String, listId: String) async throws {
        
        defer {
            isLoading = false
        }
        
        isLoading = true
        error = nil
        
        do {
            try await itemRepository.deleteItem(id: id)
            
            await dataStore.removeItem(id: id, listId: listId)
            
            items.removeAll { $0.id == id }
            
            LogInfo("Deleted item \(id)", category: .business)
        } catch {
            self.error = .deleteFailed
            isLoading = false
            LogError("Failed to delete item: \(error)", category: .business)
            throw error
        }
    }
    
    func clearItems() {
        items = []
        currentListId = nil
    }
    
    func loadItemDetail(id: String) async throws {
        currentItem = try await itemRepository.fetchItemDetail(id: id)
    }
    
    func clearItemDetail() {
        currentItem = nil
    }
    
    // MARK: - Purchase Support
    
    private func refreshItem(id: String) async throws {
        guard let item = items.first(where: { $0.id == id }),
              let listId = currentListId else {
            return
        }
        
        let updatedItems = try await itemRepository.fetchItems(listId: listId)
        await dataStore.setItems(updatedItems, listId: listId)
        items = updatedItems
        
        LogInfo("Refreshed items after purchase operation", category: .business)
    }
    
    func notiftyPurchaseChase() {
        LogInfo("Purchase change notification", category: .business)
    }
}
