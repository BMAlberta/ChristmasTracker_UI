//
//  PurchaseError.swift
//  ChristmasTracker
//
//  Errors of recording a purchase. The errors of managing an existing purchase are
//  PurchaseManagementError.
//

import Foundation

nonisolated enum PurchaseError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case unauthorized
    case forbidden
    case cannotPurchaseOwnList
    case validation(message: String)
    case invalidPrice
    case rateLimited(retryAfter: TimeInterval)
    case sessionEnded
    case network
    case invalidResponse
    case server
    /// No HTTP response came back and the request may have reached the server, so the purchase
    /// may have been recorded.
    case unconfirmed

    /// A plain, user-facing message. Never interpolates a payload, an id or a raw error.
    var userMessage: String {
        switch self {
        case .notFound:
            return "This item no longer exists."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You don't have permission to do that."
        case .cannotPurchaseOwnList:
            return "You can't record a purchase for an item on your own list."
        case .validation(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Please check the purchase details and try again." : message
        case .invalidPrice:
            return "Enter a total cost from 0.01 to 999,999.99 with at most two decimals."
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
        case .unconfirmed:
            return "We couldn't confirm whether this purchase was recorded."
        }
    }

    var failureKind: PurchaseFailureKind {
        if case .unconfirmed = self { return .unconfirmed }
        return .definitive
    }

    var errorDescription: String? { userMessage }

    /// True only when the item or its list is gone, so the form has nothing left to edit.
    var closesForm: Bool {
        if case .notFound = self { return true }
        return false
    }

    var isRetryable: Bool {
        switch self {
        case .network, .server, .rateLimited, .invalidResponse: return true
        case .notFound, .unauthorized, .forbidden, .cannotPurchaseOwnList, .validation, .invalidPrice, .sessionEnded, .unconfirmed:
            return false
        }
    }
}
