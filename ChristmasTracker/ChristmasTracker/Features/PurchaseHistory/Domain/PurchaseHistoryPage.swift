//
//  PurchaseHistoryPage.swift
//  ChristmasTracker
//
//  One page of the purchase history in the server's order. `nextCursor` is opaque and nil on the last page.
//

import Foundation

nonisolated struct PurchaseHistoryPage: Equatable, Sendable {
    let rows: [PurchaseHistoryRow]
    let nextCursor: String?
}
