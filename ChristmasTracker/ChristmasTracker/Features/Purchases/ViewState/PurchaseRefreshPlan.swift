//
//  PurchaseRefreshPlan.swift
//  ChristmasTracker
//
//  The refreshes that follow a recorded purchase, as a pure list. It carries ids only: no count,
//  no status and no quantity, and it never infers any (the server decides what changed).
//

import Foundation

nonisolated enum PurchaseRefreshStep: Equatable, Sendable {
    /// itemService.loadItemDetail(id:)
    case itemDetail(id: String)
    /// itemService.refreshItems(); the item service already holds this list.
    case itemsRefresh
    /// itemService.loadItems(listId:); the item service holds another list or none.
    case itemsLoad(listId: String)
    /// listService.refreshListDetail(id:)
    case listDetail(id: String)
    /// Marks the stats and budget caches stale (spending changed). Always the last step.
    case invalidateSpending
}

nonisolated enum PurchaseRefreshPlan {
    /// Always four steps in this order: the item detail, then the items (refresh in place or
    /// load, the same choice as the list detail refresh), then the list detail, then the spending
    /// cache invalidation.
    static func steps(itemId: String, listId: String, currentItemsListId: String?) -> [PurchaseRefreshStep] {
        let itemsStep: PurchaseRefreshStep = currentItemsListId == listId ? .itemsRefresh : .itemsLoad(listId: listId)
        return [.itemDetail(id: itemId), itemsStep, .listDetail(id: listId), .invalidateSpending]
    }

    /// After deleting a purchase the refreshes are exactly the ones after recording one.
    static func stepsAfterDelete(itemId: String, listId: String, currentItemsListId: String?) -> [PurchaseRefreshStep] {
        steps(itemId: itemId, listId: listId, currentItemsListId: currentItemsListId)
    }
}
