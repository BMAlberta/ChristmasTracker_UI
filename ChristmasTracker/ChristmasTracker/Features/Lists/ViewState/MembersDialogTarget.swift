//
//  MembersDialogTarget.swift
//  ChristmasTracker
//
//  Names which members dialog is open on the list detail screen.
//

import Foundation

nonisolated enum MembersDialogTarget: Hashable, Sendable {
    case leave
    case removeMember(userId: String)
}

/// Names which dialog is open on the edit list screen.
nonisolated enum EditListDialogTarget: Hashable, Sendable {
    case removeCoOwner
}
