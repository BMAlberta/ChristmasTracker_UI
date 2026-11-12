//
//  GeneratedClientPurchaseRepository.swift
//  ChristmasTracker
//
//  Repository for the create-purchase operation on the generated TrackerAPI client. Every
//  documented response is mapped explicitly (no default case), and every failure becomes a typed
//  RecordPurchaseError. Nothing past this file sees a generated type. Nothing is logged: the
//  confirmation token, amounts, ids and names never reach a log or Sentry.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and PurchaseService discards the results of a stale session.
nonisolated final class GeneratedClientPurchaseRepository: PurchaseRecording, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    @Instrumented
    func createPurchase(
        itemId: String,
        draft: PurchaseDraft,
        confirmationToken: String?
    ) async throws -> PurchaseOutcome {
        do {
            // The body is the draft and nothing else; nil optionals and a nil token are omitted.
            let body = Operations.CreatePurchase.Input.Body.JsonPayload(
                quantity: draft.quantity,
                totalCost: decimalToDouble(draft.totalCost),
                storeName: draft.storeName,
                notes: draft.notes,
                confirmationNumber: draft.confirmationNumber,
                trackingNumber: draft.trackingNumber,
                confirmationToken: confirmationToken
            )
            let output = try await client.createPurchase(
                Operations.CreatePurchase.Input(path: .init(itemId: itemId), headers: .init(), body: .json(body))
            )
            switch output {
            case .created(let response):
                return try mapCreatedOutcome(try response.body.json.data)
            case .ok(let response):
                let payload = try response.body.json
                return try mapConfirmationOutcome(payload.data, warnings: payload.warnings)
            case .badRequest(let response):
                throw purchaseBadRequest(response.body)
            case .unauthorized:
                throw RecordPurchaseError.unauthorized
            case .forbidden(let response):
                throw purchaseForbidden(response.body)
            case .notFound:
                throw RecordPurchaseError.notFound
            case .tooManyRequests:
                throw RecordPurchaseError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw RecordPurchaseError.server
            case .undocumented(let statusCode, _):
                throw purchaseUndocumentedFailure(statusCode)
            }
        } catch {
            throw purchaseFailure(error)
        }
    }
}

// MARK: - Failure mapping

/// 400: INVALID_PRICE (3007) is its own case; anything else carries the envelope's message
/// (blank when absent, which the user message turns into the generic text).
nonisolated private func purchaseBadRequest(_ body: Components.Responses.ValidationError.Body) -> RecordPurchaseError {
    let envelope = (try? body.json)?.error
    if envelope?.errorCode == "INVALID_PRICE" || envelope?.code == 3007 {
        return .invalidPrice
    }
    return .validation(message: envelope?.message ?? "")
}

/// 403: CANNOT_PURCHASE_OWN_LIST (6104) is its own case; any other 403 is a plain refusal.
nonisolated private func purchaseForbidden(_ body: Components.Responses.ForbiddenError.Body) -> RecordPurchaseError {
    let envelope = (try? body.json)?.error
    if envelope?.errorCode == "CANNOT_PURCHASE_OWN_LIST" || envelope?.code == 6104 {
        return .cannotPurchaseOwnList
    }
    return .forbidden
}

/// A status the contract does not document: 5xx is a server failure, anything else (a 422
/// included) is a response the app cannot interpret.
nonisolated private func purchaseUndocumentedFailure(_ statusCode: Int) -> RecordPurchaseError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// Turns anything thrown while calling the client into a RecordPurchaseError, except cancellation,
/// which is passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding
/// errors in `ClientError`; the root cause is its `underlyingError`.
nonisolated private func purchaseFailure(_ error: any Error) -> any Error {
    if let purchaseError = error as? RecordPurchaseError {
        return purchaseError
    }
    if let clientError = error as? ClientError {
        // A 400 whose envelope could not be decoded is still a validation failure.
        if clientError.response?.status.code == 400, clientError.underlyingError is DecodingError {
            return RecordPurchaseError.validation(message: "")
        }
        return classifyPurchaseRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyPurchaseRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyPurchaseRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let purchaseError = cause as? RecordPurchaseError {
        return purchaseError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyPurchaseAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : RecordPurchaseError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return RecordPurchaseError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? RecordPurchaseError.invalidResponse : RecordPurchaseError.network
}

nonisolated private func classifyPurchaseAPIError(_ error: TrackerAPIError) -> RecordPurchaseError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return purchaseUndocumentedFailure(status)
    // Not produced by this endpoint; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
