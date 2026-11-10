//
//  ChildError.swift
//  ChristmasTracker
//
//  Typed failures of the children operations and how they are shown. Messages are plain: the
//  server text is shown only for `validation`; no ids or names ever appear. Cases shared with
//  ListError use the identical text.
//

import Foundation

nonisolated enum ChildError: Error, LocalizedError, Equatable, Sendable {
    /// 404 RESOURCE_NOT_FOUND for an unknown or foreign child.
    case childNotFound
    /// 422 CANNOT_DELETE_RESOURCE (6501): the child still has lists.
    case childHasLists
    case validation(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case unauthorized
    case sessionEnded
    case network
    case invalidResponse
    case server
    case forbidden

    var userMessage: String {
        switch self {
        case .childNotFound:
            return "That child could not be found."
        case .childHasLists:
            return "This child still has lists, so it can't be removed. Delete those lists first."
        case .validation(let message):
            return ListError.validation(message: message).userMessage
        case .rateLimited(let retryAfter):
            return ListError.rateLimited(retryAfter: retryAfter).userMessage
        case .unauthorized:
            return ListError.unauthorized.userMessage
        case .sessionEnded:
            return ListError.sessionEnded.userMessage
        case .network:
            return ListError.network.userMessage
        case .invalidResponse:
            return ListError.invalidResponse.userMessage
        case .server:
            return ListError.server.userMessage
        case .forbidden:
            return ListError.forbidden.userMessage
        }
    }

    var errorDescription: String? {
        userMessage
    }
}

/// How a ChildError is shown: the message and whether a retry makes sense.
nonisolated struct ChildErrorPresentation: Equatable, Sendable {
    let message: String
    let isRetryable: Bool

    init(_ error: ChildError) {
        message = error.userMessage
        switch error {
        case .network, .server, .rateLimited, .invalidResponse:
            isRetryable = true
        case .childNotFound, .childHasLists, .validation, .unauthorized, .sessionEnded, .forbidden:
            isRetryable = false
        }
    }
}
