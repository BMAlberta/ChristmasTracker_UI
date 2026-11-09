//
//  ListRowStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: ListRowState for every privacy scenario. The state is built from domain
//  models only; fake ids and names only. Visibility comes from the flags, never from myRole.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List row state Tests")
struct ListRowStateTests {

    // MARK: - Helpers

    private func makeSUT(_ list: GiftList) -> ListRowState {
        ListRowState(list: list)
    }

    private func mapped(_ spec: ListFixtures.Spec) throws -> GiftList {
        mapListSummary(try ListFixtures.summary(spec))
    }

    /// Every String reachable from the state's stored properties (including optionals).
    private func storedStrings(_ state: ListRowState) -> [String] {
        Mirror(reflecting: state).children.compactMap { child in
            if let text = child.value as? String { return text }
            if let text = child.value as? String? { return text }
            return nil
        }
    }

    private let hintWords = ["surprise", "hidden", "purchased", "secret", "gift activity"]

    private func assertNoHiddenHints(_ state: ListRowState, sourceLocation: SourceLocation = #_sourceLocation) {
        let texts = storedStrings(state) + [state.accessibilityLabel, state.accessibilityHint]
        for text in texts {
            let lower = text.lowercased()
            for word in hintWords {
                #expect(!lower.contains(word), "'\(text)' hints at hidden data via '\(word)'", sourceLocation: sourceLocation)
            }
        }
        #expect(state.itemCountText == nil, sourceLocation: sourceLocation)
        #expect(state.purchasedCountText == nil, sourceLocation: sourceLocation)
        #expect(!state.showsCounts, sourceLocation: sourceLocation)
        #expect(!state.showsProgress, sourceLocation: sourceLocation)
        #expect(state.progress == nil, sourceLocation: sourceLocation)
    }

    // MARK: - Blind owner of a self list

    @Test("Blind owner of a self list: no counts, no progress, no hints; delete shown")
    func blindOwnerHidesEverythingAboutItems() throws {
        let state = makeSUT(try mapped(ListFixtures.blindOwnerOfSelfList()))
        assertNoHiddenHints(state)
        #expect(state.showsDeleteAction)
        #expect(state.category == .owned)
        #expect(state.title == "Fake Family List")
        #expect(state.year == 2026)
    }

    @Test("Blind owner state carries no per-item text even when the list was built with counts")
    func blindOwnerWithCountsConstructedDirectly() {
        var flags = ListFixtures.Flags()
        flags.isRecipient = true
        flags.canDeleteList = true
        flags.canSeeGiftActivity = false
        let list = ListFixtures.giftList(myRole: .owner, flags: flags, itemCount: 37, purchasedCount: 19)
        let state = makeSUT(list)
        assertNoHiddenHints(state)
        let texts = storedStrings(state) + [state.accessibilityLabel, state.accessibilityHint]
        for text in texts {
            #expect(!text.contains("37"))
            #expect(!text.contains("19"))
        }
    }

    @Test("Recipient of a self list sees no counts or progress")
    func recipientOfSelfList() throws {
        let state = makeSUT(try mapped(ListFixtures.recipientOfSelfList()))
        assertNoHiddenHints(state)
    }

    // MARK: - Owner of a child list

    @Test("Owner of a child list: counts and progress shown")
    func ownerOfChildListShowsCounts() throws {
        let state = makeSUT(try mapped(ListFixtures.ownerOfChildList()))
        #expect(state.showsCounts)
        let items = try #require(state.itemCountText)
        let purchased = try #require(state.purchasedCountText)
        #expect(items.contains("8"))
        #expect(purchased.contains("3"))
        #expect(state.showsProgress)
        let progress = try #require(state.progress)
        #expect(abs(progress - 3.0 / 8.0) < 0.0001)
        #expect(state.showsDeleteAction)
        #expect(state.category == .owned)
    }

    @Test("Counts visible but itemCount 0: counts shown, progress nil")
    func zeroItemsHasNoProgress() {
        var flags = ListFixtures.Flags()
        flags.canSeeGiftActivity = true
        let state = makeSUT(ListFixtures.giftList(flags: flags, itemCount: 0, purchasedCount: 0))
        #expect(state.showsCounts)
        #expect(state.itemCountText != nil)
        #expect(state.purchasedCountText != nil)
        #expect(!state.showsProgress)
        #expect(state.progress == nil)
    }

