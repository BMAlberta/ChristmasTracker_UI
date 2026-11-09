//
//  ListRoleBadgeTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: ListRoleBadge is the only place a role is read, and only for display.
//  Titles are "Owner", "Co-Owner", "Member", "Viewer" (the strings the app already shows).
//  A VIEWER-role member and a PUBLIC non-member both arrive as myRole viewer and both
//  show "Viewer".
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ListRoleBadge Tests")
struct ListRoleBadgeTests {

    @Test("Badge title for a list, per role",
          arguments: [
            (ListRole.owner, "Owner"),
            (ListRole.coOwner, "Co-Owner"),
            (ListRole.member, "Member"),
            (ListRole.viewer, "Viewer")
          ])
    func titleFromList(role: ListRole, expected: String) {
        let list = ListFixtures.giftList(myRole: role)
        #expect(ListRoleBadge(list: list).title == expected)
    }

    @Test("Badge title for a detail, per role",
          arguments: [
            (ListRole.owner, "Owner"),
            (ListRole.coOwner, "Co-Owner"),
            (ListRole.member, "Member"),
            (ListRole.viewer, "Viewer")
          ])
    func titleFromDetail(role: ListRole, expected: String) {
        let detail = ListFixtures.listDetail(myRole: role)
        #expect(ListRoleBadge(detail: detail).title == expected)
    }

    @Test("A VIEWER-role member shows Viewer (list and detail)")
    func viewerRoleMemberShowsViewer() throws {
        let spec = ListFixtures.viewerRoleMember()
        let list = mapListSummary(try ListFixtures.summary(spec))
        let detail = mapListDetail(try ListFixtures.detail(spec))
        #expect(ListRoleBadge(list: list).title == "Viewer")
        #expect(ListRoleBadge(detail: detail).title == "Viewer")
    }

    @Test("A PUBLIC non-member shows Viewer (list and detail)")
    func publicNonMemberShowsViewer() throws {
        let spec = ListFixtures.publicNonMember()
        let list = mapListSummary(try ListFixtures.summary(spec))
        let detail = mapListDetail(try ListFixtures.detail(spec))
        #expect(ListRoleBadge(list: list).title == "Viewer")
        #expect(ListRoleBadge(detail: detail).title == "Viewer")
    }

    @Test("A co-owner mapped from the wire shows Co-Owner")
    func coOwnerFromWire() throws {
        let list = mapListSummary(try ListFixtures.summary(ListFixtures.blindCoOwner()))
        #expect(ListRoleBadge(list: list).title == "Co-Owner")
    }

    @Test("The badge title is independent of the flags")
    func badgeIgnoresFlags() {
        let allTrue = ListFixtures.giftList(myRole: .viewer, flags: ListFixtures.uniformFlags(true))
        let allFalse = ListFixtures.giftList(myRole: .owner, flags: ListFixtures.uniformFlags(false))
        #expect(ListRoleBadge(list: allTrue).title == "Viewer")
        #expect(ListRoleBadge(list: allFalse).title == "Owner")
    }
}
