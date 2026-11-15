//
//  PurchaseHistoryModelSessionTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: a session end leaves no purchase data in the model and drops late results.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: session", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelSessionTests {

    @Test("A session end during the first load leaves no rows and no banner")
    func sessionEndDuringLoad() async throws {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]), held: true)
        let task = sut.start { await $0.onAppear() }
        await sut.nextHeld()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanners.isEmpty)
        #expect(!sut.model.isRefreshing)
    }

    @Test("A next page result that arrives after the session ended changes nothing")
    func lateNextPageAfterSessionEnd() async throws {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["late"]), held: true)
        await sut.model.onAppear()
        let task = sut.start { await $0.loadNextPageIfNeeded(currentRowId: "a") }
        await sut.nextHeld()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.model.rows.isEmpty)
        #expect(!sut.model.nextPageFailed)
        #expect(!sut.model.isLoadingNextPage)
        #expect(sut.model.failureBanner == nil)
    }

    @Test("A failure that arrives after the session ended shows nothing")
    func lateFailureAfterSessionEnd() async throws {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.network, held: true)
        await sut.model.onAppear()
        let task = sut.start { await $0.refresh() }
        await sut.nextHeld()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.model.failureBanner == nil)
    }

    @Test("reconcileSession resets a loaded model to the initial state")
    func reconcileResets() async throws {
        let pat = PurchaseHistoryRecipient(id: "user-r9", name: "Pat Nine")
        let sut = await makePurchaseHistoryModelSUT(preselected: pat)
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["b"]))
        await sut.model.onAppear()
        await sut.model.select(year: 2025)
        #expect(sut.model.recipientOptions.count == 2)

        try await sut.service.clearForSession()
        sut.model.reconcileSession()

        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.filter == PurchaseHistoryFilter(year: 2026, recipientId: "user-r9", shippingStatus: nil))
        #expect(sut.model.recipientOptions == [pat])
        #expect(sut.model.emptyKind == nil)
        #expect(!sut.model.nextPageFailed)
    }

    @Test("A model reused after a session change starts from the initial state")
    func reusedModelStartsFresh() async throws {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"], next: "c1"))
        sut.loader.enqueue(phPage(["b"]))
        sut.loader.enqueue(phPage(["fresh"]))
        await sut.model.onAppear()
        await sut.model.select(shipping: .shipped)

        try await sut.service.clearForSession()
        await sut.model.onAppear()

        #expect(sut.rowIds() == ["fresh"])
        #expect(sut.model.filter == PurchaseHistoryFilter(year: 2026))
        #expect(sut.loader.calls.last == .init(filter: PurchaseHistoryFilter(year: 2026), cursor: nil))
    }
}
