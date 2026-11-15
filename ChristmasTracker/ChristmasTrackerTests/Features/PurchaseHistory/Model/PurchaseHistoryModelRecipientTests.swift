//
//  PurchaseHistoryModelRecipientTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: the accumulating recipient options of the recipient filter.
//

import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: recipient options", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelRecipientTests {

    private static let pat = PurchaseHistoryRecipient(id: "user-r1", name: "Pat Recipient")
    private static let sam = PurchaseHistoryRecipient(id: "user-r2", name: "Sam Recipient")

    private func rows(_ pairs: [(String, PurchaseHistoryRecipient)]) -> PurchaseHistoryPage {
        PurchaseHistoryFix.page(pairs.map {
            PurchaseHistoryFix.row(id: $0.0, recipientId: $0.1.id, recipientName: $0.1.name)
        })
    }

    @Test("Options are deduplicated and in the order of first sighting")
    func dedupedInOrder() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(rows([("a", Self.sam), ("b", Self.pat), ("c", Self.sam)]))

        await sut.model.onAppear()

        #expect(sut.model.recipientOptions == [Self.sam, Self.pat])
    }

    @Test("Options accumulate over the next page and keep their order")
    func accumulateAcrossPages() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(PurchaseHistoryPage(
            rows: [PurchaseHistoryFix.row(id: "a", recipientId: Self.pat.id, recipientName: Self.pat.name)],
            nextCursor: "c1"
        ))
        sut.loader.enqueue(rows([("b", Self.sam), ("c", Self.pat)]))
        await sut.model.onAppear()

        await sut.model.loadNextPageIfNeeded(currentRowId: "a")

        #expect(sut.model.recipientOptions == [Self.pat, Self.sam])
    }

    @Test("The preselected recipient is first, is kept with no rows and is not duplicated")
    func preselectedFirst() async {
        let sut = await makePurchaseHistoryModelSUT(preselected: Self.sam)
        sut.loader.enqueue(PurchaseHistoryFix.page([]))
        await sut.model.onAppear()
        #expect(sut.model.recipientOptions == [Self.sam])

        sut.loader.enqueue(rows([("a", Self.pat), ("b", Self.sam)]))
        await sut.model.refresh()
        #expect(sut.model.recipientOptions == [Self.sam, Self.pat])
    }

    @Test("Options survive a filter change and the selected recipient is always listed")
    func surviveFilterChange() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(rows([("a", Self.pat), ("b", Self.sam)]))
        sut.loader.enqueue(rows([("b", Self.sam)]))
        sut.loader.enqueue(rows([]))
        await sut.model.onAppear()

        await sut.model.select(recipient: Self.sam)
        #expect(sut.model.recipientOptions == [Self.pat, Self.sam])

        await sut.model.select(shipping: .delivered)
        #expect(sut.model.recipientOptions == [Self.pat, Self.sam])
        #expect(sut.model.filter.recipientId == Self.sam.id)
    }

    @Test("Selecting a recipient that was never seen adds it to the options")
    func selectedIsListed() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([]))

        await sut.model.select(recipient: Self.pat)

        #expect(sut.model.recipientOptions == [Self.pat])
    }
}
