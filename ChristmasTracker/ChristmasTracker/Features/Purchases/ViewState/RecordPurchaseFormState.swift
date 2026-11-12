//
//  RecordPurchaseFormState.swift
//  ChristmasTracker
//
//  The pure validity rules of the record-purchase form. Money is Decimal end to end: the cost
//  text is parsed to an exact Decimal and the unit cost is a Decimal division, never a Double.
//  The over-purchase prompt is advisory and never affects validity or the draft.
//

import Foundation

nonisolated struct RecordPurchaseFormInput: Equatable, Sendable {
    var quantity: Int
    var totalCostText: String
    var storeName: String
    var notes: String
    var confirmationNumber: String
    var trackingNumber: String
}

nonisolated struct OverPurchasePrompt: Equatable, Sendable {
    let title: String
    let message: String
    let confirmButtonTitle: String
}

nonisolated struct RecordPurchaseFormState: Equatable, Sendable {
    private static let storeNameLimit = 200
    private static let notesLimit = 1000
    private static let confirmationNumberLimit = 100
    private static let trackingNumberLimit = 100
    private static let maximumCost = Decimal(string: "999999.99", locale: Locale(identifier: "en_US_POSIX"))

    /// quantity < 1 (the generated schema has a minimum of 1 and no maximum)
    let quantityInvalid: Bool
    /// The text is empty or not a valid cost.
    let totalCostInvalid: Bool
    let storeNameInvalid: Bool
    let notesInvalid: Bool
    let confirmationNumberInvalid: Bool
    let trackingNumberInvalid: Bool
    /// Nil unless the form is valid. The optional strings are trimmed and nil when blank.
    let draft: PurchaseDraft?
    /// The currency text of totalCost / quantity (rounded to two places); nil unless valid.
    let unitCostText: String?
    let overPurchasePrompt: OverPurchasePrompt?

    var isValid: Bool {
        !quantityInvalid && !totalCostInvalid && !storeNameInvalid && !notesInvalid
            && !confirmationNumberInvalid && !trackingNumberInvalid
    }

    init(
        input: RecordPurchaseFormInput,
        quantityRemaining: Int?,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) {
        let store = input.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmation = input.confirmationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let tracking = input.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cost = Self.parseTotalCost(input.totalCostText, locale: locale)

        quantityInvalid = input.quantity < 1
        totalCostInvalid = cost == nil
        storeNameInvalid = store.count > Self.storeNameLimit
        notesInvalid = notes.count > Self.notesLimit
        confirmationNumberInvalid = confirmation.count > Self.confirmationNumberLimit
        trackingNumberInvalid = tracking.count > Self.trackingNumberLimit

        let valid = !quantityInvalid && !totalCostInvalid && !storeNameInvalid && !notesInvalid
            && !confirmationNumberInvalid && !trackingNumberInvalid
        if valid, let cost {
            draft = PurchaseDraft(
                quantity: input.quantity,
                totalCost: cost,
                storeName: store.isEmpty ? nil : store,
                notes: notes.isEmpty ? nil : notes,
                confirmationNumber: confirmation.isEmpty ? nil : confirmation,
                trackingNumber: tracking.isEmpty ? nil : tracking
            )
            let unit = Self.unitCost(total: cost, quantity: input.quantity)
            unitCostText = unit.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale))
            overPurchasePrompt = Self.prompt(quantity: input.quantity, remaining: quantityRemaining)
        } else {
            draft = nil
            unitCostText = nil
            overPurchasePrompt = nil
        }
    }

    /// max(1, remaining) when the remaining quantity is known and above zero, else 1.
    static func defaultQuantity(quantityRemaining: Int?) -> Int {
        guard let quantityRemaining, quantityRemaining > 0 else { return 1 }
        return max(1, quantityRemaining)
    }

    /// Parses the typed total cost. The text is trimmed and may hold only ASCII digits and the
    /// locale's decimal separator: grouping separators, signs, exponents, currency symbols and
    /// any other character are rejected. At most two fraction digits; the value must be above 0
    /// and at most 999999.99. The result is exact (no Double on the way).
    static func parseTotalCost(_ text: String, locale: Locale) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Character(locale.decimalSeparator ?? ".")
        let parts = trimmed.split(separator: separator, maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        let whole = parts[0]
        let fraction = parts.count == 2 ? parts[1] : ""
        let isDigits: (Substring) -> Bool = { $0.allSatisfy { ("0"..."9").contains($0) } }
        guard !whole.isEmpty, isDigits(whole), isDigits(fraction) else { return nil }
        guard fraction.count <= 2, parts.count == 1 || !fraction.isEmpty else { return nil }
        let canonical = fraction.isEmpty ? String(whole) : "\(whole).\(fraction)"
        guard let value = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")),
              let maximum = maximumCost,
              value > 0, value <= maximum else { return nil }
        return value
    }

    private static func unitCost(total: Decimal, quantity: Int) -> Decimal {
        var divided = total / Decimal(quantity)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &divided, 2, .plain)
        return rounded
    }

    private static func prompt(quantity: Int, remaining: Int?) -> OverPurchasePrompt? {
        guard let remaining, quantity > remaining else { return nil }
        let message = remaining > 0
            ? "Only \(remaining) remaining. You're recording \(quantity)."
            : "This item has already been fully purchased, and others may have bought it too."
        return OverPurchasePrompt(title: "Record anyway?", message: message, confirmButtonTitle: "Continue Anyway")
    }
}
