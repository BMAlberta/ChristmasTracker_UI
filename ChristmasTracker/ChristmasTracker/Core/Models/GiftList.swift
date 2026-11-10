//
//  GiftList.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import Foundation

/// Domain model of a list in the list of lists. Built from the generated ListSummary at the
/// repository boundary (see mapListSummary); it carries no wire concerns.
nonisolated struct GiftList: Identifiable, Equatable, Sendable {
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
    /// Absent for blind viewers, viewer-role members and public non-members.
    let itemCount: Int?
    let purchasedCount: Int?

    // MARK: - Metadata
    let createdAt: Date
    let updatedAt: Date

    // MARK: - Computed Properties

    /// Purchased over items, only when both counts are present and there is at least one item.
    var progress: Double? {
        listProgress(itemCount: itemCount, purchasedCount: purchasedCount)
    }

    var recipientName: String {
        recipient.displayName
    }

    var ownerName: String {
        owner.displayName
    }

    /// The detail form of this list with the given members (nil when the viewer may not see them).
    func asDetail(members: [ListMember]?) -> ListDetail {
        ListDetail(
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
            updatedAt: updatedAt,
            members: members
        )
    }
}

/// Shared by GiftList and ListDetail so both follow the same rule.
nonisolated func listProgress(itemCount: Int?, purchasedCount: Int?) -> Double? {
    guard let itemCount, let purchasedCount, itemCount > 0 else { return nil }
    return Double(purchasedCount) / Double(itemCount)
}

// MARK: - ListPerson (Nested Object)

nonisolated struct ListPerson: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
}

// MARK: - Enums

nonisolated enum ListRole: String, Equatable, Sendable {
    case owner = "owner"
    case coOwner = "co-owner"
    case member = "member"
    case viewer = "viewer"

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .coOwner: return "Co-Owner"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
}

nonisolated enum ListVisibility: String, Equatable, Hashable, Sendable {
    case `private` = "PRIVATE"
    case inviteOnly = "INVITE_ONLY"
    case friendsOnly = "FRIENDS_ONLY"
    case `public` = "PUBLIC"
}

nonisolated enum ListStatus: String, Equatable, Hashable, Sendable {
    case draft = "DRAFT"
    case active = "ACTIVE"
    case archived = "ARCHIVED"
}
