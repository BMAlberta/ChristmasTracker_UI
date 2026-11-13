//
//  PurchaseManagementUpdates.swift
//  ChristmasTracker
//
//  The inputs of changing a purchase: the notes update (updatePurchase carries notes only; it has
//  no tracking member at all) and the shipping update. Both builders are pure and compare after
//  trimming. A notes clear is the empty string on the wire, never null. A tracking number clear is
//  also the empty string on the wire (decision S15); an unchanged tracking number is omitted.
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

/// Decision S15: an empty string clears the tracking number; an omitted field is unchanged.
/// Case order matters: with `.clear` declared after `.set(String)` the compiler (iOS 27.2 simulator
/// toolchain) emitted a retain of a bogus String object when a `.clear` update was copied inside
/// PurchaseService.updateShipping (EXC_BAD_ACCESS). Keep `set` last.
nonisolated enum PurchaseTrackingChange: Equatable, Sendable {
    case unchanged
    case clear
    case set(String)

    /// Pure. The 100-character limit is not applied here (the section state blocks Save).
    static func derive(original: String?, edited: String) -> PurchaseTrackingChange {
        let trimmedOriginal = (original ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEdited = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEdited.isEmpty {
            return trimmedOriginal.isEmpty ? .unchanged : .clear
        }
        return trimmedEdited == trimmedOriginal ? .unchanged : .set(trimmedEdited)
    }
}

/// How an absent or empty stored value is shown: as an empty string. Any other value is unchanged.
nonisolated enum PurchaseEmptyValue {
    static func displayText(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        return value
    }
}

nonisolated struct PurchaseShippingUpdate: Equatable, Sendable {
    let status: PurchaseShippingStatus
    let trackingChange: PurchaseTrackingChange

    /// nil omits the field (unchanged); clear is the empty string, never null.
    var wireTrackingNumber: String? {
        switch trackingChange {
        case .unchanged: return nil
        case .set(let value): return value
        case .clear: return ""
        }
    }

    static func make(
        originalStatus: PurchaseShippingStatus,
        originalTracking: String?,
        editedStatus: PurchaseShippingStatus,
        editedTracking: String
    ) -> PurchaseShippingUpdate? {
        let change = PurchaseTrackingChange.derive(original: originalTracking, edited: editedTracking)
        if originalStatus == editedStatus && change == .unchanged { return nil }
        return PurchaseShippingUpdate(status: editedStatus, trackingChange: change)
    }
}
