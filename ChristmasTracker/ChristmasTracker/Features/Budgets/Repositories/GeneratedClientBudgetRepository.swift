//
//  GeneratedClientBudgetRepository.swift
//  ChristmasTracker
//
//  Repository for listBudgets, getBudget, createBudget, updateBudget, deleteBudget and
//  duplicateBudget on the generated TrackerAPI client. Every documented response is mapped
//  explicitly (no default case), and every failure becomes a typed BudgetError. Nothing past this
//  file sees a generated type. Money crosses the wire only through the package helpers. Nothing is
//  logged: amounts, names and ids never reach a log.
//
//  Contract issue 3: createBudget, updateBudget and duplicateBudget document no 422, so a 422 on
//  them arrives as an undocumented status and is the sum rule by status (the body is not parsed).
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and BudgetService discards the results of a stale session.
nonisolated final class GeneratedClientBudgetRepository: BudgetManaging, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func listBudgets() async throws -> [Budget] {
        do {
            let output = try await client.listBudgets(Operations.ListBudgets.Input())
            switch output {
            case .ok(let response):
                return try response.body.json.data.map(mapBudget)
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
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: false)
            }
        } catch {
            throw budgetFailure(error)
        }
    }

    @Instrumented
    func budget(year: Int) async throws -> Budget {
        do {
            let output = try await client.getBudget(Operations.GetBudget.Input(path: .init(year: year)))
            switch output {
            case .ok(let response):
                return try mapBudget(try response.body.json.data)
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
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: false)
            }
        } catch {
            throw budgetFailure(error)
        }
    }

    @Instrumented
    func create(_ request: CreateBudgetRequest) async throws -> Budget {
        do {
            let body = Operations.CreateBudget.Input.Body.JsonPayload(
                year: request.year,
                totalBudget: decimalToDouble(request.totalBudget),
                recipients: request.recipients.map {
                    .init(recipientId: $0.recipientId, maxSpend: decimalToDouble($0.maxSpend))
                }
            )
            let output = try await client.createBudget(Operations.CreateBudget.Input(body: .json(body)))
            switch output {
            case .created(let response):
                return try mapBudget(try response.body.json.data)
            case .badRequest(let response):
                throw BudgetError.validation(message: budgetEnvelopeMessage { try response.body.json })
            case .unauthorized:
                throw BudgetError.unauthorized
            case .forbidden:
                throw BudgetError.forbidden
            case .notFound:
                throw BudgetError.notFound
            case .conflict(let response):
                throw BudgetError.alreadyExists(message: budgetEnvelopeMessage { try response.body.json })
            case .tooManyRequests:
                throw BudgetError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw BudgetError.server
            case .undocumented(let statusCode, _):
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: true)
            }
        } catch {
            throw budgetFailure(error)
        }
    }

    @Instrumented
    func update(_ request: UpdateBudgetRequest) async throws -> Budget {
        do {
            // Only the non-nil fields are sent; a nil field is omitted from the JSON.
            let body = Operations.UpdateBudget.Input.Body.JsonPayload(
                totalBudget: request.totalBudget.map(decimalToDouble),
                recipients: request.recipients?.map {
                    .init(recipientId: $0.recipientId, maxSpend: decimalToDouble($0.maxSpend))
                }
            )
            let output = try await client.updateBudget(
                Operations.UpdateBudget.Input(path: .init(year: request.year), body: .json(body))
            )
            switch output {
            case .ok(let response):
                return try mapBudget(try response.body.json.data)
            case .badRequest(let response):
                throw BudgetError.validation(message: budgetEnvelopeMessage { try response.body.json })
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
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: true)
            }
        } catch {
            throw budgetFailure(error)
        }
    }

    @Instrumented
    func delete(year: Int) async throws {
        do {
            let output = try await client.deleteBudget(Operations.DeleteBudget.Input(path: .init(year: year)))
            switch output {
            case .ok:
                return
            case .unauthorized:
                throw BudgetError.unauthorized
            case .forbidden:
                throw BudgetError.forbidden
            case .notFound:
                throw BudgetError.notFound
            case .unprocessableContent(let response):
                throw BudgetError.hasPurchases(message: budgetEnvelopeMessage { try response.body.json })
            case .tooManyRequests:
                throw BudgetError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw BudgetError.server
            case .undocumented(let statusCode, _):
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: false)
            }
        } catch {
            throw budgetFailure(error)
        }
    }

    @Instrumented
    func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget {
        do {
            let body = Operations.DuplicateBudget.Input.Body.JsonPayload(toYear: request.toYear)
            let output = try await client.duplicateBudget(
                Operations.DuplicateBudget.Input(path: .init(year: request.fromYear), body: .json(body))
            )
            switch output {
            case .created(let response):
                return try mapBudget(try response.body.json.data)
            case .badRequest(let response):
                throw BudgetError.validation(message: budgetEnvelopeMessage { try response.body.json })
            case .unauthorized:
                throw BudgetError.unauthorized
            case .forbidden:
                throw BudgetError.forbidden
            case .notFound:
                throw BudgetError.notFound
            case .conflict(let response):
                throw BudgetError.alreadyExists(message: budgetEnvelopeMessage { try response.body.json })
            case .tooManyRequests:
                throw BudgetError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw BudgetError.server
            case .undocumented(let statusCode, _):
                throw budgetUndocumentedFailure(statusCode, isSumRuleWrite: true)
            }
        } catch {
            throw budgetFailure(error)
        }
    }
}

