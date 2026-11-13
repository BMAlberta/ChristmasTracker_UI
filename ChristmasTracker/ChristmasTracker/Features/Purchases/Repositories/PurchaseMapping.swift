//
//  PurchaseMapping.swift
//  ChristmasTracker
//
//  Pure mapping from the generated purchase schemas to the purchase domain types. This is the
//  repository boundary: nothing past it sees a generated type. Like ItemMapping.swift these are
//  nonisolated free functions and carry no instrumentation (they neither suspend nor perform I/O).
//  Money goes through the package helper; a value that cannot convert (NaN, infinite) throws
//  `PurchaseError.invalidResponse`.
//

import Foundation
import TrackerAPI

private nonisolated func purchaseMoney(_ value: Double) throws -> Decimal {
    guard let converted = doubleToDecimal(value) else { throw PurchaseError.invalidResponse }
    return converted
}

private nonisolated func mapRecordedShippingStatus(_ status: Components.Schemas.ShippingStatus) -> PurchaseShippingStatus {
    switch status {
    case .notTracked: return .notTracked
    case .notShipped: return .notShipped
    case .shipped: return .shipped
    case .delivered: return .delivered
    }
}

/// The server may send null or an empty string for a cleared optional text field. Both (and a
/// whitespace-only value) mean "none" and map to nil; any other value is kept exactly as received.
private nonisolated func nilIfBlank(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return value
}

nonisolated func mapRecordedPurchase(_ purchase: Components.Schemas.Purchase) throws -> RecordedPurchase {
    RecordedPurchase(
        id: purchase.id,
        itemId: purchase.itemId,
        quantity: purchase.quantity,
        totalCost: try purchaseMoney(purchase.totalCost),
        storeName: purchase.storeName,
        notes: nilIfBlank(purchase.notes),
        confirmationNumber: purchase.confirmationNumber,
        trackingNumber: nilIfBlank(purchase.trackingNumber),
        shippingStatus: mapRecordedShippingStatus(purchase.shippingStatus),
        shippedAt: purchase.shippedAt,
        deliveredAt: purchase.deliveredAt,
        purchaser: mapListItemPerson(purchase.purchaser),
        recipient: mapListItemPerson(purchase.recipient),
        item: PurchaseItemReference(id: purchase.item.id, name: purchase.item.name, listId: purchase.item.listId),
        purchasedAt: purchase.purchasedAt,
        createdAt: purchase.createdAt,
        updatedAt: purchase.updatedAt
    )
}

nonisolated func mapBudgetWarning(_ warning: Components.Schemas.BudgetOverageWarning) throws -> BudgetWarning {
    let details = warning.details
    let level: BudgetWarningLevel
    switch warning.level {
    case .recipient: level = .recipient
    case .total: level = .total
    }
    return BudgetWarning(
        level: level,
        recipientName: level == .recipient ? details.recipientName : nil,
        budgetLimit: try purchaseMoney(details.budgetLimit),
        currentSpent: try purchaseMoney(details.currentSpent),
        purchaseAmount: try purchaseMoney(details.purchaseAmount),
        overage: try purchaseMoney(details.overage)
    )
}

/// The 201 body: it must carry `created`.
nonisolated func mapCreatedOutcome(_ result: Components.Schemas.PurchaseResult) throws -> PurchaseOutcome {
    switch result {
    case .created(let data):
        return .created(try mapRecordedPurchase(data.purchase))
    case .confirmationRequired:
        throw PurchaseError.invalidResponse
    }
}

/// The 200 body. A `confirmation_required` body never becomes `created`; a body that carries
/// `created` maps to `created` because the purchase exists.
nonisolated func mapConfirmationOutcome(
    _ result: Components.Schemas.PurchaseResult,
    warnings: [Components.Schemas.BudgetOverageWarning]
) throws -> PurchaseOutcome {
    switch result {
    case .created(let data):
        return .created(try mapRecordedPurchase(data.purchase))
    case .confirmationRequired:
        guard let token = warnings.map(\.confirmationToken).first(where: { !$0.isEmpty }) else {
            throw PurchaseError.invalidResponse
        }
        let mapped = try warnings.map(mapBudgetWarning)
        return .confirmationRequired(warnings: mapped, token: token)
    }
}
