//
//  MembersFixtures.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: shared, fake-data fixtures for the members, co-owner and child tests.
//
//  Wire side: literal JSON decoded with the generated Codable types (MemberSummary through
//  `memberSummary(_:)`, the list detail through ListFixtures). No hand parsing.
//  Domain side: details are built by running the generated ListDetail through `mapListDetail`,
//  so no test needs the memberwise initialiser of ListDetail or ListMember.
//
//  All ids, names and addresses are fake (example.com).
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum MembersFixtures {

    // MARK: - People

    static let ownerId = "user-owner"
    static let coOwnerId = "user-co"
    static let memberUserId = "user-m1"
    static let viewerUserId = "user-v1"

    static let ownerName = "Olivia Owner"
    static let coOwnerName = "Cody CoOwner"
    static let memberName = "Casey Member"
    static let viewerName = "Sam Viewer"

    static let ownerEmail = "olivia.owner@example.com"
    static let coOwnerEmail = "cody.coowner@example.com"
    static let memberEmail = "casey.member@example.com"

    // MARK: - Flags that matter to the members section

    /// The four flags the members and co-owner sections depend on.
    struct SectionFlags: Sendable, Equatable {
        var canSeeMembers = false
        var canManageMembers = false
        var canLeaveList = false
        var canSetCoOwner = false
    }

    /// Every one of the 16 combinations, bit 0 = canSeeMembers ... bit 3 = canSetCoOwner.
    static func sectionFlags(bits: Int) -> SectionFlags {
        func bit(_ index: Int) -> Bool { (bits >> index) & 1 == 1 }
        return SectionFlags(
            canSeeMembers: bit(0), canManageMembers: bit(1), canLeaveList: bit(2), canSetCoOwner: bit(3)
        )
    }

    // MARK: - Roster

    /// Roster rows. The OWNER row deliberately carries the wire role "viewer" and the CO-OWNER row
    /// the role "member", so a kind derived from the row role instead of the person ids fails.
    static func ownerRow() -> ListFixtures.MemberSpec {
        ListFixtures.MemberSpec(
            id: "mem-owner", userId: ownerId, displayName: ownerName, email: ownerEmail, role: "viewer"
        )
    }

    static func coOwnerRow() -> ListFixtures.MemberSpec {
        ListFixtures.MemberSpec(
            id: "mem-co", userId: coOwnerId, displayName: coOwnerName, email: coOwnerEmail, role: "member"
        )
    }

    static func memberRow() -> ListFixtures.MemberSpec {
        ListFixtures.MemberSpec(
            id: "mem-m1", userId: memberUserId, displayName: memberName, email: memberEmail, role: "member"
        )
    }

    static func viewerRow() -> ListFixtures.MemberSpec {
        ListFixtures.MemberSpec(
            id: "mem-v1", userId: viewerUserId, displayName: viewerName, email: nil, role: "viewer"
        )
    }

    /// Rows that must never show: INVITED, REMOVED and EXPIRED.
    static func inactiveRows() -> [ListFixtures.MemberSpec] {
        [
            ListFixtures.MemberSpec(
                id: "mem-inv", userId: "user-i1", displayName: "Ivy Invited", email: nil, role: "member",
                status: "INVITED", acceptedAt: nil, expiresAt: "2026-03-03T10:00:00.000Z"
            ),
            ListFixtures.MemberSpec(
                id: "mem-rem", userId: "user-r1", displayName: "Rex Removed", email: nil, role: "member",
                status: "REMOVED", acceptedAt: nil
            ),
            ListFixtures.MemberSpec(
                id: "mem-exp", userId: "user-e1", displayName: "Eve Expired", email: nil, role: "viewer",
                status: "EXPIRED", acceptedAt: nil, expiresAt: "2026-01-03T10:00:00.000Z"
            )
        ]
    }

    /// The full roster in server order: owner, co-owner (optional), member, viewer, then the
    /// inactive rows interleaved at the end.
    static func fullRoster(includeCoOwner: Bool = true, includeInactive: Bool = true) -> [ListFixtures.MemberSpec] {
        var rows = [ownerRow()]
        if includeCoOwner { rows.append(coOwnerRow()) }
        rows.append(memberRow())
        rows.append(viewerRow())
        if includeInactive { rows += inactiveRows() }
        return rows
    }

    /// I3d-D1: the roster as the server now sends it. The owner and co-owner are never in it, only
    /// members and viewers (and the inactive rows, which never show).
    static func memberRoster(includeInactive: Bool = true) -> [ListFixtures.MemberSpec] {
        var rows = [memberRow(), viewerRow()]
        if includeInactive { rows += inactiveRows() }
        return rows
    }

    // MARK: - Detail

    /// A domain detail. `roster` nil means the `members` key is absent from the wire JSON.
    /// `myRole` is varied by tests to prove it never matters.
    static func detail(
        flags: SectionFlags,
        roster: [ListFixtures.MemberSpec]? = fullRoster(),
        hasCoOwner: Bool = true,
        memberCount: Int = 4,
        status: String = "ACTIVE",
        visibility: String = "PRIVATE",
        myRole: String = "owner"
    ) throws -> ListDetail {
        var spec = ListFixtures.Spec()
        spec.id = "list-members"
        spec.status = status
        spec.visibility = visibility
        spec.recipientId = ownerId
        spec.recipientName = ownerName
        spec.ownerId = ownerId
        spec.ownerName = ownerName
        spec.coOwner = hasCoOwner ? (id: coOwnerId, name: coOwnerName) : nil
        spec.myRole = myRole
        spec.memberCount = memberCount
        spec.flags.canSeeMembers = flags.canSeeMembers
        spec.flags.canManageMembers = flags.canManageMembers
        spec.flags.canLeaveList = flags.canLeaveList
        spec.flags.canSetCoOwner = flags.canSetCoOwner
        spec.members = roster
        return mapListDetail(try ListFixtures.detail(spec))
    }

    // MARK: - Wire member

    /// Decodes one generated `MemberSummary` from literal JSON.
    static func memberSummary(_ member: ListFixtures.MemberSpec) throws -> Components.Schemas.MemberSummary {
        var object: [String: Any] = [
            "id": member.id,
            "userId": member.userId,
            "displayName": member.displayName,
            "role": member.role,
            "status": member.status,
            "invitedAt": member.invitedAt
        ]
        if let email = member.email { object["email"] = email }
        if let acceptedAt = member.acceptedAt { object["acceptedAt"] = acceptedAt }
        if let expiresAt = member.expiresAt { object["expiresAt"] = expiresAt }
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try TrackerDateTranscoder().decode(text)
        }
        return try decoder.decode(Components.Schemas.MemberSummary.self, from: data)
    }
}

// MARK: - Children

nonisolated enum ChildFixtures {

    static func child(
        id: String = "child-1",
        firstName: String = "Charlie",
        lastName: String = "Child",
        displayName: String? = nil,
        relationship: ChildRelationship = .parent
    ) -> Child {
        Child(
            id: id,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            relationship: relationship
        )
    }

    /// Two children with distinct ids and names, in a fixed order.
    static func twoChildren() -> [Child] {
        [
            child(id: "child-1", firstName: "Charlie", lastName: "Child", displayName: "Charlie C", relationship: .parent),
            child(id: "child-2", firstName: "Dana", lastName: "Dependent", displayName: nil, relationship: .guardian)
        ]
    }
}
