//
//  MembersViewState.swift
//  ChristmasTracker
//
//  Pure view states for the Members section of the list detail. Every affordance follows a
//  server capability flag (through ListPermissions). The ONLY role read in the app's screens
//  logic is the MEMBERSHIP role of a roster row, read here to label the row; the viewer's own
//  role is never used. Rows show ACTIVE members only, and no email is ever shown.
//

import Foundation

// MARK: - Row

/// Who a roster row is. The owner and co-owner rows come from the detail's own person fields,
/// not from the wire roster (which only holds members and viewers).
nonisolated enum MemberRowKind: Equatable, Sendable {
    case owner
    case coOwner
    case member
    case viewer

    var title: String {
        switch self {
        case .owner: return "Owner"
        case .coOwner: return "Co-owner"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
}

/// What one roster row shows and offers.
nonisolated struct MemberRowState: Identifiable, Equatable, Sendable {
    /// The membership id, or a synthetic "owner:<id>" / "co-owner:<id>" for those rows.
    let id: String
    let userId: String
    let displayName: String
    let kind: MemberRowKind
    let roleLabel: String
    let canRemove: Bool

    var accessibilityLabel: String {
        "\(displayName), \(roleLabel)"
    }
}

// MARK: - Section

/// What the Members section of the list detail shows and offers.
nonisolated struct MembersSectionState: Equatable, Sendable {
    let showsRoster: Bool
    let rows: [MemberRowState]
    let showsAdd: Bool
    let showsLeave: Bool
    let memberCountText: String

    init(detail: ListDetail) {
        let permissions = ListPermissions(detail.capabilities)
        let roster = permissions.showsMembersSection ? detail.members : nil

        showsRoster = roster != nil
        showsAdd = permissions.canManageMembers
        showsLeave = permissions.canLeaveList
        memberCountText = detail.memberCount == 1 ? "1 member" : "\(detail.memberCount) members"
        guard let roster else {
            rows = []
            return
        }

        var built: [MemberRowState] = [Self.personRow(detail.owner, kind: .owner)]
        var shownIds: Set<String> = [detail.owner.id]
        if let coOwner = detail.coOwner {
            built.append(Self.personRow(coOwner, kind: .coOwner))
            shownIds.insert(coOwner.id)
        }
        for member in roster where member.status == .active && !shownIds.contains(member.userId) {
            let kind = Self.kind(of: member)
            built.append(
                MemberRowState(
                    id: member.id,
                    userId: member.userId,
                    displayName: member.displayName,
                    kind: kind,
                    roleLabel: kind.title,
                    canRemove: permissions.canManageMembers
                )
            )
        }
        rows = built
    }

    /// The texts of the remove-member confirmation for a roster row.
    static func removeConfirmation(for row: MemberRowState) -> (title: String, message: String, confirmButtonTitle: String) {
        (
            title: MemberRemoveConfirmation.title(displayName: row.displayName),
            message: MemberRemoveConfirmation.message(displayName: row.displayName),
            confirmButtonTitle: MemberRemoveConfirmation.confirmButtonTitle
        )
    }

    /// The texts of the leave-list confirmation.
    static var leaveConfirmation: (title: String, message: String, confirmButtonTitle: String) {
        (
            title: LeaveListConfirmation.title,
            message: LeaveListConfirmation.message,
            confirmButtonTitle: LeaveListConfirmation.confirmButtonTitle
        )
    }

    /// The owner or co-owner row: built from the detail's person, never removable, with a
    /// synthetic id that cannot collide with a membership id.
    private static func personRow(_ person: ListPerson, kind: MemberRowKind) -> MemberRowState {
        let prefix = kind == .owner ? "owner" : "co-owner"
        return MemberRowState(
            id: "\(prefix):\(person.id)",
            userId: person.id,
            displayName: person.displayName,
            kind: kind,
            roleLabel: kind.title,
            canRemove: false
        )
    }

    /// The server never sends the owner or co-owner in members, so a roster row is a member or viewer.
    private static func kind(of member: ListMember) -> MemberRowKind {
        switch member.role {
        case .member: return .member
        case .viewer: return .viewer
        }
    }
}

// MARK: - Confirmations

nonisolated enum MemberRemoveConfirmation {
    static let confirmButtonTitle = "Remove"

    static func title(displayName: String) -> String {
        "Remove \(displayName)?"
    }

    static func message(displayName: String) -> String {
        "\(displayName) will lose access to this list."
    }
}

nonisolated enum LeaveListConfirmation {
    static let title = "Leave this list?"
    static let message = "The list will be removed from your lists."
    static let confirmButtonTitle = "Leave List"
}

// MARK: - Add member form

nonisolated struct AddMemberFormValidity: Equatable, Sendable {
    let emailInvalid: Bool

    var isValid: Bool {
        !emailInvalid
    }
}

/// Rules and request builder of the add-member form.
nonisolated enum AddMemberFormValidation {
    static let emailLimit = 254

    static func validate(email: String, role: MemberRole) -> AddMemberFormValidity {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = !RegistrationFormValidator.isValidEmail(trimmed) || trimmed.count > emailLimit
        return AddMemberFormValidity(emailInvalid: invalid)
    }

    /// Valid input and no mutation in flight: a form cannot be submitted twice.
    static func canSubmit(email: String, role: MemberRole, isMutating: Bool) -> Bool {
        !isMutating && validate(email: email, role: role).isValid
    }

    static func makeInput(email: String, role: MemberRole) -> AddMemberInput {
        AddMemberInput(email: email.trimmingCharacters(in: .whitespacesAndNewlines), role: role)
    }
}
