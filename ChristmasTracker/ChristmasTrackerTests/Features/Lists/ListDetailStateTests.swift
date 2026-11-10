//
//  ListDetailStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: ListDetailState for every privacy scenario. Fake data only. Actions come
//  from the flags, never from myRole.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List detail state Tests")
struct ListDetailStateTests {

    // MARK: - Helpers

    private func makeSUT(_ detail: ListDetail) -> ListDetailState {
        ListDetailState(detail: detail)
    }

    private func mapped(_ spec: ListFixtures.Spec) throws -> ListDetail {
        mapListDetail(try ListFixtures.detail(spec))
    }

    private func member(id: String = "mem-1") -> ListMember {
        ListMember(
            id: id, userId: "user-2", displayName: "Casey Member", email: nil,
            role: .member, status: .active,
            invitedAt: Date(timeIntervalSince1970: 1_767_600_000), acceptedAt: nil, expiresAt: nil
        )
    }

    private func assertHidesGiftActivity(_ state: ListDetailState, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!state.showsStatsCard, sourceLocation: sourceLocation)
        #expect(state.itemCountText == nil, sourceLocation: sourceLocation)
        #expect(state.purchasedCountText == nil, sourceLocation: sourceLocation)
        #expect(!state.showsProgress, sourceLocation: sourceLocation)
        #expect(state.progress == nil, sourceLocation: sourceLocation)
    }

    // MARK: - Scenarios

    @Test("Blind owner of a self list: no stats, edit and delete shown, members shown, add item shown")
    func blindOwner() throws {
        let state = makeSUT(try mapped(ListFixtures.blindOwnerOfSelfList()))
        assertHidesGiftActivity(state)
        #expect(state.showsEditAction)
        #expect(state.showsDeleteAction)
        #expect(state.showsMembersSection)
        #expect(state.showsAddItemAction)
        #expect(state.memberCountText.contains("2"))
    }

    @Test("Recipient of a self list: no stats")
    func recipientOfSelfList() throws {
        assertHidesGiftActivity(makeSUT(try mapped(ListFixtures.recipientOfSelfList())))
    }

    @Test("Owner of a child list: stats and progress shown, edit and delete shown")
    func ownerOfChildList() throws {
        let state = makeSUT(try mapped(ListFixtures.ownerOfChildList()))
        #expect(state.showsStatsCard)
        #expect(state.itemCountText?.contains("8") == true)
        #expect(state.purchasedCountText?.contains("3") == true)
        #expect(state.showsProgress)
        let progress = try #require(state.progress)
        #expect(abs(progress - 3.0 / 8.0) < 0.0001)
        #expect(state.showsEditAction)
        #expect(state.showsDeleteAction)
        #expect(state.showsMembersSection)
    }

    @Test("MEMBER-role member: stats shown, no edit or delete, members section shown")
    func memberRoleMember() throws {
        let state = makeSUT(try mapped(ListFixtures.memberRoleMember()))
        #expect(state.showsStatsCard)
        #expect(state.itemCountText?.contains("5") == true)
        #expect(state.purchasedCountText?.contains("2") == true)
        #expect(!state.showsEditAction)
        #expect(!state.showsDeleteAction)
        #expect(state.showsMembersSection)
        #expect(state.memberCountText.contains("4"))
    }

    @Test("VIEWER-role member: no stats, no actions, no members section, member count text kept, viewer badge")
    func viewerRoleMember() throws {
        let state = makeSUT(try mapped(ListFixtures.viewerRoleMember()))
        assertHidesGiftActivity(state)
        #expect(!state.showsEditAction)
        #expect(!state.showsDeleteAction)
        #expect(!state.showsMembersSection)
        #expect(!state.showsAddItemAction)
        #expect(state.memberCountText.contains("4"))
        #expect(state.badgeTitle.lowercased().contains("viewer"))
    }

    @Test("PUBLIC non-member looks the same as a viewer")
    func publicNonMember() throws {
        let state = makeSUT(try mapped(ListFixtures.publicNonMember()))
        assertHidesGiftActivity(state)
        #expect(!state.showsEditAction)
        #expect(!state.showsDeleteAction)
        #expect(!state.showsMembersSection)
        #expect(state.memberCountText.contains("1"))
        #expect(state.visibilityTitle == ListVisibility.public.title)
    }

    @Test("Blind co-owner: no stats, edit and delete both shown")
    func blindCoOwner() throws {
        let state = makeSUT(try mapped(ListFixtures.blindCoOwner()))
        assertHidesGiftActivity(state)
        #expect(state.showsEditAction)
        #expect(state.showsDeleteAction)
    }

    @Test("Archived list: edit and delete hidden because the flags are false")
    func archivedLists() throws {
        let owner = makeSUT(try mapped(ListFixtures.archivedAsOwner()))
        #expect(!owner.showsEditAction)
        #expect(!owner.showsDeleteAction)
        let member = makeSUT(try mapped(ListFixtures.archivedAsMember()))
        #expect(!member.showsEditAction)
        #expect(!member.showsDeleteAction)
    }

    // MARK: - canCreateItem

    @Test("showsAddItemAction follows canCreateItem only")
    func addItemFollowsFlag() {
        var on = ListFixtures.Flags()
        on.canCreateItem = true
        #expect(makeSUT(ListFixtures.listDetail(myRole: .viewer, flags: on)).showsAddItemAction)
        #expect(!makeSUT(ListFixtures.listDetail(myRole: .owner, flags: ListFixtures.Flags())).showsAddItemAction)
        #expect(!makeSUT(ListFixtures.listDetail(myRole: .owner, flags: ListFixtures.uniformFlags(true).with { $0.canCreateItem = false })).showsAddItemAction)
    }

    // MARK: - Flags decide, the role does not

    @Test("A viewer-role list with edit and delete flags shows both")
    func viewerRoleWithEditFlags() {
        var flags = ListFixtures.Flags()
        flags.canEditList = true
        flags.canDeleteList = true
        let state = makeSUT(ListFixtures.listDetail(myRole: .viewer, flags: flags))
        #expect(state.showsEditAction)
        #expect(state.showsDeleteAction)
    }

    @Test("Edit and delete are independent flags")
    func editAndDeleteIndependent() {
        var editOnly = ListFixtures.Flags()
        editOnly.canEditList = true
        let a = makeSUT(ListFixtures.listDetail(flags: editOnly))
        #expect(a.showsEditAction)
        #expect(!a.showsDeleteAction)
        var deleteOnly = ListFixtures.Flags()
        deleteOnly.canDeleteList = true
        let b = makeSUT(ListFixtures.listDetail(flags: deleteOnly))
        #expect(!b.showsEditAction)
        #expect(b.showsDeleteAction)
    }

    @Test("An owner-role list with no flags shows no actions, no stats, no members")
    func ownerRoleWithoutFlags() {
        let state = makeSUT(ListFixtures.listDetail(
            myRole: .owner, flags: ListFixtures.Flags(), memberCount: 3,
            itemCount: 9, purchasedCount: 4, members: [member()]
        ))
        #expect(!state.showsEditAction)
        #expect(!state.showsDeleteAction)
        #expect(!state.showsAddItemAction)
        #expect(!state.showsMembersSection)
        assertHidesGiftActivity(state)
    }

    // MARK: - Counts

    @Test("Counts present but canSeeGiftActivity false: the state hides them even when built directly")
    func countsHiddenWhenBuiltDirectly() {
        var flags = ListFixtures.Flags()
        flags.canEditList = true
        let state = makeSUT(ListFixtures.listDetail(flags: flags, itemCount: 37, purchasedCount: 19))
        assertHidesGiftActivity(state)
    }

    @Test("itemCount 0 with counts visible: stats shown, progress nil")
    func zeroItems() {
        var flags = ListFixtures.Flags()
        flags.canSeeGiftActivity = true
        let state = makeSUT(ListFixtures.listDetail(flags: flags, itemCount: 0, purchasedCount: 0))
        #expect(state.showsStatsCard)
        #expect(state.itemCountText != nil)
        #expect(state.purchasedCountText != nil)
        #expect(!state.showsProgress)
        #expect(state.progress == nil)
    }

    // MARK: - Members section

    @Test("Members section needs canSeeMembers and a non-nil members array")
    func membersSection() {
        var see = ListFixtures.Flags()
        see.canSeeMembers = true
        #expect(makeSUT(ListFixtures.listDetail(flags: see, members: [member()])).showsMembersSection)
        #expect(!makeSUT(ListFixtures.listDetail(flags: see, members: nil)).showsMembersSection)
        #expect(!makeSUT(ListFixtures.listDetail(flags: ListFixtures.Flags(), members: [member()])).showsMembersSection)
    }

    @Test("Members present but empty with canSeeMembers: section still shown (empty is not absent)")
    func membersEmptyArrayIsNotAbsent() {
        var see = ListFixtures.Flags()
        see.canSeeMembers = true
        #expect(makeSUT(ListFixtures.listDetail(flags: see, members: [])).showsMembersSection)
    }

    @Test("Member count text is always present and reflects the count")
    func memberCountTextAlways() {
        let state = makeSUT(ListFixtures.listDetail(flags: ListFixtures.Flags(), memberCount: 7))
        #expect(state.memberCountText.contains("7"))
    }

    // MARK: - Titles

    @Test("Title, year, theme and visibility title come from the list")
    func basicFields() {
        let state = makeSUT(ListFixtures.listDetail(name: "Fake Winter List"))
        #expect(state.title == "Fake Winter List")
        #expect(state.year == 2026)
        #expect(state.theme == nil)
        #expect(state.visibilityTitle == ListVisibility.private.title)
    }

    @Test("Badge title comes from the role badge")
    func badgeTitleMatchesBadge() {
        let detail = ListFixtures.listDetail(myRole: .coOwner)
        #expect(makeSUT(detail).badgeTitle == ListRoleBadge(detail: detail).title)
    }
}

private extension ListFixtures.Flags {
    func with(_ change: (inout ListFixtures.Flags) -> Void) -> ListFixtures.Flags {
        var copy = self
        change(&copy)
        return copy
    }
}
