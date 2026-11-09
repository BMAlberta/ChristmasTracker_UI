//
//  ListDetail.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

/// Domain model of one list. Built from the generated ListDetail at the repository boundary
/// (see mapListDetail); it carries no wire concerns.
nonisolated struct ListDetail: Identifiable, Equatable, Sendable {

    // MARK: - Basic Info

    let id: String
    let name: String
    let theme: String?
    let year: Int

    // MARK: - Settings

    let visibility: ListVisibility
    let status: ListStatus

    // MARK: - People

    let recipient: ListPerson
    let owner: ListPerson
    let coOwner: ListPerson?

    /// Display only (badge). Never used to decide what the viewer may do.
    let myRole: ListRole

    // MARK: - Capabilities

    let capabilities: ListCapabilities

    // MARK: - Statistics

    let memberCount: Int
    let itemCount: Int?
    let purchasedCount: Int?

    // MARK: - Metadata

    let createdAt: Date
    let updatedAt: Date

    // MARK: - Members

    /// ABSENT (nil, not empty) unless the viewer may see members.
    let members: [ListMember]?

    // MARK: - Computed Properties

    var progress: Double? {
        listProgress(itemCount: itemCount, purchasedCount: purchasedCount)
    }

    var recipientName: String {
        recipient.displayName
    }

    var ownerName: String {
        owner.displayName
    }

    /// A copy with the changed fields applied (used by the mock repository).
    func applying(_ input: UpdateListInput, at date: Date) -> ListDetail {
        ListDetail(
            id: id,
            name: input.name ?? name,
            theme: input.theme ?? theme,
            year: year,
            visibility: input.visibility ?? visibility,
            status: status,
            recipient: recipient,
            owner: owner,
            coOwner: coOwner,
            myRole: myRole,
            capabilities: capabilities,
            memberCount: memberCount,
            itemCount: itemCount,
            purchasedCount: purchasedCount,
            createdAt: createdAt,
            updatedAt: date,
            members: members
        )
    }

    /// The summary form of this list, for the list of lists and the cache.
    func asGiftList() -> GiftList {
        GiftList(
            id: id,
            name: name,
            theme: theme,
            year: year,
            visibility: visibility,
            status: status,
            recipient: recipient,
            owner: owner,
            coOwner: coOwner,
            myRole: myRole,
            capabilities: capabilities,
            memberCount: memberCount,
            itemCount: itemCount,
            purchasedCount: purchasedCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Members

nonisolated enum ListMemberRole: String, Equatable, Sendable {
    case member
    case viewer

    var displayName: String {
        switch self {
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
}

nonisolated enum ListMemberStatus: String, Equatable, Sendable {
    case invited = "INVITED"
    case active = "ACTIVE"
    case removed = "REMOVED"
    case expired = "EXPIRED"
}

/// A member of a list. The email is held for the members package and must never be logged.
nonisolated struct ListMember: Identifiable, Equatable, Sendable {
    let id: String
    let userId: String
    let displayName: String
    let email: String?
    let role: ListMemberRole
    let status: ListMemberStatus
    let invitedAt: Date
    let acceptedAt: Date?
    let expiresAt: Date?
}

// MARK: - Inputs

/// What the app sends to create a list. The domain value; the repository builds the wire body.
nonisolated struct CreateListInput: Equatable, Sendable {
    let recipientId: String
    let year: Int
    let name: String
    let theme: String?
    let visibility: ListVisibility?
}

/// What the app sends to update a list. Only the fields that changed are non-nil.
nonisolated struct UpdateListInput: Equatable, Sendable {
    let name: String?
    let theme: String?
    let visibility: ListVisibility?
}
