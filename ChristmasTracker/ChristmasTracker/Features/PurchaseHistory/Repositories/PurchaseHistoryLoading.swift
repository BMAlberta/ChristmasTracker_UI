//
//  PurchaseHistoryLoading.swift
//  ChristmasTracker
//
//  The seam for the caller's purchase history. Implementations throw `PurchaseHistoryError`, or
//  `CancellationError`, and nothing else.
//

import Foundation

nonisolated protocol PurchaseHistoryLoading: Sendable {
    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage
}
