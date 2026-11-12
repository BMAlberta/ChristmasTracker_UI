//
//  GiftItemLegacyBridgeTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B (deviation D1): the LEGACY bridge from the new `ListItem` to the old `GiftItem`
//  the purchase screens still take. It is the only Double money path left in the app and is
//  deleted in I4 together with the legacy type. Only the members the Gate 1 addendum names are
//  asserted (id, listId, name, description, quantityRequested, price, updatedAt, purchases,
//  totalQuantityPurchased), because Story D trims the legacy type to what the purchase screens use.
//
//  Fails today because ListItem and ListItem.legacyPurchaseItem do not exist yet.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("GiftItem legacy bridge Tests")
struct GiftItemLegacyBridgeTests {

    // MARK: - Factory

    private func makeSUT(
        price: Decimal? = ItemFixtures.decimal("19.99"),
        updatedAt: Date? = ItemFixtures.updatedDate,
        purchases: [ListItemPurchaseSummary]? = nil,
        totalQuantityPurchased: Int? = nil
    ) -> GiftItem {
        ItemFixtures.item(
            id: "item-9", listId: "list-4", name: "Fake Lamp", description: "A fake lamp",
            url: "https://example.com/lamp", imageUrl: "https://example.com/lamp.png",
            price: price, quantity: 3, priority: 7, status: .partial, offList: true,
            createdBy: ItemFixtures.person(id: "user-5", displayName: "Pat Owner"),
            updatedAt: updatedAt, purchases: purchases, totalQuantityPurchased: totalQuantityPurchased
        ).legacyPurchaseItem
    }

    // MARK: - Mapping

    @Test("Identifying fields carry over")
    func identityFields() {
        let gift = makeSUT()
        #expect(gift.id == "item-9")
        #expect(gift.listId == "list-4")
        #expect(gift.name == "Fake Lamp")
        #expect(gift.description == "A fake lamp")
        #expect(gift.quantityRequested == 3)
    }

    @Test("Price converts through the package helper to the matching Double",
          arguments: [("19.99", 19.99), ("0.10", 0.10), ("1234.50", 1234.5), ("0", 0.0), ("999999.99", 999_999.99)])
    func priceConverts(decimal: String, expected: Double) {
        let gift = makeSUT(price: ItemFixtures.decimal(decimal))
        #expect(gift.expectedUnitPrice == expected)
        #expect(gift.expectedUnitPrice == decimalToDouble(ItemFixtures.decimal(decimal)))
    }

    @Test("A missing price stays nil")
    func nilPrice() {
        #expect(makeSUT(price: nil).expectedUnitPrice == nil)
    }

    @Test("A missing updatedAt falls back to createdAt")
    func updatedAtFallsBackToCreatedAt() {
        #expect(makeSUT(updatedAt: nil).updatedAt == ItemFixtures.createdDate)
    }

    @Test("A present updatedAt is kept")
    func updatedAtKept() {
        #expect(makeSUT(updatedAt: ItemFixtures.updatedDate).updatedAt == ItemFixtures.updatedDate)
    }

    @Test("Purchases are always nil on the legacy item, even when the new item has them")
    func purchasesAlwaysNil() {
        #expect(makeSUT(purchases: nil).purchases == nil)
        #expect(makeSUT(purchases: [ItemFixtures.purchase()], totalQuantityPurchased: 1).purchases == nil)
    }

    @Test("totalQuantityPurchased carries over, nil stays nil")
    func totalQuantityPurchased() {
        #expect(makeSUT(totalQuantityPurchased: 2).totalQuantityPurchased == 2)
        #expect(makeSUT(totalQuantityPurchased: nil).totalQuantityPurchased == nil)
    }
}
