//
//  ListRespository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

protocol ListRepository: Repository {
    
    /// Fetch all lists visible to the current user.
    /// - Returns: Array of GiftList objects.
    func fetchLists() async throws -> [GiftList]
    
    /// Fetch detailed information for a specific list
    /// - Parameter id: ID of the list in question
    /// - Returns: ListDetail
    func fetchListDetail(id: String) async throws -> ListDetail
    
    /// Create a new list
    /// - Parameter request: CreateListRequest with new list information.
    /// - Returns: ListDetail
    func createList(_ request: CreateListRequest) async throws -> ListDetail
    
    /// Update an existing list.
    /// - Parameter request: UpdateListRequest with the updated list information.
    /// - Returns: ListDetail
    func updateList(id: String, _ request: UpdateListRequest) async throws -> ListDetail
    
    /// Delete a list
    /// - Parameter id: ID of the list to be deleted.
    func deleteList(id: String) async throws
}
// MARK: - List Errors
enum ListError: Error, LocalizedError {
    case fetchFailed
    case notFound
    case createFailed
    case updateFailed
    case deleteFailed
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to load lists."
        case .notFound:
            return "List not found."
        case .createFailed:
            return "Failed to create list."
        case .updateFailed:
            return "Failed to update list."
        case .deleteFailed:
            return "Failed to delete list."
        case .unauthorized:
            return "You don't have permission to perform this action"
        }
    }
}
