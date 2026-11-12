//
//  PurchasePermissions.swift
//  ChristmasTracker
//
//  The only place that decides whether a purchase can be opened for management. It compares ids
//  and never looks at a role.
//

import Foundation

nonisolated enum PurchasePermissions {
    static func canManage(purchasePurchaserId: String, currentUserId: String?) -> Bool {
        guard let currentUserId, !currentUserId.isEmpty else { return false }
        return currentUserId == purchasePurchaserId
    }
}
