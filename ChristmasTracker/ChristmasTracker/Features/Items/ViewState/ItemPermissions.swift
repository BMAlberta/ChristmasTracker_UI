//
//  ItemPermissions.swift
//  ChristmasTracker
//
//  The ONE pure function that decides item rights. It reads only the list's capability flags,
//  the item's offList and creator id, and the current user's id. No screen reads a role.
//
//  Source: Docs/privacy-matrix.md (item rows). A regular item is edited and deleted by the
//  owner or co-owner (blind or not); a member's off-list item only by its creator (the owner
//  and co-owner get 403); members, viewers and PUBLIC non-members never touch a regular item.
//  In flag terms: canCreateItem without canAddOffList identifies the owner or co-owner write
//  role, canAddOffList the member write role. The list status is not an input.
//
//  MISSING PER-ITEM FLAGS: ItemResponse carries no canEdit or canDelete flag, so the rule above
//  is derived from the list flags. Brian has asked the API chat to consider adding canEdit and
//  canDelete to ItemResponse; if the contract adds them, this type becomes a thin read of them.
//

import Foundation

nonisolated struct ItemPermissions: Equatable, Sendable {
    private let canCreateItem: Bool
    private let canAddOffList: Bool
    private let currentUserId: String?

    let canSeeGiftActivity: Bool
    let canSeeOffListItems: Bool
    let canPurchase: Bool

    init(capabilities: ListCapabilities, currentUserId: String?) {
        self.canCreateItem = capabilities.canCreateItem
        self.canAddOffList = capabilities.canAddOffList
        self.currentUserId = currentUserId
        self.canSeeGiftActivity = capabilities.canSeeGiftActivity
        self.canSeeOffListItems = capabilities.canSeeOffList
        self.canPurchase = capabilities.canPurchase
    }

    var canAddItem: Bool { canCreateItem }

    /// True when the add form should say the item will be hidden from the recipient.
    var showsOffListNotice: Bool { canAddOffList }

    func canEdit(_ item: ListItem) -> Bool {
        if item.offList {
            guard let currentUserId else { return false }
            return item.createdBy.id == currentUserId
        }
        return canCreateItem && !canAddOffList
    }

    func canDelete(_ item: ListItem) -> Bool {
        canEdit(item)
    }

    /// Drops off-list items when the viewer may not see them (the server already omits them;
    /// this is defensive). Order is kept.
    func visibleItems(_ items: [ListItem]) -> [ListItem] {
        canSeeOffListItems ? items : items.filter { !$0.offList }
    }
}