    @Test("Counts visible but only one count present: nothing shown")
    func partialCountsAreHidden() {
        var flags = ListFixtures.Flags()
        flags.canSeeGiftActivity = true
        let state = makeSUT(ListFixtures.giftList(flags: flags, itemCount: 5, purchasedCount: nil))
        #expect(!state.showsCounts)
        #expect(state.itemCountText == nil)
        #expect(state.purchasedCountText == nil)
        #expect(state.progress == nil)
    }

    // MARK: - Members and viewers

    @Test("MEMBER-role member: counts shown, no delete")
    func memberRoleMember() throws {
        let state = makeSUT(try mapped(ListFixtures.memberRoleMember()))
        #expect(state.showsCounts)
        #expect(state.itemCountText?.contains("5") == true)
        #expect(state.purchasedCountText?.contains("2") == true)
        #expect(state.showsProgress)
        #expect(!state.showsDeleteAction)
        #expect(state.category == .shared)
        #expect(state.badgeTitle == ListRoleBadge(list: try mapped(ListFixtures.memberRoleMember())).title)
    }

    @Test("VIEWER-role member: no counts, no progress, viewer badge, no delete")
    func viewerRoleMember() throws {
        let state = makeSUT(try mapped(ListFixtures.viewerRoleMember()))
        assertNoHiddenHints(state)
        #expect(!state.showsDeleteAction)
        #expect(state.category == .shared)
        #expect(state.badgeTitle.lowercased().contains("viewer"))
    }

    @Test("PUBLIC non-member looks the same as a viewer")
    func publicNonMember() throws {
        let state = makeSUT(try mapped(ListFixtures.publicNonMember()))
        assertNoHiddenHints(state)
        #expect(!state.showsDeleteAction)
        #expect(state.category == .shared)
        #expect(state.badgeTitle.lowercased().contains("viewer"))
    }

    @Test("Blind co-owner: no counts, delete shown")
    func blindCoOwner() throws {
        let state = makeSUT(try mapped(ListFixtures.blindCoOwner()))
        assertNoHiddenHints(state)
        #expect(state.showsDeleteAction)
        #expect(state.category == .owned)
    }

    @Test("Archived list: delete hidden because the flag is false")
    func archivedListHasNoDelete() throws {
        let owner = makeSUT(try mapped(ListFixtures.archivedAsOwner()))
        #expect(!owner.showsDeleteAction)
        let member = makeSUT(try mapped(ListFixtures.archivedAsMember()))
        #expect(!member.showsDeleteAction)
    }

    // MARK: - Flags decide, the role does not

    @Test("A viewer-role list with delete flag shows delete")
    func viewerRoleWithDeleteFlag() {
        var flags = ListFixtures.Flags()
        flags.canDeleteList = true
        let state = makeSUT(ListFixtures.giftList(myRole: .viewer, flags: flags))
        #expect(state.showsDeleteAction)
        #expect(state.category == .owned)
    }

    @Test("An owner-role list with no flags shows no delete and no counts")
    func ownerRoleWithoutFlags() {
        let state = makeSUT(ListFixtures.giftList(myRole: .owner, flags: ListFixtures.Flags(), itemCount: 9, purchasedCount: 4))
        #expect(!state.showsDeleteAction)
        #expect(state.category == .shared)
        assertNoHiddenHints(state)
    }

    // MARK: - Accessibility

    @Test("Accessibility label names the list and contains no ids; hint is non-empty")
    func accessibilityHasNoIds() throws {
        let spec = ListFixtures.ownerOfChildList()
        let state = makeSUT(try mapped(spec))
        #expect(state.accessibilityLabel.contains("Fake Family List"))
        #expect(!state.accessibilityHint.isEmpty)
        for text in [state.accessibilityLabel, state.accessibilityHint] {
            #expect(!text.contains(spec.id))
            #expect(!text.contains(spec.recipientId))
            #expect(!text.contains(spec.ownerId))
        }
    }

    @Test("Accessibility label and hint of a blind list contain no counts and no ids")
    func accessibilityBlindHasNoCounts() {
        var flags = ListFixtures.Flags()
        flags.canDeleteList = true
        let list = ListFixtures.giftList(id: "list-blind-77", flags: flags, itemCount: 37, purchasedCount: 19)
        let state = makeSUT(list)
        for text in [state.accessibilityLabel, state.accessibilityHint] {
            #expect(!text.contains("37"))
            #expect(!text.contains("19"))
            #expect(!text.contains("list-blind-77"))
        }
    }
}
