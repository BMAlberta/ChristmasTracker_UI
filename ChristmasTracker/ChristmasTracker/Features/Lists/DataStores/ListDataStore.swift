//
//  ListDataStore.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

// In-memory cache for list data

actor ListDataStore {
    
    // MARK: - State
    private var listSummaries: [GiftList] = []
    private var listDetails: [String: ListDetail] = [:]
    private var lastFetch: Date?
    
    // MARK: - List Summaries
    
    func getLists() -> [GiftList] {
        return listSummaries
    }
    
    func setLists(_ lists: [GiftList]) {
        self.listSummaries = lists
        self.lastFetch = Date()
    }
    
    func addList(_ list: GiftList) {
        listSummaries.append(list)
    }
    
    func updateListSummary(_ list: GiftList) {
        if let index = listSummaries.firstIndex(where: { $0.id == list.id }) {
            listSummaries[index] = list
        }
    }
    
    /// Caches a newly created list in ONE actor hop: the detail, and its summary (replaced in
    /// place when the id exists, appended otherwise). Atomic so a teardown cannot fall between
    /// the two writes.
    func storeCreated(_ detail: ListDetail) {
        listDetails[detail.id] = detail
        let summary = detail.asGiftList()
        if let index = listSummaries.firstIndex(where: { $0.id == summary.id }) {
            listSummaries[index] = summary
        } else {
            listSummaries.append(summary)
        }
    }

    func removeList(id: String) {
        listSummaries.removeAll { $0.id == id }
        listDetails.removeValue(forKey: id)
    }
    
    // MARK: - List Details
    
    func getListDetail(id: String) -> ListDetail? {
        return listDetails[id]
    }
    
    func setListDetail(_ detail: ListDetail) {
        listDetails[detail.id] = detail
        updateListSummary(detail.asGiftList())
    }
    
    // MARK: - Cache Management
    
    func shouldRefresh() -> Bool {
        guard let lastFetch = lastFetch else {
            return true
        }
        
        let fifteenMinutes: TimeInterval = 15 * 60
        return Date().timeIntervalSince(lastFetch) > fifteenMinutes
    }
    
    func clear() {
        listSummaries = []
        listDetails = [:]
        lastFetch = nil
    }

}

// MARK: - SessionClearable

extension ListDataStore: SessionClearable {
    func clearForSession() async throws {
        clear()
    }
}
