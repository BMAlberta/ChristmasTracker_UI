//
//  OffListPurchaseOption.swift
//  ChristmasTracker
//
//  The pure rules behind the "I already bought this" choice on the Add Item form. The choice is
//  shown only on the Add form, only when the list's capability flags allow an off-list add and a
//  purchase (never a role). While it is on, the price must be a valid amount above zero, and the
//  total (price cents times quantity, in integer cents) must fit the Record Purchase form.
//  Nothing here logs, reports or formats a value into a message.
//

import Foundation

nonisolated enum OffListPurchaseFormMode: Equatable, Sendable {
    case add
    case edit
}

nonisolated struct OffListPurchaseOption: Equatable, Sendable {

    /// The Record Purchase form rejects a cost above 999999.99.
    static let maxTotalCents = 99_999_999

    private let permissions: ItemPermissions
    private let mode: OffListPurchaseFormMode
    private let wantsPurchase: Bool
    private let priceText: String
    private let quantity: Int
    private let locale: Locale

    init(
        capabilities: ListCapabilities,
        mode: OffListPurchaseFormMode,
        wantsPurchase: Bool,
        priceText: String,
        quantity: Int,
        locale: Locale = .current
    ) {
        self.permissions = ItemPermissions(capabilities: capabilities)
        self.mode = mode
        self.wantsPurchase = wantsPurchase
        self.priceText = priceText
        self.quantity = quantity
        self.locale = locale
    }

    // MARK: - Visibility

    var isToggleShown: Bool {
        mode == .add && permissions.showsOffListNotice && permissions.canPurchase
    }

    var isPurchaseRequested: Bool { isToggleShown && wantsPurchase }

    // MARK: - Total

    /// Price cents times quantity, or nil for a missing, zero or invalid price, a quantity outside
    /// 1...999, an overflow, or a total above the cap.
    var totalCents: Int? {
        guard (1...999).contains(quantity),
              let price = ItemFormValidation.parsePrice(priceText),
              price > 0 else { return nil }
        let scaled = NSDecimalNumber(decimal: price * 100)
        guard scaled == scaled.rounding(accordingToBehavior: nil) else { return nil }
        let unitCents = scaled.intValue
        guard unitCents > 0 else { return nil }
        let (total, overflow) = unitCents.multipliedReportingOverflow(by: quantity)
        guard !overflow, total > 0, total <= Self.maxTotalCents else { return nil }
        return total
    }

    /// The total with two decimals and the locale's decimal separator, no grouping.
    var totalText: String? {
        guard let cents = totalCents else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let fraction = cents % 100
        let fractionText = fraction < 10 ? "0" + String(fraction) : String(fraction)
        return String(cents / 100) + separator + fractionText
    }

    // MARK: - Add rule

    /// True when the price rule holds: always when no purchase is requested, otherwise a total exists.
    var priceRequirementMet: Bool {
        !isPurchaseRequested || totalCents != nil
    }

    func allowsAdd(formIsValid: Bool) -> Bool {
        formIsValid && priceRequirementMet
    }

    // MARK: - Starting input

    /// The prefilled Record Purchase input, only when a purchase is requested and the total is known.
    var startingInput: RecordPurchaseFormInput? {
        guard isPurchaseRequested, let text = totalText else { return nil }
        return RecordPurchaseFormInput(
            quantity: quantity,
            totalCostText: text,
            storeName: "",
            notes: "",
            confirmationNumber: "",
            trackingNumber: ""
        )
    }
}
