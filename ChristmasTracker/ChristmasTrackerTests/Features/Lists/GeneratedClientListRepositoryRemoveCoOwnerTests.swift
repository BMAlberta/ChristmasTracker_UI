//
//  GeneratedClientListRepositoryRemoveCoOwnerTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-2 R2: GeneratedClientListRepository.removeCoOwner (DELETE /lists/{id}/co-owner,
//  decision L15, client guide "Clear the co-owner") over the REAL factory-built client with a
//  fake transport. Fixtures are literal guide-shaped envelopes with the full meta object.
//
//  - 200 returns the mapped detail with coOwner nil and the fresh flags; an idempotent 200 for a
//    list without a co-owner maps the same way.
//  - The request is DELETE to /tracker/v2/lists/{id}/co-owner with the four client headers and
//    the bearer token, no body and no query.
//  - 401 (after one refresh), 403, 404 LIST_NOT_FOUND, 422 CANNOT_EDIT_ARCHIVED_LIST, 429 with
//    retryAfter, 500, undocumented statuses, transport failures, malformed bodies, cancellation.
//  - The PATCH path (updateList) still never carries a null coOwnerEmail.
//
//  All ids, names and addresses are fake.
//

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

private struct SUT {
    let repo: GeneratedClientListRepository
    let wire: WireHarness

    var transport: ListFakeTransport { wire.transport }
    var refresher: ListFakeRefresher { wire.refresher }
}

private func makeSUT(token: String? = WireHarness.accessToken, refreshFailure: (any Error)? = nil) throws -> SUT {
    let wire = try WireHarness.make(token: token, refreshFailure: refreshFailure)
    return SUT(repo: GeneratedClientListRepository(client: wire.client), wire: wire)
}

private let listId = "list-1"

/// The owner's list as the server returns it after the removal: coOwner is an explicit JSON null.
private func removedSpec() -> ListFixtures.Spec {
    var spec = ListFixtures.ownerOfChildList()
    spec.id = listId
    spec.coOwner = nil
    spec.flags.canSetCoOwner = true
    spec.flags.canEditList = true
    spec.flags.canManageMembers = true
    spec.flags.canSeeMembers = true
    return spec
}

/// A 200 envelope for the spec with `"coOwner": null` present (client guide L15 example).
private func detailJSONWithNullCoOwner(_ spec: ListFixtures.Spec) throws -> String {
    guard var object = try JSONSerialization.jsonObject(with: ListFixtures.detailData(spec)) as? [String: Any] else {
        throw CocoaError(.coderInvalidValue)
    }
    object["coOwner"] = NSNull()
    return ListWire.success(data: ListWire.text(try JSONSerialization.data(withJSONObject: object)))
}

@Suite("GeneratedClientListRepository removeCoOwner")
struct GeneratedClientListRepositoryRemoveCoOwnerTests {

    // MARK: 200

    @Test("removeCoOwner 200 returns the mapped detail with no co-owner and its fresh flags")
    func removeSuccess() async throws {
        let sut = try makeSUT()
        let spec = removedSpec()
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(spec))

        let detail = try await sut.repo.removeCoOwner(listId: listId)

