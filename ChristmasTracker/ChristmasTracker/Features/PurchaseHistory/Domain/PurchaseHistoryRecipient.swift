//
//  PurchaseHistoryRecipient.swift
//  ChristmasTracker
//
//  A person the user bought for, as an option of the recipient filter of the purchase history.
//

import Foundation

nonisolated struct PurchaseHistoryRecipient: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
}
