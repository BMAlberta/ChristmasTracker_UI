//
//  RecordPurchaseItemSummaryTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (c): the item summary at the top of the Record Purchase form.
//
//  Rules under test: "N remaining" only when canSeeGiftActivity AND the server sent
//  quantityRemaining (never computed from the requested quantity or from purchases); zero is
//  shown; an absent value shows nothing; there is NO already-purchased member or text, even when
//  the item carries purchases and a totalQuantityPurchased.
//
//  Fails today because RecordPurchaseItemSummary does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase item summary Tests")
struct RecordPurchaseItemSummaryTests {

    private func makeSUT(
        _ item: ListItem,
        capabilities: ListCapabilities = RecordPurchaseTestCaps.buyer,
        locale: Locale = Locale(identifier: "en_US")
    ) -> RecordPurchaseItemSummary {
        RecordPurchaseItemSummary(item: item, capabilities: capabilities, currencyCode: "USD", locale: locale)
    }

    @Test("Name and requested text")
    func nameAndRequested() {
        let sut = makeSUT(ItemFixtures.item(name: "Fake Lamp", quantity: 4))
        #expect(sut.name == "Fake Lamp")
        #expect(sut.requestedText == "Requested: 4")
    }

    @Test("Remaining is shown from the server's quantityRemaining", arguments: [1, 2, 7])
    func remainingPresent(remaining: Int) {
        let sut = makeSUT(ItemFixtures.item(quantity: 9, quantityRemaining: remaining))
        #expect(sut.remainingText == "\(remaining) remaining")
    }

    @Test("Zero remaining is shown as 0 remaining, not hidden")
    func remainingZero() {
        let sut = makeSUT(ItemFixtures.item(quantity: 2, quantityPurchased: 2, quantityRemaining: 0))
        #expect(sut.remainingText == "0 remaining")
    }

    @Test("An absent quantityRemaining shows nothing and is never computed from the other fields")
    func remainingAbsent() {
        let item = ItemFixtures.item(
            quantity: 5, purchases: [ItemFixtures.purchase(quantity: 2)], totalQuantityPurchased: 2,
            quantityPurchased: 2, quantityRemaining: nil
        )
        #expect(makeSUT(item).remainingText == nil)
    }

    @Test("Without gift activity the remaining text is hidden even if the value slipped through")
    func remainingHiddenWithoutActivity() {
        let item = ItemFixtures.item(quantity: 5, quantityPurchased: 3, quantityRemaining: 2)
        #expect(makeSUT(item, capabilities: RecordPurchaseTestCaps.buyerWithoutActivity).remainingText == nil)
    }

    @Test("The expected price is formatted from the Decimal, and nil when the item has none")
    func priceText() {
        #expect(makeSUT(ItemFixtures.item(price: ItemFixtures.decimal("1234.50"))).expectedPriceText == "$1,234.50")
        #expect(makeSUT(ItemFixtures.item(price: ItemFixtures.decimal("0.10"))).expectedPriceText == "$0.10")
        #expect(makeSUT(ItemFixtures.item(price: nil)).expectedPriceText == nil)
    }

    @Test("There is no already-purchased member and no text that mentions purchases")
    func noAlreadyPurchased() {
        let item = ItemFixtures.item(
            name: "Fake Lamp", price: ItemFixtures.decimal("19.99"), quantity: 5,
            status: .partial,
            purchases: [ItemFixtures.purchase(id: "p-1", quantity: 2)], totalQuantityPurchased: 2,
            quantityPurchased: 2, quantityRemaining: 3
        )
        let sut = makeSUT(item)

        let labels = Set(Mirror(reflecting: sut).children.compactMap(\.label))
        #expect(labels == ["name", "requestedText", "remainingText", "expectedPriceText"])

        let texts = [sut.name, sut.requestedText, sut.remainingText, sut.expectedPriceText].compactMap { $0 }
        for text in texts {
            #expect(!text.lowercased().contains("purchased"), "\(text)")
            #expect(!text.lowercased().contains("bought"), "\(text)")
        }
    }

    @Test("The summary does not depend on the item status (no status is inferred)", arguments: [
        ItemStatus.available, .partial, .purchased, .wrapped, .gifted
    ])
    func independentOfStatus(status: ItemStatus) {
        let sut = makeSUT(ItemFixtures.item(quantity: 4, status: status, quantityRemaining: 1))
        #expect(sut.remainingText == "1 remaining")
        #expect(sut.requestedText == "Requested: 4")
    }
}
