//
//  ItemDataStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

actor ItemDataStore {

    // MARK: - State

    private var itemsByList: [String: [ListItem]] = [:]
    private var lastFetchByList: [String: Date] = [:]

    // MARK: - Items Access

    func getItems(listId: String) -> [ListItem] {
        return itemsByList[listId] ?? []
    }

    func setItems(_ items: [ListItem], listId: String) {
        self.itemsByList[listId] = items
        self.lastFetchByList[listId] = Date()
    }

    func addItem(_ item: ListItem) {
        var items = itemsByList[item.listId] ?? []
        items.append(item)
        self.itemsByList[item.listId] = items
    }

    func updateItem(_ item: ListItem) {
        guard var items = itemsByList[item.listId] else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            itemsByList[item.listId] = items
        }
    }

    func removeItem(id: String, listId: String) {
        guard var items = itemsByList[listId] else { return }

        items.removeAll { $0.id == id }
        itemsByList[listId] = items
    }

    /// Removes an item from every cached list (used when only the item id is known).
    func removeItem(id: String) {
        for listId in Array(itemsByList.keys) {
            itemsByList[listId]?.removeAll { $0.id == id }
        }
    }

    // MARK: - Cache Management

    func shouldRefresh(listId: String) -> Bool {
        guard let lastFetch = lastFetchByList[listId] else {
            return true
        }

        let fifteeenMinutes: TimeInterval = 15 * 60
        return Date().timeIntervalSince(lastFetch) > fifteeenMinutes
    }

    func clear(listId: String) {
        itemsByList.removeValue(forKey: listId)
        lastFetchByList.removeValue(forKey: listId)
    }

    func clearAll() {
        itemsByList = [:]
        lastFetchByList = [:]
    }
}

// MARK: - SessionClearable

extension ItemDataStore: SessionClearable {
    func clearForSession() async throws {
        clearAll()
    }
}
