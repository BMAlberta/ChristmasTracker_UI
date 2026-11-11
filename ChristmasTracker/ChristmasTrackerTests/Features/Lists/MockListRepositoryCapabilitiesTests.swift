//
//  MockListRepositoryCapabilitiesTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: `MockListRepository.capabilities(forListId:)` hands the item mock the same flags
//  the list mock shows for a list, so mock mode never disagrees with itself.
//
//      static func capabilities(forListId: String) -> ListCapabilities?
//
//  A list id the mock does not know returns nil.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("MockListRepository capabilities(forListId:)", .timeLimit(.minutes(1)))
@MainActor
struct MockListRepositoryCapabilitiesTests {

    @Test("every mock scenario list returns exactly its own flags", arguments: MockListData.allScenarios)
    func scenarioFlags(detail: ListDetail) {
        #expect(MockListRepository.capabilities(forListId: detail.id) == detail.capabilities)
    }

    @Test("an unknown list id returns nil", arguments: ["", "no-such-list", "list-test"])
    func unknownListId(id: String) {
        #expect(MockListRepository.capabilities(forListId: id) == nil)
    }

    @Test("the flags equal what the mock repository serves for the list")
    func agreesWithTheRepository() async throws {
        let repo = MockListRepository(withMockData: true, includeAllScenarios: true)
        await repo.setDelay(0)

        for list in try await repo.fetchLists() {
            #expect(MockListRepository.capabilities(forListId: list.id) == list.capabilities, "\(list.name)")
        }
    }

    @Test("the scenarios cover a blind owner, a member, a viewer and a public non-member with distinct item flags")
    func scenariosCoverThePrivacyPersonas() throws {
        let blind = try #require(MockListRepository.capabilities(forListId: MockListData.blindOwnerOfSelfList.id))
        let member = try #require(MockListRepository.capabilities(forListId: MockListData.memberList.id))
        let viewer = try #require(MockListRepository.capabilities(forListId: MockListData.viewerMemberList.id))
        let publicNonMember = try #require(MockListRepository.capabilities(forListId: MockListData.publicNonMemberList.id))

        #expect(blind.canCreateItem && !blind.canSeeGiftActivity && !blind.canAddOffList)
        #expect(member.canCreateItem && member.canAddOffList && member.canSeeOffList)
        #expect(!viewer.canCreateItem && !viewer.canSeeGiftActivity)
        #expect(!publicNonMember.canCreateItem && !publicNonMember.canSeeOffList)
    }
}
