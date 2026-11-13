//
//  PurchaseRefreshRunner.swift
//  ChristmasTracker
//
//  Runs the steps of PurchaseRefreshPlan in order against the item and list services. A failed step
//  never throws and never stops the next one: the screens' own banners apply. An item refetch that
//  answers 404 is handled by ItemService itself (it drops the item and sets goneItemId).
//

import Foundation

@MainActor
final class PurchaseRefreshRunner {

    private let itemService: ItemService
    private let listService: ListService

    private let spendingCaches: (any SpendingCacheInvalidating)?

    init(
        itemService: ItemService,
        listService: ListService,
        spendingCaches: (any SpendingCacheInvalidating)? = nil
    ) {
        self.itemService = itemService
        self.listService = listService
        self.spendingCaches = spendingCaches
    }

    func run(_ steps: [PurchaseRefreshStep]) async {
        await run(steps, while: { true })
    }

    /// Asks `shouldContinue` before each step and stops when it answers false.
    func run(_ steps: [PurchaseRefreshStep], while shouldContinue: @MainActor () -> Bool) async {
        for step in steps {
            guard shouldContinue() else { return }
            switch step {
            case .itemDetail(let id): await itemService.loadItemDetail(id: id)
            case .itemsRefresh: await itemService.refreshItems()
            case .itemsLoad(let listId): await itemService.loadItems(listId: listId)
            case .listDetail(let id): _ = await listService.refreshListDetail(id: id)
            case .invalidateSpending: spendingCaches?.markSpendingStale()
            }
        }
    }
}
