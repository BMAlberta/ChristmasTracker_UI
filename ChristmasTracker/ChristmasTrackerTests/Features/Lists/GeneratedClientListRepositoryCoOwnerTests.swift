//
//  GeneratedClientListRepositoryCoOwnerTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the co-owner change through GeneratedClientListRepository.updateList, over the
//  REAL factory-built client with a fake transport (client guide 7.4).
//
//  - `.set(email)` sends `coOwnerEmail` (and only the other fields that were supplied).
//  - `.unchanged` sends NO `coOwnerEmail` key.
//  - `.clear` is REFUSED before any request: the generated payload cannot encode an explicit
//    JSON null, so the repository throws ListError.validation and the transport sees nothing.
//  - 404 MEMBER_EMAIL_NOT_FOUND -> memberEmailNotFound (other 404 -> notFound); 403 -> forbidden;
//    422 -> archivedReadOnly (still). createList still never sends coOwnerEmail.
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
}

private func makeSUT() throws -> SUT {
    let wire = try WireHarness.make()
    return SUT(repo: GeneratedClientListRepository(client: wire.client), wire: wire)
}

private let coOwnerAddress = "spouse@example.com"
private let clearRefusal = "Removing the co-owner is not available yet."

@Suite("GeneratedClientListRepository co-owner")
struct GeneratedClientListRepositoryCoOwnerTests {

    // MARK: .set

    @Test("updateList with .set(email) sends only coOwnerEmail when nothing else is supplied")
    func setSendsOnlyCoOwnerEmail() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(
            id: "list-1",
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
        )

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == .patch)
        #expect(recorded.pathOnly == "/tracker/v2/lists/list-1")
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["coOwnerEmail"])
        #expect(body["coOwnerEmail"] as? String == coOwnerAddress)
    }

    @Test("updateList with .set(email) sends the other fields only when supplied", arguments: [
        (UpdateListInput(name: "New Name", theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress)), ["name", "coOwnerEmail"]),
        (UpdateListInput(name: nil, theme: "New Theme", visibility: .public, coOwner: .set(email: coOwnerAddress)), ["theme", "visibility", "coOwnerEmail"]),
        (UpdateListInput(name: "New Name", theme: "New Theme", visibility: .friendsOnly, coOwner: .set(email: coOwnerAddress)),
         ["name", "theme", "visibility", "coOwnerEmail"])
    ])
    func setSendsOtherFieldsOnlyWhenSupplied(input: UpdateListInput, expectedKeys: [String]) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(id: "list-1", input)

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == Set(expectedKeys))
        #expect(body["coOwnerEmail"] as? String == coOwnerAddress)
        #expect(body["status"] == nil)
    }

    @Test("updateList with .set(email) returns the mapped detail with its fresh flags and co-owner")
    func setReturnsMappedDetail() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.blindCoOwner()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.updateList(
            id: spec.id,
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
        )

        #expect(detail.id == spec.id)
        #expect(detail.coOwner == ListPerson(id: "user-1", displayName: "Robin Recipient"))
        #expect(detail.capabilities == ListFixtures.capabilities(spec.flags))
    }

    // MARK: .unchanged

    @Test("updateList with .unchanged sends no coOwnerEmail key", arguments: [
        UpdateListInput(name: "New Name", theme: nil, visibility: nil, coOwner: .unchanged),
        UpdateListInput(name: "New Name", theme: "New Theme", visibility: .public)
    ])
    func unchangedSendsNoCoOwnerEmail(input: UpdateListInput) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(id: "list-1", input)

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(body["coOwnerEmail"] == nil)
        #expect(body["name"] as? String == "New Name")
    }

    // MARK: .clear

    @Test("updateList with .clear throws the not-available validation error and sends no request", arguments: [
        UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .clear),
        UpdateListInput(name: "New Name", theme: "New Theme", visibility: .public, coOwner: .clear)
    ])
    func clearIsRefusedWithoutARequest(input: UpdateListInput) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))
        let repo = sut.repo

        await #expect(throws: ListError.validation(message: clearRefusal)) {
            _ = try await repo.updateList(id: "list-1", input)
        }

        #expect(await sut.transport.requestCount == 0, "no request, and in particular no empty PATCH")
    }

    // MARK: Errors

    @Test("updateList 404 MEMBER_EMAIL_NOT_FOUND (4009) throws memberEmailNotFound")
    func updateListMemberEmailNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: MembersWire.memberEmailNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.memberEmailNotFound) {
            _ = try await repo.updateList(
                id: "list-1",
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
            )
        }
    }

    @Test("updateList 404 with another code throws notFound", arguments: [
        ListWire.listNotFound, ListWire.recipientNotFound, MembersWire.membershipNotFound, MembersWire.resourceNotFound
    ])
    func updateListOtherNotFound(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.updateList(
                id: "list-1",
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
            )
        }
    }

    @Test("updateList 403 throws forbidden (a co-owner setting it, or the owner or recipient as co-owner)", arguments: [
        ListWire.notListOwner, MembersWire.forbidden
    ])
    func updateList403(body: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: body)
        let repo = sut.repo

        await #expect(throws: ListError.forbidden) {
            _ = try await repo.updateList(
                id: "list-1",
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
            )
        }
    }

    @Test("updateList 422 CANNOT_EDIT_ARCHIVED_LIST still throws archivedReadOnly with a co-owner change")
    func updateList422() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 422, json: ListWire.archivedList)
        let repo = sut.repo

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.updateList(
                id: "list-1",
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: coOwnerAddress))
            )
        }
    }

    // MARK: createList regression

    @Test("createList still never sends coOwnerEmail, also for a child recipient")
    func createListStillSendsNoCoOwnerEmail() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.createList(
            CreateListInput(recipientId: "child-1", year: 2026, name: "Fake Child List", theme: nil, visibility: .private)
        )

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(body["coOwnerEmail"] == nil)
        #expect(body["recipientId"] as? String == "child-1")
    }
}
