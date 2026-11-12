//
//  ItemRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//

import Foundation

nonisolated protocol ItemRepository: Repository {
    /// Fetch all items for a given list. What comes back already follows the caller's privacy
    /// rules (the server hides status, updatedAt and off-list items from some viewers).
    func fetchItems(listId: String) async throws -> [ListItem]

    /// Fetch one item with its purchase summaries (when the caller may see them).
    func fetchItemDetail(id: String) async throws -> ListItem

    /// Adds a new item to a list. The server derives whether it is an off-list item.
    func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem

    /// Update an existing item; only the non-nil fields of the input are sent.
    func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem

    /// Delete an item by id.
    func deleteItem(id: String) async throws
}

// MARK: - Item Errors

nonisolated enum ItemError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case unauthorized
    case forbidden
    case validation(message: String)
    case invalidPrice
    case cannotDeleteWithPurchases
    case rateLimited(retryAfter: TimeInterval)
    case sessionEnded
    case network
    case invalidResponse
    case server

    /// A plain, user-facing message. Never interpolates a payload, an id or a raw error.
    var userMessage: String {
        switch self {
        case .forbidden:
            return "You don't have permission to do that."
        case .notFound:
            return "This item no longer exists."
        case .validation(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Please check the item details and try again." : message
        case .invalidPrice:
            return "Enter a price from 0 to 999,999.99 with at most two decimals."
        case .cannotDeleteWithPurchases:
            return "This item has purchases and can't be deleted."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .sessionEnded:
            return "You were signed out. Please sign in again."
        case .network:
            return "Couldn't reach the server. Check your connection and try again."
        case .invalidResponse:
            return "The server sent a response the app couldn't read."
        case .server:
            return "Something went wrong on the server. Please try again later."
        }
    }

    var errorDescription: String? { userMessage }
}
