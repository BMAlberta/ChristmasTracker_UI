//
//  BudgetError.swift
//  ChristmasTracker
//
//  I5a Story A: typed error for budgets and statistics, with fixed user messages.
//

import Foundation

nonisolated enum BudgetError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case unauthorized
    case forbidden
    case validation(message: String)
    case alreadyExists(message: String)
    case sumExceedsTotal(message: String)
    case hasPurchases(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case sessionEnded
    case network
    case invalidResponse
    case server

    var userMessage: String {
        switch self {
        case .notFound:
            return "That budget could not be found."
        case .unauthorized:
            return "Please sign in again."
        case .forbidden:
            return "You don't have permission to do that."
        case .validation(let message):
            return Self.text(message, fallback: "Please check the amounts and try again.")
        case .alreadyExists(let message):
            return Self.text(message, fallback: "You already have a budget for that year.")
        case .sumExceedsTotal(let message):
            return Self.text(message, fallback: "Limits add up to more than the total")
        case .hasPurchases(let message):
            return Self.text(message, fallback: "A budget with purchases can't be deleted.")
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .sessionEnded:
            return "Your session has ended. Please sign in again."
        case .network:
            return "Check your connection and try again."
        case .invalidResponse, .server:
            return "Something went wrong. Please try again."
        }
    }

    var errorDescription: String? { userMessage }

    /// True when the budget no longer exists (a 404 counts as already gone).
    var isGone: Bool {
        switch self {
        case .notFound:
            return true
        case .unauthorized, .forbidden, .validation, .alreadyExists, .sumExceedsTotal, .hasPurchases,
             .rateLimited, .sessionEnded, .network, .invalidResponse, .server:
            return false
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network, .server, .rateLimited, .invalidResponse:
            return true
        case .notFound, .unauthorized, .forbidden, .validation, .alreadyExists, .sumExceedsTotal,
             .hasPurchases, .sessionEnded:
            return false
        }
    }

    private static func text(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
