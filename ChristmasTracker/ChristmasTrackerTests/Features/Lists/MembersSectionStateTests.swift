//
//  MembersSectionStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: MembersSectionState rows, flags and texts. Every answer comes from the
//  capability flags and the person ids of the detail; the viewer's own role never matters.
//  The full flag truth table lives in MembersTruthTableTests.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("MembersSectionState Tests")
struct MembersSectionStateTests {

    // MARK: - Factory

    private static let managerFlags = MembersFixtures.SectionFlags(
        canSeeMembers: true, canManageMembers: true, canLeaveList: false, canSetCoOwner: true
    )

    private func makeSUT(
        flags: MembersFixtures.SectionFlags = MembersSectionStateTests.managerFlags,
        roster: [ListFixtures.MemberSpec]? = MembersFixtures.fullRoster(),
        hasCoOwner: Bool = true,
        memberCount: Int = 4,
        myRole: String = "owner"
    ) throws -> MembersSectionState {
        MembersSectionState(
            detail: try MembersFixtures.detail(
                flags: flags, roster: roster, hasCoOwner: hasCoOwner, memberCount: memberCount, myRole: myRole
            )
        )
    }

    // MARK: - Rows

    @Test("Rows show ACTIVE members only, in server order")
    func activeRowsOnly() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.id) == ["mem-owner", "mem-co", "mem-m1", "mem-v1"])
    }

    @Test("INVITED, REMOVED and EXPIRED rows never appear")
    func inactiveRowsFiltered() throws {
        let state = try makeSUT()
        for hidden in ["mem-inv", "mem-rem", "mem-exp"] {
            #expect(!state.rows.map(\.id).contains(hidden))
        }
        #expect(!state.rows.map(\.displayName).contains("Ivy Invited"))
    }

    @Test("Row kind comes from the owner and co-owner person ids, else the row membership role")
    func rowKinds() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.kind) == [.owner, .coOwner, .member, .viewer])
        #expect(state.rows.map(\.userId) == [
            MembersFixtures.ownerId, MembersFixtures.coOwnerId, MembersFixtures.memberUserId, MembersFixtures.viewerUserId
        ])
    }

    @Test("The owner row is the owner even when its wire role is viewer, and the co-owner row even when member")
    func kindIgnoresWireRoleForOwnerAndCoOwner() throws {
        // MembersFixtures gives the owner row role "viewer" and the co-owner row role "member".
        let state = try makeSUT()
        #expect(state.rows[0].kind == .owner)
        #expect(state.rows[1].kind == .coOwner)
    }

    @Test("Without a co-owner on the list the co-owner id matches nothing")
    func noCoOwnerOnList() throws {
        let state = try makeSUT(roster: MembersFixtures.fullRoster(includeCoOwner: false), hasCoOwner: false)
        #expect(state.rows.map(\.kind) == [.owner, .member, .viewer])
    }

    @Test("Role labels are Owner, Co-owner, Member and Viewer")
    func roleLabels() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.roleLabel) == ["Owner", "Co-owner", "Member", "Viewer"])
    }

    @Test("Row display names come from the roster")
    func displayNames() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.displayName) == [
            MembersFixtures.ownerName, MembersFixtures.coOwnerName, MembersFixtures.memberName, MembersFixtures.viewerName
        ])
    }

    @Test("Row ids are the membership ids, not the user ids")
    func rowIdIsMembershipId() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.id) != state.rows.map(\.userId))
    }

    // MARK: - Remove per row

    @Test("A manager can remove member and viewer rows but never the owner or co-owner rows")
    func canRemoveForManager() throws {
        let state = try makeSUT()
        #expect(state.rows.map(\.canRemove) == [false, false, true, true])
    }

    @Test("Nobody can remove anyone without canManageMembers")
    func cannotRemoveWithoutFlag() throws {
        let flags = MembersFixtures.SectionFlags(
            canSeeMembers: true, canManageMembers: false, canLeaveList: true, canSetCoOwner: false
        )
        let state = try makeSUT(flags: flags)
        #expect(state.showsRoster)
        #expect(state.rows.count == 4)
        #expect(state.rows.allSatisfy { !$0.canRemove })
    }

    // MARK: - Roster visibility

    @Test("The roster shows when canSeeMembers is true and members are present")
    func rosterShows() throws {
        let state = try makeSUT()
        #expect(state.showsRoster)
        #expect(!state.rows.isEmpty)
    }

    @Test("No rows when canSeeMembers is true but members are absent")
    func noRowsWhenMembersAbsent() throws {
        let state = try makeSUT(roster: nil)
        #expect(!state.showsRoster)
        #expect(state.rows.isEmpty)
    }

    @Test("A present but empty roster still shows the (empty) roster")
    func emptyRoster() throws {
        let state = try makeSUT(roster: [])
        #expect(state.showsRoster)
        #expect(state.rows.isEmpty)
    }

    @Test("A viewer-role member gets no rows even when a members array is in the model")
    func viewerGetsNoRowsEvenIfModelHasMembers() throws {
        let flags = MembersFixtures.SectionFlags(
            canSeeMembers: false, canManageMembers: false, canLeaveList: true, canSetCoOwner: false
        )
        let state = try makeSUT(flags: flags, roster: MembersFixtures.fullRoster(), myRole: "viewer")
        #expect(!state.showsRoster)
        #expect(state.rows.isEmpty)
        #expect(!state.showsAdd)
        #expect(state.showsLeave)
    }

    @Test("A PUBLIC non-member gets no rows even when a members array is in the model")
    func publicNonMemberGetsNoRows() throws {
        let flags = MembersFixtures.SectionFlags()
        let detail = try MembersFixtures.detail(
            flags: flags, roster: MembersFixtures.fullRoster(), memberCount: 1, visibility: "PUBLIC", myRole: "viewer"
        )
        let state = MembersSectionState(detail: detail)
        #expect(!state.showsRoster)
        #expect(state.rows.isEmpty)
        #expect(!state.showsAdd)
        #expect(!state.showsLeave)
        #expect(state.memberCountText == "1 member")
    }

    // MARK: - Add and leave

    @Test("showsAdd follows canManageMembers only")
    func addFollowsFlag() throws {
        let on = MembersFixtures.SectionFlags(canManageMembers: true)
        let off = MembersFixtures.SectionFlags(canSeeMembers: true, canLeaveList: true, canSetCoOwner: true)
        #expect(try makeSUT(flags: on, roster: nil).showsAdd)
        #expect(try !makeSUT(flags: off).showsAdd)
    }

    @Test("showsLeave follows canLeaveList only")
    func leaveFollowsFlag() throws {
        let on = MembersFixtures.SectionFlags(canLeaveList: true)
        let off = MembersFixtures.SectionFlags(canSeeMembers: true, canManageMembers: true, canSetCoOwner: true)
        #expect(try makeSUT(flags: on, roster: nil).showsLeave)
        #expect(try !makeSUT(flags: off).showsLeave)
    }

    // MARK: - Member count

    @Test("The member count text is singular for one and plural otherwise",
          arguments: [(0, "0 members"), (1, "1 member"), (2, "2 members"), (12, "12 members")])
    func memberCountText(count: Int, expected: String) throws {
        let state = try makeSUT(roster: nil, memberCount: count)
        #expect(state.memberCountText == expected)
    }

    @Test("The member count is shown even with no roster at all")
    func memberCountWithoutRoster() throws {
        let state = try makeSUT(flags: MembersFixtures.SectionFlags(), roster: nil, memberCount: 4)
        #expect(state.memberCountText == "4 members")
    }

    @Test("The member count comes from the detail, not from the number of rows")
    func memberCountIsNotRowCount() throws {
        let state = try makeSUT(memberCount: 9)
        #expect(state.rows.count == 4)
        #expect(state.memberCountText == "9 members")
    }

    // MARK: - The viewer's own role never matters

    @Test("Changing only myRole changes nothing", arguments: ["owner", "co-owner", "member", "viewer"])
    func myRoleNeverMatters(myRole: String) throws {
        let baseline = try makeSUT(myRole: "owner")
        let other = try makeSUT(myRole: myRole)
        #expect(other.rows == baseline.rows)
        #expect(other.showsRoster == baseline.showsRoster)
        #expect(other.showsAdd == baseline.showsAdd)
        #expect(other.showsLeave == baseline.showsLeave)
        #expect(other.memberCountText == baseline.memberCountText)
    }

    // MARK: - Accessibility

    @Test("The accessibility label has the display name and role label")
    func accessibilityLabelContents() throws {
        let state = try makeSUT()
        for row in state.rows {
            #expect(row.accessibilityLabel.contains(row.displayName))
            #expect(row.accessibilityLabel.contains(row.roleLabel))
        }
    }

    @Test("The accessibility label never contains an email address")
    func accessibilityLabelHasNoEmail() throws {
        let state = try makeSUT()
        let emails = [MembersFixtures.ownerEmail, MembersFixtures.coOwnerEmail, MembersFixtures.memberEmail]
        for row in state.rows {
            for email in emails {
                #expect(!row.accessibilityLabel.contains(email))
            }
            #expect(!row.accessibilityLabel.contains("@"))
        }
    }

    @Test("A member whose email is set still has no email in any row text")
    func rowTextsHaveNoEmail() throws {
        let state = try makeSUT()
        let member = try #require(state.rows.first { $0.id == "mem-m1" })
        #expect(!member.displayName.contains("@"))
        #expect(!member.roleLabel.contains("@"))
        #expect(!member.accessibilityLabel.contains(MembersFixtures.memberEmail))
    }
}
