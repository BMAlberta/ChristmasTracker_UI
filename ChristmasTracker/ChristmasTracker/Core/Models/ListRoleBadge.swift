//
//  ListRoleBadge.swift
//  ChristmasTracker
//
//  The only place a list role is read, and only to label a badge. It never decides what
//  a viewer may do (that is ListPermissions, from the server flags). A VIEWER-role member
//  and a PUBLIC non-member both arrive as the viewer role and both show "Viewer".
//

import Foundation
import SwiftUI
import TrackerAPI

nonisolated struct ListRoleBadge: Equatable, Sendable {

    /// A neutral name for the badge colour; the view maps it to an AppColors token.
    enum Tone: Equatable, Sendable {
        case owner
        case coOwner
        case member
        case viewer
    }

    let title: String
    let tone: Tone

    init(list: GiftList) {
        self.init(role: list.myRole)
    }

    init(detail: ListDetail) {
        self.init(role: detail.myRole)
    }

    private init(role: ListRole) {
        title = role.displayName
        switch role {
        case .owner: tone = .owner
        case .coOwner: tone = .coOwner
        case .member: tone = .member
        case .viewer: tone = .viewer
        }
    }
}

nonisolated extension ListRole {
    /// Reads the wire role of a generated summary, for display. Lives here because this file is
    /// the only one allowed to touch a role. The switch is exhaustive: a new server role fails to
    /// compile instead of being mapped silently.
    init(wire summary: Components.Schemas.ListSummary) {
        switch summary.value1.myRole {
        case .owner: self = .owner
        case .coOwner: self = .coOwner
        case .member: self = .member
        case .viewer: self = .viewer
        }
    }
}

extension ListRoleBadge.Tone {
    /// Badge background, from the design system colours.
    @MainActor var color: Color {
        switch self {
        case .owner: return .primaryColor
        case .coOwner: return .accentColor
        case .member: return .highlightColor
        case .viewer: return .textMutedColor
        }
    }
}
