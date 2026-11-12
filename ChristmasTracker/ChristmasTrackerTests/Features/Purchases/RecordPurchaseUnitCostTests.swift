//
//  RecordPurchaseUnitCostTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the unit-cost line of the form. It is totalCost / quantity computed with Decimal
//  (no Double), rounded to two places, formatted with the user's currency, and present only when
//  the form is valid.
//
//  Fails today because RecordPurchaseFormState does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase unit cost Tests")
struct RecordPurchaseUnitCostTests {

    private func makeSUT(
        quantity: Int,
        totalCost: String,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) -> RecordPurchaseFormState {
        RecordPurchaseFormState(
            input: RecordPurchaseFormInput(
                quantity: quantity, totalCostText: totalCost, storeName: "", notes: "",
                confirmationNumber: "", trackingNumber: ""
            ),
            quantityRemaining: nil,
            currencyCode: currencyCode,
            locale: locale
        )
    }

    @Test("A divisible total gives the exact unit cost",
          arguments: [(1, "25.50", "$25.50"), (2, "40.00", "$20.00"), (4, "10.00", "$2.50"), (3, "30.00", "$10.00")])
    func divisible(quantity: Int, total: String, expected: String) {
        #expect(makeSUT(quantity: quantity, totalCost: total).unitCostText == expected, "\(quantity) x \(total)")
    }

    @Test("A non-divisible total is rounded to two places",
          arguments: [(3, "10.00", "$3.33"), (3, "20.00", "$6.67"), (7, "1.00", "$0.14"), (6, "100.00", "$16.67")])
    func rounded(quantity: Int, total: String, expected: String) {
        #expect(makeSUT(quantity: quantity, totalCost: total).unitCostText == expected, "\(quantity) x \(total)")
    }

    @Test("Large totals use the currency grouping")
    func grouping() {
        #expect(makeSUT(quantity: 1, totalCost: "999999.99").unitCostText == "$999,999.99")
    }

    @Test("The unit cost is nil whenever the form is invalid",
          arguments: [(0, "10.00"), (-1, "10.00"), (2, ""), (2, "0"), (2, "1000000.00"), (2, "12.345")])
    func nilWhenInvalid(quantity: Int, total: String) {
        #expect(makeSUT(quantity: quantity, totalCost: total).unitCostText == nil, "\(quantity) x \(total)")
    }

    @Test("The unit cost is formatted for the injected currency and locale")
    func injectedFormatting() throws {
        let text = try #require(makeSUT(quantity: 3, totalCost: "10,00", currencyCode: "EUR",
                                        locale: Locale(identifier: "de_DE")).unitCostText)
        #expect(text.contains("3,33"))
        #expect(text.contains("€"))
    }
}
