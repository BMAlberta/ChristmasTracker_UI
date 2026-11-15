//
//  PurchaseHistoryModelPagingTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: next page loading: append, stop at no cursor, one request at a time, failure and retry.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: paging", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelPagingTests {

    @Test("The last row loads the next page, appends it and stops when the cursor is nil")
    func appendsAndStops() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueue(phPage(["c"]))
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "b")
        await sut.model.loadNextPageIfNeeded(currentRowId: "c")

        #expect(sut.rowIds() == ["a", "b", "c"])
        #expect(sut.loader.calls.map(\.cursor) == [nil, "c1"])
        #expect(!sut.model.isLoadingNextPage)
    }

    @Test("A row that is not the last row does nothing")
    func notLastRowIgnored() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "a")
        await sut.model.loadNextPageIfNeeded(currentRowId: "unknown")

        #expect(sut.loader.callCount == 1)
    }

    @Test("A second request while one is in flight is ignored")
    func oneAtATime() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueue(phPage(["c"]), held: true)
        await sut.model.onAppear()

        let first = sut.start { await $0.loadNextPageIfNeeded(currentRowId: "b") }
        await sut.nextHeld()
        #expect(sut.model.isLoadingNextPage)

        await sut.model.loadNextPageIfNeeded(currentRowId: "b")
        await sut.model.retryNextPage()
        #expect(sut.loader.callCount == 2)

        sut.loader.gate.releaseAll()
        await first.value
        #expect(sut.rowIds() == ["a", "b", "c"])
        #expect(!sut.model.isLoadingNextPage)
    }

    @Test("Rows are appended without removing duplicates")
    func noDedupe() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueue(phPage(["b", "c"]))
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "b")

        #expect(sut.rowIds() == ["a", "b", "b", "c"])
    }

    @Test("A next page failure keeps the rows, sets the flag, shows no banner and does not retry itself")
    func nextPageFailure() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "b")

        #expect(sut.rowIds() == ["a", "b"])
        #expect(sut.model.nextPageFailed)
        #expect(!sut.model.isLoadingNextPage)
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanners.isEmpty)

        await sut.model.loadNextPageIfNeeded(currentRowId: "b")
        #expect(sut.loader.callCount == 2)
    }

    @Test("retryNextPage asks for the same cursor again and clears the flag on success")
    func retryNextPage() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"], next: "c1"))
        sut.loader.enqueueFailure(PurchaseHistoryError.server)
        sut.loader.enqueue(phPage(["c"]))
        await sut.model.onAppear()
        await sut.model.loadNextPageIfNeeded(currentRowId: "b")

        await sut.model.retryNextPage()

        #expect(sut.loader.calls.map(\.cursor) == [nil, "c1", "c1"])
        #expect(!sut.model.nextPageFailed)
        #expect(sut.rowIds() == ["a", "b", "c"])
    }

    @Test("retryNextPage that fails again sets the flag again")
    func retryFailsAgain() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueueFailure(PurchaseHistoryError.server)
        sut.loader.enqueueFailure(PurchaseHistoryError.server)
        await sut.model.onAppear()
        await sut.model.loadNextPageIfNeeded(currentRowId: "a")

        await sut.model.retryNextPage()

        #expect(sut.model.nextPageFailed)
        #expect(sut.rowIds() == ["a"])
        #expect(sut.loader.callCount == 3)
    }

    @Test("A cancelled next page request sets no flag and can be asked again")
    func nextPageCancellationIsSilent() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueueFailure(CancellationError())
        sut.loader.enqueue(phPage(["b"]))
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "a")
        #expect(!sut.model.nextPageFailed)
        #expect(!sut.model.isLoadingNextPage)

        await sut.model.loadNextPageIfNeeded(currentRowId: "a")
        #expect(sut.rowIds() == ["a", "b"])
    }
}
