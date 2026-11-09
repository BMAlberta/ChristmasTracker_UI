//
//  GeneratedClientListRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: GeneratedClientListRepository through the REAL factory-built client with a fake
//  transport and guide-accurate literal JSON (full `meta` object).
//
//  Construction assumption (same as the auth repository):
//      GeneratedClientListRepository(client: client)    // client from TrackerClientFactory.make
//
//  Rate-limit note: RateLimitMiddleware retries a 429 on GET (twice) with a REAL sleeper. The
//  429 fixtures use `Retry-After: 0.001` so the retries cost about a millisecond, and the
//  mapped value is asserted exactly (0.001) so a repository that drops the value fails.
//
//  These tests do not compile until the implementer adds GeneratedClientListRepository and the
//  new ListError cases (.server, .network, .invalidResponse, .recipientNotFound, ...).
//

import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Shared setup

private let baseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()
private let accessToken = "tok-access-FAKE"

private struct SUT {
    let repo: GeneratedClientListRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher
}

private func makeSUT(token: String? = accessToken, refreshFailure: (any Error)? = nil) throws -> SUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: baseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return SUT(repo: GeneratedClientListRepository(client: client), transport: transport, refresher: refresher)
}

private func sampleCreateInput(
    theme: String? = nil,
    visibility: ListVisibility = .private
) -> CreateListInput {
    CreateListInput(recipientId: "user-1", year: 2026, name: "Fake Family List", theme: theme, visibility: visibility)
}

// MARK: - The five operations, for cross-cutting tests

nonisolated enum ListRepoOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case fetchLists, fetchListDetail, createList, updateList, deleteList

    var testDescription: String {
        switch self {
        case .fetchLists: "fetchLists"
        case .fetchListDetail: "fetchListDetail"
        case .createList: "createList"
        case .updateList: "updateList"
        case .deleteList: "deleteList"
        }
    }

    var successStatus: Int { self == .createList ? 201 : 200 }

    var method: HTTPRequest.Method {
        switch self {
        case .fetchLists, .fetchListDetail: .get
        case .createList: .post
        case .updateList: .patch
        case .deleteList: .delete
        }
    }

    func successJSON() throws -> String {
        switch self {
        case .fetchLists: try ListWire.listsJSON([ListFixtures.ownerOfChildList()])
        case .fetchListDetail, .createList, .updateList: try ListWire.detailJSON(ListFixtures.ownerOfChildList())
        case .deleteList: ListWire.messageJSON()
        }
    }

    func run(_ repo: GeneratedClientListRepository) async throws {
        switch self {
        case .fetchLists:
            _ = try await repo.fetchLists()
        case .fetchListDetail:
            _ = try await repo.fetchListDetail(id: "list-1")
        case .createList:
            _ = try await repo.createList(sampleCreateInput())
        case .updateList:
            _ = try await repo.updateList(id: "list-1", UpdateListInput(name: "New Name", theme: nil, visibility: nil))
        case .deleteList:
            try await repo.deleteList(id: "list-1")
        }
    }
}

nonisolated enum ListMalformedBody: CaseIterable, Sendable, CustomTestStringConvertible {
    case notJSON, missingData, emptyData

    var testDescription: String {
        switch self {
        case .notJSON: "not JSON"
        case .missingData: "data missing"
        case .emptyData: "data is an empty object"
        }
    }

    var json: String {
        switch self {
        case .notJSON: "{ this is not json"
        case .missingData: "{ \"success\": true, \"meta\": \(ListWire.metaJSON) }"
        case .emptyData: "{ \"success\": true, \"data\": {}, \"meta\": \(ListWire.metaJSON) }"
        }
    }
}

/// The privacy and ownership scenarios from the contract, as wire specs.
nonisolated enum ListScenario: CaseIterable, Sendable, CustomTestStringConvertible {
    case blindOwner, ownerOfChild, memberRole, viewerRole, publicNonMember, blindCoOwner
    case recipient, archivedAsMember, archivedAsOwner

    var testDescription: String { "\(self)" }

    var spec: ListFixtures.Spec {
        switch self {
        case .blindOwner: ListFixtures.blindOwnerOfSelfList()
        case .ownerOfChild: ListFixtures.ownerOfChildList()
        case .memberRole: ListFixtures.memberRoleMember()
        case .viewerRole: ListFixtures.viewerRoleMember()
        case .publicNonMember: ListFixtures.publicNonMember()
        case .blindCoOwner: ListFixtures.blindCoOwner()
        case .recipient: ListFixtures.recipientOfSelfList()
        case .archivedAsMember: ListFixtures.archivedAsMember()
        case .archivedAsOwner: ListFixtures.archivedAsOwner()
        }
    }
}

