//
//  GeneratedClientListRepository.swift
//  ChristmasTracker
//
//  Repository for the five list operations on the generated TrackerAPI client. Every documented
//  response is mapped explicitly (no default case), and every failure becomes a typed ListError.
//  Nothing past this file sees a generated type. No ids, names, emails or tokens are logged.
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

/// `.sessionEnded` is deliberately never produced here: the session-ending middleware ends the
/// session before the error returns, and ListService discards the results of a stale session.
nonisolated final class GeneratedClientListRepository: ListRepository, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: - Fetch lists

    @Instrumented
    func fetchLists() async throws -> [GiftList] {
        do {
            // No query parameters at all: the server has no multi-value status filter and no
            // default, so archived lists are dropped by the service instead.
            let output = try await client.listLists(Operations.ListLists.Input(query: .init(), headers: .init()))
            switch output {
            case .ok(let response):
                return try response.body.json.data.map(mapListSummary)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound:
                throw ListError.notFound
            case .tooManyRequests:
                // RateLimitMiddleware normally throws first and carries the Retry-After value.
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }

    // MARK: - Fetch detail

    @Instrumented
    func fetchListDetail(id: String) async throws -> ListDetail {
        do {
            let output = try await client.getList(Operations.GetList.Input(path: .init(id: id), headers: .init()))
            switch output {
            case .ok(let response):
                return mapListDetail(try response.body.json.data)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound:
                throw ListError.notFound
            case .tooManyRequests:
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }

    // MARK: - Create

    @Instrumented
    func createList(_ input: CreateListInput) async throws -> ListDetail {
        do {
            // coOwnerEmail is never sent. A nil visibility omits the key (the server default is
            // PRIVATE); a nil theme omits the key.
            let body = Operations.CreateList.Input.Body.JsonPayload(
                recipientId: input.recipientId,
                year: input.year,
                name: input.name,
                theme: input.theme,
                visibility: input.visibility.map(wireVisibility),
                coOwnerEmail: nil
            )
            let output = try await client.createList(Operations.CreateList.Input(headers: .init(), body: .json(body)))
            switch output {
            case .created(let response):
                return mapListDetail(try response.body.json.data)
            case .badRequest(let response):
                throw validationFailure(response.body)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound(let response):
                // A bad recipient is an identical 404 RECIPIENT_NOT_FOUND (4010); any other 404
                // is a plain not-found.
                let envelope = try? response.body.json
                if envelope?.error.errorCode == "RECIPIENT_NOT_FOUND" || envelope?.error.code == 4010 {
                    throw ListError.recipientNotFound
                }
                throw ListError.notFound
            case .conflict:
                // 409 LIST_ALREADY_EXISTS (5002): one list per recipient per year.
                throw ListError.duplicateRecipientYear
            case .tooManyRequests:
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }

    // MARK: - Update

    @Instrumented
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail {
        do {
            // Only the non-nil fields are sent; status never is. An all-nil input therefore sends
            // an empty JSON object body ({}), which the server accepts as a no-op update.
            // The key is only present for .set; clearing is the separate removeCoOwner call.
            let coOwnerEmail: String?
            switch input.coOwner {
            case .unchanged:
                coOwnerEmail = nil
            case .set(let email):
                coOwnerEmail = email
            }
            let body = Operations.UpdateList.Input.Body.JsonPayload(
                name: input.name,
                theme: input.theme,
                visibility: input.visibility.map(wireVisibility),
                status: nil,
                coOwnerEmail: coOwnerEmail
            )
            let output = try await client.updateList(
                Operations.UpdateList.Input(path: .init(id: id), headers: .init(), body: .json(body))
            )
            switch output {
            case .ok(let response):
                return mapListDetail(try response.body.json.data)
            case .badRequest(let response):
                throw validationFailure(response.body)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound(let response):
                // 404 MEMBER_EMAIL_NOT_FOUND (4009): no account for the co-owner email.
                throw notFoundFailure(response.body, memberEmailCode: true)
            case .unprocessableContent:
                // 422 CANNOT_EDIT_ARCHIVED_LIST: an archived list is read-only.
                throw ListError.archivedReadOnly
            case .tooManyRequests:
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }

    // MARK: - Remove co-owner

    @Instrumented
    func removeCoOwner(listId: String) async throws -> ListDetail {
        do {
            let output = try await client.removeCoOwner(
                Operations.RemoveCoOwner.Input(path: .init(id: listId), headers: .init())
            )
            switch output {
            case .ok(let response):
                return mapListDetail(try response.body.json.data)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound:
                throw ListError.notFound
            case .unprocessableContent:
                // 422 CANNOT_EDIT_ARCHIVED_LIST: an archived list is read-only.
                throw ListError.archivedReadOnly
            case .tooManyRequests:
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }

    // MARK: - Delete

    @Instrumented
    func deleteList(id: String) async throws {
        do {
            let output = try await client.deleteList(Operations.DeleteList.Input(path: .init(id: id), headers: .init()))
            switch output {
            case .ok:
                return
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound:
                throw ListError.notFound
            case .tooManyRequests:
                throw ListError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ListError.server
            case .undocumented(let statusCode, _):
                throw undocumentedFailure(statusCode)
            }
        } catch {
            throw listFailure(error)
        }
    }
}

// MARK: - Request mapping

nonisolated private func wireVisibility(_ value: ListVisibility) -> Components.Schemas.ListVisibility {
    switch value {
    case .private: return ._private
    case .inviteOnly: return .inviteOnly
    case .friendsOnly: return .friendsOnly
    case .public: return ._public
    }
}

// MARK: - Failure mapping

/// 404 on an operation that can also report MEMBER_EMAIL_NOT_FOUND (4009), or on removing a
/// member that can report MEMBERSHIP_NOT_FOUND (4006). Any other 404 is a plain not-found.
nonisolated func notFoundFailure(_ body: Components.Responses.NotFoundError.Body, memberEmailCode: Bool) -> ListError {
    let error = (try? body.json)?.error
    if memberEmailCode, error?.errorCode == "MEMBER_EMAIL_NOT_FOUND" || error?.code == 4009 {
        return .memberEmailNotFound
    }
    if !memberEmailCode, error?.errorCode == "MEMBERSHIP_NOT_FOUND" || error?.code == 4006 {
        return .membershipNotFound
    }
    return .notFound
}

/// 400: the documented message text from the envelope, or a plain fallback.
nonisolated func validationFailure(_ body: Components.Responses.ValidationError.Body) -> ListError {
    let message = (try? body.json)?.error.message ?? ""
    return .validation(message: message)
}

/// A status the contract does not document: 5xx is a server failure, anything else is a
/// response the app cannot interpret.
nonisolated func undocumentedFailure(_ statusCode: Int) -> ListError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// Turns anything thrown while calling the client into a ListError, except cancellation, which
/// is passed through unchanged. The OpenAPI runtime wraps transport, middleware and decoding
/// errors in `ClientError`; the root cause is its `underlyingError`.
nonisolated func listFailure(_ error: any Error) -> any Error {
    if let listError = error as? ListError {
        return listError
    }
    if let clientError = error as? ClientError {
        return classifyRootCause(clientError.underlyingError, wrappedByClient: true)
    }
    return classifyRootCause(error, wrappedByClient: false)
}

nonisolated private func classifyRootCause(_ cause: any Error, wrappedByClient: Bool) -> any Error {
    if cause is CancellationError {
        return cause
    }
    if let listError = cause as? ListError {
        return listError
    }
    if let apiError = cause as? TrackerAPIError {
        return classifyAPIError(apiError)
    }
    if let urlError = cause as? URLError {
        return urlError.code == .cancelled ? CancellationError() : ListError.network
    }
    if cause is SessionRefreshError {
        // A refresh that failed for a reason other than a credential failure (which the
        // middleware already turned into TrackerAPIError.unauthorized): treat as connectivity.
        return ListError.network
    }
    // Decoding failures and runtime errors from the client are an unreadable response. A bare
    // unknown error that did not come through the client is treated like a transport failure.
    return wrappedByClient ? ListError.invalidResponse : ListError.network
}

nonisolated private func classifyAPIError(_ error: TrackerAPIError) -> ListError {
    switch error {
    case .unauthorized: return .unauthorized
    case .forbidden: return .forbidden
    case .notFound: return .notFound
    case .validation(let message): return .validation(message: message)
    case .rateLimited(let retryAfter): return .rateLimited(retryAfter: retryAfter)
    case .network: return .network
    case .decoding: return .invalidResponse
    case .server: return .server
    case .undocumented(let status): return undocumentedFailure(status)
    // Not produced by the list endpoints; mapped to the closest plain failure, never silently.
    case .conflict: return .server
    case .invalidServerURL: return .invalidResponse
    case .versionOutdated: return .server
    }
}
