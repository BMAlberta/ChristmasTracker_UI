//
//  PurchaseManagementError.swift
//  ChristmasTracker
//
//  Typed errors of getting, updating, updating the shipping of, and deleting a purchase.
//

import Foundation

nonisolated enum PurchaseManagementError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case unauthorized
    case forbidden
    case validation(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case sessionEnded
    case network
    case invalidResponse
    case server

    /// A plain, user-facing message. Never interpolates a payload, an id or a raw error.
    var userMessage: String {
        switch self {
        case .notFound:
            return "This purchase no longer exists."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to do that."
        case .validation(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Please check the purchase details and try again." : message
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
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

    /// True only when the purchase is gone.
    var isGone: Bool {
        if case .notFound = self { return true }
        return false
    }

    var keepsScreenOpen: Bool {
        switch self {
        case .notFound, .sessionEnded, .unauthorized: return false
        case .forbidden, .validation, .rateLimited, .network, .invalidResponse, .server: return true
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network, .server, .rateLimited, .invalidResponse: return true
        case .notFound, .unauthorized, .forbidden, .validation, .sessionEnded: return false
        }
    }
}
