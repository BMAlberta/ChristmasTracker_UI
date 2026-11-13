//
//  PurchaseManaging.swift
//  ChristmasTracker
//
//  The seam for managing a purchase the caller made: get it, change its notes, change its shipping,
//  delete it. Every method answers the purchase (the deleted one for a delete). Implementations
//  throw `PurchaseManagementError`, or `CancellationError`, and nothing else.
//

import Foundation

nonisolated protocol PurchaseManaging: Sendable {
    func fetchPurchase(id: String) async throws -> RecordedPurchase
    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase
    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase
    /// Answers the deleted purchase.
    func deletePurchase(id: String) async throws -> RecordedPurchase
}
