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

    init(itemService: ItemService, listService: ListService) {
        self.itemService = itemService
        self.listService = listService
    }

    func run(_ steps: [PurchaseRefreshStep]) async {
        for step in steps {
            switch step {
            case .itemDetail(let id): await itemService.loadItemDetail(id: id)
            case .itemsRefresh: await itemService.refreshItems()
            case .itemsLoad(let listId): await itemService.loadItems(listId: listId)
            case .listDetail(let id): _ = await listService.refreshListDetail(id: id)
            }
        }
    }
}
