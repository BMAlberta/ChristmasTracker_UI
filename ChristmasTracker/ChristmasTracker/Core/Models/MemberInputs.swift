//
//  MemberInputs.swift
//  ChristmasTracker
//
//  Domain values for adding a member and changing the co-owner. Pure and Sendable; the
//  repository builds the wire bodies. Emails are held here and must never be logged.
//

import Foundation

/// The role a new member is added with (member or viewer). It is the existing membership role.
typealias MemberRole = ListMemberRole

nonisolated extension ListMemberRole {
    /// The user-facing name, for the role picker.
    var title: String {
        displayName
    }
}

/// What the app sends to add a member to a list.
nonisolated struct AddMemberInput: Equatable, Sendable {
    let email: String
    let role: MemberRole
}

/// How an update changes the co-owner of a list.
nonisolated enum CoOwnerChange: Equatable, Sendable {
    /// Leave the co-owner as it is.
    case unchanged
    /// Set the co-owner to the person with this email.
    case set(email: String)
    /// Remove the co-owner. Not sendable through the generated client today (see CoOwnerSectionState).
    case clear
}
