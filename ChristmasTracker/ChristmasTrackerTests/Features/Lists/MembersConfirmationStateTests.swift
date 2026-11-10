//
//  MembersConfirmationStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: the confirmation dialogs the Members section shows come from
//  `MembersSectionState.removeConfirmation(for:)` and `MembersSectionState.leaveConfirmation`,
//  built from MemberRemoveConfirmation and LeaveListConfirmation (the texts are tested in
//  MemberConfirmationTests).
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Members confirmation state Tests")
struct MembersConfirmationStateTests {

    private func makeRows() throws -> [MemberRowState] {
        let flags = MembersFixtures.SectionFlags(
            canSeeMembers: true, canManageMembers: true, canLeaveList: false, canSetCoOwner: true
        )
        return MembersSectionState(detail: try MembersFixtures.detail(flags: flags)).rows
    }

    @Test("The remove confirmation is built from the row's display name")
    func removeConfirmationMatches() throws {
        let rows = try makeRows()
        #expect(!rows.isEmpty)
        for row in rows {
            let confirmation = MembersSectionState.removeConfirmation(for: row)
            #expect(confirmation.title == MemberRemoveConfirmation.title(displayName: row.displayName))
            #expect(confirmation.message == MemberRemoveConfirmation.message(displayName: row.displayName))
            #expect(confirmation.confirmButtonTitle == MemberRemoveConfirmation.confirmButtonTitle)
        }
    }

    @Test("The remove confirmation names the row and never shows an email")
    func removeConfirmationNamesRow() throws {
        let rows = try makeRows()
        let member = try #require(rows.first { $0.displayName == MembersFixtures.memberName })
        let viewer = try #require(rows.first { $0.displayName == MembersFixtures.viewerName })
        let first = MembersSectionState.removeConfirmation(for: member)
        let second = MembersSectionState.removeConfirmation(for: viewer)
        #expect(first.message.contains(MembersFixtures.memberName))
        #expect(second.message.contains(MembersFixtures.viewerName))
        #expect(first.message != second.message)
        #expect(!first.title.contains("@"))
        #expect(!first.message.contains("@"))
    }

    @Test("The leave confirmation equals the LeaveListConfirmation texts")
    func leaveConfirmationMatches() {
        let confirmation = MembersSectionState.leaveConfirmation
        #expect(confirmation.title == LeaveListConfirmation.title)
        #expect(confirmation.message == LeaveListConfirmation.message)
        #expect(confirmation.confirmButtonTitle == LeaveListConfirmation.confirmButtonTitle)
    }

    @Test("Neither confirmation has an empty text")
    func nothingEmpty() throws {
        let leave = MembersSectionState.leaveConfirmation
        #expect(!leave.title.isEmpty && !leave.message.isEmpty && !leave.confirmButtonTitle.isEmpty)
        let row = try #require(try makeRows().first)
        let remove = MembersSectionState.removeConfirmation(for: row)
        #expect(!remove.title.isEmpty && !remove.message.isEmpty && !remove.confirmButtonTitle.isEmpty)
    }
}
