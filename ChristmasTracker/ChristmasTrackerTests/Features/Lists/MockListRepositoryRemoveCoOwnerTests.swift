//
//  MockListRepositoryRemoveCoOwnerTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-2 R2: the pinned behavior of MockListRepository.removeCoOwner, so previews and
//  mock mode behave like the server (decision L15).
//
//  - Returns the detail with coOwner nil, and the change is visible through fetchListDetail.
//  - Idempotent: a list without a co-owner returns the unchanged detail.
//  - forbidden when the stored list's canSetCoOwner is false; notFound for an unknown id;
//    shouldFail throws server.
//
//  Delay is set to 0 through the test helper so nothing waits on the mock's sleep.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockListRepository removeCoOwner", .timeLimit(.minutes(1)))
struct MockListRepositoryRemoveCoOwnerTests {

    // Ids and addresses of the mock data (see MockMemberRepositoryTests).
    private let childListId = "mock-list-child"      // the current user owns it: canSetCoOwner, no co-owner
    private let coOwnerListId = "mock-list-coowner"  // the current user is the co-owner: canSetCoOwner false
    private let knownCoOwnerEmail = "cody.coowner@example.com"

    private func makeSUT() async -> MockListRepository {
        let repo = MockListRepository(withMockData: true, includeAllScenarios: true)
        await repo.setDelay(0)
        return repo
    }

    private func setCoOwner(_ repo: MockListRepository) async throws -> ListDetail {
        try await repo.updateList(
            id: childListId,
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: knownCoOwnerEmail))
        )
    }

    // MARK: - Success

    @Test("removeCoOwner returns the detail with no co-owner")
    func returnsDetailWithoutCoOwner() async throws {
        let repo = await makeSUT()
        let withCoOwner = try await setCoOwner(repo)
        #expect(withCoOwner.coOwner != nil, "precondition")

        let detail = try await repo.removeCoOwner(listId: childListId)

        #expect(detail.id == childListId)
        #expect(detail.coOwner == nil)
        #expect(detail.name == withCoOwner.name)
        #expect(detail.capabilities == withCoOwner.capabilities)
    }

    @Test("the removal is visible through fetchListDetail and fetchLists")
    func removalIsPersisted() async throws {
        let repo = await makeSUT()
        _ = try await setCoOwner(repo)

        _ = try await repo.removeCoOwner(listId: childListId)

        let fetched = try await repo.fetchListDetail(id: childListId)
        #expect(fetched.coOwner == nil)
        let summary = try #require(try await repo.fetchLists().first(where: { $0.id == childListId }))
        #expect(summary.coOwner == nil)
    }

    @Test("a co-owner can be set again after it was removed")
    func setAgainAfterRemoval() async throws {
        let repo = await makeSUT()
        _ = try await setCoOwner(repo)
        _ = try await repo.removeCoOwner(listId: childListId)

        let again = try await setCoOwner(repo)

        #expect(again.coOwner != nil)
    }

    @Test("removeCoOwner is idempotent: with no co-owner it returns the unchanged detail")
    func idempotentWithoutCoOwner() async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchListDetail(id: childListId)
        #expect(before.coOwner == nil, "precondition")

        let detail = try await repo.removeCoOwner(listId: childListId)

        #expect(detail == before)
        let after = try await repo.fetchListDetail(id: childListId)
        #expect(after == before)
    }

    @Test("removing twice gives the same detail both times")
    func removeTwice() async throws {
        let repo = await makeSUT()
        _ = try await setCoOwner(repo)

        let first = try await repo.removeCoOwner(listId: childListId)
        let second = try await repo.removeCoOwner(listId: childListId)

        #expect(first == second)
    }

    // MARK: - Errors

    @Test("removeCoOwner throws forbidden where canSetCoOwner is false, and changes nothing", arguments: [
        "mock-list-coowner", "mock-list-member", "mock-list-viewer"
    ])
    func forbiddenWithoutCanSetCoOwner(listId: String) async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchListDetail(id: listId)
        #expect(before.capabilities.canSetCoOwner == false, "precondition")

        await #expect(throws: ListError.forbidden) {
            _ = try await repo.removeCoOwner(listId: listId)
        }

        let after = try await repo.fetchListDetail(id: listId)
        #expect(after == before)
    }

    @Test("the co-owner of a list cannot remove the co-owner (forbidden), the co-owner stays")
    func coOwnerCannotRemoveSelf() async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchListDetail(id: coOwnerListId)
        #expect(before.coOwner != nil, "precondition")

        await #expect(throws: ListError.forbidden) {
            _ = try await repo.removeCoOwner(listId: coOwnerListId)
        }

        let after = try await repo.fetchListDetail(id: coOwnerListId)
        #expect(after.coOwner == before.coOwner)
    }

    @Test("removeCoOwner for an unknown list throws notFound")
    func unknownListNotFound() async {
        let repo = await makeSUT()

        await #expect(throws: ListError.notFound) {
            _ = try await repo.removeCoOwner(listId: "mock-list-missing")
        }
    }

    @Test("removeCoOwner honors shouldFail and changes nothing")
    func honorsShouldFail() async throws {
        let repo = await makeSUT()
        let withCoOwner = try await setCoOwner(repo)
        await repo.setShouldFail(true)

        await #expect(throws: ListError.server) {
            _ = try await repo.removeCoOwner(listId: childListId)
        }

        await repo.setShouldFail(false)
        let after = try await repo.fetchListDetail(id: childListId)
        #expect(after.coOwner == withCoOwner.coOwner)
    }
}
