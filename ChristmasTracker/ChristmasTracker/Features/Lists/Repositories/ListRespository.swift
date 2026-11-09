//
//  ListRespository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

nonisolated protocol ListRepository: Repository {

    /// Fetch all lists visible to the current user.
    /// - Returns: Array of GiftList objects.
    func fetchLists() async throws -> [GiftList]

    /// Fetch detailed information for a specific list
    /// - Parameter id: ID of the list in question
    /// - Returns: ListDetail
    func fetchListDetail(id: String) async throws -> ListDetail

    /// Create a new list
    /// - Parameter input: CreateListInput with new list information.
    /// - Returns: ListDetail
    func createList(_ input: CreateListInput) async throws -> ListDetail

    /// Update an existing list.
    /// - Parameter input: UpdateListInput with the updated list information.
    /// - Returns: ListDetail
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail

    /// Delete a list
    /// - Parameter id: ID of the list to be deleted.
    func deleteList(id: String) async throws
}
// MARK: - List Errors

/// Typed failures of the list operations. Messages are plain: the documented server message
/// text is shown only for `validation`; no ids, names or emails ever appear.
nonisolated enum ListError: Error, LocalizedError, Equatable, Sendable {
    case forbidden
    case notFound
    case recipientNotFound
    case duplicateRecipientYear
    case archivedReadOnly
    case validation(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case unauthorized
    /// Kept for the views. The repository never produces it: the session-ending middleware ends
    /// the session before the error returns, and the service discards results of a stale session.
    case sessionEnded
    case network
    case invalidResponse
    case server

    var userMessage: String {
        switch self {
        case .forbidden:
            return "You don't have permission to do that."
        case .notFound:
            return "That list could not be found."
        case .recipientNotFound:
            return "That recipient could not be found."
        case .duplicateRecipientYear:
            return "A list for this person and year already exists."
        case .archivedReadOnly:
            return "This list is archived and can no longer be changed."
        case .validation(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "The information you provided is invalid." : message
        case .rateLimited(let retryAfter):
            guard retryAfter.isFinite, retryAfter >= 1 else {
                return "Too many requests. Please try again in a moment."
            }
            let seconds = Int(min(retryAfter, 3600).rounded(.up))
            return "Too many requests. Please try again in \(seconds) seconds."
        case .unauthorized:
            return "Please sign in again to continue."
        case .sessionEnded:
            return "Your session has ended. Please sign in again."
        case .network:
            return "Could not reach the server. Check your connection and try again."
        case .invalidResponse:
            return "The server sent a response the app could not read."
        case .server:
            return "Something went wrong on the server. Please try again later."
        }
    }

    var errorDescription: String? {
        userMessage
    }
}
