//
//  ItemPermissions.swift
//  ChristmasTracker
//
//  Pure display rules driven only by the list's capability flags: canAddItem,
//  showsOffListNotice, visibleItems, canSeeGiftActivity, canSeeOffListItems and canPurchase.
//  No screen reads a role.
//
//  Source: Docs/privacy-matrix.md (list capability flags).
//
//  PER-ITEM FLAGS: the item's own canEdit and canDelete come from the server (P25) and are read
//  straight off ListItem. This type no longer derives edit or delete rights.
//

import Foundation

nonisolated struct ItemPermissions: Equatable, Sendable {
    private let canCreateItem: Bool
    private let canAddOffList: Bool

    let canSeeGiftActivity: Bool
    let canSeeOffListItems: Bool
    let canPurchase: Bool

    init(capabilities: ListCapabilities) {
        self.canCreateItem = capabilities.canCreateItem
        self.canAddOffList = capabilities.canAddOffList
        self.canSeeGiftActivity = capabilities.canSeeGiftActivity
        self.canSeeOffListItems = capabilities.canSeeOffList
        self.canPurchase = capabilities.canPurchase
    }

    var canAddItem: Bool { canCreateItem }

    /// True when the add form should say the item will be hidden from the recipient.
    var showsOffListNotice: Bool { canAddOffList }

    /// Drops off-list items when the viewer may not see them (the server already omits them;
    /// this is defensive). Order is kept.
    func visibleItems(_ items: [ListItem]) -> [ListItem] {
        canSeeOffListItems ? items : items.filter { !$0.offList }
    }
}
