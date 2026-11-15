//
//  PurchaseHistoryModelFilterTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: filter changes and the request token: a result of an old request never lands.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: filters", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelFilterTests {

    @Test("A filter change clears the rows at once and loads the first page of the new filter")
    func clearsRowsImmediately() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["y"]), held: true)
        await sut.model.onAppear()

        let task = sut.start { await $0.select(year: 2025) }
        let call = await sut.nextHeld()

        #expect(call == .init(filter: PurchaseHistoryFilter(year: 2025), cursor: nil))
        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.filter.year == 2025)

        sut.loader.gate.releaseAll()
        await task.value
        #expect(sut.rowIds() == ["y"])
        #expect(sut.model.loadPhase == .content)
    }

    @Test("Selecting nil year, a shipping status and a recipient set the filter and reload")
    func selections() async {
        let sut = await makePurchaseHistoryModelSUT()
        let pat = PurchaseHistoryRecipient(id: "user-r1", name: "Pat Recipient")
        for _ in 0..<4 { sut.loader.enqueue(phPage(["a"])) }
        await sut.model.onAppear()

        await sut.model.select(year: nil)
        await sut.model.select(shipping: .shipped)
        await sut.model.select(recipient: pat)

        #expect(sut.loader.calls.map(\.filter) == [
            PurchaseHistoryFilter(year: 2026),
            PurchaseHistoryFilter(year: nil),
            PurchaseHistoryFilter(year: nil, shippingStatus: .shipped),
            PurchaseHistoryFilter(year: nil, recipientId: "user-r1", shippingStatus: .shipped)
        ])
        #expect(sut.model.recipientOptions.contains(pat))
        #expect(sut.model.hasActiveFilters)
    }

    @Test("A filter change that equals the current filter does not reload")
    func noOpChange() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        await sut.model.onAppear()

        await sut.model.select(year: 2026)
        await sut.model.select(shipping: nil)
        await sut.model.select(recipient: nil)
        await sut.model.clearFilters()

        #expect(sut.loader.callCount == 1)
        #expect(sut.rowIds() == ["a"])
    }

    @Test("clearFilters goes back to the default year with no recipient and no status")
    func clearFilters() async {
        let sut = await makePurchaseHistoryModelSUT()
        for _ in 0..<4 { sut.loader.enqueue(phPage(["a"])) }
        await sut.model.onAppear()
        await sut.model.select(year: nil)
        await sut.model.select(shipping: .delivered)
        #expect(sut.model.hasActiveFilters)

        await sut.model.clearFilters()

        #expect(sut.model.filter == PurchaseHistoryFilter(year: 2026, recipientId: nil, shippingStatus: nil))
        #expect(!sut.model.hasActiveFilters)
        #expect(sut.loader.calls.last?.filter == PurchaseHistoryFilter(year: 2026))
    }

    @Test("clearFilters removes a preselected recipient from the filter but keeps it as an option")
    func clearPreselected() async {
        let pat = PurchaseHistoryRecipient(id: "user-r9", name: "Pat Nine")
        let sut = await makePurchaseHistoryModelSUT(preselected: pat)
        sut.loader.enqueue(phPage([]))
        sut.loader.enqueue(phPage(["a"]))
        await sut.model.onAppear()
        #expect(sut.model.hasActiveFilters)
        #expect(sut.model.emptyKind == .noMatches)

        await sut.model.clearFilters()

        #expect(!sut.model.hasActiveFilters)
        #expect(sut.model.filter.recipientId == nil)
        #expect(sut.model.recipientOptions.first == pat)
    }

    @Test("A first page result of an old filter that arrives after the new one landed changes nothing")
    func oldResultAfterNewLanded() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["old"]), held: true)
        sut.loader.enqueue(phPage(["new"]))
        let first = sut.start { await $0.onAppear() }
        await sut.nextHeld()

        await sut.model.select(year: 2025)
        #expect(sut.rowIds() == ["new"])

        sut.loader.gate.releaseAll()
        await first.value
        #expect(sut.rowIds() == ["new"])
        #expect(sut.model.loadPhase == .content)
    }

    @Test("A first page result of an old filter that arrives while the new one is pending changes nothing")
    func oldResultWhileNewPending() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["old"]), held: true)
        sut.loader.enqueue(phPage(["new"]), held: true)
        let first = sut.start { await $0.onAppear() }
        await sut.nextHeld()
        let second = sut.start { await $0.select(year: 2025) }
        await sut.nextHeld()

        sut.loader.gate.release(at: 0)
        await first.value
        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.loadPhase == .loading)

        sut.loader.gate.release(at: 1)
        await second.value
        #expect(sut.rowIds() == ["new"])
    }

    @Test("A failure of an old filter that arrives late shows nothing")
    func oldFailureDropped() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(PurchaseHistoryError.network, held: true)
        sut.loader.enqueue(phPage(["new"]))
        let first = sut.start { await $0.onAppear() }
        await sut.nextHeld()
        await sut.model.select(year: 2025)

        sut.loader.gate.releaseAll()
        await first.value

        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.model.loadPhase == .content)
        #expect(sut.rowIds() == ["new"])
    }

    @Test("A filter change while a next page is in flight drops that page")
    func filterChangeDropsNextPage() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["late"]), held: true)
        sut.loader.enqueue(phPage(["x"]))
        await sut.model.onAppear()
        let next = sut.start { await $0.loadNextPageIfNeeded(currentRowId: "a") }
        await sut.nextHeld()

        await sut.model.select(shipping: .shipped)
        #expect(!sut.model.isLoadingNextPage)

        sut.loader.gate.releaseAll()
        await next.value
        #expect(sut.rowIds() == ["x"])
        #expect(!sut.model.nextPageFailed)
    }

    @Test("A filter change failure shows the full error because the rows were cleared")
    func filterChangeFailure() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()

        await sut.model.select(year: 2025)

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])
        #expect(sut.model.rows.isEmpty)
    }
}
