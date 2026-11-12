//
//  PurchaseRecording.swift
//  ChristmasTracker
//
//  The seam for recording a purchase. It deliberately does not inherit the legacy Repository
//  protocol (Core/Networking is deleted in I4b). The confirmation token is an argument of one call
//  and is never stored by an implementation.
//

import Foundation

nonisolated protocol PurchaseRecording: Sendable {
    /// Records a purchase for an item, or answers with the budget warnings and a confirmation token
    /// when the purchase would exceed a budget. Throws `PurchaseError`, or `CancellationError`.
    func createPurchase(
        itemId: String,
        draft: PurchaseDraft,
        confirmationToken: String?
    ) async throws -> PurchaseOutcome
}
