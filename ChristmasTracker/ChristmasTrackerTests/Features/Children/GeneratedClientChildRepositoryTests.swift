//
//  GeneratedClientChildRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: GeneratedClientChildRepository through the REAL factory-built client with a
//  fake transport and guide-accurate literal JSON (client guide 7.10; full `meta` object).
//
//  Construction assumption (same as the list repository):
//      GeneratedClientChildRepository(client: client)    // client from TrackerClientFactory.make
//
//  Wire facts the tests pin: the list response types relationshipType as the generated enum, the
//  create response as a plain String (an unknown value is invalidResponse in both); a null
//  displayName is legal; the create body sends displayName only when non-nil and relationshipType
//  always.
//
//  Rate-limit note: GET is retried twice by the middleware, so three 429s are queued; the
//  Retry-After "0.001" keeps the real sleeper at about a millisecond.
//

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Shared setup

private struct SUT {
    let repo: GeneratedClientChildRepository
    let wire: WireHarness

    var transport: ListFakeTransport { wire.transport }
    var refresher: ListFakeRefresher { wire.refresher }
}

private func makeSUT(refreshFailure: (any Error)? = nil) throws -> SUT {
    let wire = try WireHarness.make(refreshFailure: refreshFailure)
    return SUT(repo: GeneratedClientChildRepository(client: wire.client), wire: wire)
}

private func sampleInput(displayName: String? = "Tommy D.", relationship: ChildRelationship = .parent) -> CreateChildInput {
    CreateChildInput(firstName: "Tommy", lastName: "Doe", displayName: displayName, relationship: relationship)
}

// MARK: - The three operations, for cross-cutting tests

nonisolated enum ChildRepoOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case fetchChildren, createChild, deleteChild

    var testDescription: String {
        switch self {
        case .fetchChildren: "fetchChildren"
        case .createChild: "createChild"
        case .deleteChild: "deleteChild"
        }
    }

    var successStatus: Int { self == .createChild ? 201 : 200 }

    var method: HTTPRequest.Method {
        switch self {
        case .fetchChildren: .get
        case .createChild: .post
        case .deleteChild: .delete
        }
    }

    func successJSON() throws -> String {
        switch self {
        case .fetchChildren: try MembersWire.childrenJSON()
        case .createChild: try MembersWire.createChildJSON()
        case .deleteChild: MembersWire.deleteChildJSON
        }
    }

    func run(_ repo: GeneratedClientChildRepository) async throws {
        switch self {
        case .fetchChildren:
            _ = try await repo.fetchChildren()
        case .createChild:
            _ = try await repo.createChild(
                CreateChildInput(firstName: "Tommy", lastName: "Doe", displayName: "Tommy D.", relationship: .parent)
            )
        case .deleteChild:
            try await repo.deleteChild(id: "child-1")
        }
    }
}

// MARK: - Suite

@Suite("GeneratedClientChildRepository")
struct GeneratedClientChildRepositoryTests {

    // MARK: fetchChildren success