// MARK: - Wire-to-domain expectations

private func expectedRole(_ raw: String) -> ListRole {
    switch raw {
    case "owner": .owner
    case "co-owner": .coOwner
    case "member": .member
    default: .viewer
    }
}

private func expectedVisibility(_ raw: String) -> ListVisibility {
    switch raw {
    case "INVITE_ONLY": .inviteOnly
    case "FRIENDS_ONLY": .friendsOnly
    case "PUBLIC": .public
    default: .private
    }
}

private func expectedStatus(_ raw: String) -> ListStatus {
    switch raw {
    case "DRAFT": .draft
    case "ARCHIVED": .archived
    default: .active
    }
}

/// Counts are only ever shown to viewers who may see gift activity (count hardening).
private func expectedCount(_ value: Int?, _ spec: ListFixtures.Spec) -> Int? {
    spec.flags.canSeeGiftActivity ? value : nil
}

private func expectMatches(_ list: GiftList, _ spec: ListFixtures.Spec) {
    #expect(list.id == spec.id)
    #expect(list.name == spec.name)
    #expect(list.theme == spec.theme)
    #expect(list.year == spec.year)
    #expect(list.visibility == expectedVisibility(spec.visibility))
    #expect(list.status == expectedStatus(spec.status))
    #expect(list.recipient == ListPerson(id: spec.recipientId, displayName: spec.recipientName))
    #expect(list.owner == ListPerson(id: spec.ownerId, displayName: spec.ownerName))
    #expect(list.coOwner == spec.coOwner.map { ListPerson(id: $0.id, displayName: $0.name) })
    #expect(list.myRole == expectedRole(spec.myRole))
    #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    #expect(list.memberCount == spec.memberCount)
    #expect(list.itemCount == expectedCount(spec.itemCount, spec))
    #expect(list.purchasedCount == expectedCount(spec.purchasedCount, spec))
}

private func expectMatches(_ detail: ListDetail, _ spec: ListFixtures.Spec) {
    expectMatches(detail.asGiftList(), spec)
    #expect(detail.members?.count == spec.members?.count)
}

// MARK: - Suite

@Suite("GeneratedClientListRepository")
struct GeneratedClientListRepositoryTests {

    // MARK: fetchLists success

    @Test("fetchLists maps every privacy scenario: all twelve flags, optional fields, counts", arguments: ListScenario.allCases)
    func fetchListsMapsScenario(scenario: ListScenario) async throws {
        let sut = try makeSUT()
        let spec = scenario.spec
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([spec]))

        let lists = try await sut.repo.fetchLists()

