//
//  PurchaseHistoryModelRefreshTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: pull to refresh and the return from a purchase: rows are replaced, a failure keeps them
//  under the stale banner.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: refresh", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelRefreshTests {

    private static let staleText = "Couldn't update. Showing saved data."

    @Test("Refresh replaces the rows: a deleted purchase disappears and a changed shipping status updates")
    func replacesRows() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([
            PurchaseHistoryFix.row(id: "a"),
            PurchaseHistoryFix.row(id: "b", shippingStatus: .notShipped)
        ], nextCursor: "c1"))
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "b", shippingStatus: .shipped)]))
        await sut.model.onAppear()

        await sut.model.refresh()

        #expect(sut.rowIds() == ["b"])
        #expect(sut.model.rows.first?.shippingStatus == .shipped)
        #expect(sut.loader.calls.map(\.cursor) == [nil, nil])
        await sut.model.loadNextPageIfNeeded(currentRowId: "b")
        #expect(sut.loader.callCount == 2, "the refreshed page had no cursor")
    }

    @Test("Refresh keeps the old rows until the new first page lands")
    func keepsRowsWhileRefreshing() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"]))
        sut.loader.enqueue(phPage(["x"]), held: true)
        await sut.model.onAppear()

        let task = sut.start { await $0.refresh() }
        await sut.nextHeld()
        #expect(sut.model.isRefreshing)
        #expect(sut.rowIds() == ["a", "b"])
        #expect(sut.model.loadPhase == .content)

        sut.loader.gate.releaseAll()
        await task.value
        #expect(sut.rowIds() == ["x"])
        #expect(!sut.model.isRefreshing)
    }

    @Test("A refresh failure keeps the rows and shows exactly the stale text")
    func refreshFailureKeepsRows() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()

        await sut.model.refresh()

        #expect(sut.rowIds() == ["a", "b"])
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.staleBanners.map(\.message) == [Self.staleText])
        #expect(sut.model.staleBanners.first?.actions == [.tryAgain, .dismiss])
        #expect(sut.model.failureBanner == nil)
        #expect(!sut.model.isRefreshing)
    }

    @Test("The stale banner can be dismissed and a new failure shows it again")
    func dismissStaleBanner() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()
        await sut.model.refresh()

        sut.model.dismissStaleBanner()
        #expect(sut.model.staleBanners.isEmpty)

        await sut.model.refresh()
        #expect(sut.model.staleBanners.map(\.message) == [Self.staleText])
    }

    @Test("Try Again from the stale banner reloads and removes it")
    func staleTryAgain() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        sut.loader.enqueue(phPage(["a", "n"]))
        await sut.model.onAppear()
        await sut.model.refresh()

        await sut.model.tryAgain()

        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.rowIds() == ["a", "n"])
    }

    @Test("A refresh failure with no rows behaves like a first page failure")
    func refreshFailureWithoutRows() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage([]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()

        await sut.model.refresh()

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])
        #expect(sut.model.staleBanners.isEmpty)
    }

    @Test("A cancelled refresh changes nothing and shows nothing")
    func refreshCancellationIsSilent() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(CancellationError())
        await sut.model.onAppear()

        await sut.model.refresh()

        #expect(sut.rowIds() == ["a"])
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.model.failureBanner == nil)
        #expect(!sut.model.isRefreshing)
    }

    @Test("A refresh over a refresh drops the older result")
    func refreshOverRefresh() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueue(phPage(["older"]), held: true)
        sut.loader.enqueue(phPage(["newer"]))
        await sut.model.onAppear()
        let older = sut.start { await $0.refresh() }
        await sut.nextHeld()

        await sut.model.refresh()
        #expect(sut.rowIds() == ["newer"])

        sut.loader.gate.releaseAll()
        await older.value
        #expect(sut.rowIds() == ["newer"])
        #expect(!sut.model.isRefreshing)
    }

    @Test("Returning from a purchase reloads the first page")
    func returnedFromPurchase() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueue(phPage(["b"]))
        await sut.model.onAppear()

        await sut.model.returnedFromPurchase()

        #expect(sut.loader.calls.map(\.cursor) == [nil, nil])
        #expect(sut.rowIds() == ["b"])
    }

    @Test("A refresh while a next page is in flight drops that page")
    func refreshDuringNextPage() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["late"]), held: true)
        sut.loader.enqueue(phPage(["z"]))
        await sut.model.onAppear()
        let next = sut.start { await $0.loadNextPageIfNeeded(currentRowId: "a") }
        await sut.nextHeld()

        await sut.model.refresh()
        #expect(sut.rowIds() == ["z"])
        #expect(!sut.model.isLoadingNextPage)

        sut.loader.gate.releaseAll()
        await next.value
        #expect(sut.rowIds() == ["z"])
        #expect(!sut.model.nextPageFailed)
        #expect(!sut.model.isLoadingNextPage)
    }
}