    @Test("fetchChildren maps two children in server order, including a null displayName")
    func fetchChildrenMapsTwo() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try MembersWire.childrenJSON())

        let children = try await sut.repo.fetchChildren()

        #expect(children.count == 2)
        let first = children[0]
        #expect(first.id == "child-1")
        #expect(first.firstName == "Tommy")
        #expect(first.lastName == "Doe")
        #expect(first.displayName == "Tommy D.")
        #expect(first.relationship == .parent)
        let second = children[1]
        #expect(second.id == "child-2")
        #expect(second.firstName == "Dana")
        #expect(second.displayName == nil)
        #expect(second.relationship == .guardian)
    }

    @Test("fetchChildren maps every relationship value", arguments: [
        ("PARENT", ChildRelationship.parent), ("GUARDIAN", ChildRelationship.guardian), ("CARETAKER", ChildRelationship.caretaker)
    ])
    func fetchChildrenMapsRelationship(raw: String, expected: ChildRelationship) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try MembersWire.childrenJSON(secondRelationship: raw))

        let children = try await sut.repo.fetchChildren()

        #expect(children.last?.relationship == expected)
    }

    @Test("fetchChildren with an empty data array returns no children")
    func fetchChildrenEmpty() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: MembersWire.emptyChildrenJSON)

        let children = try await sut.repo.fetchChildren()

        #expect(children.isEmpty)
    }

    @Test("fetchChildren with an unknown relationshipType value throws invalidResponse")
    func fetchChildrenUnknownRelationship() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try MembersWire.childrenJSON(secondRelationship: "SIBLING"))
        let repo = sut.repo

        await #expect(throws: ChildError.invalidResponse) {
            _ = try await repo.fetchChildren()
        }
    }

    // MARK: createChild success

    @Test("createChild 201 maps the new child, whose relationshipType is a plain string", arguments: [
        ("PARENT", ChildRelationship.parent), ("GUARDIAN", ChildRelationship.guardian), ("CARETAKER", ChildRelationship.caretaker)
    ])
    func createChildSuccess(raw: String, expected: ChildRelationship) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.createChildJSON(relationshipType: raw))

        let child = try await sut.repo.createChild(sampleInput(relationship: expected))

        #expect(child.id == "child-new")
        #expect(child.firstName == "Tommy")
        #expect(child.lastName == "Doe")
        #expect(child.displayName == "Tommy D.")
        #expect(child.relationship == expected)
    }

    @Test("createChild 201 with a null displayName maps displayName to nil")
    func createChildSuccessNullDisplayName() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.createChildJSON(displayName: nil))

        let child = try await sut.repo.createChild(sampleInput(displayName: nil))

        #expect(child.displayName == nil)
    }

    @Test("createChild 201 with an unknown relationship string throws invalidResponse")
    func createChildUnknownRelationship() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.createChildJSON(relationshipType: "SIBLING"))
        let repo = sut.repo

        await #expect(throws: ChildError.invalidResponse) {
            _ = try await repo.createChild(sampleInput())
        }
    }

    @Test("deleteChild 200 completes and returns nothing")
    func deleteChildSuccess() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: MembersWire.deleteChildJSON)

        try await sut.repo.deleteChild(id: "child-1")

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Request shape

    @Test("every operation uses the right method and path", arguments: ChildRepoOp.allCases)
    func methodAndPath(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == op.method)
        switch op {
        case .fetchChildren, .createChild:
            #expect(recorded.pathOnly == "/tracker/v2/users/me/children")
        case .deleteChild:
            #expect(recorded.pathOnly == "/tracker/v2/users/me/children/child-1")
        }
        #expect(recorded.hasQuery == false)
    }

    @Test("every request carries X-Platform, X-Build, X-App-Version, X-Client-Platform and the bearer token", arguments: ChildRepoOp.allCases)
    func requestHeaders(op: ChildRepoOp) async throws {
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

    @Test("fetchChildren and deleteChild send no request body")
    func noBodyOnGetAndDelete() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try MembersWire.childrenJSON())
        await sut.transport.enqueue(status: 200, json: MembersWire.deleteChildJSON)

        _ = try await sut.repo.fetchChildren()
        try await sut.repo.deleteChild(id: "child-1")

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 2)
        #expect(recorded.allSatisfy { ($0.bodyData ?? Data()).isEmpty })
    }

    @Test("createChild body has exactly firstName, lastName, displayName and relationshipType when a display name is given", arguments: [
        (ChildRelationship.parent, "PARENT"), (ChildRelationship.guardian, "GUARDIAN"), (ChildRelationship.caretaker, "CARETAKER")
    ])
    func createChildBodyWithDisplayName(relationship: ChildRelationship, wire: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.createChildJSON(relationshipType: wire))

        _ = try await sut.repo.createChild(sampleInput(displayName: "Tommy D.", relationship: relationship))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["firstName", "lastName", "displayName", "relationshipType"])
        #expect(body["firstName"] as? String == "Tommy")
        #expect(body["lastName"] as? String == "Doe")
        #expect(body["displayName"] as? String == "Tommy D.")
        #expect(body["relationshipType"] as? String == wire)
    }

    @Test("createChild body omits displayName when it is nil and always sends relationshipType")
    func createChildBodyWithoutDisplayName() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try MembersWire.createChildJSON(displayName: nil))

        _ = try await sut.repo.createChild(sampleInput(displayName: nil, relationship: .caretaker))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["firstName", "lastName", "relationshipType"])
        #expect(body["relationshipType"] as? String == "CARETAKER")
    }

    // MARK: 400 validation (createChild)

    @Test("createChild 400 throws validation with the server message")
    func createChild400() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 400, json: MembersWire.validation("First name must be between 1 and 100 characters"))
        let repo = sut.repo

        await #expect(throws: ChildError.validation(message: "First name must be between 1 and 100 characters")) {
            _ = try await repo.createChild(sampleInput())
        }
    }

    // MARK: 401 (after the middleware's refresh attempt)

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: ChildRepoOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)
        let repo = sut.repo

        await #expect(throws: ChildError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized", arguments: ChildRepoOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: ChildRepoOp) async throws {
        let sut = try makeSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        let repo = sut.repo

        await #expect(throws: ChildError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed result", arguments: ChildRepoOp.allCases)
    func refreshThenReplaySucceeds(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 2)
    }

    // MARK: 403

    @Test("403 throws forbidden", arguments: ChildRepoOp.allCases)
    func forbidden(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: MembersWire.forbidden)
        let repo = sut.repo

        await #expect(throws: ChildError.forbidden) {
            try await op.run(repo)
        }
    }

    // MARK: 404

    @Test("404 RESOURCE_NOT_FOUND throws childNotFound", arguments: ChildRepoOp.allCases)
    func notFound(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: MembersWire.resourceNotFound)
        let repo = sut.repo

        await #expect(throws: ChildError.childNotFound) {
            try await op.run(repo)
        }
    }

    @Test("deleteChild 404 with any other code still throws childNotFound")
    func deleteChildOtherNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.listNotFound)
        let repo = sut.repo

        await #expect(throws: ChildError.childNotFound) {
            try await repo.deleteChild(id: "child-1")
        }
    }

    // MARK: 422 (deleteChild)

    @Test("deleteChild 422 CANNOT_DELETE_RESOURCE (6501) throws childHasLists")
    func deleteChildHasLists() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 422, json: MembersWire.cannotDeleteResource)
        let repo = sut.repo

        await #expect(throws: ChildError.childHasLists) {
            try await repo.deleteChild(id: "child-1")
        }
    }

    @Test("deleteChild 422 with another code throws validation carrying the server message")
    func deleteChild422Other() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 422, json: MembersWire.validation("The request could not be processed"))
        let repo = sut.repo

        await #expect(throws: ChildError.validation(message: "The request could not be processed")) {
            try await repo.deleteChild(id: "child-1")
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: ChildRepoOp.allCases)
    func rateLimited(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)
        let repo = sut.repo

        await #expect(throws: ChildError.rateLimited(retryAfter: 0.001)) {
            try await op.run(repo)
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited maps to rateLimited with its value", arguments: ChildRepoOp.allCases)
    func thrownRateLimited(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 5))
        let repo = sut.repo

        await #expect(throws: ChildError.rateLimited(retryAfter: 5)) {
            try await op.run(repo)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: ChildRepoOp.allCases)
    func serverError(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ChildError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: ChildRepoOp.allCases, [502, 503])
    func undocumented5xx(op: ChildRepoOp, status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ChildError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented non-5xx status (418) throws invalidResponse", arguments: ChildRepoOp.allCases)
    func undocumented418(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: 418,
            json: ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
        )
        let repo = sut.repo

        await #expect(throws: ChildError.invalidResponse) {
            try await op.run(repo)
        }
    }

    // MARK: Malformed and transport

    @Test("a malformed 200/201 body throws invalidResponse", arguments: ChildRepoOp.allCases, ListMalformedBody.allCases)
    func malformedSuccessBody(op: ChildRepoOp, malformed: ListMalformedBody) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: malformed.json)
        let repo = sut.repo

        await #expect(throws: ChildError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a 200/201 with no body at all throws invalidResponse", arguments: ChildRepoOp.allCases)
    func emptySuccessBody(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueEmpty(status: op.successStatus)
        let repo = sut.repo

        await #expect(throws: ChildError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a transport failure (URLError) throws network", arguments: ChildRepoOp.allCases)
    func transportFailure(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))
        let repo = sut.repo

        await #expect(throws: ChildError.network) {
            try await op.run(repo)
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network", arguments: ChildRepoOp.allCases)
    func middlewareNetworkError(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))
        let repo = sut.repo

        await #expect(throws: ChildError.network) {
            try await op.run(repo)
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to a ChildError", arguments: ChildRepoOp.allCases)
    func cancellationIsRethrown(op: ChildRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(CancellationError())
        let repo = sut.repo

        await #expect(throws: CancellationError.self) {
            try await op.run(repo)
        }
    }
}
