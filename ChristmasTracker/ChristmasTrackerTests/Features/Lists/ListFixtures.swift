//
//  ListFixtures.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: shared, fake-data fixtures for the list domain tests.
//
//  Wire side: literal JSON built from a `Spec` and decoded with the generated
//  Codable types (`Components.Schemas.ListSummary` / `ListDetail`), using the
//  package's date convention (`TrackerDateTranscoder`). No hand parsing.
//
//  Domain side: the ONLY call sites of the memberwise initialisers of
//  `ListCapabilities`, `GiftList` and `ListDetail` in the test target live in
//  this file, so a change of argument order is a one-file fix.
//
//  All names, ids and addresses are fake. No money fields exist on these types.
//

import Foundation
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum ListFixtures {

    // MARK: - Wire-side specification

    /// The twelve per-viewer booleans, as sent on the wire.
    struct Flags: Sendable, Equatable {
        var isRecipient = false
        var canSeeGiftActivity = false
        var canPurchase = false
        var canAddOffList = false
        var canSeeOffList = false
        var canCreateItem = false
        var canSeeMembers = false
        var canEditList = false
        var canDeleteList = false
        var canManageMembers = false
        var canSetCoOwner = false
        var canLeaveList = false
    }

    struct MemberSpec: Sendable {
        var id = "mem-1"
        var userId = "user-2"
        var displayName = "Casey Member"
        var email: String? = "casey@example.invalid"
        var role = "member"
        var status = "ACTIVE"
        var invitedAt = "2026-02-01T10:00:00.000Z"
        var acceptedAt: String? = "2026-02-02T10:00:00.000Z"
        var expiresAt: String?
    }

    struct Spec: Sendable {
        var id = "list-1"
        var name = "Fake Family List"
        var theme: String? = "Cosy"
        var year = 2026
        var visibility = "PRIVATE"
        var status = "ACTIVE"
        var recipientId = "user-1"
        var recipientName = "Robin Recipient"
        var ownerId = "user-1"
        var ownerName = "Robin Recipient"
        var coOwner: (id: String, name: String)?
        var myRole = "owner"
        var itemCount: Int?
        var purchasedCount: Int?
        var memberCount = 0
        var flags = Flags()
        /// nil means the `members` key is ABSENT from the JSON (not an empty array).
        var members: [MemberSpec]?
        var createdAt = "2026-01-05T08:30:00.000Z"
        var updatedAt = "2026-01-06T09:45:00Z"
    }

    // MARK: - Scenarios

    /// Blind owner of a self list: counts absent, can edit and delete, no members section data
    /// beyond the list of members the owner is allowed to see.
    static func blindOwnerOfSelfList() -> Spec {
        var spec = Spec()
        spec.id = "list-self"
        spec.myRole = "owner"
        spec.memberCount = 2
        spec.flags = Flags(
            isRecipient: true, canSeeGiftActivity: false, canPurchase: false,
            canAddOffList: false, canSeeOffList: false, canCreateItem: true,
            canSeeMembers: true, canEditList: true, canDeleteList: true,
            canManageMembers: true, canSetCoOwner: true, canLeaveList: false
        )
        spec.members = [MemberSpec()]
        return spec
    }

    /// Owner of a child list: not blind, counts present.
    static func ownerOfChildList() -> Spec {
        var spec = Spec()
        spec.id = "list-child"
        spec.recipientId = "child-1"
        spec.recipientName = "Charlie Child"
        spec.ownerId = "user-1"
        spec.ownerName = "Robin Recipient"
        spec.myRole = "owner"
        spec.itemCount = 8
        spec.purchasedCount = 3
        spec.memberCount = 3
        spec.flags = Flags(
            isRecipient: false, canSeeGiftActivity: true, canPurchase: true,
            canAddOffList: false, canSeeOffList: true, canCreateItem: true,
            canSeeMembers: true, canEditList: true, canDeleteList: true,
            canManageMembers: true, canSetCoOwner: true, canLeaveList: false
        )
        spec.members = [MemberSpec()]
        return spec
    }

    /// MEMBER-role member: counts present, sees members, may leave.
    static func memberRoleMember() -> Spec {
        var spec = Spec()
        spec.id = "list-member"
        spec.recipientId = "user-9"
        spec.recipientName = "Jordan Other"
        spec.ownerId = "user-9"
        spec.ownerName = "Jordan Other"
        spec.myRole = "member"
        spec.itemCount = 5
        spec.purchasedCount = 2
        spec.memberCount = 4
        spec.flags = Flags(
            isRecipient: false, canSeeGiftActivity: true, canPurchase: true,
            canAddOffList: true, canSeeOffList: true, canCreateItem: true,
            canSeeMembers: true, canEditList: false, canDeleteList: false,
            canManageMembers: false, canSetCoOwner: false, canLeaveList: true
        )
        spec.members = [
            MemberSpec(),
            MemberSpec(id: "mem-2", userId: "user-3", displayName: "Sam Viewer",
                       email: nil, role: "viewer", status: "INVITED",
                       invitedAt: "2026-02-03T10:00:00Z", acceptedAt: nil,
                       expiresAt: "2026-03-03T10:00:00.000Z")
        ]
        return spec
    }

    /// VIEWER-role member: no counts, no members, may leave.
    static func viewerRoleMember() -> Spec {
        var spec = Spec()
        spec.id = "list-viewer"
        spec.recipientId = "user-9"
        spec.recipientName = "Jordan Other"
        spec.ownerId = "user-9"
        spec.ownerName = "Jordan Other"
        spec.myRole = "viewer"
        spec.memberCount = 4
        spec.flags = Flags(
            isRecipient: false, canSeeGiftActivity: false, canPurchase: false,
            canAddOffList: false, canSeeOffList: false, canCreateItem: false,
            canSeeMembers: false, canEditList: false, canDeleteList: false,
            canManageMembers: false, canSetCoOwner: false, canLeaveList: true
        )
        spec.members = nil
        return spec
    }

    /// PUBLIC non-member: myRole is viewer, no counts, cannot leave.
    static func publicNonMember() -> Spec {
        var spec = viewerRoleMember()
        spec.id = "list-public"
        spec.visibility = "PUBLIC"
        spec.memberCount = 1
        spec.flags.canLeaveList = false
        return spec
    }

    /// Blind co-owner: no counts, may edit and delete, may not set the co-owner.
    static func blindCoOwner() -> Spec {
        var spec = Spec()
        spec.id = "list-coowner"
        spec.recipientId = "user-9"
        spec.recipientName = "Jordan Other"
        spec.ownerId = "user-8"
        spec.ownerName = "Pat Owner"
        spec.coOwner = (id: "user-1", name: "Robin Recipient")
        spec.myRole = "co-owner"
        spec.memberCount = 2
        spec.flags = Flags(
            isRecipient: false, canSeeGiftActivity: false, canPurchase: false,
            canAddOffList: false, canSeeOffList: false, canCreateItem: true,
            canSeeMembers: true, canEditList: true, canDeleteList: true,
            canManageMembers: true, canSetCoOwner: false, canLeaveList: false
        )
        spec.members = [MemberSpec()]
        return spec
    }

    /// The recipient of a self list seen through the recipient flag.
    static func recipientOfSelfList() -> Spec {
        var spec = blindOwnerOfSelfList()
        spec.id = "list-recipient"
        spec.myRole = "owner"
        spec.flags.isRecipient = true
        return spec
    }

    /// An ARCHIVED list as a MEMBER-role member: management flags false, leave still true.
    static func archivedAsMember() -> Spec {
        var spec = memberRoleMember()
        spec.id = "list-archived-member"
        spec.status = "ARCHIVED"
        return spec
    }

    /// An ARCHIVED list as the owner: every management flag false.
    static func archivedAsOwner() -> Spec {
        var spec = ownerOfChildList()
        spec.id = "list-archived-owner"
        spec.status = "ARCHIVED"
        spec.flags.canEditList = false
        spec.flags.canDeleteList = false
        spec.flags.canManageMembers = false
        spec.flags.canSetCoOwner = false
        return spec
    }

    /// Twelve flags with a distinct, asymmetric true/false pattern so a swapped mapping fails.
    static let distinctFlags = Flags(
        isRecipient: true, canSeeGiftActivity: false, canPurchase: true,
        canAddOffList: true, canSeeOffList: false, canCreateItem: false,
        canSeeMembers: true, canEditList: false, canDeleteList: false,
        canManageMembers: true, canSetCoOwner: true, canLeaveList: false
    )

    // MARK: - Wire decoding

    static func summary(_ spec: Spec) throws -> Components.Schemas.ListSummary {
        try decoder().decode(Components.Schemas.ListSummary.self, from: summaryData(spec))
    }

    static func detail(_ spec: Spec) throws -> Components.Schemas.ListDetail {
        try decoder().decode(Components.Schemas.ListDetail.self, from: detailData(spec))
    }

    static func summaryData(_ spec: Spec) throws -> Data {
        try JSONSerialization.data(withJSONObject: summaryObject(spec))
    }

    static func detailData(_ spec: Spec) throws -> Data {
        var object = summaryObject(spec)
        if let members = spec.members {
            object["members"] = members.map(memberObject)
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try TrackerDateTranscoder().decode(text)
        }
        return decoder
    }

    private static func summaryObject(_ spec: Spec) -> [String: Any] {
        var object: [String: Any] = [
            "id": spec.id,
            "name": spec.name,
            "year": spec.year,
            "visibility": spec.visibility,
            "status": spec.status,
            "recipient": ["id": spec.recipientId, "displayName": spec.recipientName],
            "owner": ["id": spec.ownerId, "displayName": spec.ownerName],
            "myRole": spec.myRole,
            "memberCount": spec.memberCount,
            "createdAt": spec.createdAt,
            "updatedAt": spec.updatedAt,
            "isRecipient": spec.flags.isRecipient,
            "canSeeGiftActivity": spec.flags.canSeeGiftActivity,
            "canPurchase": spec.flags.canPurchase,
            "canAddOffList": spec.flags.canAddOffList,
            "canSeeOffList": spec.flags.canSeeOffList,
            "canCreateItem": spec.flags.canCreateItem,
            "canSeeMembers": spec.flags.canSeeMembers,
            "canEditList": spec.flags.canEditList,
            "canDeleteList": spec.flags.canDeleteList,
            "canManageMembers": spec.flags.canManageMembers,
            "canSetCoOwner": spec.flags.canSetCoOwner,
            "canLeaveList": spec.flags.canLeaveList
        ]
        if let theme = spec.theme { object["theme"] = theme }
        if let coOwner = spec.coOwner {
            object["coOwner"] = ["id": coOwner.id, "displayName": coOwner.name]
        }
        if let itemCount = spec.itemCount { object["itemCount"] = itemCount }
        if let purchasedCount = spec.purchasedCount { object["purchasedCount"] = purchasedCount }
        return object
    }

    private static func memberObject(_ member: MemberSpec) -> [String: Any] {
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
        return object
    }

    // MARK: - Domain construction (the only memberwise call sites)

    /// Builds the domain capabilities from a wire `Flags` value, one labelled argument per flag.
    static func capabilities(_ flags: Flags) -> ListCapabilities {
        ListCapabilities(
            isRecipient: flags.isRecipient,
            canSeeGiftActivity: flags.canSeeGiftActivity,
            canPurchase: flags.canPurchase,
            canAddOffList: flags.canAddOffList,
            canSeeOffList: flags.canSeeOffList,
            canCreateItem: flags.canCreateItem,
            canSeeMembers: flags.canSeeMembers,
            canEditList: flags.canEditList,
            canDeleteList: flags.canDeleteList,
            canManageMembers: flags.canManageMembers,
            canSetCoOwner: flags.canSetCoOwner,
            canLeaveList: flags.canLeaveList
        )
    }

    /// Builds a domain `GiftList` directly (not via the mapper).
    static func giftList(
        id: String = "list-1",
        name: String = "Fake Family List",
        theme: String? = nil,
        year: Int = 2026,
        visibility: ListVisibility = .private,
        status: ListStatus = .active,
        myRole: ListRole = .owner,
        flags: Flags = Flags(),
        memberCount: Int = 0,
        itemCount: Int? = nil,
        purchasedCount: Int? = nil,
        recipient: ListPerson? = nil
    ) -> GiftList {
        let person = ListPerson(id: "user-1", displayName: "Robin Recipient")
        return GiftList(
            id: id,
            name: name,
            theme: theme,
            year: year,
            visibility: visibility,
            status: status,
            recipient: recipient ?? person,
            owner: person,
            coOwner: nil,
            myRole: myRole,
            capabilities: capabilities(flags),
            memberCount: memberCount,
            itemCount: itemCount,
            purchasedCount: purchasedCount,
            createdAt: Date(timeIntervalSince1970: 1_767_600_000),
            updatedAt: Date(timeIntervalSince1970: 1_767_686_400)
        )
    }

    /// Builds a domain `ListDetail` directly (not via the mapper). `members` is the last argument.
    static func listDetail(
        id: String = "list-1",
        name: String = "Fake Family List",
        status: ListStatus = .active,
        myRole: ListRole = .owner,
        flags: Flags = Flags(),
        memberCount: Int = 0,
        itemCount: Int? = nil,
        purchasedCount: Int? = nil,
        members: [ListMember]? = nil
    ) -> ListDetail {
        let person = ListPerson(id: "user-1", displayName: "Robin Recipient")
        return ListDetail(
            id: id,
            name: name,
            theme: nil,
            year: 2026,
            visibility: .private,
            status: status,
            recipient: person,
            owner: person,
            coOwner: nil,
            myRole: myRole,
            capabilities: capabilities(flags),
            memberCount: memberCount,
            itemCount: itemCount,
            purchasedCount: purchasedCount,
            createdAt: Date(timeIntervalSince1970: 1_767_600_000),
            updatedAt: Date(timeIntervalSince1970: 1_767_686_400),
            members: members
        )
    }

    /// A capabilities value with every flag set to the same value.
    static func uniformFlags(_ value: Bool) -> Flags {
        Flags(
            isRecipient: value, canSeeGiftActivity: value, canPurchase: value,
            canAddOffList: value, canSeeOffList: value, canCreateItem: value,
            canSeeMembers: value, canEditList: value, canDeleteList: value,
            canManageMembers: value, canSetCoOwner: value, canLeaveList: value
        )
    }

    /// Flags for bit pattern `bits` (bit 0 is the first flag, in the addendum order).
    static func flags(bits: Int) -> Flags {
        func bit(_ index: Int) -> Bool { (bits >> index) & 1 == 1 }
        return Flags(
            isRecipient: bit(0), canSeeGiftActivity: bit(1), canPurchase: bit(2),
            canAddOffList: bit(3), canSeeOffList: bit(4), canCreateItem: bit(5),
            canSeeMembers: bit(6), canEditList: bit(7), canDeleteList: bit(8),
            canManageMembers: bit(9), canSetCoOwner: bit(10), canLeaveList: bit(11)
        )
    }
}
