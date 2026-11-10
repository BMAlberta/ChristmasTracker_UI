//
//  GeneratedClientMemberRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: GeneratedClientMemberRepository through the REAL factory-built client with a
//  fake transport and guide-accurate literal JSON (client guide 7.3; full `meta` object).
//
//  Construction assumption (same as the list repository):
//      GeneratedClientMemberRepository(client: client)    // client from TrackerClientFactory.make
//
//  Leaving a list is removeMember with the caller's own user id: there is no separate wire call.
//
//  Rate-limit note: Retry-After "0.001" keeps the middleware's real sleeper at about a
//  millisecond; the mapped value is asserted exactly.
//

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Shared setup

private struct SUT {
    let repo: GeneratedClientMemberRepository
    let wire: WireHarness

    var transport: ListFakeTransport { wire.transport }
    var refresher: ListFakeRefresher { wire.refresher }
}

private func makeSUT(refreshFailure: (any Error)? = nil) throws -> SUT {
    let wire = try WireHarness.make(refreshFailure: refreshFailure)
    return SUT(repo: GeneratedClientMemberRepository(client: wire.client), wire: wire)
}

private let addInput = AddMemberInput(email: "friend@example.com", role: .member)

// MARK: - The two operations, for cross-cutting tests

nonisolated enum MemberRepoOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case addMember, removeMember

    var testDescription: String {
        switch self {
        case .addMember: "addMember"
        case .removeMember: "removeMember"
        }
    }

    var successStatus: Int { self == .addMember ? 201 : 200 }

    var method: HTTPRequest.Method { self == .addMember ? .post : .delete }

    func successJSON() throws -> String {
        switch self {
        case .addMember: try MembersWire.addMemberJSON()
        case .removeMember: MembersWire.removeMemberJSON
        }
    }

    func run(_ repo: GeneratedClientMemberRepository) async throws {
        switch self {
        case .addMember:
            _ = try await repo.addMember(listId: "list-1", AddMemberInput(email: "friend@example.com", role: .member))
        case .removeMember:
            try await repo.removeMember(listId: "list-1", userId: "user-9")
        }
    }
}

// MARK: - Suite

@Suite("GeneratedClientMemberRepository")
struct GeneratedClientMemberRepositoryTests {

    // MARK: Success

