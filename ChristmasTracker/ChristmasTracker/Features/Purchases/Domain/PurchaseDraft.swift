//
//  PurchaseDraft.swift
//  ChristmasTracker
//
//  What the record-purchase form sends: a validated quantity and total cost, and the optional
//  strings, which are nil when blank.
//

import Foundation

nonisolated struct PurchaseDraft: Equatable, Sendable {
    let quantity: Int
    let totalCost: Decimal
    let storeName: String?
    let notes: String?
    let confirmationNumber: String?
    let trackingNumber: String?
}
