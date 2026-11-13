//
//  PurchaseMappingClearTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-B (S15): the pure mapping `mapRecordedPurchase` normalizes `trackingNumber` and `notes`:
//  nil, "" and a whitespace-only value become nil; any other value is kept as received (not trimmed).
//  No other field changes.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Purchase mapping of cleared fields")
struct PurchaseMappingClearTests {

    @Test("trackingNumber: nil, empty and blank map to nil; a value is kept as received",
          arguments: [
        (String?.none, String?.none), ("", nil), (" ", nil), ("   ", nil), ("\n\t ", nil),
        ("TRK-FAKE-1", "TRK-FAKE-1"), (" TRK-FAKE-1 ", " TRK-FAKE-1 ")
    ])
    func trackingNumber(pair: (String?, String?)) throws {
        let mapped = try mapRecordedPurchase(PurchaseFixtures.wirePurchase(trackingNumber: pair.0))

        #expect(mapped.trackingNumber == pair.1)
    }

    @Test("notes: nil, empty and blank map to nil; a value is kept as received",
          arguments: [
        (String?.none, String?.none), ("", nil), (" ", nil), ("   ", nil), ("\n\t ", nil),
        ("Gift wrap please", "Gift wrap please"), (" Gift wrap ", " Gift wrap ")
    ])
    func notes(pair: (String?, String?)) throws {
        let mapped = try mapRecordedPurchase(PurchaseFixtures.wirePurchase(notes: pair.0))

        #expect(mapped.notes == pair.1)
    }

    @Test("normalizing the two fields changes no other field")
    func otherFieldsUntouched() throws {
        let wire = PurchaseFixtures.wirePurchase(
            id: "purchase-7", itemId: "item-4", quantity: 3, totalCost: 1234.50,
            storeName: "Fake Store", notes: "", confirmationNumber: "CONF-1",
            trackingNumber: "", shippingStatus: .shipped
        )

        let mapped = try mapRecordedPurchase(wire)

        #expect(mapped.id == "purchase-7")
        #expect(mapped.itemId == "item-4")
        #expect(mapped.quantity == 3)
        #expect(mapped.totalCost == PurchaseFixtures.decimal("1234.50"))
        #expect(mapped.storeName == "Fake Store")
        #expect(mapped.confirmationNumber == "CONF-1")
        #expect(mapped.shippingStatus == .shipped)
        #expect(mapped.notes == nil)
        #expect(mapped.trackingNumber == nil)
    }

    @Test("only the two cleared fields are normalized: a blank store name and confirmation number stay as received")
    func storeAndConfirmationAreNotNormalized() throws {
        let wire = PurchaseFixtures.wirePurchase(storeName: "", confirmationNumber: "")

        let mapped = try mapRecordedPurchase(wire)

        #expect(mapped.storeName == "")
        #expect(mapped.confirmationNumber == "")
    }
}
