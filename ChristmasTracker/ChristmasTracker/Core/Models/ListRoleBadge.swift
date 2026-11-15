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

/// How a badge looks, by theme token: an optional fill, an optional 1 point edge and the text.
/// Pure data, so tests measure it without SwiftUI. The view turns tokens into Colors.
nonisolated struct RoleBadgeLook: Equatable, Sendable {

    /// Where the text color comes from.
    enum Text: Equatable, Sendable {
        /// The contrast label chosen for the fill (`ThemeStatusLabelTable`).
        case onFill
        case token(ThemeToken)
    }

    /// Width of the edge, in points.
    static let borderWidth: CGFloat = 1

    let fill: ThemeToken?
    let border: ThemeToken?
    let text: Text

    /// The text color for a mode.
    func label(for mode: ThemeMode) -> ThemeLabel {
        switch text {
        case .token(let token):
            return .token(token)
        case .onFill:
            guard let fill else { return .token(.textPrimary) }
            return ThemeStatusLabelTable.label(onFill: fill, mode: mode)
        }
    }
}

nonisolated extension ListRoleBadge.Tone {
    /// Owner: green fill. Co-owner: green edge and text. Member: quiet fill with a neutral edge.
    /// Viewer: neutral edge and muted text. No gold, no cranberry.
    var look: RoleBadgeLook {
        switch self {
        case .owner: return RoleBadgeLook(fill: .primary, border: nil, text: .onFill)
        case .coOwner: return RoleBadgeLook(fill: nil, border: .primary, text: .token(.primary))
        case .member: return RoleBadgeLook(fill: .backgroundSecondary, border: .border, text: .token(.textPrimary))
        case .viewer: return RoleBadgeLook(fill: nil, border: .border, text: .token(.textMuted))
        }
    }
}
