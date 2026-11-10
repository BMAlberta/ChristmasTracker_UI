//
//  GeneratedClientChildRepository.swift
//  ChristmasTracker
//
//  Repository for the three children operations on the generated TrackerAPI client. Every
//  documented response is mapped explicitly (no default case) and every failure becomes a typed
//  ChildError. Nothing in this file logs: children's names and ids must never reach a log.
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

nonisolated final class GeneratedClientChildRepository: ChildRepository, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: - Fetch

    @Instrumented
    func fetchChildren() async throws -> [Child] {
        do {
            let output = try await client.listChildren(Operations.ListChildren.Input(headers: .init()))
            switch output {
            case .ok(let response):
                return try response.body.json.data.map { element in
                    try requireChild(mapChild(
                        id: element.id,
                        firstName: element.firstName,
                        lastName: element.lastName,
                        displayName: element.displayName,
                        relationshipRaw: element.relationshipType.rawValue
                    ))
                }
            case .unauthorized:
                throw ChildError.unauthorized
            case .forbidden:
                throw ChildError.forbidden
            case .notFound:
                throw ChildError.childNotFound
            case .tooManyRequests:
                // RateLimitMiddleware normally throws first and carries the Retry-After value.
                throw ChildError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ChildError.server
            case .undocumented(let statusCode, _):
                throw childUndocumentedFailure(statusCode)
            }
        } catch {
            throw childFailure(error)
        }
    }

    // MARK: - Create

    @Instrumented
    func createChild(_ input: CreateChildInput) async throws -> Child {
        do {
            // displayName is omitted when nil; relationshipType is always sent.
            let body = Operations.CreateChild.Input.Body.JsonPayload(
                firstName: input.firstName,
                lastName: input.lastName,
                displayName: input.displayName,
                relationshipType: wireRelationship(input.relationship)
            )
            let output = try await client.createChild(Operations.CreateChild.Input(headers: .init(), body: .json(body)))
            switch output {
            case .created(let response):
                let created = try response.body.json.data
                // The created child's relationship is a plain string on the wire: an unknown
                // value is an unreadable response.
                return try requireChild(mapChild(
                    id: created.id,
                    firstName: created.firstName,
                    lastName: created.lastName,
                    displayName: created.displayName,
                    relationshipRaw: created.relationshipType
                ))
            case .badRequest(let response):
                throw ChildError.validation(message: (try? response.body.json)?.error.message ?? "")
            case .unauthorized:
                throw ChildError.unauthorized
            case .forbidden:
                throw ChildError.forbidden
            case .notFound:
                throw ChildError.childNotFound
            case .tooManyRequests:
                throw ChildError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ChildError.server
            case .undocumented(let statusCode, _):
                throw childUndocumentedFailure(statusCode)
            }
        } catch {
            throw childFailure(error)
        }
    }

    // MARK: - Delete

    @Instrumented
    func deleteChild(id: String) async throws {
        do {
            let output = try await client.deleteChild(Operations.DeleteChild.Input(path: .init(id: id), headers: .init()))
            switch output {
            case .ok(let response):
                // The body only carries a message; reading it proves the response is well formed.
                _ = try response.body.json
                return
            case .unauthorized:
                throw ChildError.unauthorized
            case .forbidden:
                throw ChildError.forbidden
            case .notFound:
                // 404 RESOURCE_NOT_FOUND for an unknown or foreign child (any 404 code).
                throw ChildError.childNotFound
            case .unprocessableContent(let response):
                let error = (try? response.body.json)?.error
                // 422 CANNOT_DELETE_RESOURCE (6501): the child still has lists.
                if error?.errorCode == "CANNOT_DELETE_RESOURCE" || error?.code == 6501 {
                    throw ChildError.childHasLists
                }
                throw ChildError.validation(message: error?.message ?? "")
            case .tooManyRequests:
                throw ChildError.rateLimited(retryAfter: 0)
            case .internalServerError:
                throw ChildError.server
            case .undocumented(let statusCode, _):
                throw childUndocumentedFailure(statusCode)
            }
        } catch {
            throw childFailure(error)
        }
    }
}

// MARK: - Request and response mapping

nonisolated private func wireRelationship(_ value: ChildRelationship) -> Components.Schemas.RelationshipType {
    switch value {
    case .parent: return .parent
    case .guardian: return .guardian
    case .caretaker: return .caretaker
    }
}

/// A child the mapper could not build (unknown relationship) is an unreadable response.
nonisolated private func requireChild(_ child: Child?) throws -> Child {
    guard let child else { throw ChildError.invalidResponse }
    return child
}

// MARK: - Failure mapping

nonisolated private func childUndocumentedFailure(_ statusCode: Int) -> ChildError {
    statusCode >= 500 ? .server : .invalidResponse
}

/// Turns anything thrown while calling the client into a ChildError, except cancellation, which
/// is passed through unchanged. Transport, middleware and decoding failures are classified by
/// the same rules as the list operations (listFailure) and then renamed.
nonisolated private func childFailure(_ error: any Error) -> any Error {
    if let childError = error as? ChildError {
        return childError
    }
    let classified = listFailure(error)
    guard let listError = classified as? ListError else {
        return classified
    }
    switch listError {
    case .unauthorized: return ChildError.unauthorized
    case .forbidden: return ChildError.forbidden
    case .notFound: return ChildError.childNotFound
    case .validation(let message): return ChildError.validation(message: message)
    case .rateLimited(let retryAfter): return ChildError.rateLimited(retryAfter: retryAfter)
    case .sessionEnded: return ChildError.sessionEnded
    case .network: return ChildError.network
    case .invalidResponse: return ChildError.invalidResponse
    case .server: return ChildError.server
    // List-only failures that no children operation can produce; an unreadable response, never silent.
    case .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly, .memberEmailNotFound,
         .alreadyMember, .membershipNotFound:
        return ChildError.invalidResponse
    }
}
