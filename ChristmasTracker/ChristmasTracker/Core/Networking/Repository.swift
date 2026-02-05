//
//  Repository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

/// Base protocol for all repositories
protocol Repository: Sendable {

}

// Marker protocol
/// Example: List repository protocol
/// (Will be fully implemented in Phase 5)
protocol ListRepository: Repository {
    func fetchLists() async throws -> [GiftList]
}

/// Example: Item repository protocol
/// (Will be fully implemented in Phase 6)
protocol ItemRepository: Repository {
    func fetchItems(listId: String) async throws -> [GiftItem]
}
