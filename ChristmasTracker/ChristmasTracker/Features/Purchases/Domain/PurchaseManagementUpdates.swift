//
//  PurchaseManagementUpdates.swift
//  ChristmasTracker
//
//  The inputs of changing a purchase: the notes update (updatePurchase carries notes only; it has
//  no tracking member at all) and the shipping update. Both builders are pure and compare after
//  trimming. A notes clear is the empty string on the wire, never null. An empty tracking field is
//  "unchanged" and is never sent: the contract is silent on clearing a tracking number.
//

import Foundation

nonisolated enum PurchaseNotesChange: Equatable, Sendable {
    case unchanged
    case set(String)
    case clear
}

nonisolated struct PurchaseNotesUpdate: Equatable, Sendable {
    let change: PurchaseNotesChange

    /// nil omits the field; clear is the empty string, never null.
    var wireNotes: String? {
        switch change {
        case .unchanged: return nil
        case .set(let text): return text
        case .clear: return ""
        }
    }

    static func make(original: String?, edited: String) -> PurchaseNotesUpdate? {
        let trimmedOriginal = (original ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEdited = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOriginal == trimmedEdited { return nil }
        if trimmedEdited.isEmpty { return PurchaseNotesUpdate(change: .clear) }
        return PurchaseNotesUpdate(change: .set(trimmedEdited))
    }
}

nonisolated struct PurchaseShippingUpdate: Equatable, Sendable {
    let status: PurchaseShippingStatus
    /// nil omits the field (unchanged). Never an empty string.
    let trackingNumber: String?

    static func make(
        originalStatus: PurchaseShippingStatus,
        originalTracking: String?,
        editedStatus: PurchaseShippingStatus,
        editedTracking: String
    ) -> PurchaseShippingUpdate? {
        let trimmedOriginal = (originalTracking ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEdited = editedTracking.trimmingCharacters(in: .whitespacesAndNewlines)
        let trackingChanged = !trimmedEdited.isEmpty && trimmedEdited != trimmedOriginal
        if originalStatus == editedStatus && !trackingChanged { return nil }
        return PurchaseShippingUpdate(status: editedStatus, trackingNumber: trackingChanged ? trimmedEdited : nil)
    }
}
