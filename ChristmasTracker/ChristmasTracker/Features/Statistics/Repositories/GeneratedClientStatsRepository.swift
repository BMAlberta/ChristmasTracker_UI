//
//  GeneratedClientStatsRepository.swift
//  ChristmasTracker
//
//  Repository for getStats (the year scope only) on the generated TrackerAPI client. Every
//  documented response is mapped explicitly (no default case), and every failure becomes a typed
//  BudgetError. Nothing past this file sees a generated type. Nothing is logged: amounts, names and
//  ids never reach a log.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and StatsService discards the results of a stale session.
nonisolated final class GeneratedClientStatsRepository: StatsLoading, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func yearStats(year: Int) async throws -> StatsYear {
        do {
            // The year query is the decimal string of the year; the all scope is never requested.
            let input = Operations.GetStats.Input(query: .init(year: String(year)))
            let output = try await client.getStats(input)
            switch output {
            case .ok(let response):
                return try mapStatsYear(try response.body.json.data)
            case .badRequest(let response):
                throw BudgetError.validation(message: statsEnvelopeMessage { try response.body.json })
            case .unauthorized:
                throw BudgetError.unauthorized
            case .forbidden:
                throw BudgetError.forbidden
            case .notFound:
                throw BudgetError.notFound
            case .tooManyRequests:
                throw BudgetError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw BudgetError.server
            case .undocumented(let statusCode, _):
                throw statsUndocumentedFailure(statusCode)
            }
        } catch {
            throw statsFailure(error)
        }
    }
}

// MARK: - Failure mapping

/// The envelope's message, trimmed; blank when the body is absent or unreadable (the user message
/// then turns it into the generic text).
nonisolated private func statsEnvelopeMessage(_ read: () throws -> Components.Schemas._Error) -> String {
    let message = (try? read())?.error.message ?? ""
    return message.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// A status the contract does not document: 5xx is a server failure, anything else is a response
/// the app cannot interpret.
nonisolated private func statsUndocumentedFailure(_ statusCode: Int) -> BudgetError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// The documented error statuses whose body could not be decoded: the status decides.
nonisolated private let statsUnreadableBodyFailures: [Int: BudgetError] = [
    400: .validation(message: ""),
    403: .forbidden,
    404: .notFound,
    500: .server
]

/// Turns anything thrown while calling the client into a BudgetError, except cancellation, which is
/// passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding errors in
/// `ClientError`; the root cause is its `underlyingError`.
nonisolated private func statsFailure(_ error: any Error) -> any Error {
    if let budgetError = error as? BudgetError {
        return budgetError
    }
    if let clientError = error as? ClientError {
        // A documented error status whose body could not be decoded is still that error: the
        // status decides, not the unreadable body (a 404 stays "not found").
        if clientError.underlyingError is DecodingError,
           let status = clientError.response?.status.code,
           let failure = statsUnreadableBodyFailures[status] {
            return failure
        }
        return classifyStatsRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyStatsRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyStatsRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let budgetError = cause as? BudgetError {
        return budgetError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyStatsAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : BudgetError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return BudgetError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? BudgetError.invalidResponse : BudgetError.network
}

nonisolated private func classifyStatsAPIError(_ error: TrackerAPIError) -> BudgetError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return statsUndocumentedFailure(status)
    // Not produced by this endpoint; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
