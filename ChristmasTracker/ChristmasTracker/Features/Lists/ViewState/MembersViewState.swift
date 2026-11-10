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

/// Who a roster row is. The owner and co-owner rows are identified by the detail's person ids,
/// not by the wire role (which only knows member and viewer).
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
    /// The membership id.
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
        rows = (roster ?? [])
            .filter { $0.status == .active }
            .map { member in
                let kind = Self.kind(of: member, in: detail)
                return MemberRowState(
                    id: member.id,
                    userId: member.userId,
                    displayName: member.displayName,
                    kind: kind,
                    roleLabel: kind.title,
                    canRemove: permissions.canManageMembers && (kind == .member || kind == .viewer)
                )
            }
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

    private static func kind(of member: ListMember, in detail: ListDetail) -> MemberRowKind {
        if member.userId == detail.owner.id { return .owner }
        if let coOwner = detail.coOwner, member.userId == coOwner.id { return .coOwner }
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
