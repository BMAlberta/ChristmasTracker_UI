//
//  MockListRepositoryScenarioTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: small sanity test that MockListRepository serves the privacy scenarios with
//  the flags the server would send, so previews and tests built on it are trustworthy.
//  Delay is set to 0 so nothing waits on the mock's built-in sleep.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockListRepository scenarios")
struct MockListRepositoryScenarioTests {

    private func makeSUT(allScenarios: Bool = true) async -> MockListRepository {
        let repo = MockListRepository(withMockData: true, includeAllScenarios: allScenarios)
        await repo.setDelay(0)
        return repo
    }

    private func byId(_ lists: [GiftList]) -> [String: GiftList] {
        Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0) })
    }

    @Test("the default seed has three non-archived lists")
    func defaultSeed() async throws {
        let repo = await makeSUT(allScenarios: false)

        let lists = try await repo.fetchLists()

        #expect(lists.count == 3)
        #expect(lists.allSatisfy { $0.status != .archived })
    }

    @Test("every scenario carries the flags the server would send")
    func scenarioFlags() async throws {
        let repo = await makeSUT()
        let lists = byId(try await repo.fetchLists())
        #expect(lists.count == 7)

        let blindOwner = try #require(lists["mock-list-self"])
        #expect(blindOwner.capabilities.isRecipient)
        #expect(!blindOwner.capabilities.canSeeGiftActivity)
        #expect(blindOwner.capabilities.canEditList && blindOwner.capabilities.canDeleteList)
        #expect(blindOwner.itemCount == nil && blindOwner.purchasedCount == nil)

        let ownerOfChild = try #require(lists["mock-list-child"])
        #expect(ownerOfChild.capabilities.canSeeGiftActivity)
        #expect(ownerOfChild.capabilities.canSetCoOwner)
        #expect(ownerOfChild.itemCount != nil && ownerOfChild.purchasedCount != nil)

        let member = try #require(lists["mock-list-member"])
        #expect(member.capabilities.canLeaveList)
        #expect(!member.capabilities.canEditList && !member.capabilities.canDeleteList && !member.capabilities.canManageMembers)
        #expect(member.itemCount != nil)

        let viewer = try #require(lists["mock-list-viewer"])
        #expect(!viewer.capabilities.canSeeMembers)
        #expect(!viewer.capabilities.canSeeGiftActivity)
        #expect(viewer.capabilities.canLeaveList)
        #expect(viewer.itemCount == nil)

        let publicNonMember = try #require(lists["mock-list-public"])
        #expect(!publicNonMember.capabilities.canLeaveList)
        #expect(!publicNonMember.capabilities.canSeeMembers)
        #expect(publicNonMember.visibility == .public)
        #expect(publicNonMember.itemCount == nil)

        let blindCoOwner = try #require(lists["mock-list-coowner"])
        #expect(blindCoOwner.capabilities.canEditList)
        #expect(!blindCoOwner.capabilities.canSetCoOwner)
        #expect(!blindCoOwner.capabilities.canSeeGiftActivity)
        #expect(blindCoOwner.itemCount == nil)

        let archived = try #require(lists["mock-list-archived"])
        #expect(archived.status == .archived)
        #expect(!archived.capabilities.canEditList)
        #expect(!archived.capabilities.canDeleteList)
        #expect(!archived.capabilities.canManageMembers)
        #expect(!archived.capabilities.canSetCoOwner)
    }

    @Test("across all scenarios: counts only with gift activity, members only with canSeeMembers")
    func invariants() async throws {
        let repo = await makeSUT()
        let lists = try await repo.fetchLists()

        for list in lists {
            if !list.capabilities.canSeeGiftActivity {
                #expect(list.itemCount == nil && list.purchasedCount == nil, "blind or viewer scenarios carry no counts")
            }
            let detail = try await repo.fetchListDetail(id: list.id)
            if !detail.capabilities.canSeeMembers {
                #expect(detail.members == nil, "members must be absent, not empty, without canSeeMembers")
            }
        }
    }

    @Test("a failing mock throws the typed .server error for every operation")
    func failingMockThrowsServer() async throws {
        let repo = await makeSUT()
        await repo.setShouldFail(true)
        let input = CreateListInput(recipientId: "user-1", year: 2026, name: "N", theme: nil, visibility: .private)

        await #expect(throws: ListError.server) { _ = try await repo.fetchLists() }
        await #expect(throws: ListError.server) { _ = try await repo.fetchListDetail(id: "mock-list-self") }
        await #expect(throws: ListError.server) { _ = try await repo.createList(input) }
        await #expect(throws: ListError.server) {
            _ = try await repo.updateList(id: "mock-list-self", UpdateListInput(name: "X", theme: nil, visibility: nil))
        }
        await #expect(throws: ListError.server) { try await repo.deleteList(id: "mock-list-self") }
    }

    @Test("a missing id throws notFound")
    func missingIdThrowsNotFound() async throws {
        let repo = await makeSUT()

        await #expect(throws: ListError.notFound) { _ = try await repo.fetchListDetail(id: "no-such-list") }
        await #expect(throws: ListError.notFound) { try await repo.deleteList(id: "no-such-list") }
    }

    @Test("creating a list for yourself returns a blind owner detail")
    func createForSelfIsBlind() async throws {
        let repo = await makeSUT()
        let input = CreateListInput(
            recipientId: MockListData.currentUser.id, year: 2026, name: "Mine", theme: nil, visibility: .private
        )

        let detail = try await repo.createList(input)

        #expect(detail.capabilities.isRecipient)
        #expect(!detail.capabilities.canSeeGiftActivity)
        #expect(detail.capabilities.canEditList)
        #expect(detail.itemCount == nil && detail.purchasedCount == nil)
    }
}
