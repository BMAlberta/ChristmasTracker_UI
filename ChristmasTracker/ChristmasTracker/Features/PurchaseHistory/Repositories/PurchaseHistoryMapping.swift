//
//  PurchaseHistoryMapping.swift
//  ChristmasTracker
//
//  Pure mapping between the purchase history domain types and the generated listPurchases types.
//  This is the repository boundary: nothing past it sees a generated type. The functions are
//  nonisolated, neither suspend nor perform I/O, and carry no instrumentation. The list name, the
//  item image and the page totals of the response are not carried. Money goes through the package
//  helper; a value that cannot convert (NaN, infinite) throws `PurchaseHistoryError.invalidResponse`.
//

import Foundation
import TrackerAPI

/// The query of one page. Unset filters and a nil cursor send nothing; listId and itemId are never sent.
nonisolated func makePurchaseHistoryQuery(
    filter: PurchaseHistoryFilter,
    cursor: String?
) -> Operations.ListPurchases.Input.Query {
    Operations.ListPurchases.Input.Query(
        recipientId: filter.recipientId,
        year: filter.year,
        shippingStatus: filter.shippingStatus.map(wireShippingStatus),
        limit: GeneratedClientPurchaseHistoryRepository.pageLimit,
        cursor: cursor
    )
}

nonisolated private func wireShippingStatus(_ status: PurchaseShippingStatus) -> Components.Schemas.ShippingStatus {
    switch status {
    case .notTracked: return .notTracked
    case .notShipped: return .notShipped
    case .shipped: return .shipped
    case .delivered: return .delivered
    }
}

nonisolated private func domainShippingStatus(_ status: Components.Schemas.ShippingStatus) -> PurchaseShippingStatus {
    switch status {
    case .notTracked: return .notTracked
    case .notShipped: return .notShipped
    case .shipped: return .shipped
    case .delivered: return .delivered
    }
}

nonisolated func mapPurchaseHistoryRow(_ row: Components.Schemas.PurchaseHistoryRow) throws -> PurchaseHistoryRow {
    guard let totalCost = doubleToDecimal(row.totalCost) else { throw PurchaseHistoryError.invalidResponse }
    return PurchaseHistoryRow(
        id: row.id,
        itemId: row.item.id,
        itemName: row.item.name,
        listId: row.list.id,
        recipientId: row.recipient.id,
        recipientName: row.recipient.displayName,
        purchasedAt: row.purchasedAt,
        quantity: row.quantity,
        totalCost: totalCost,
        shippingStatus: domainShippingStatus(row.shippingStatus)
    )
}

nonisolated func mapPurchaseHistoryPage(
    _ payload: Operations.ListPurchases.Output.Ok.Body.JsonPayload
) throws -> PurchaseHistoryPage {
    PurchaseHistoryPage(
        rows: try payload.data.map(mapPurchaseHistoryRow),
        nextCursor: payload.meta.value2.nextCursor
    )
}
