//
//  GeneratedClientItemRepository.swift
//  ChristmasTracker
//
//  Repository for the five item operations on the generated TrackerAPI client. Every documented
//  response is mapped explicitly (no default case), and every failure becomes a typed ItemError.
//  Nothing past this file sees a generated type. No ids, names, urls, prices or tokens are logged.
//  The status operation is not built: no screen offers a status change.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and ItemService discards the results of a stale session.
nonisolated final class GeneratedClientItemRepository: ItemRepository, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: - Fetch items

    @Instrumented
    func fetchItems(listId: String) async throws -> [ListItem] {
        do {
            let output = try await client.listItems(
                Operations.ListItems.Input(path: .init(listId: listId), query: .init(), headers: .init())
            )
            switch output {
            case .ok(let response):
                return try response.body.json.data.map { try mapListItem($0) }
            case .unauthorized:
                throw ItemError.unauthorized
            case .forbidden:
                throw ItemError.forbidden
            case .notFound:
                throw ItemError.notFound
            case .tooManyRequests:
                throw ItemError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ItemError.server
            case .undocumented(let statusCode, _):
                throw itemUndocumentedFailure(statusCode)
            }
        } catch {
            throw itemFailure(error)
        }
    }

    // MARK: - Fetch detail

    @Instrumented
    func fetchItemDetail(id: String) async throws -> ListItem {
        do {
            let output = try await client.getItem(Operations.GetItem.Input(path: .init(id: id), headers: .init()))
            switch output {
            case .ok(let response):
                return try mapListItem(try response.body.json.data)
            case .unauthorized:
                throw ItemError.unauthorized
            case .forbidden:
                throw ItemError.forbidden
            case .notFound:
                throw ItemError.notFound
            case .tooManyRequests:
                throw ItemError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ItemError.server
            case .undocumented(let statusCode, _):
                throw itemUndocumentedFailure(statusCode)
            }
        } catch {
            throw itemFailure(error)
        }
    }

    // MARK: - Create

    @Instrumented
    func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem {
        do {
            // The request has no offList field: the server derives it from the caller. Nil
            // optionals are omitted from the body.
            let body = Operations.CreateItem.Input.Body.JsonPayload(
                name: input.name,
                description: input.description,
                url: input.url,
                expectedUnitPrice: input.expectedUnitPrice.map(decimalToDouble),
                quantityRequested: input.quantityRequested,
                priority: input.priority,
                imageUrl: input.imageUrl
            )
            let output = try await client.createItem(
                Operations.CreateItem.Input(path: .init(listId: listId), headers: .init(), body: .json(body))
            )
            switch output {
            case .created(let response):
                return try mapListItem(try response.body.json.data)
            case .badRequest(let response):
                throw itemBadRequest(response.body)
            case .unauthorized:
                throw ItemError.unauthorized
            case .forbidden:
                throw ItemError.forbidden
            case .notFound:
                throw ItemError.notFound
            case .tooManyRequests:
                throw ItemError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ItemError.server
            case .undocumented(let statusCode, _):
                throw itemUndocumentedFailure(statusCode)
            }
        } catch {
            throw itemFailure(error)
        }
    }

    // MARK: - Update

    @Instrumented
    func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem {
        do {
            // Only the non-nil fields are sent; a nil field is omitted.
            let body = Operations.UpdateItem.Input.Body.JsonPayload(
                name: input.name,
                description: input.description,
                url: input.url,
                expectedUnitPrice: input.expectedUnitPrice.map(decimalToDouble),
                quantityRequested: input.quantityRequested,
                priority: input.priority,
                imageUrl: input.imageUrl
            )
            let output = try await client.updateItem(
                Operations.UpdateItem.Input(path: .init(id: id), headers: .init(), body: .json(body))
            )
            switch output {
            case .ok(let response):
                return try mapListItem(try response.body.json.data)
            case .badRequest(let response):
                throw itemBadRequest(response.body)
            case .unauthorized:
                throw ItemError.unauthorized
            case .forbidden:
                throw ItemError.forbidden
            case .notFound:
                throw ItemError.notFound
            case .tooManyRequests:
                throw ItemError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ItemError.server
            case .undocumented(let statusCode, _):
                throw itemUndocumentedFailure(statusCode)
            }
        } catch {
            throw itemFailure(error)
        }
    }

    // MARK: - Delete

    @Instrumented
    func deleteItem(id: String) async throws {
        do {
            let output = try await client.deleteItem(Operations.DeleteItem.Input(path: .init(id: id), headers: .init()))
            switch output {
            case .ok(let response):
                // Reading the body makes an unreadable success response an error.
                _ = try response.body.json
                return
            case .unauthorized:
                throw ItemError.unauthorized
            case .forbidden:
                throw ItemError.forbidden
            case .notFound:
                throw ItemError.notFound
            case .unprocessableContent(let response):
                let error = (try? response.body.json)?.error
                if error?.errorCode == "CANNOT_DELETE_ITEM_WITH_PURCHASES" {
                    throw ItemError.cannotDeleteWithPurchases
                }
                throw ItemError.validation(message: error?.message ?? "")
            case .tooManyRequests:
                throw ItemError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ItemError.server
            case .undocumented(let statusCode, _):
                throw itemUndocumentedFailure(statusCode)
            }
        } catch {
            throw itemFailure(error)
        }
    }
}

// MARK: - Failure mapping

/// 400: INVALID_PRICE (3007) is its own case; anything else carries the envelope's message
/// (blank or absent becomes an empty message, which the user message turns into the generic text).
nonisolated private func itemBadRequest(_ body: Components.Responses.ValidationError.Body) -> ItemError {
    let error = (try? body.json)?.error
    if error?.errorCode == "INVALID_PRICE" || error?.code == 3007 {
        return .invalidPrice
    }
    return .validation(message: error?.message ?? "")
}

/// A status the contract does not document: 5xx is a server failure, anything else is a
/// response the app cannot interpret.
nonisolated private func itemUndocumentedFailure(_ statusCode: Int) -> ItemError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// Turns anything thrown while calling the client into an ItemError, except cancellation, which
/// is passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding
/// errors in `ClientError`; the root cause is its `underlyingError`.
nonisolated private func itemFailure(_ error: any Error) -> any Error {
    if let itemError = error as? ItemError {
        return itemError
    }
    if let clientError = error as? ClientError {
        // A 400 or 422 whose envelope could not be decoded (for example no message) is still a
        // validation failure; the generic text is used.
        if let status = clientError.response?.status.code, status == 400 || status == 422,
           clientError.underlyingError is DecodingError {
            return ItemError.validation(message: "")
        }
        return classifyItemRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyItemRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyItemRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let itemError = cause as? ItemError {
        return itemError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyItemAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : ItemError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return ItemError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? ItemError.invalidResponse : ItemError.network
}

nonisolated private func classifyItemAPIError(_ error: TrackerAPIError) -> ItemError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return itemUndocumentedFailure(status)
    // Not produced by the item endpoints; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
