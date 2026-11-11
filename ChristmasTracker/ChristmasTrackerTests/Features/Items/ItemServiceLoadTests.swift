//
//  ItemServiceLoadTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: the read side of ItemService (UI rule 2): separate loading flags, a load error
//  that only loads set, the cache, a list change, refresh, and the detail load.
//
//  Rules under test (Gate 1 addendum):
//   - `listLoadError` is set only by loadItems / refreshItems failures and `detailLoadError` only by
//     loadItemDetail failures; each is cleared
//     at the start of its own loads and by `clearListLoadError()` / `clearDetailLoadError()`.
//   - showing the cached items of the same list first is kept; success replaces items,
//     currentListId and the cache; a list change empties `items` and clears `listLoadError` first.
//   - a 404 on the detail load means the item is gone: it is dropped from items / currentItem /
//     the cache, `goneItemId` is set and `detailLoadError` is `.notFound`.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService loading", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceLoadTests {

    private func item(_ id: String, listId: String = "list-1", name: String? = nil) -> ListItem {
        ItemServiceFix.item(id, listId: listId, name: name)
    }

    // MARK: - loadItems

    @Test("loadItems publishes the fetched items, the list id and caches them")
    func loadItemsSuccess() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.currentListId == "list-1")
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.isLoadingItems == false)
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-1"), item("item-2")])
    }

    @Test("isLoadingItems is true only while the fetch is in flight, and no other flag moves")
    func loadItemsFlag() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isLoadingItems == true)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isMutating == false)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("loadItems failure sets listLoadError to the typed error and leaves no items", arguments: [
        ItemError.forbidden, .notFound, .network, .server, .rateLimited(retryAfter: 3), .invalidResponse
    ])
    func loadItemsFailure(error: ItemError) async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(error))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.listLoadError == error)
        #expect(sut.service.items.isEmpty)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("a new load clears the previous listLoadError at its start")
    func newLoadClearsListLoadError() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.network))
        await sut.service.loadItems(listId: "list-1")
        #expect(sut.service.listLoadError == .network, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.listLoadError == nil, "cleared as soon as the new load starts, not only when it succeeds")

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.items == [item("item-1")])
    }

    @Test("clearDetailLoadError clears the detail load error and nothing else")
    func clearDetailLoadError() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.server))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .server, "precondition")

        sut.service.clearDetailLoadError()

        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.currentListId == "list-1")
        #expect(sut.service.goneItemId == nil)
    }

    @Test("a load that fails again replaces the previous listLoadError")
    func secondFailureReplaces() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.network))
        sut.repo.enqueueFetchItems(.failure(ItemError.forbidden))

        await sut.service.loadItems(listId: "list-1")
        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.listLoadError == .forbidden)
    }

    // MARK: - Cache

    @Test("a fresh cache for the list is shown without calling the repository")
    func freshCacheIsShown() async {
        let sut = await makeItemServiceSUT()
        await sut.store.setItems([item("item-1"), item("item-2")], listId: "list-1")

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.currentListId == "list-1")
        #expect(sut.repo.fetchItemsCount == 0)
        #expect(sut.service.isLoadingItems == false)
        #expect(sut.service.listLoadError == nil)
    }

    @Test("a second load of the same list is served from the cache")
    func secondLoadUsesCache() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))

        await sut.service.loadItems(listId: "list-1")
        await sut.service.loadItems(listId: "list-1")

        #expect(sut.repo.fetchItemsCount == 1)
        #expect(sut.service.items == [item("item-1")])
    }

    @Test("the cache of another list is never shown")
    func otherListCacheNotShown() async {
        let sut = await makeItemServiceSUT()
        await sut.store.setItems([item("item-a", listId: "list-a")], listId: "list-a")
        sut.repo.enqueueFetchItems(.success([item("item-b", listId: "list-b")]))

        await sut.service.loadItems(listId: "list-b")

        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.repo.fetchedListIds == ["list-b"])
    }

    // MARK: - List change

    @Test("a list change empties items and clears listLoadError before the new load finishes")
    func listChangeEmptiesItemsAndListLoadError() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-a", listId: "list-a")]))
        await sut.service.loadItems(listId: "list-a")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-a")
        #expect(sut.service.detailLoadError == .network, "precondition")
        #expect(sut.service.items.isEmpty == false, "precondition")
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.refreshItems()
        #expect(sut.service.listLoadError == .server, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-b", listId: "list-b")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-b") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.items.isEmpty, "list A's items must never show under list B")
        #expect(sut.service.listLoadError == nil)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.service.currentListId == "list-b")
    }

    @Test("a list change whose load fails leaves the new list with no items and the new error")
    func listChangeFailure() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-a", listId: "list-a")]))
        await sut.service.loadItems(listId: "list-a")
        sut.repo.enqueueFetchItems(.failure(ItemError.forbidden))

        await sut.service.loadItems(listId: "list-b")

        #expect(sut.service.items.isEmpty)
        #expect(sut.service.listLoadError == .forbidden)
    }

    // MARK: - refreshItems

    @Test("refreshItems refetches the current list and replaces items and cache")
    func refreshReplaces() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))

        await sut.service.refreshItems()

        #expect(sut.repo.fetchedListIds == ["list-1", "list-1"])
        #expect(sut.service.items == [item("item-1"), item("item-2")])
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-1"), item("item-2")])
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("refreshItems without a current list does nothing")
    func refreshWithoutList() async {
        let sut = await makeItemServiceSUT()

        await sut.service.refreshItems()

        #expect(sut.repo.fetchItemsCount == 0)
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("refreshItems sets isLoadingItems while in flight and clears the old listLoadError at its start")
    func refreshFlagAndErrorClear() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.refreshItems()
        #expect(sut.service.listLoadError == .server, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.refreshItems() }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isLoadingItems == true)
        #expect(sut.service.listLoadError == nil)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("refreshItems failure sets listLoadError")
    func refreshFailure() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItems(.failure(ItemError.rateLimited(retryAfter: 2)))

        await sut.service.refreshItems()

        #expect(sut.service.listLoadError == .rateLimited(retryAfter: 2))
        #expect(sut.service.isLoadingItems == false)
    }

    // MARK: - loadItemDetail

    @Test("loadItemDetail publishes currentItem; isLoadingDetail is true only while in flight")
    func detailSuccess() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.success(item("item-1", name: "Detail")), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isLoadingDetail == true)
        #expect(sut.service.isLoadingItems == false)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.currentItem == item("item-1", name: "Detail"))
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.repo.detailIds == ["item-1"])
    }

    @Test("loadItemDetail failure sets detailLoadError (it does not throw) and publishes no item", arguments: [
        ItemError.forbidden, .network, .server, .invalidResponse
    ])
    func detailFailure(error: ItemError) async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.failure(error))

        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.detailLoadError == error)
        #expect(sut.service.currentItem == nil)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.goneItemId == nil)
    }

    @Test("loadItemDetail clears the previous detailLoadError at its start")
    func detailClearsDetailLoadError() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .network, "precondition")
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.detailLoadError == nil)

        sut.repo.gate.releaseAll()
        await task.value
    }

    @Test("a 404 on the detail load means gone: dropped from items, currentItem and cache, goneItemId set, detailLoadError notFound")
    func detailNotFoundDropsItem() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.currentItem != nil, "precondition")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.notFound))

        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.detailLoadError == .notFound)
        #expect(sut.service.goneItemId == "item-1")
        #expect(sut.service.currentItem == nil)
        #expect(sut.service.items == [item("item-2")])
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-2")])
    }

    @Test("clearItemDetail empties currentItem only")
    func clearItemDetail() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")))
        await sut.service.loadItemDetail(id: "item-1")

        sut.service.clearItemDetail()

        #expect(sut.service.currentItem == nil)
        #expect(sut.service.items == [item("item-1")])
    }

    @Test("clearItems empties the items and the current list id")
    func clearItems() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        await sut.service.loadItems(listId: "list-1")

        sut.service.clearItems()

        #expect(sut.service.items.isEmpty)
        #expect(sut.service.currentListId == nil)
    }

    // MARK: - Initial state

    @Test("a new service is idle: no items, no flags, no errors")
    func initialState() async {
        let sut = await makeItemServiceSUT()

        #expect(sut.service.items.isEmpty)
        #expect(sut.service.currentListId == nil)
        #expect(sut.service.currentItem == nil)
        #expect(sut.service.isLoadingItems == false)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.goneItemId == nil)
    }
}
