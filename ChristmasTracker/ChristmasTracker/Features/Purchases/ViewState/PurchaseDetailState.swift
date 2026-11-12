//
//  PurchaseDetailState.swift
//  ChristmasTracker
//
//  The pure view state of the purchase detail: the read-only core rows (money is Decimal,
//  formatted like the item price text), the fixed texts and the limits. The editable sections live
//  in PurchaseShippingSectionState and PurchaseNotesSectionState.
//

import Foundation

nonisolated struct PurchaseDetailState: Equatable, Sendable {
    static let immutableSentence = "To change the quantity or cost, delete this purchase and record it again."
    static let notesLimit = 1000
    static let trackingLimit = 100
    static let deleteTitle = "Delete this purchase?"
    static let deleteMessage =
        "It will be removed from this item and from your budget, and the remaining quantity will update. This can't be undone."
    static let deleteButtonTitle = "Delete Purchase"

    let itemName: String
    let quantityText: String
    let totalCostText: String
    let storeText: String?
    let purchasedText: String
    let confirmationNumberText: String?

    init(purchase: RecordedPurchase, currencyCode: String = "USD", locale: Locale = Locale(identifier: "en_US")) {
        itemName = purchase.item?.name ?? "This item"
        quantityText = "Quantity: \(purchase.quantity)"
        totalCostText = purchase.totalCost.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale))
        storeText = Self.nonBlank(purchase.storeName)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        purchasedText = formatter.string(from: purchase.purchasedAt)
        confirmationNumberText = Self.nonBlank(purchase.confirmationNumber)
    }

    private static func nonBlank(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

nonisolated struct PurchaseShippingSectionState: Equatable, Sendable {
    private let originalStatus: PurchaseShippingStatus
    private let originalTracking: String?
    let draftStatus: PurchaseShippingStatus
    let draftTracking: String

    init(purchase: RecordedPurchase) {
        originalStatus = purchase.shippingStatus
        originalTracking = purchase.trackingNumber
        draftStatus = purchase.shippingStatus
        draftTracking = purchase.trackingNumber ?? ""
    }

    private init(
        originalStatus: PurchaseShippingStatus,
        originalTracking: String?,
        draftStatus: PurchaseShippingStatus,
        draftTracking: String
    ) {
        self.originalStatus = originalStatus
        self.originalTracking = originalTracking
        self.draftStatus = draftStatus
        self.draftTracking = draftTracking
    }

    /// An omitted argument keeps the current draft value.
    func editing(status: PurchaseShippingStatus? = nil, tracking: String? = nil) -> PurchaseShippingSectionState {
        PurchaseShippingSectionState(
            originalStatus: originalStatus,
            originalTracking: originalTracking,
            draftStatus: status ?? draftStatus,
            draftTracking: tracking ?? draftTracking
        )
    }

    var update: PurchaseShippingUpdate? {
        PurchaseShippingUpdate.make(
            originalStatus: originalStatus,
            originalTracking: originalTracking,
            editedStatus: draftStatus,
            editedTracking: draftTracking
        )
    }

    var trackingTooLong: Bool {
        draftTracking.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > PurchaseDetailState.trackingLimit
    }

    var canSave: Bool { update != nil && !trackingTooLong }

    /// Resets original and draft from a returned purchase.
    func applying(_ purchase: RecordedPurchase) -> PurchaseShippingSectionState {
        PurchaseShippingSectionState(purchase: purchase)
    }
}

nonisolated struct PurchaseNotesSectionState: Equatable, Sendable {
    private let originalNotes: String?
    let draftText: String

    init(purchase: RecordedPurchase) {
        originalNotes = purchase.notes
        draftText = purchase.notes ?? ""
    }

    private init(originalNotes: String?, draftText: String) {
        self.originalNotes = originalNotes
        self.draftText = draftText
    }

    func editing(text: String) -> PurchaseNotesSectionState {
        PurchaseNotesSectionState(originalNotes: originalNotes, draftText: text)
    }

    var update: PurchaseNotesUpdate? {
        PurchaseNotesUpdate.make(original: originalNotes, edited: draftText)
    }

    var tooLong: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > PurchaseDetailState.notesLimit
    }

    var remainingCharacters: Int { PurchaseDetailState.notesLimit - draftText.utf16.count }

    var canSave: Bool { update != nil && !tooLong }

    /// Resets original and draft from a returned purchase.
    func applying(_ purchase: RecordedPurchase) -> PurchaseNotesSectionState {
        PurchaseNotesSectionState(purchase: purchase)
    }
}
