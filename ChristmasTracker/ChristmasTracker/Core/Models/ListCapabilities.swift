//
//  ListCapabilities.swift
//  ChristmasTracker
//
//  The twelve per-viewer booleans the server sends on every list summary and detail.
//  A true flag means the server accepts the action now. Screens never derive any of
//  this from the viewer's role; they ask ListPermissions.
//

import Foundation

nonisolated struct ListCapabilities: Equatable, Sendable {
    let isRecipient: Bool
    let canSeeGiftActivity: Bool
    let canPurchase: Bool
    let canAddOffList: Bool
    let canSeeOffList: Bool
    let canCreateItem: Bool
    let canSeeMembers: Bool
    let canEditList: Bool
    let canDeleteList: Bool
    let canManageMembers: Bool
    let canSetCoOwner: Bool
    let canLeaveList: Bool

    init(
        isRecipient: Bool,
        canSeeGiftActivity: Bool,
        canPurchase: Bool,
        canAddOffList: Bool,
        canSeeOffList: Bool,
        canCreateItem: Bool,
        canSeeMembers: Bool,
        canEditList: Bool,
        canDeleteList: Bool,
        canManageMembers: Bool,
        canSetCoOwner: Bool,
        canLeaveList: Bool
    ) {
        self.isRecipient = isRecipient
        self.canSeeGiftActivity = canSeeGiftActivity
        self.canPurchase = canPurchase
        self.canAddOffList = canAddOffList
        self.canSeeOffList = canSeeOffList
        self.canCreateItem = canCreateItem
        self.canSeeMembers = canSeeMembers
        self.canEditList = canEditList
        self.canDeleteList = canDeleteList
        self.canManageMembers = canManageMembers
        self.canSetCoOwner = canSetCoOwner
        self.canLeaveList = canLeaveList
    }
}
