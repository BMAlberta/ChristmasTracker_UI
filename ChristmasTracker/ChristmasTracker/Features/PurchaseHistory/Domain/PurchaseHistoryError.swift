//
//  PurchaseHistoryError.swift
//  ChristmasTracker
//
//  Typed errors of loading the purchase history, with fixed user messages.
//

import Foundation

nonisolated enum PurchaseHistoryError: Error, LocalizedError, Equatable, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case validation(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case network
    case server
    case invalidResponse
    case sessionEnded

    /// A plain, user-facing message. Never interpolates a payload, an id or a raw error.
    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to do that."
        case .notFound:
            return "Your purchase history could not be found."
        case .validation(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Please check the filters and try again." : trimmed
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .network:
            return "Couldn't reach the server. Check your connection and try again."
        case .server:
            return "Something went wrong on the server. Please try again later."
        case .invalidResponse:
            return "The server sent a response the app couldn't read."
        case .sessionEnded:
            return "You were signed out. Please sign in again."
        }
    }

    var errorDescription: String? { userMessage }
}