// MARK: - Failure mapping

/// The envelope's message, trimmed; blank when the body is absent or unreadable (the user message
/// then turns it into the fixed fallback text).
nonisolated private func budgetEnvelopeMessage(_ read: () throws -> Components.Schemas._Error) -> String {
    let message = (try? read())?.error.message ?? ""
    return message.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// A status the contract does not document: a 422 on a write is the sum rule (by status; the body
/// is not parsed), 5xx is a server failure, anything else is a response the app cannot interpret.
nonisolated private func budgetUndocumentedFailure(_ statusCode: Int, isSumRuleWrite: Bool) -> BudgetError {
    if isSumRuleWrite && statusCode == 422 {
        return .sumExceedsTotal(message: "")
    }
    return statusCode >= 500 ? .server : .invalidResponse
}

/// The documented error statuses whose body could not be decoded: the status decides. A 422 is the
/// one documented on deleteBudget (a budget with purchases).
nonisolated private let budgetUnreadableBodyFailures: [Int: BudgetError] = [
    400: .validation(message: ""),
    403: .forbidden,
    404: .notFound,
    409: .alreadyExists(message: ""),
    422: .hasPurchases(message: ""),
    500: .server
]

/// Turns anything thrown while calling the client into a BudgetError, except cancellation, which is
/// passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding errors in
/// `ClientError`; the root cause is its `underlyingError`.
nonisolated private func budgetFailure(_ error: any Error) -> any Error {
    if let budgetError = error as? BudgetError {
        return budgetError
    }
    if let clientError = error as? ClientError {
        // A documented error status whose body could not be decoded is still that error: the
        // status decides, not the unreadable body (a 404 stays "not found").
        if clientError.underlyingError is DecodingError,
           let status = clientError.response?.status.code,
           let failure = budgetUnreadableBodyFailures[status] {
            return failure
        }
        return classifyBudgetRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyBudgetRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyBudgetRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let budgetError = cause as? BudgetError {
        return budgetError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyBudgetAPIError(apiError)
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

nonisolated private func classifyBudgetAPIError(_ error: TrackerAPIError) -> BudgetError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .conflict: return .alreadyExists(message: "")
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return budgetUndocumentedFailure(status, isSumRuleWrite: false)
    // Not produced by these endpoints; mapped to the closest plain failure, never silently.
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
