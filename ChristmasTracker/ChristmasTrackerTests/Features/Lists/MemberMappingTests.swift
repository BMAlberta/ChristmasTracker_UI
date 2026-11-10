//
//  MemberMappingTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: mapMemberSummary and mapChild (pure), plus a check that mapListDetail still
//  maps the roster. Wire values are decoded from literal JSON by the generated types.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("Member mapping Tests")
struct MemberMappingTests {

    // MARK: - Factory

    private func makeMember(_ spec: ListFixtures.MemberSpec) throws -> ListMember {
        mapMemberSummary(try MembersFixtures.memberSummary(spec))
    }

    private func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = formatter.date(from: text) { return value }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    // MARK: - mapMemberSummary

    @Test("Scalar fields map across")
    func scalarFields() throws {
        let spec = ListFixtures.MemberSpec(
            id: "mem-77", userId: "user-77", displayName: "Pat Person", email: "pat@example.com",
            role: "member", status: "ACTIVE", invitedAt: "2026-02-01T10:00:00.000Z",
            acceptedAt: "2026-02-02T10:00:00.000Z", expiresAt: nil
        )
        let member = try makeMember(spec)
        #expect(member.id == "mem-77")
        #expect(member.userId == "user-77")
        #expect(member.displayName == "Pat Person")
        #expect(member.email == "pat@example.com")
        #expect(member.invitedAt == date("2026-02-01T10:00:00.000Z"))
        #expect(member.acceptedAt == date("2026-02-02T10:00:00.000Z"))
        #expect(member.expiresAt == nil)
    }

    @Test("Every membership role maps",
          arguments: [("member", ListMemberRole.member), ("viewer", ListMemberRole.viewer)])
    func roleMaps(raw: String, expected: ListMemberRole) throws {
        let member = try makeMember(ListFixtures.MemberSpec(role: raw))
        #expect(member.role == expected)
    }

    @Test("Every member status maps",
          arguments: [
            ("INVITED", ListMemberStatus.invited),
            ("ACTIVE", ListMemberStatus.active),
            ("REMOVED", ListMemberStatus.removed),
            ("EXPIRED", ListMemberStatus.expired)
          ])
    func statusMaps(raw: String, expected: ListMemberStatus) throws {
        let member = try makeMember(ListFixtures.MemberSpec(status: raw))
        #expect(member.status == expected)
    }

    @Test("Role and status are mapped independently", arguments: ["member", "viewer"], ["INVITED", "ACTIVE", "REMOVED", "EXPIRED"])
    func roleAndStatusCombinations(role: String, status: String) throws {
        let member = try makeMember(ListFixtures.MemberSpec(role: role, status: status))
        #expect(member.role.rawValue == role)
        #expect(member.status.rawValue == status)
    }

    @Test("A missing email maps to nil and a present email is kept")
    func emailOptional() throws {
        #expect(try makeMember(ListFixtures.MemberSpec(email: nil)).email == nil)
        #expect(try makeMember(ListFixtures.MemberSpec(email: "kept@example.com")).email == "kept@example.com")
    }

    @Test("acceptedAt and expiresAt are each present or absent on their own")
    func optionalDates() throws {
        let neither = try makeMember(ListFixtures.MemberSpec(acceptedAt: nil, expiresAt: nil))
        #expect(neither.acceptedAt == nil)
        #expect(neither.expiresAt == nil)

        let accepted = try makeMember(ListFixtures.MemberSpec(acceptedAt: "2026-02-02T10:00:00.000Z", expiresAt: nil))
        #expect(accepted.acceptedAt != nil)
        #expect(accepted.expiresAt == nil)

        let expiring = try makeMember(ListFixtures.MemberSpec(acceptedAt: nil, expiresAt: "2026-03-03T10:00:00.000Z"))
        #expect(expiring.acceptedAt == nil)
        #expect(expiring.expiresAt != nil)

        let both = try makeMember(
            ListFixtures.MemberSpec(acceptedAt: "2026-02-02T10:00:00.000Z", expiresAt: "2026-03-03T10:00:00.000Z")
        )
        #expect(both.acceptedAt != nil)
        #expect(both.expiresAt != nil)
    }

    // MARK: - mapListDetail still maps the roster

    @Test("mapListDetail maps every roster row in order when members are present")
    func detailMapsRoster() throws {
        let flags = MembersFixtures.SectionFlags(canSeeMembers: true, canManageMembers: true)
        let detail = try MembersFixtures.detail(flags: flags)
        let members = try #require(detail.members)
        #expect(members.map(\.id) == MembersFixtures.fullRoster().map(\.id))
        #expect(members.map(\.status) == [.active, .active, .active, .active, .invited, .removed, .expired])
    }

    @Test("mapListDetail leaves members nil when the roster is absent")
    func detailMembersAbsent() throws {
        let detail = try MembersFixtures.detail(flags: MembersFixtures.SectionFlags(), roster: nil)
        #expect(detail.members == nil)
    }

    // MARK: - mapChild

    @Test("mapChild maps every documented relationship",
          arguments: [
            ("PARENT", ChildRelationship.parent),
            ("GUARDIAN", ChildRelationship.guardian),
            ("CARETAKER", ChildRelationship.caretaker)
          ])
    func childRelationshipMaps(raw: String, expected: ChildRelationship) {
        let child = mapChild(id: "child-1", firstName: "Charlie", lastName: "Child", displayName: nil, relationshipRaw: raw)
        #expect(child?.relationship == expected)
    }

    @Test("mapChild carries id, names and display name")
    func childFieldsMap() {
        let child = mapChild(
            id: "child-5", firstName: "Dana", lastName: "Dependent", displayName: "Dani", relationshipRaw: "GUARDIAN"
        )
        #expect(child?.id == "child-5")
        #expect(child?.firstName == "Dana")
        #expect(child?.lastName == "Dependent")
        #expect(child?.displayName == "Dani")
    }

    @Test("mapChild keeps an absent display name nil")
    func childNilDisplayName() {
        let child = mapChild(id: "child-5", firstName: "Dana", lastName: "Dependent", displayName: nil, relationshipRaw: "PARENT")
        #expect(child != nil)
        #expect(child?.displayName == nil)
    }

    @Test("mapChild returns nil for an unknown relationship so the repository can report invalidResponse",
          arguments: ["UNCLE", "", "GUARDIANS", "Parent "])
    func childUnknownRelationship(raw: String) {
        let child = mapChild(id: "child-1", firstName: "Charlie", lastName: "Child", displayName: nil, relationshipRaw: raw)
        #expect(child == nil)
    }
}