        #expect(detail.id == spec.id)
        #expect(detail.coOwner == nil)
        #expect(detail.capabilities == ListFixtures.capabilities(spec.flags))
        #expect(detail.capabilities.canSetCoOwner)
    }

    @Test("removeCoOwner 200 for a list that had no co-owner (idempotent) returns the unchanged detail")
    func removeIdempotent() async throws {
        let sut = try makeSUT()
        let spec = removedSpec()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.removeCoOwner(listId: listId)

        #expect(detail.id == spec.id)
        #expect(detail.name == spec.name)
        #expect(detail.coOwner == nil)
        #expect(detail.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("removeCoOwner 200 applies the count hardening when canSeeGiftActivity is false")
    func removeCountHardening() async throws {
        let sut = try makeSUT()
        var spec = removedSpec()
        spec.flags.canSeeGiftActivity = false
        spec.itemCount = 4
        spec.purchasedCount = 2
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(spec))

        let detail = try await sut.repo.removeCoOwner(listId: listId)

        #expect(detail.itemCount == nil)
        #expect(detail.purchasedCount == nil)
    }

    // MARK: Request shape

    @Test("removeCoOwner sends DELETE to /tracker/v2/lists/{id}/co-owner with no body and no query")
    func requestLine() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(removedSpec()))

        _ = try await sut.repo.removeCoOwner(listId: listId)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == .delete)
        #expect(recorded.pathOnly == "/tracker/v2/lists/\(listId)/co-owner")
        #expect(recorded.hasQuery == false)
        #expect(recorded.bodyData == nil || recorded.bodyData?.isEmpty == true, "no request body")
        #expect(await sut.transport.requestCount == 1)
    }

    @Test("removeCoOwner carries X-Platform, X-Build, X-App-Version, X-Client-Platform and the bearer token")
    func requestHeaders() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(removedSpec()))

        _ = try await sut.repo.removeCoOwner(listId: listId)

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

    // MARK: 401

    @Test("401 then a second 401 after one refresh throws unauthorized")
    func unauthorizedAfterRefreshAttempt() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 then success after one refresh returns the replayed result")
    func refreshThenReplaySucceeds() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(removedSpec()))

        let detail = try await sut.repo.removeCoOwner(listId: listId)

        #expect(detail.coOwner == nil)
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 2)
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized and does not replay")
    func unauthorizedWhenRefreshCredentialFails() async throws {
        let sut = try makeSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: 403, 404, 422

    @Test("403 FORBIDDEN (a co-owner, member or public non-member) throws forbidden", arguments: [
        MembersWire.forbidden, ListWire.notListOwner
    ])
    func forbidden(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.forbidden) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("404 LIST_NOT_FOUND throws a plain notFound")
    func listNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.listNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("404 with another code stays a plain notFound (no member-email or membership meaning here)", arguments: [
        MembersWire.memberEmailNotFound, MembersWire.membershipNotFound, MembersWire.resourceNotFound, ListWire.recipientNotFound
    ])
    func otherNotFound(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("422 CANNOT_EDIT_ARCHIVED_LIST throws archivedReadOnly")
    func archived() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 422, json: ListWire.archivedList)
        let repo = sut.repo

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    // MARK: 429, 500, undocumented

    @Test("429 with Retry-After throws rateLimited carrying that value")
    func rateLimited() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)
        let repo = sut.repo

        await #expect(throws: ListError.rateLimited(retryAfter: 0.001)) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("500 throws server")
    func serverError() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: [502, 503])
    func undocumented5xx(status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("an undocumented non-5xx status (418, 409) throws invalidResponse", arguments: [418, 409])
    func undocumentedOther(status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: status,
            json: ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
        )
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    // MARK: Malformed and transport

    @Test("a malformed 200 body throws invalidResponse", arguments: ListMalformedBody.allCases)
    func malformedSuccessBody(malformed: ListMalformedBody) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: malformed.json)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("a 200 with no body at all throws invalidResponse")
    func emptySuccessBody() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueEmpty(status: 200)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("a transport failure (URLError) throws network")
    func transportFailure() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network")
    func middlewareNetworkError() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to a ListError")
    func cancellationIsRethrown() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(CancellationError())
        let repo = sut.repo

        await #expect(throws: CancellationError.self) {
            _ = try await repo.removeCoOwner(listId: listId)
        }
    }

    // MARK: The PATCH path only sets

    @Test("updateList never sends a coOwnerEmail key unless the change is .set, and never a null", arguments: [
        UpdateListInput(name: "New Name", theme: nil, visibility: nil),
        UpdateListInput(name: "New Name", theme: "New Theme", visibility: .public, coOwner: .unchanged)
    ])
    func patchNeverCarriesNullCoOwner(input: UpdateListInput) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(id: listId, input)

        let recorded = try #require(await sut.transport.lastRequest())
        let raw = String(decoding: recorded.bodyData ?? Data(), as: UTF8.self)
        #expect(raw.contains("coOwnerEmail") == false, "neither a value nor an explicit null")
        let body = try #require(recorded.jsonObject)
        #expect(body["coOwnerEmail"] == nil)
        #expect((body["coOwnerEmail"] as? NSNull) == nil)
    }

    @Test("clearing never goes through the PATCH route: removeCoOwner issues DELETE, not PATCH")
    func clearUsesDeleteNotPatch() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try detailJSONWithNullCoOwner(removedSpec()))

        _ = try await sut.repo.removeCoOwner(listId: listId)

        let all = await sut.transport.recorded
        #expect(all.count == 1)
        #expect(all.allSatisfy { $0.request.method == .delete })
    }
}
