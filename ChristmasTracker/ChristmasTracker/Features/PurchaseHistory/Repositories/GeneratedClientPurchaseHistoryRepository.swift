//
//  GeneratedClientPurchaseHistoryRepository.swift
//  ChristmasTracker
//
//  Repository for listPurchases on the generated TrackerAPI client. Every documented response is
//  mapped explicitly (no default case), and every failure becomes a typed PurchaseHistoryError.
//  Nothing past this file sees a generated type. Nothing is logged: amounts, names, ids and cursors
//  never reach a log.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and PurchaseHistoryService discards the results of a stale session.
nonisolated final class GeneratedClientPurchaseHistoryRepository: PurchaseHistoryLoading, Sendable {

    /// Rows per request (the web's default; the contract's default is 50).
    static let pageLimit = 20

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage {
        do {
            let input = Operations.ListPurchases.Input(query: makePurchaseHistoryQuery(filter: filter, cursor: cursor))
            let output = try await client.listPurchases(input)
            switch output {
            case .ok(let response):
                return try mapPurchaseHistoryPage(try response.body.json)
            case .badRequest(let response):
                throw PurchaseHistoryError.validation(message: historyEnvelopeMessage { try response.body.json })
            case .unauthorized:
                throw PurchaseHistoryError.unauthorized
            case .forbidden:
                throw PurchaseHistoryError.forbidden
            case .notFound:
                throw PurchaseHistoryError.notFound
            case .tooManyRequests:
                throw PurchaseHistoryError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw PurchaseHistoryError.server
            case .undocumented(let statusCode, _):
                throw historyUndocumentedFailure(statusCode)
            }
        } catch {
            throw historyFailure(error)
        }
    }
}

// MARK: - Failure mapping

/// The envelope's message, trimmed; blank when the body is absent or unreadable (the user message
/// then turns it into the generic text).
nonisolated private func historyEnvelopeMessage(_ read: () throws -> Components.Schemas._Error) -> String {
    let message = (try? read())?.error.message ?? ""
    return message.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// A status the contract does not document: 5xx is a server failure, anything else is a response
/// the app cannot interpret.
nonisolated private func historyUndocumentedFailure(_ statusCode: Int) -> PurchaseHistoryError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// The documented error statuses whose body could not be decoded: the status decides.
nonisolated private let historyUnreadableBodyFailures: [Int: PurchaseHistoryError] = [
    400: .validation(message: ""),
    401: .unauthorized,
    403: .forbidden,
    404: .notFound,
    429: .rateLimited(retryAfter: 0),
    500: .server
]

/// Turns anything thrown while calling the client into a PurchaseHistoryError, except cancellation,
/// which is passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding
/// errors in `ClientError`; the root cause is its `underlyingError`.
nonisolated private func historyFailure(_ error: any Error) -> any Error {
    if let historyError = error as? PurchaseHistoryError {
        return historyError
    }
    if let clientError = error as? ClientError {
        // A documented error status whose body could not be decoded is still that error: the
        // status decides, not the unreadable body (a 404 stays "not found").
        if clientError.underlyingError is DecodingError,
           let status = clientError.response?.status.code,
           let failure = historyUnreadableBodyFailures[status] {
            return failure
        }
        return classifyHistoryRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyHistoryRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyHistoryRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let historyError = cause as? PurchaseHistoryError {
        return historyError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyHistoryAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : PurchaseHistoryError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return PurchaseHistoryError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? PurchaseHistoryError.invalidResponse : PurchaseHistoryError.network
}

nonisolated private func classifyHistoryAPIError(_ error: TrackerAPIError) -> PurchaseHistoryError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return historyUndocumentedFailure(status)
    // Not produced by this endpoint; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
