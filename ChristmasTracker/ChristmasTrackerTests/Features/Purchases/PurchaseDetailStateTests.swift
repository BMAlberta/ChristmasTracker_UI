//
//  PurchaseDetailStateTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the read-only core rows of the purchase detail and the fixed texts. Money is
//  Decimal formatted with the same style as the item price text; the date is a medium date.
//
//  Fails today because PurchaseDetailState does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail state Tests")
struct PurchaseDetailStateTests {

    private let locale = Locale(identifier: "en_US")

    private func makeSUT(
        _ purchase: RecordedPurchase = PurchaseFixtures.recordedPurchase(item: PurchaseFixtures.fakeItemReference),
        currencyCode: String = "USD"
    ) -> PurchaseDetailState {
        PurchaseDetailState(purchase: purchase, currencyCode: currencyCode, locale: locale)
    }

    // MARK: - Core rows

    @Test("The item name comes from the item reference")
    func itemName() {
        #expect(makeSUT().itemName == "Fake Lamp")
    }

    @Test("A purchase without an item reference says This item")
    func itemNameFallback() {
        #expect(makeSUT(PurchaseFixtures.recordedPurchase(item: nil)).itemName == "This item")
    }

    @Test("Quantity text", arguments: [(1, "Quantity: 1"), (2, "Quantity: 2"), (12, "Quantity: 12")])
    func quantityText(quantity: Int, expected: String) {
        #expect(makeSUT(PurchaseFixtures.recordedPurchase(quantity: quantity)).quantityText == expected)
    }

    @Test("Total cost is formatted from the Decimal like the item price text",
          arguments: [("19.99", "$19.99"), ("1234.50", "$1,234.50"), ("0.10", "$0.10"), ("999999.99", "$999,999.99")])
    func totalCostText(total: String, expected: String) {
        let purchase = PurchaseFixtures.recordedPurchase(totalCost: PurchaseFixtures.decimal(total))
        #expect(makeSUT(purchase).totalCostText == expected)
    }

    @Test("The store text is the store name, nil when absent or blank", arguments: [
        ("Fake Store", "Fake Store" as String?), (nil, nil), ("", nil), ("   ", nil), ("\n\t", nil)
    ] as [(String?, String?)])
    func storeText(store: String?, expected: String?) {
        #expect(makeSUT(PurchaseFixtures.recordedPurchase(storeName: store)).storeText == expected)
    }

    @Test("The purchased text is the medium date")
    func purchasedText() {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        #expect(makeSUT().purchasedText == formatter.string(from: PurchaseFixtures.purchasedDate))
    }

    @Test("The confirmation number text is the number, nil when absent or blank", arguments: [
        ("CONF-1", "CONF-1" as String?), (nil, nil), ("", nil), ("  ", nil)
    ] as [(String?, String?)])
    func confirmationNumberText(number: String?, expected: String?) {
        #expect(makeSUT(PurchaseFixtures.recordedPurchase(confirmationNumber: number)).confirmationNumberText == expected)
    }

    // MARK: - Constants

    @Test("The fixed sentence, limits and delete texts")
    func constants() {
        #expect(PurchaseDetailState.immutableSentence
                == "To change the quantity or cost, delete this purchase and record it again.")
        #expect(PurchaseDetailState.notesLimit == 1000)
        #expect(PurchaseDetailState.trackingLimit == 100)
        #expect(PurchaseDetailState.deleteTitle == "Delete this purchase?")
        #expect(PurchaseDetailState.deleteMessage
                == "It will be removed from this item and from your budget, and the remaining quantity will update. This can't be undone.")
        #expect(PurchaseDetailState.deleteButtonTitle == "Delete Purchase")
    }
}
