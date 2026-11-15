//
//  PurchaseHistoryModelInitialTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: the initial state of the model and the preselected recipient.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: initial state", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelInitialTests {

    @Test("A new model is loading, empty and has nothing to show")
    func initialState() async {
        let sut = await makePurchaseHistoryModelSUT()
        let model = sut.model

        #expect(model.filter == PurchaseHistoryFilter(year: 2026, recipientId: nil, shippingStatus: nil))
        #expect(model.defaultYear == 2026)
        #expect(model.rows.isEmpty)
        #expect(model.loadPhase == .loading)
        #expect(!model.isLoadingNextPage)
        #expect(!model.isRefreshing)
        #expect(!model.nextPageFailed)
        #expect(!model.hasActiveFilters)
        #expect(model.emptyKind == nil)
        #expect(model.recipientOptions.isEmpty)
        #expect(model.failureBanner == nil)
        #expect(model.staleBanners.isEmpty)
        #expect(sut.loader.callCount == 0)
    }

    @Test("A preselected recipient is in the filter, counts as an active filter and is the first option")
    func preselected() async {
        let pat = PurchaseHistoryRecipient(id: "user-r9", name: "Pat Nine")
        let sut = await makePurchaseHistoryModelSUT(preselected: pat)

        #expect(sut.model.filter == PurchaseHistoryFilter(year: 2026, recipientId: "user-r9", shippingStatus: nil))
        #expect(sut.model.hasActiveFilters)
        #expect(sut.model.recipientOptions == [pat])
    }

    @Test("The first load uses the initial filter")
    func firstLoadUsesInitialFilter() async {
        let pat = PurchaseHistoryRecipient(id: "user-r9", name: "Pat Nine")
        let sut = await makePurchaseHistoryModelSUT(preselected: pat)
        sut.loader.enqueue(phPage(["a"]))

        await sut.model.onAppear()

        #expect(sut.loader.calls == [.init(filter: sut.model.filter, cursor: nil)])
        #expect(sut.loader.calls.first?.filter.recipientId == "user-r9")
    }
}
