//
//  ListMappingTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: the pure mapping from the generated list schemas to the domain models.
//
//  Fixtures are literal JSON decoded with the generated Codable types (see ListFixtures).
//  Fails today because mapListSummary, mapListDetail, mapListPerson, ListCapabilities,
//  ListMemberRole and ListMemberStatus do not exist yet.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("List mapping Tests")
struct ListMappingTests {

    // MARK: - Factory

    private func makeSummary(_ spec: ListFixtures.Spec) throws -> GiftList {
        mapListSummary(try ListFixtures.summary(spec))
    }

    private func makeDetail(_ spec: ListFixtures.Spec) throws -> ListDetail {
        mapListDetail(try ListFixtures.detail(spec))
    }

    // MARK: - Privacy scenarios (summary)

    @Test("Blind owner of a self list: counts absent, manage flags true")
    func blindOwnerOfSelfList() throws {
        let spec = ListFixtures.blindOwnerOfSelfList()
        let list = try makeSummary(spec)
        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
        #expect(list.progress == nil)
        #expect(list.myRole == .owner)
        #expect(list.capabilities.isRecipient == true)
        #expect(list.capabilities.canSeeGiftActivity == false)
        #expect(list.capabilities.canEditList == true)
        #expect(list.capabilities.canDeleteList == true)
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("Owner of a child list: counts present, gift activity visible")
    func ownerOfChildList() throws {
        let spec = ListFixtures.ownerOfChildList()
        let list = try makeSummary(spec)
        #expect(list.itemCount == 8)
        #expect(list.purchasedCount == 3)
        #expect(list.capabilities.canSeeGiftActivity == true)
        #expect(list.capabilities.isRecipient == false)
        #expect(list.recipient.id == "child-1")
        #expect(list.recipient.displayName == "Charlie Child")
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("MEMBER-role member: counts present, canSeeMembers true, may leave, cannot manage")
    func memberRoleMember() throws {
        let spec = ListFixtures.memberRoleMember()
        let list = try makeSummary(spec)
        #expect(list.myRole == .member)
        #expect(list.itemCount == 5)
        #expect(list.purchasedCount == 2)
        #expect(list.capabilities.canSeeMembers == true)
        #expect(list.capabilities.canLeaveList == true)
        #expect(list.capabilities.canEditList == false)
        #expect(list.capabilities.canDeleteList == false)
        #expect(list.capabilities.canManageMembers == false)
        #expect(list.capabilities.canSetCoOwner == false)
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("VIEWER-role member: no counts, canSeeMembers false, canLeaveList true")
    func viewerRoleMember() throws {
        let spec = ListFixtures.viewerRoleMember()
        let list = try makeSummary(spec)
        #expect(list.myRole == .viewer)
        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
        #expect(list.capabilities.canSeeMembers == false)
        #expect(list.capabilities.canLeaveList == true)
        #expect(list.capabilities.canSeeGiftActivity == false)
        #expect(list.memberCount == 4)
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("PUBLIC non-member: myRole viewer, no counts, canLeaveList false")
    func publicNonMember() throws {
        let spec = ListFixtures.publicNonMember()
        let list = try makeSummary(spec)
        #expect(list.myRole == .viewer)
        #expect(list.visibility == .public)
        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
        #expect(list.capabilities.canLeaveList == false)
        #expect(list.capabilities.canSeeMembers == false)
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("Blind co-owner: no counts, edit and delete true, set co-owner false")
    func blindCoOwner() throws {
        let spec = ListFixtures.blindCoOwner()
        let list = try makeSummary(spec)
        #expect(list.myRole == .coOwner)
        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
        #expect(list.capabilities.canEditList == true)
        #expect(list.capabilities.canDeleteList == true)
        #expect(list.capabilities.canManageMembers == true)
        #expect(list.capabilities.canSetCoOwner == false)
        #expect(list.coOwner?.id == "user-1")
        #expect(list.coOwner?.displayName == "Robin Recipient")
        #expect(list.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("Recipient of a self list: isRecipient true and blind")
    func recipientOfSelfList() throws {
        let spec = ListFixtures.recipientOfSelfList()
        let list = try makeSummary(spec)
        #expect(list.capabilities.isRecipient == true)
        #expect(list.capabilities.canSeeGiftActivity == false)
        #expect(list.capabilities.canPurchase == false)
        #expect(list.capabilities.canSeeOffList == false)
        #expect(list.itemCount == nil)
        #expect(list.purchasedCount == nil)
    }

    @Test("ARCHIVED list as a member: management flags false, canLeaveList true")
    func archivedListAsMember() throws {
        let spec = ListFixtures.archivedAsMember()
        let list = try makeSummary(spec)
        #expect(list.status == .archived)
        #expect(list.capabilities.canEditList == false)
        #expect(list.capabilities.canDeleteList == false)
        #expect(list.capabilities.canManageMembers == false)
        #expect(list.capabilities.canSetCoOwner == false)
        #expect(list.capabilities.canLeaveList == true)
    }

    @Test("ARCHIVED list as the owner: every management flag false and passed through as sent")
    func archivedListAsOwner() throws {
        let spec = ListFixtures.archivedAsOwner()
        let list = try makeSummary(spec)
        #expect(list.status == .archived)
        #expect(list.myRole == .owner)
        #expect(list.capabilities.canEditList == false)
        #expect(list.capabilities.canDeleteList == false)
        #expect(list.capabilities.canManageMembers == false)
        #expect(list.capabilities.canSetCoOwner == false)
    }

    // MARK: - Details: members absent versus present

    @Test("Detail members are ABSENT (nil, not empty) when the key is not sent")
    func detailMembersAbsent() throws {
        let spec = ListFixtures.viewerRoleMember()
        let detail = try makeDetail(spec)
        #expect(detail.members == nil)
        #expect(detail.memberCount == 4)
        #expect(detail.capabilities.canSeeMembers == false)
        #expect(detail.itemCount == nil)
    }

    @Test("Detail members present for a MEMBER-role member, with email and status mapped")
    func detailMembersPresent() throws {
        let spec = ListFixtures.memberRoleMember()
        let detail = try makeDetail(spec)
        let members = try #require(detail.members)
        #expect(members.count == 2)
        #expect(detail.memberCount == 4)
        #expect(detail.capabilities.canSeeMembers == true)

        let first = members[0]
        #expect(first.id == "mem-1")
        #expect(first.userId == "user-2")
        #expect(first.displayName == "Casey Member")
        #expect(first.email == "casey@example.invalid")
        #expect(first.role == .member)
        #expect(first.status == .active)
        #expect(first.acceptedAt != nil)
        #expect(first.expiresAt == nil)

        let second = members[1]
        #expect(second.id == "mem-2")
        #expect(second.email == nil)
        #expect(second.role == .viewer)
        #expect(second.status == .invited)
        #expect(second.acceptedAt == nil)
        #expect(second.expiresAt != nil)
    }

    @Test("Detail from a blind owner of a self list carries members and no counts")
    func detailBlindOwner() throws {
        let spec = ListFixtures.blindOwnerOfSelfList()
        let detail = try makeDetail(spec)
        #expect(detail.members?.count == 1)
        #expect(detail.itemCount == nil)
        #expect(detail.purchasedCount == nil)
        #expect(detail.progress == nil)
        #expect(detail.capabilities == ListFixtures.capabilities(spec.flags))
    }

    @Test("Detail and summary of the same payload agree on every shared field")
    func detailAndSummaryAgree() throws {
        let spec = ListFixtures.ownerOfChildList()
        let summary = try makeSummary(spec)
        let detail = try makeDetail(spec)
        #expect(detail.id == summary.id)
        #expect(detail.name == summary.name)
        #expect(detail.theme == summary.theme)
        #expect(detail.year == summary.year)
        #expect(detail.visibility == summary.visibility)
        #expect(detail.status == summary.status)
        #expect(detail.recipient == summary.recipient)
        #expect(detail.owner == summary.owner)
        #expect(detail.coOwner == summary.coOwner)
        #expect(detail.myRole == summary.myRole)
        #expect(detail.capabilities == summary.capabilities)
        #expect(detail.memberCount == summary.memberCount)
        #expect(detail.itemCount == summary.itemCount)
        #expect(detail.purchasedCount == summary.purchasedCount)
        #expect(detail.createdAt == summary.createdAt)
        #expect(detail.updatedAt == summary.updatedAt)
    }

    // MARK: - All twelve flags round trip

    @Test("All twelve flags map one to one with a distinct true/false pattern (summary)")
    func twelveFlagsRoundTripSummary() throws {
        var spec = ListFixtures.Spec()
        spec.flags = ListFixtures.distinctFlags
        let caps = try makeSummary(spec).capabilities
        #expect(caps.isRecipient == true)
        #expect(caps.canSeeGiftActivity == false)
        #expect(caps.canPurchase == true)
        #expect(caps.canAddOffList == true)
        #expect(caps.canSeeOffList == false)
        #expect(caps.canCreateItem == false)
        #expect(caps.canSeeMembers == true)
        #expect(caps.canEditList == false)
        #expect(caps.canDeleteList == false)
        #expect(caps.canManageMembers == true)
        #expect(caps.canSetCoOwner == true)
        #expect(caps.canLeaveList == false)
    }

    @Test("All twelve flags map one to one with a distinct true/false pattern (detail)")
    func twelveFlagsRoundTripDetail() throws {
        var spec = ListFixtures.Spec()
        spec.flags = ListFixtures.distinctFlags
        let caps = try makeDetail(spec).capabilities
        #expect(caps.isRecipient == true)
        #expect(caps.canSeeGiftActivity == false)
        #expect(caps.canPurchase == true)
        #expect(caps.canAddOffList == true)
        #expect(caps.canSeeOffList == false)
        #expect(caps.canCreateItem == false)
        #expect(caps.canSeeMembers == true)
        #expect(caps.canEditList == false)
        #expect(caps.canDeleteList == false)
        #expect(caps.canManageMembers == true)
        #expect(caps.canSetCoOwner == true)
        #expect(caps.canLeaveList == false)
    }

    @Test("Every single flag is mapped independently: only that flag is true")
    func eachFlagMapsIndependently() throws {
        for bit in 0..<12 {
            var spec = ListFixtures.Spec()
            spec.flags = ListFixtures.flags(bits: 1 << bit)
            let mapped = try makeSummary(spec).capabilities
            #expect(mapped == ListFixtures.capabilities(spec.flags), "bit \(bit) was not mapped to its own flag")
        }
    }

    // MARK: - Optional fields

    @Test("Optional coOwner and theme are nil when absent and mapped when present")
    func optionalCoOwnerAndTheme() throws {
        var bare = ListFixtures.Spec()
        bare.theme = nil
        bare.coOwner = nil
        let bareList = try makeSummary(bare)
        #expect(bareList.theme == nil)
        #expect(bareList.coOwner == nil)

        var full = ListFixtures.Spec()
        full.theme = "Winter Wonderland"
        full.coOwner = (id: "user-5", name: "Alex CoOwner")
        let fullList = try makeSummary(full)
        #expect(fullList.theme == "Winter Wonderland")
        #expect(fullList.coOwner?.id == "user-5")
        #expect(fullList.coOwner?.displayName == "Alex CoOwner")
    }

    @Test("Scalar fields, people and dates map across")
    func scalarFieldsMap() throws {
        var spec = ListFixtures.Spec()
        spec.id = "list-xyz"
        spec.name = "Fake Name"
        spec.year = 2031
        spec.recipientId = "r-1"
        spec.recipientName = "Rae Recipient"
        spec.ownerId = "o-1"
        spec.ownerName = "Olly Owner"
        spec.memberCount = 7
        spec.itemCount = 10
        spec.purchasedCount = 4
        spec.flags.canSeeGiftActivity = true
        let list = try makeSummary(spec)
        #expect(list.id == "list-xyz")
        #expect(list.name == "Fake Name")
        #expect(list.year == 2031)
        #expect(list.recipient.id == "r-1")
        #expect(list.recipient.displayName == "Rae Recipient")
        #expect(list.owner.id == "o-1")
        #expect(list.owner.displayName == "Olly Owner")
        #expect(list.memberCount == 7)
        #expect(list.itemCount == 10)
        #expect(list.purchasedCount == 4)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(list.createdAt == formatter.date(from: "2026-01-05T08:30:00.000Z"))
        // updatedAt is sent without fractional seconds.
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        #expect(list.updatedAt == plain.date(from: "2026-01-06T09:45:00Z"))
    }

    @Test("mapListPerson maps id and displayName")
    func mapPerson() {
        let person = mapListPerson(Components.Schemas.PersonRef(id: "p-1", displayName: "Pip Person"))
        #expect(person.id == "p-1")
        #expect(person.displayName == "Pip Person")
    }

    // MARK: - Enumerations

    @Test("Every ListVisibility wire value maps, including FRIENDS_ONLY",
          arguments: [
            ("PRIVATE", ListVisibility.private),
            ("INVITE_ONLY", ListVisibility.inviteOnly),
            ("FRIENDS_ONLY", ListVisibility.friendsOnly),
            ("PUBLIC", ListVisibility.public)
          ])
    func visibilityMaps(raw: String, expected: ListVisibility) throws {
        var spec = ListFixtures.Spec()
        spec.visibility = raw
        #expect(try makeSummary(spec).visibility == expected)
        #expect(try makeDetail(spec).visibility == expected)
        #expect(expected.rawValue == raw)
    }

    @Test("Every ListStatus wire value maps, including DRAFT",
          arguments: [
            ("DRAFT", ListStatus.draft),
            ("ACTIVE", ListStatus.active),
            ("ARCHIVED", ListStatus.archived)
          ])
    func statusMaps(raw: String, expected: ListStatus) throws {
        var spec = ListFixtures.Spec()
        spec.status = raw
        #expect(try makeSummary(spec).status == expected)
        #expect(try makeDetail(spec).status == expected)
        #expect(expected.rawValue == raw)
    }

    @Test("Every ListRole wire value maps, including co-owner",
          arguments: [
            ("owner", ListRole.owner),
            ("co-owner", ListRole.coOwner),
            ("member", ListRole.member),
            ("viewer", ListRole.viewer)
          ])
    func roleMaps(raw: String, expected: ListRole) throws {
        var spec = ListFixtures.Spec()
        spec.myRole = raw
        #expect(try makeSummary(spec).myRole == expected)
        #expect(try makeDetail(spec).myRole == expected)
        #expect(expected.rawValue == raw)
    }

    @Test("Every member status wire value maps",
          arguments: [
            ("INVITED", ListMemberStatus.invited),
            ("ACTIVE", ListMemberStatus.active),
            ("REMOVED", ListMemberStatus.removed),
            ("EXPIRED", ListMemberStatus.expired)
          ])
    func memberStatusMaps(raw: String, expected: ListMemberStatus) throws {
        var spec = ListFixtures.memberRoleMember()
        spec.members = [ListFixtures.MemberSpec(status: raw)]
        let members = try #require(try makeDetail(spec).members)
        #expect(members.first?.status == expected)
    }

    @Test("Every member role wire value maps",
          arguments: [
            ("member", ListMemberRole.member),
            ("viewer", ListMemberRole.viewer)
          ])
    func memberRoleMaps(raw: String, expected: ListMemberRole) throws {
        var spec = ListFixtures.memberRoleMember()
        spec.members = [ListFixtures.MemberSpec(role: raw)]
        let members = try #require(try makeDetail(spec).members)
        #expect(members.first?.role == expected)
    }

    @Test("A present but empty members array maps to an empty array, not nil")
    func emptyMembersArrayStaysEmpty() throws {
        var spec = ListFixtures.memberRoleMember()
        spec.members = []
        let detail = try makeDetail(spec)
        #expect(detail.members == [])
    }
}
