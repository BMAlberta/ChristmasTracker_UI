//
//  GeneratedClientMemberRepository.swift
//  ChristmasTracker
//
//  Repository for adding and removing list members on the generated TrackerAPI client. Every
//  documented response is mapped explicitly (no default case) and every failure becomes a typed
//  ListError. Nothing in this file logs: member emails, names and ids must never reach a log.
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
import TrackerInstrumentation

nonisolated final class GeneratedClientMemberRepository: MemberRepository, Sendable {

    private let client: any APIProtocol

    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: - Add

    @Instrumented
    func addMember(listId: String, _ input: AddMemberInput) async throws -> ListMember {
        do {
            let body = Operations.AddMember.Input.Body.JsonPayload(email: input.email, role: wireRole(input.role))
            let output = try await client.addMember(
                Operations.AddMember.Input(path: .init(id: listId), headers: .init(), body: .json(body))
            )
            switch output {
            case .created(let response):
                return mapMemberSummary(try response.body.json.data)
            case .badRequest(let response):
                throw validationFailure(response.body)
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound(let response):
                // 404 MEMBER_EMAIL_NOT_FOUND (4009) is shown to the user; any other 404 is a
                // plain not-found.
                throw notFoundFailure(response.body, memberEmailCode: true)
            case .conflict:
                // 409 MEMBERSHIP_ALREADY_EXISTS (5004).
                throw ListError.alreadyMember
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

    // MARK: - Remove (also: leave)

    @Instrumented
    func removeMember(listId: String, userId: String) async throws {
        do {
            let output = try await client.removeMember(
                Operations.RemoveMember.Input(path: .init(id: listId, userId: userId), headers: .init())
            )
            switch output {
            case .ok(let response):
                // The body only carries a message; reading it proves the response is well formed.
                _ = try response.body.json
                return
            case .unauthorized:
                throw ListError.unauthorized
            case .forbidden:
                throw ListError.forbidden
            case .notFound(let response):
                // 404 MEMBERSHIP_NOT_FOUND (4006): the person is not a member (any more).
                throw notFoundFailure(response.body, memberEmailCode: false)
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

nonisolated private func wireRole(_ role: ListMemberRole) -> Components.Schemas.MembershipRole {
    switch role {
    case .member: return .member
    case .viewer: return .viewer
    }
}
