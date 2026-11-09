//
//  ListPermissions.swift
//  ChristmasTracker
//
//  The ONE place that answers list-level questions for the screens. Pure and flag-driven:
//  it is built from ListCapabilities only and has no access to the viewer's role.
//

import Foundation

/// Display grouping of a list: owned (the viewer manages it) or shared (everything else).
nonisolated enum ListCategory: Equatable, Sendable {
    case owned
    case shared
}

nonisolated struct ListPermissions: Equatable, Sendable {
    let canEditList: Bool
    let canDeleteList: Bool
    let canManageMembers: Bool
    let canSetCoOwner: Bool
    let canLeaveList: Bool
    let showsMembersSection: Bool

    private let canSeeGiftActivity: Bool

    init(_ capabilities: ListCapabilities) {
        canEditList = capabilities.canEditList
        canDeleteList = capabilities.canDeleteList
        canManageMembers = capabilities.canManageMembers
        canSetCoOwner = capabilities.canSetCoOwner
        canLeaveList = capabilities.canLeaveList
        showsMembersSection = capabilities.canSeeMembers
        canSeeGiftActivity = capabilities.canSeeGiftActivity
    }

    /// Counts show only when the server allows gift activity and both counts are present.
    func showsCounts(itemCount: Int?, purchasedCount: Int?) -> Bool {
        guard canSeeGiftActivity else { return false }
        return itemCount != nil && purchasedCount != nil
    }

    /// Progress shows when counts show and there is at least one item.
    func showsProgress(itemCount: Int?, purchasedCount: Int?) -> Bool {
        guard showsCounts(itemCount: itemCount, purchasedCount: purchasedCount),
              let itemCount else { return false }
        return itemCount > 0
    }

    /// Owned means the viewer can edit, delete or manage members of the list.
    var category: ListCategory {
        (canEditList || canDeleteList || canManageMembers) ? .owned : .shared
    }
}
