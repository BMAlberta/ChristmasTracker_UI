//
//  MockListRepositoryArchiveTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: MockListRepository behaves like the server for archiving (decision L16).
//
//  - deleteList ARCHIVES: the list stays, status ARCHIVED, the four management flags
//    (canEditList, canDeleteList, canManageMembers, canSetCoOwner) false, every other flag unchanged.
//  - updateList and removeCoOwner on an archived list throw archivedReadOnly (the 422).
//
//  Delay is set to 0 through the test helper so nothing waits on the mock's sleep. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockListRepository archive", .timeLimit(.minutes(1)))
struct MockListRepositoryArchiveTests {

    private let childListId = "mock-list-child"
    private let selfListId = "mock-list-self"
    private let seededArchivedListId = "mock-list-archived"
    private let knownCoOwnerEmail = "cody.coowner@example.com"

    /// The lists the current user may delete (canDeleteList true on the seeded active scenarios).
    nonisolated static let deletableListIds = ["mock-list-child", "mock-list-self", "mock-list-coowner"]

    private func makeSUT() async -> MockListRepository {
        let repo = MockListRepository(withMockData: true, includeAllScenarios: true)
        await repo.setDelay(0)
        return repo
    }

    private func rename() -> UpdateListInput {
        UpdateListInput(name: "Renamed", theme: nil, visibility: nil)
    }

    // MARK: - deleteList archives

    @Test("deleteList keeps the list and sets its status to ARCHIVED", arguments: MockListRepositoryArchiveTests.deletableListIds)
    func deleteArchives(listId: String) async throws {
        let repo = await makeSUT()
        let countBefore = try await repo.fetchLists().count

        try await repo.deleteList(id: listId)

        let detail = try await repo.fetchListDetail(id: listId)
        #expect(detail.status == .archived)
        let lists = try await repo.fetchLists()
        #expect(lists.count == countBefore, "nothing is removed")
        let summary = try #require(lists.first { $0.id == listId })
        #expect(summary.status == .archived)
    }

    @Test("deleteList sets the four management flags false and leaves every other flag unchanged",
          arguments: MockListRepositoryArchiveTests.deletableListIds)
    func deleteChangesOnlyManagementFlags(listId: String) async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchListDetail(id: listId).capabilities
        #expect(before.canDeleteList, "precondition")

        try await repo.deleteList(id: listId)

        let after = try await repo.fetchListDetail(id: listId).capabilities
        #expect(!after.canEditList)
        #expect(!after.canDeleteList)
        #expect(!after.canManageMembers)
        #expect(!after.canSetCoOwner)
        #expect(after.isRecipient == before.isRecipient)
        #expect(after.canSeeGiftActivity == before.canSeeGiftActivity)
        #expect(after.canPurchase == before.canPurchase)
        #expect(after.canAddOffList == before.canAddOffList)
        #expect(after.canSeeOffList == before.canSeeOffList)
        #expect(after.canCreateItem == before.canCreateItem)
        #expect(after.canSeeMembers == before.canSeeMembers)
        #expect(after.canLeaveList == before.canLeaveList)
    }

    @Test("an archived list keeps its name, owner, counts and roster")
    func archiveKeepsContent() async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchListDetail(id: childListId)

        try await repo.deleteList(id: childListId)

        let after = try await repo.fetchListDetail(id: childListId)
        #expect(after.name == before.name)
        #expect(after.owner == before.owner)
        #expect(after.itemCount == before.itemCount)
        #expect(after.purchasedCount == before.purchasedCount)
        #expect(after.members == before.members)
    }

    @Test("the summary in fetchLists carries the same archived status and flags as the detail")
    func summaryMatchesDetail() async throws {
        let repo = await makeSUT()

        try await repo.deleteList(id: childListId)

        let detail = try await repo.fetchListDetail(id: childListId)
        let summary = try #require(try await repo.fetchLists().first { $0.id == childListId })
        #expect(summary.status == detail.status)
        #expect(summary.capabilities == detail.capabilities)
    }

    @Test("other lists are not touched by archiving one")
    func otherListsUnchanged() async throws {
        let repo = await makeSUT()
        let otherBefore = try await repo.fetchListDetail(id: selfListId)

        try await repo.deleteList(id: childListId)

        let otherAfter = try await repo.fetchListDetail(id: selfListId)
        #expect(otherAfter == otherBefore)
    }

    @Test("deleteList of an unknown list still throws notFound and changes nothing")
    func deleteUnknownStillNotFound() async throws {
        let repo = await makeSUT()
        let before = try await repo.fetchLists()

        await #expect(throws: ListError.notFound) { try await repo.deleteList(id: "mock-list-missing") }

        let after = try await repo.fetchLists()
        #expect(after == before)
    }

    @Test("a failing mock archives nothing")
    func failingMockArchivesNothing() async throws {
        let repo = await makeSUT()
        await repo.setShouldFail(true)

        await #expect(throws: ListError.server) { try await repo.deleteList(id: childListId) }

        await repo.setShouldFail(false)
        let detail = try await repo.fetchListDetail(id: childListId)
        #expect(detail.status == .active)
        #expect(detail.capabilities.canDeleteList)
    }

    // MARK: - Writes on an archived list are the 422

    @Test("updateList on a list archived through deleteList throws archivedReadOnly and changes nothing")
    func updateAfterArchiveThrows() async throws {
        let repo = await makeSUT()
        try await repo.deleteList(id: childListId)
        let before = try await repo.fetchListDetail(id: childListId)

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.updateList(id: childListId, rename())
        }

        let after = try await repo.fetchListDetail(id: childListId)
        #expect(after == before)
    }

    @Test("updateList on the seeded archived scenario throws archivedReadOnly")
    func updateSeededArchivedThrows() async {
        let repo = await makeSUT()

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.updateList(id: seededArchivedListId, rename())
        }
    }

    @Test("setting a co-owner through updateList on an archived list throws archivedReadOnly")
    func setCoOwnerOnArchivedThrows() async throws {
        let repo = await makeSUT()
        try await repo.deleteList(id: childListId)

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.updateList(
                id: childListId,
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: knownCoOwnerEmail))
            )
        }
    }

    @Test("removeCoOwner on a list archived through deleteList throws archivedReadOnly")
    func removeCoOwnerAfterArchiveThrows() async throws {
        let repo = await makeSUT()
        try await repo.deleteList(id: childListId)

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.removeCoOwner(listId: childListId)
        }
    }

    @Test("removeCoOwner on the seeded archived scenario throws archivedReadOnly")
    func removeCoOwnerSeededArchivedThrows() async {
        let repo = await makeSUT()

        await #expect(throws: ListError.archivedReadOnly) {
            _ = try await repo.removeCoOwner(listId: seededArchivedListId)
        }
    }

    @Test("an active list can still be updated (the archived rule is status based)")
    func activeListStillUpdates() async throws {
        let repo = await makeSUT()

        let updated = try await repo.updateList(id: childListId, rename())

        #expect(updated.name == "Renamed")
        #expect(updated.status == .active)
    }
}
