//
//  ItemServiceForcedRefreshTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-F2: the list screen's pull to refresh must really fetch. loadItems stays
//  cache-first (a fresh non-empty cache performs no fetch); refreshItems always fetches inside
//  the same cache window, reports a failure through listLoadError and keeps the cached items.
//
//  Determinism: the counting fetch counters of GatedItemRepository. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService forced refresh", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceForcedRefreshTests {

    private func item(_ id: String, name: String? = nil) -> ListItem {
        ItemServiceFix.item(id, name: name)
    }

    /// list-1 is loaded once (one fetch) so its cache is fresh and non-empty.
    private func makeLoadedSUT() async -> ItemServiceSUT {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))
        await sut.service.loadItems(listId: "list-1")
        return sut
    }

    // MARK: - Cache-first stays

    @Test("loadItems with a fresh non-empty cache performs no fetch")
    func loadItemsIsCacheFirst() async {
        let sut = await makeLoadedSUT()
        #expect(sut.repo.fetchItemsCount == 1, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-9")]))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.repo.fetchItemsCount == 1, "a fresh cache is served without a fetch")
        #expect(sut.service.items.map(\.id) == ["item-1", "item-2"])
    }

    // MARK: - Forced refresh

    @Test("refreshItems performs a fetch inside the same cache window")
    func refreshItemsFetchesInsideCacheWindow() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2"), item("item-3")]))

        await sut.service.loadItems(listId: "list-1")
        #expect(sut.repo.fetchItemsCount == 1, "precondition: still inside the cache window")
        await sut.service.refreshItems()

        #expect(sut.repo.fetchItemsCount == 2)
        #expect(sut.repo.fetchedListIds == ["list-1", "list-1"])
        #expect(sut.service.items.map(\.id) == ["item-1", "item-2", "item-3"])
    }

    @Test("a refresh updates the cache, so the next cache-first load serves the refreshed items")
    func refreshUpdatesCache() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.success([item("item-7")]))
        await sut.service.refreshItems()

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.repo.fetchItemsCount == 2, "the load after the refresh was served from the cache")
        #expect(sut.service.items.map(\.id) == ["item-7"])
    }

    @Test("every refresh fetches again")
    func repeatedRefreshFetchesEachTime() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        sut.repo.enqueueFetchItems(.success([item("item-1")]))

        await sut.service.refreshItems()
        await sut.service.refreshItems()

        #expect(sut.repo.fetchItemsCount == 3)
    }

    // MARK: - Failure and recovery

    @Test("a failed refreshItems sets listLoadError and keeps the cached items", arguments: [
        ItemError.network, .server, .rateLimited(retryAfter: 5)
    ])
    func failedRefreshKeepsItems(error: ItemError) async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(error))

        await sut.service.refreshItems()

        #expect(sut.service.listLoadError == error)
        #expect(sut.service.items.map(\.id) == ["item-1", "item-2"])
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached.map(\.id) == ["item-1", "item-2"])
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("a successful refreshItems clears a previous listLoadError")
    func successfulRefreshClearsError() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.network))
        await sut.service.refreshItems()
        #expect(sut.service.listLoadError == .network, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-5")]))

        await sut.service.refreshItems()

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.items.map(\.id) == ["item-1", "item-5"])
    }

    @Test("a refresh that is retried after a failure fetches again and recovers")
    func retryAfterFailureRecovers() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        sut.repo.enqueueFetchItems(.success([item("item-4")]))

        await sut.service.refreshItems()
        await sut.service.refreshItems()

        #expect(sut.repo.fetchItemsCount == 3)
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.items.map(\.id) == ["item-4"])
    }
}
