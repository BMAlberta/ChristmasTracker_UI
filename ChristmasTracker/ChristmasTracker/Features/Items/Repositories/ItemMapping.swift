//
//  ItemMapping.swift
//  ChristmasTracker
//
//  Pure mapping from the generated item schemas to the domain `ListItem`. This is the
//  repository boundary: nothing past it sees a generated type. The mapper is flag-free and
//  never invents a value: an absent updatedAt, purchases or totalQuantityPurchased stays nil.
//  Money goes through the package helper; a value that cannot convert (NaN, infinite) throws
//  `ItemError.invalidResponse`.
//

import Foundation
import TrackerAPI

nonisolated func mapListItemPerson(_ person: Components.Schemas.PersonRef) -> ListItemPerson {
    ListItemPerson(id: person.id, displayName: person.displayName)
}

nonisolated func mapListItemStatus(_ status: Components.Schemas.ItemStatus) -> ItemStatus {
    switch status {
    case .available: return .available
    case .partial: return .partial
    case .purchased: return .purchased
    case .wrapped: return .wrapped
    case .gifted: return .gifted
    }
}

nonisolated func mapListItem(_ item: Components.Schemas.Item) throws -> ListItem {
    try buildListItem(item, purchases: nil, totalQuantityPurchased: nil)
}

nonisolated func mapListItem(_ data: Operations.GetItem.Output.Ok.Body.JsonPayload.DataPayload) throws -> ListItem {
    let purchases = try data.value2.purchases.map { try $0.map(mapListItemPurchase) }
    return try buildListItem(data.value1, purchases: purchases, totalQuantityPurchased: data.value2.totalQuantityPurchased)
}

private nonisolated func buildListItem(
    _ item: Components.Schemas.Item,
    purchases: [ListItemPurchaseSummary]?,
    totalQuantityPurchased: Int?
) throws -> ListItem {
    var price: Decimal?
    if let wirePrice = item.expectedUnitPrice {
        guard let converted = doubleToDecimal(wirePrice) else { throw ItemError.invalidResponse }
        price = converted
    }
    return ListItem(
        id: item.id,
        listId: item.listId,
        name: item.name,
        description: item.description,
        url: item.url,
        imageUrl: item.imageUrl,
        expectedUnitPrice: price,
        quantityRequested: item.quantityRequested,
        priority: item.priority,
        status: mapListItemStatus(item.status),
        offList: item.offList,
        createdBy: mapListItemPerson(item.createdBy),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        purchases: purchases,
        totalQuantityPurchased: totalQuantityPurchased,
        quantityPurchased: item.quantityPurchased,
        quantityRemaining: item.quantityRemaining
    )
}

private nonisolated func mapListItemPurchase(_ purchase: Components.Schemas.PurchaseSummary) throws -> ListItemPurchaseSummary {
    guard let cost = doubleToDecimal(purchase.totalCost) else { throw ItemError.invalidResponse }
    return ListItemPurchaseSummary(
        id: purchase.id,
        quantity: purchase.quantity,
        totalCost: cost,
        purchaser: mapListItemPerson(purchase.purchaser),
        purchasedAt: purchase.purchasedAt
    )
}