    @Test("addMember 201 maps the MemberSummary: role, ACTIVE status and the optional fields", arguments: [
        ("member", ListMemberRole.member), ("viewer", ListMemberRole.viewer)
    ])
    func addMemberSuccess(wireRole: String, expected: ListMemberRole) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.addMemberJSON(role: wireRole))

        let member = try await sut.repo.addMember(listId: "list-1", AddMemberInput(email: "friend@example.com", role: expected))

        #expect(member.id == "mem-new")
        #expect(member.userId == "user-new")
        #expect(member.displayName == "Fran Friend")
        #expect(member.email == "friend@example.com")
        #expect(member.role == expected)
        #expect(member.status == .active)
        #expect(member.acceptedAt != nil)
        #expect(member.expiresAt == nil)
    }

    @Test("addMember 201 without an email in the response maps email to nil")
    func addMemberSuccessWithoutEmail() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.addMemberJSON(email: nil))

        let member = try await sut.repo.addMember(listId: "list-1", addInput)

        #expect(member.email == nil)
    }

    @Test("removeMember 200 completes and returns nothing")
    func removeMemberSuccess() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: MembersWire.removeMemberJSON)

        try await sut.repo.removeMember(listId: "list-1", userId: "user-9")

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Request shape

    @Test("every operation uses the right method and path", arguments: MemberRepoOp.allCases)
    func methodAndPath(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == op.method)
        switch op {
        case .addMember:
            #expect(recorded.pathOnly == "/tracker/v2/lists/list-1/members")
        case .removeMember:
            #expect(recorded.pathOnly == "/tracker/v2/lists/list-1/members/user-9")
        }
        #expect(recorded.hasQuery == false)
    }

    @Test("every request carries X-Platform, X-Build, X-App-Version, X-Client-Platform and the bearer token", arguments: MemberRepoOp.allCases)
    func requestHeaders(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        let fields = recorded.request.headerFields
        let platform = try #require(ListWire.headerName("X-Platform"))
        let build = try #require(ListWire.headerName("X-Build"))
        let version = try #require(ListWire.headerName("X-App-Version"))
        let clientPlatform = try #require(ListWire.headerName("X-Client-Platform"))
        let cookie = try #require(ListWire.headerName("Cookie"))
        #expect(fields[platform] == "ios")
        #expect(fields[build] == "1")
        #expect(fields[version] == "1.0.0")
        #expect(fields[clientPlatform] == "ios")
        #expect(fields[.authorization] == "Bearer \(WireHarness.accessToken)")
        #expect(fields[cookie] == nil)
    }

    @Test("addMember body is exactly the keys email and role, with the raw role value", arguments: [
        (ListMemberRole.member, "member"), (ListMemberRole.viewer, "viewer")
    ])
    func addMemberBody(role: ListMemberRole, wire: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.addMemberJSON(role: wire))

        _ = try await sut.repo.addMember(listId: "list-1", AddMemberInput(email: "friend@example.com", role: role))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["email", "role"])
        #expect(body["email"] as? String == "friend@example.com")
        #expect(body["role"] as? String == wire)
    }

    @Test("removeMember sends no request body")
    func removeMemberSendsNoBody() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: MembersWire.removeMemberJSON)

        try await sut.repo.removeMember(listId: "list-1", userId: "user-9")

        let recorded = try #require(await sut.transport.lastRequest())
        #expect((recorded.bodyData ?? Data()).isEmpty)
    }

    @Test("leaving a list is removeMember with the caller's own user id in the path")
    func leaveIsRemoveMemberWithOwnId() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: MembersWire.removeMemberJSON)

        try await sut.repo.removeMember(listId: "list-7", userId: "user-me-FAKE")

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == .delete)
        #expect(recorded.pathOnly == "/tracker/v2/lists/list-7/members/user-me-FAKE")
        #expect((recorded.bodyData ?? Data()).isEmpty)
    }

    // MARK: 400 validation (addMember)

    @Test("addMember 400 throws validation with the server message")
    func addMember400() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 400, json: MembersWire.validation("Email must be a valid email address"))
        let repo = sut.repo

        await #expect(throws: ListError.validation(message: "Email must be a valid email address")) {
            _ = try await repo.addMember(listId: "list-1", addInput)
        }
    }

    // MARK: 401 (after the middleware's refresh attempt)

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: MemberRepoOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized", arguments: MemberRepoOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: MemberRepoOp) async throws {
        let sut = try makeSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed result", arguments: MemberRepoOp.allCases)
    func refreshThenReplaySucceeds(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 2)
    }

    // MARK: 403

    @Test("403 throws forbidden", arguments: MemberRepoOp.allCases)
    func forbidden(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: MembersWire.forbidden)
        let repo = sut.repo

        await #expect(throws: ListError.forbidden) {
            try await op.run(repo)
        }
    }

    @Test("403 NOT_LIST_OWNER throws forbidden too", arguments: MemberRepoOp.allCases)
    func forbiddenNotListOwner(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: ListWire.notListOwner)
        let repo = sut.repo

        await #expect(throws: ListError.forbidden) {
            try await op.run(repo)
        }
    }

    // MARK: 404

    @Test("addMember 404 MEMBER_EMAIL_NOT_FOUND (4009) throws memberEmailNotFound")
    func addMemberEmailNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: MembersWire.memberEmailNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.memberEmailNotFound) {
            _ = try await repo.addMember(listId: "list-1", addInput)
        }
    }

    @Test("addMember 404 with another code throws notFound", arguments: [
        ListWire.listNotFound, MembersWire.membershipNotFound, MembersWire.resourceNotFound
    ])
    func addMemberOtherNotFound(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.addMember(listId: "list-1", addInput)
        }
    }

    @Test("removeMember 404 MEMBERSHIP_NOT_FOUND (4006) throws membershipNotFound")
    func removeMemberMembershipNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: MembersWire.membershipNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.membershipNotFound) {
            try await repo.removeMember(listId: "list-1", userId: "user-9")
        }
    }

    @Test("removeMember 404 with another code throws notFound", arguments: [
        ListWire.listNotFound, MembersWire.memberEmailNotFound, MembersWire.resourceNotFound
    ])
    func removeMemberOtherNotFound(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            try await repo.removeMember(listId: "list-1", userId: "user-9")
        }
    }

    // MARK: 409 (addMember)

    @Test("addMember 409 MEMBERSHIP_ALREADY_EXISTS (5004) throws alreadyMember")
    func addMember409() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 409, json: MembersWire.membershipAlreadyExists)
        let repo = sut.repo

        await #expect(throws: ListError.alreadyMember) {
            _ = try await repo.addMember(listId: "list-1", addInput)
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: MemberRepoOp.allCases)
    func rateLimited(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)
        let repo = sut.repo

        await #expect(throws: ListError.rateLimited(retryAfter: 0.001)) {
            try await op.run(repo)
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited maps to rateLimited with its value", arguments: MemberRepoOp.allCases)
    func thrownRateLimited(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 5))
        let repo = sut.repo

        await #expect(throws: ListError.rateLimited(retryAfter: 5)) {
            try await op.run(repo)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: MemberRepoOp.allCases)
    func serverError(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: MemberRepoOp.allCases, [502, 503])
    func undocumented5xx(op: MemberRepoOp, status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented non-5xx status (418) throws invalidResponse", arguments: MemberRepoOp.allCases)
    func undocumented418(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: 418,
            json: ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
        )
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            try await op.run(repo)
        }
    }

    // MARK: Malformed and transport

    @Test("a malformed 200/201 body throws invalidResponse", arguments: MemberRepoOp.allCases, ListMalformedBody.allCases)
    func malformedSuccessBody(op: MemberRepoOp, malformed: ListMalformedBody) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: malformed.json)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("an addMember 201 whose role or status is not a known value throws invalidResponse", arguments: [
        ("owner", "ACTIVE"), ("member", "PENDING")
    ])
    func addMemberUnknownEnumValue(role: String, status: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.addMemberJSON(role: role, status: status))
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            _ = try await repo.addMember(listId: "list-1", addInput)
        }
    }

    @Test("a 200/201 with no body at all throws invalidResponse", arguments: MemberRepoOp.allCases)
    func emptySuccessBody(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueEmpty(status: op.successStatus)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a transport failure (URLError) throws network", arguments: MemberRepoOp.allCases)
    func transportFailure(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            try await op.run(repo)
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network", arguments: MemberRepoOp.allCases)
    func middlewareNetworkError(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            try await op.run(repo)
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to a ListError", arguments: MemberRepoOp.allCases)
    func cancellationIsRethrown(op: MemberRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(CancellationError())
        let repo = sut.repo

        await #expect(throws: CancellationError.self) {
            try await op.run(repo)
        }
    }
}
