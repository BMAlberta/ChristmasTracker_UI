//
//  GeneratedClientPurchaseManagementRepository.swift
//  ChristmasTracker
//
//  Repository for getPurchase, updatePurchase, updatePurchaseShipping and deletePurchase on the
//  generated TrackerAPI client. Every documented response is mapped explicitly (no default case),
//  and every failure becomes a typed PurchaseManagementError. Nothing past this file sees a
//  generated type. Nothing is logged: ids, notes, tracking numbers and amounts never reach a log.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and PurchaseService discards the results of a stale session.
nonisolated final class GeneratedClientPurchaseManagementRepository: PurchaseManaging, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func fetchPurchase(id: String) async throws -> RecordedPurchase {
        do {
            let output = try await client.getPurchase(Operations.GetPurchase.Input(path: .init(id: id)))
            switch output {
            case .ok(let response):
                return try mapManagedPurchase(try response.body.json.data)
            case .unauthorized:
                throw PurchaseManagementError.unauthorized
            case .forbidden:
                throw PurchaseManagementError.forbidden
            case .notFound:
                throw PurchaseManagementError.notFound
            case .tooManyRequests:
                throw PurchaseManagementError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw PurchaseManagementError.server
            case .undocumented(let statusCode, _):
                throw managementUndocumentedFailure(statusCode)
            }
        } catch {
            throw managementFailure(error)
        }
    }

    @Instrumented
    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase {
        do {
            // Notes only: the generated body has a tracking member, which is never set here.
            let body = Operations.UpdatePurchase.Input.Body.JsonPayload(notes: update.wireNotes, trackingNumber: nil)
            let output = try await client.updatePurchase(
                Operations.UpdatePurchase.Input(path: .init(id: id), body: .json(body))
            )
            switch output {
            case .ok(let response):
                return try mapManagedPurchase(try response.body.json.data)
            case .badRequest(let response):
                throw managementBadRequest(response.body)
            case .unauthorized:
                throw PurchaseManagementError.unauthorized
            case .forbidden:
                throw PurchaseManagementError.forbidden
            case .notFound:
                throw PurchaseManagementError.notFound
            case .tooManyRequests:
                throw PurchaseManagementError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw PurchaseManagementError.server
            case .undocumented(let statusCode, _):
                throw managementUndocumentedFailure(statusCode)
            }
        } catch {
            throw managementFailure(error)
        }
    }

    @Instrumented
    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase {
        do {
            let body = Operations.UpdatePurchaseShipping.Input.Body.JsonPayload(
                shippingStatus: wireShippingStatus(update.status),
                trackingNumber: update.wireTrackingNumber
            )
            let output = try await client.updatePurchaseShipping(
                Operations.UpdatePurchaseShipping.Input(path: .init(id: id), body: .json(body))
            )
            switch output {
            case .ok(let response):
                return try mapManagedPurchase(try response.body.json.data)
            case .badRequest(let response):
                throw managementBadRequest(response.body)
            case .unauthorized:
                throw PurchaseManagementError.unauthorized
            case .forbidden:
                throw PurchaseManagementError.forbidden
            case .notFound:
                throw PurchaseManagementError.notFound
            case .tooManyRequests:
                throw PurchaseManagementError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw PurchaseManagementError.server
            case .undocumented(let statusCode, _):
                throw managementUndocumentedFailure(statusCode)
            }
        } catch {
            throw managementFailure(error)
        }
    }

    @Instrumented
    func deletePurchase(id: String) async throws -> RecordedPurchase {
        do {
            let output = try await client.deletePurchase(Operations.DeletePurchase.Input(path: .init(id: id)))
            switch output {
            case .ok(let response):
                return try mapManagedPurchase(try response.body.json.data)
            case .badRequest(let response):
                throw managementBadRequest(response.body)
            case .unauthorized:
                throw PurchaseManagementError.unauthorized
            case .forbidden:
                throw PurchaseManagementError.forbidden
            case .notFound:
                throw PurchaseManagementError.notFound
            case .tooManyRequests:
                throw PurchaseManagementError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw PurchaseManagementError.server
            case .undocumented(let statusCode, _):
                throw managementUndocumentedFailure(statusCode)
            }
        } catch {
            throw managementFailure(error)
        }
    }
}

// MARK: - Mapping

/// A 200 body that cannot be mapped (for example money that is not a number) is an unreadable response.
nonisolated private func mapManagedPurchase(_ purchase: Components.Schemas.Purchase) throws -> RecordedPurchase {
    do {
        return try mapRecordedPurchase(purchase)
    } catch {
        throw PurchaseManagementError.invalidResponse
    }
}

nonisolated private func wireShippingStatus(_ status: PurchaseShippingStatus) -> Components.Schemas.ShippingStatus {
    switch status {
    case .notTracked: return .notTracked
    case .notShipped: return .notShipped
    case .shipped: return .shipped
    case .delivered: return .delivered
    }
}

// MARK: - Failure mapping

/// 400 carries the envelope's message (blank when absent, which the user message turns into the
/// generic text).
nonisolated private func managementBadRequest(_ body: Components.Responses.ValidationError.Body) -> PurchaseManagementError {
    let envelope = (try? body.json)?.error
    return .validation(message: envelope?.message ?? "")
}

/// A status the contract does not document: 5xx is a server failure, anything else is a response
/// the app cannot interpret.
nonisolated private func managementUndocumentedFailure(_ statusCode: Int) -> PurchaseManagementError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// Turns anything thrown while calling the client into a PurchaseManagementError, except
/// cancellation, which is passed through unchanged. The OpenAPI runtime wraps transport,
/// middleware and decoding errors in `ClientError`; the root cause is its `underlyingError`.
nonisolated private func managementFailure(_ error: any Error) -> any Error {
    if let managementError = error as? PurchaseManagementError {
        return managementError
    }
    if let clientError = error as? ClientError {
        // A 400 whose envelope could not be decoded is still a validation failure.
        // The same holds for any documented error status: the status decides, not the unreadable body
        // (a 404 stays "not found" and never becomes an unreadable response).
        if clientError.underlyingError is DecodingError, let status = clientError.response?.status.code {
            switch status {
            case 400: return PurchaseManagementError.validation(message: "")
            case 403: return PurchaseManagementError.forbidden
            case 404: return PurchaseManagementError.notFound
            case 500: return PurchaseManagementError.server
            default: break
            }
        }
        return classifyManagementRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyManagementRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyManagementRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let managementError = cause as? PurchaseManagementError {
        return managementError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyManagementAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : PurchaseManagementError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return PurchaseManagementError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? PurchaseManagementError.invalidResponse : PurchaseManagementError.network
}

nonisolated private func classifyManagementAPIError(_ error: TrackerAPIError) -> PurchaseManagementError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return managementUndocumentedFailure(status)
    // Not produced by these endpoints; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