        let list = try #require(lists.first)
        #expect(lists.count == 1)
        expectMatches(list, spec)
    }

    @Test("fetchLists maps several lists in server order")
    func fetchListsMapsSeveralInOrder() async throws {
        let sut = try makeSUT()
        let specs = [ListFixtures.ownerOfChildList(), ListFixtures.blindOwnerOfSelfList(), ListFixtures.viewerRoleMember()]
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON(specs))

        let lists = try await sut.repo.fetchLists()

        #expect(lists.map(\.id) == specs.map(\.id))
    }

    @Test("fetchLists with an empty data array returns an empty list")
    func fetchListsEmpty() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([]))

        let lists = try await sut.repo.fetchLists()

        #expect(lists.isEmpty)
    }

    @Test("fetchLists keeps ARCHIVED and DRAFT lists as they are (hiding is the service's job)")
    func fetchListsDoesNotFilterByStatus() async throws {
        let sut = try makeSUT()
        var draft = ListFixtures.ownerOfChildList()
        draft.id = "list-draft"
        draft.status = "DRAFT"
        let archived = ListFixtures.archivedAsOwner()
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([draft, archived]))

        let lists = try await sut.repo.fetchLists()

        #expect(lists.map(\.status) == [.draft, .archived])
    }

    @Test("fetchLists maps twelve distinct flag values to the right fields (no swapped flags)")
    func fetchListsMapsDistinctFlags() async throws {
        let sut = try makeSUT()
        var spec = ListFixtures.ownerOfChildList()
        spec.flags = ListFixtures.distinctFlags
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([spec]))

        let list = try #require(try await sut.repo.fetchLists().first)

        #expect(list.capabilities == ListFixtures.capabilities(ListFixtures.distinctFlags))
    }

    // MARK: fetchListDetail success

    @Test("fetchListDetail maps every privacy scenario, members present or absent", arguments: ListScenario.allCases)
    func fetchListDetailMapsScenario(scenario: ListScenario) async throws {
        let sut = try makeSUT()
        let spec = scenario.spec
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.fetchListDetail(id: spec.id)

        expectMatches(detail, spec)
        if spec.members == nil {
            #expect(detail.members == nil, "an absent members key must stay nil, not become an empty array")
        } else {
            #expect(detail.members != nil)
        }
    }

    @Test("fetchListDetail maps every member field, including optional email and dates")
    func fetchListDetailMapsMembers() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.memberRoleMember()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.fetchListDetail(id: spec.id)

        let members = try #require(detail.members)
        #expect(members.count == 2)
        let first = members[0]
        #expect(first.id == "mem-1")
        #expect(first.userId == "user-2")
        #expect(first.displayName == "Casey Member")
        #expect(first.email == "casey@example.invalid")
        #expect(first.role == .member)
        #expect(first.status == .active)
        #expect(first.acceptedAt != nil)
        #expect(first.expiresAt == nil)
        let second = members[1]
        #expect(second.id == "mem-2")
        #expect(second.email == nil)
        #expect(second.role == .viewer)
        #expect(second.status == .invited)
        #expect(second.acceptedAt == nil)
        #expect(second.expiresAt != nil)
    }

    @Test("fetchListDetail accepts an explicit JSON null theme")
    func fetchListDetailNullTheme() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.ownerOfChildList()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSONWithNullTheme(spec))

        let detail = try await sut.repo.fetchListDetail(id: spec.id)

        #expect(detail.theme == nil)
    }

    @Test("fetchListDetail with theme and co-owner present maps both")
    func fetchListDetailMapsThemeAndCoOwner() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.blindCoOwner()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.fetchListDetail(id: spec.id)

        #expect(detail.theme == "Cosy")
        #expect(detail.coOwner == ListPerson(id: "user-1", displayName: "Robin Recipient"))
        #expect(detail.myRole == .coOwner)
    }

    // MARK: Count hardening

    @Test("count hardening: canSeeGiftActivity false maps present counts to nil (fetchLists)")
    func countHardeningFetchLists() async throws {
        let sut = try makeSUT()
        var spec = ListFixtures.blindOwnerOfSelfList()
        spec.itemCount = 7
        spec.purchasedCount = 3
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([spec]))

        let list = try #require(try await sut.repo.fetchLists().first)

        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
    }

    @Test("count hardening: canSeeGiftActivity false maps present counts to nil (fetchListDetail)")
    func countHardeningFetchDetail() async throws {
        let sut = try makeSUT()
        var spec = ListFixtures.viewerRoleMember()
        spec.itemCount = 7
        spec.purchasedCount = 3
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.fetchListDetail(id: spec.id)

        #expect(detail.itemCount == nil)
        #expect(detail.purchasedCount == nil)
    }

    @Test("count hardening: also applies to the detail returned by createList and updateList")
    func countHardeningCreateAndUpdate() async throws {
        let sut = try makeSUT()
        var spec = ListFixtures.blindOwnerOfSelfList()
        spec.itemCount = 7
        spec.purchasedCount = 3
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(spec))
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let created = try await sut.repo.createList(sampleCreateInput())
        let updated = try await sut.repo.updateList(id: spec.id, UpdateListInput(name: "New Name", theme: nil, visibility: nil))

        #expect(created.itemCount == nil && created.purchasedCount == nil)
        #expect(updated.itemCount == nil && updated.purchasedCount == nil)
    }

    @Test("count control: canSeeGiftActivity true keeps the counts")
    func countsKeptWhenGiftActivityVisible() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.ownerOfChildList()
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([spec]))

        let list = try #require(try await sut.repo.fetchLists().first)

        #expect(list.itemCount == 8)
        #expect(list.purchasedCount == 3)
    }

    // MARK: createList / updateList / deleteList success

    @Test("createList 201 returns the mapped detail with fresh flags")
    func createListSuccess() async throws {
        let sut = try makeSUT()
        let spec = ListFixtures.blindOwnerOfSelfList()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.createList(sampleCreateInput())

        expectMatches(detail, spec)
        #expect(detail.capabilities.canEditList)
        #expect(detail.capabilities.isRecipient)
        #expect(detail.capabilities.canSeeGiftActivity == false)
    }

    @Test("updateList 200 returns the mapped detail with fresh flags")
    func updateListSuccess() async throws {
        let sut = try makeSUT()
        var spec = ListFixtures.ownerOfChildList()
        spec.name = "Renamed List"
        spec.flags = ListFixtures.distinctFlags
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(spec))

        let detail = try await sut.repo.updateList(id: spec.id, UpdateListInput(name: "Renamed List", theme: nil, visibility: nil))

        expectMatches(detail, spec)
        #expect(detail.name == "Renamed List")
    }

    @Test("deleteList 200 completes and returns nothing")
    func deleteListSuccess() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: ListWire.messageJSON())

        try await sut.repo.deleteList(id: "list-1")

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Request shape: method, path, headers, token

    @Test("every operation uses the right method and path", arguments: ListRepoOp.allCases)
    func methodAndPath(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == op.method)
        switch op {
        case .fetchLists, .createList:
            #expect(recorded.pathOnly == "/tracker/v2/lists")
        case .fetchListDetail, .updateList, .deleteList:
            #expect(recorded.pathOnly == "/tracker/v2/lists/list-1")
        }
    }

    @Test("every request carries X-Platform, X-Build, X-App-Version, X-Client-Platform and the bearer token", arguments: ListRepoOp.allCases)
    func requestHeaders(op: ListRepoOp) async throws {
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
        #expect(fields[.authorization] == "Bearer \(accessToken)")
        #expect(fields[cookie] == nil)
    }

    @Test("fetchLists sends no query string at all")
    func fetchListsSendsNoQuery() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.listsJSON([]))

        _ = try await sut.repo.fetchLists()

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.hasQuery == false, "no status, year, visibility or role parameter may be sent")
        #expect(recorded.request.path == "/tracker/v2/lists")
    }

    @Test("fetchListDetail, updateList and deleteList send no query string")
    func otherListRequestsSendNoQuery() async throws {
        let sut = try makeSUT()
        let detailJSON = try ListWire.detailJSON(ListFixtures.ownerOfChildList())
        await sut.transport.enqueue(status: 200, json: detailJSON)
        await sut.transport.enqueue(status: 200, json: detailJSON)
        await sut.transport.enqueue(status: 200, json: ListWire.messageJSON())

        _ = try await sut.repo.fetchListDetail(id: "list-1")
        _ = try await sut.repo.updateList(id: "list-1", UpdateListInput(name: "New Name", theme: nil, visibility: nil))
        try await sut.repo.deleteList(id: "list-1")

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 3)
        #expect(recorded.allSatisfy { !$0.hasQuery })
    }

    @Test("deleteList and fetchListDetail send no request body")
    func noBodyOnDeleteAndGet() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))
        await sut.transport.enqueue(status: 200, json: ListWire.messageJSON())

        _ = try await sut.repo.fetchListDetail(id: "list-1")
        try await sut.repo.deleteList(id: "list-1")

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 2)
        #expect(recorded.allSatisfy { ($0.bodyData ?? Data()).isEmpty })
    }

    // MARK: Request body: createList

    @Test("createList body has exactly recipientId, year, name, visibility when no theme is supplied")
    func createListBodyWithoutTheme() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(ListFixtures.blindOwnerOfSelfList()))

        _ = try await sut.repo.createList(sampleCreateInput(theme: nil, visibility: .inviteOnly))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["recipientId", "year", "name", "visibility"])
        #expect(body["recipientId"] as? String == "user-1")
        #expect(body["year"] as? Int == 2026)
        #expect(body["name"] as? String == "Fake Family List")
        #expect(body["visibility"] as? String == "INVITE_ONLY")
    }

    @Test("createList body adds theme only when supplied")
    func createListBodyWithTheme() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(ListFixtures.blindOwnerOfSelfList()))

        _ = try await sut.repo.createList(sampleCreateInput(theme: "Cosy Winter"))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["recipientId", "year", "name", "visibility", "theme"])
        #expect(body["theme"] as? String == "Cosy Winter")
    }

    @Test("createList never sends coOwnerEmail, offList or status", arguments: [nil, "Cosy Winter"] as [String?])
    func createListBodyNeverHasForbiddenKeys(theme: String?) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(ListFixtures.blindOwnerOfSelfList()))

        _ = try await sut.repo.createList(sampleCreateInput(theme: theme))

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        for forbidden in ["coOwnerEmail", "offList", "status"] {
            #expect(body[forbidden] == nil, "\(forbidden) must not be sent on create")
        }
    }

    @Test("createList sends the wire value for every visibility", arguments: [
        (ListVisibility.private, "PRIVATE"),
        (ListVisibility.inviteOnly, "INVITE_ONLY"),
        (ListVisibility.friendsOnly, "FRIENDS_ONLY"),
        (ListVisibility.public, "PUBLIC")
    ])
    func createListVisibilityWireValues(visibility: ListVisibility, wire: String) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 201, json: try ListWire.detailJSON(ListFixtures.blindOwnerOfSelfList()))

        _ = try await sut.repo.createList(sampleCreateInput(visibility: visibility))

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.jsonObject?["visibility"] as? String == wire)
    }

    // MARK: Request body: updateList

    @Test("updateList sends only the changed fields", arguments: [
        (UpdateListInput(name: "New Name", theme: nil, visibility: nil), ["name"]),
        (UpdateListInput(name: nil, theme: "New Theme", visibility: nil), ["theme"]),
        (UpdateListInput(name: nil, theme: nil, visibility: .friendsOnly), ["visibility"]),
        (UpdateListInput(name: "New Name", theme: "New Theme", visibility: .public), ["name", "theme", "visibility"])
    ])
    func updateListSendsOnlyChangedFields(input: UpdateListInput, expectedKeys: [String]) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(id: "list-1", input)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == .patch)
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == Set(expectedKeys))
        #expect(body["status"] == nil)
        #expect(body["coOwnerEmail"] == nil)
    }

    @Test("updateList sends the values of the changed fields")
    func updateListBodyValues() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 200, json: try ListWire.detailJSON(ListFixtures.ownerOfChildList()))

        _ = try await sut.repo.updateList(
            id: "list-1",
            UpdateListInput(name: "New Name", theme: "New Theme", visibility: .public)
        )

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(body["name"] as? String == "New Name")
        #expect(body["theme"] as? String == "New Theme")
        #expect(body["visibility"] as? String == "PUBLIC")
    }

    // MARK: 400 validation

    @Test("createList 400 throws validation with the server message")
    func createList400() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: 400,
            json: ListWire.errorJSON(code: 3001, errorCode: "VALIDATION_ERROR", message: "Name must be between 1 and 200 characters")
        )
        let repo = sut.repo

        await #expect(throws: ListError.validation(message: "Name must be between 1 and 200 characters")) {
            _ = try await repo.createList(sampleCreateInput())
        }
    }

    @Test("updateList 400 throws validation with the server message")
    func updateList400() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(
            status: 400,
            json: ListWire.errorJSON(code: 3000, errorCode: "INVALID_INPUT", message: "Theme must be at most 500 characters")
        )
        let repo = sut.repo

        await #expect(throws: ListError.validation(message: "Theme must be at most 500 characters")) {
            _ = try await repo.updateList(id: "list-1", UpdateListInput(name: nil, theme: "x", visibility: nil))
        }
    }

    // MARK: 401 (after the middleware's refresh attempt)

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: ListRepoOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized", arguments: ListRepoOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: ListRepoOp) async throws {
        let sut = try makeSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        let repo = sut.repo

        await #expect(throws: ListError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed result", arguments: ListRepoOp.allCases)
    func refreshThenReplaySucceeds(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: op.successStatus, json: try op.successJSON())

        try await op.run(sut.repo)

        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 2)
    }

    // MARK: 403

    @Test("403 throws forbidden", arguments: ListRepoOp.allCases)
    func forbidden(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 403, json: ListWire.notListOwner)
        let repo = sut.repo

        await #expect(throws: ListError.forbidden) {
            try await op.run(repo)
        }
    }

    // MARK: 404

    @Test("404 LIST_NOT_FOUND throws notFound", arguments: ListRepoOp.allCases)
    func listNotFound(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.listNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            try await op.run(repo)
        }
    }

    @Test("createList 404 RECIPIENT_NOT_FOUND (4010) throws recipientNotFound")
    func createListRecipientNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.recipientNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.recipientNotFound) {
            _ = try await repo.createList(sampleCreateInput())
        }
    }

    @Test("createList 404 with the same shape but another code (PERSON_NOT_FOUND) throws notFound")
    func createListOtherNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.personNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.createList(sampleCreateInput())
        }
    }

    @Test("createList 404 LIST_NOT_FOUND throws notFound, not recipientNotFound")
    func createListListNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.listNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.createList(sampleCreateInput())
        }
    }

    @Test("updateList 404 carrying RECIPIENT_NOT_FOUND stays notFound (the special case is create only)")
    func updateListRecipientCodeStaysNotFound() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.recipientNotFound)
        let repo = sut.repo

        await #expect(throws: ListError.notFound) {
            _ = try await repo.updateList(id: "list-1", UpdateListInput(name: "New Name", theme: nil, visibility: nil))
        }
    }

    // MARK: 409 and 422

    @Test("createList 409 LIST_ALREADY_EXISTS (5002) throws duplicateRecipientYear")
    func createList409() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 409, json: ListWire.listAlreadyExists)
        let repo = sut.repo

        await #expect(throws: ListError.duplicateRecipientYear) {
            _ = try await repo.createList(sampleCreateInput())
        }
    }

    @Test("updateList 422 CANNOT_EDIT_ARCHIVED_LIST throws archivedReadOnly")
    func updateList422() async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 422, json: ListWire.archivedList)
        let repo = sut.repo

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.updateList(id: "list-1", UpdateListInput(name: "New Name", theme: nil, visibility: nil))
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: ListRepoOp.allCases)
    func rateLimited(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        // GET is retried twice by the middleware, so queue three; other verbs use only the first.
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)
        let repo = sut.repo

        await #expect(throws: ListError.rateLimited(retryAfter: 0.001)) {
            try await op.run(repo)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: ListRepoOp.allCases)
    func serverError(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: ListRepoOp.allCases, [502, 503])
    func undocumented5xx(op: ListRepoOp, status: Int) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ListError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented non-5xx status (418) throws invalidResponse", arguments: ListRepoOp.allCases)
    func undocumented418(op: ListRepoOp) async throws {
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

    @Test("a malformed 200/201 body throws invalidResponse", arguments: ListRepoOp.allCases, ListMalformedBody.allCases)
    func malformedSuccessBody(op: ListRepoOp, malformed: ListMalformedBody) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueue(status: op.successStatus, json: malformed.json)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a 200 with no body at all throws invalidResponse", arguments: ListRepoOp.allCases)
    func emptySuccessBody(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueEmpty(status: op.successStatus)
        let repo = sut.repo

        await #expect(throws: ListError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a transport failure (URLError) throws network", arguments: ListRepoOp.allCases)
    func transportFailure(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            try await op.run(repo)
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network", arguments: ListRepoOp.allCases)
    func middlewareNetworkError(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))
        let repo = sut.repo

        await #expect(throws: ListError.network) {
            try await op.run(repo)
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to a ListError", arguments: ListRepoOp.allCases)
    func cancellationIsRethrown(op: ListRepoOp) async throws {
        let sut = try makeSUT()
        await sut.transport.enqueueThrow(CancellationError())
        let repo = sut.repo

        await #expect(throws: CancellationError.self) {
            try await op.run(repo)
        }
    }
}
