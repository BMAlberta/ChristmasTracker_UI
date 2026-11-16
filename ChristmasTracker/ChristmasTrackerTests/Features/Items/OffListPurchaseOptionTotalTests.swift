//
//  OffListPurchaseOptionTotalTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: the total in integer cents and its two-decimal text. No floating point.
//  The cap is 99_999_999 cents (the purchase form rejects a cost above 999999.99).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase option total Tests")
struct OffListPurchaseOptionTotalTests {

    private static let memberCaps = ItemFixtures.capabilities(
        canCreateItem: true, canAddOffList: true, canSeeGiftActivity: true, canSeeOffList: true, canPurchase: true
    )

    private func makeSUT(
        priceText: String,
        quantity: Int,
        wantsPurchase: Bool = true,
        locale: Locale = Locale(identifier: "en_US")
    ) -> OffListPurchaseOption {
        OffListPurchaseOption(
            capabilities: Self.memberCaps,
            mode: .add,
            wantsPurchase: wantsPurchase,
            priceText: priceText,
            quantity: quantity,
            locale: locale
        )
    }

    @Test("Arithmetic in cents and the two-decimal text", arguments: [
        ("12.50", 1, 1250, "12.50"),
        ("12.50", 3, 3750, "37.50"),
        ("0.10", 3, 30, "0.30"),
        ("19.99", 7, 13993, "139.93"),
        ("12", 2, 2400, "24.00"),
        ("0.01", 1, 1, "0.01"),
        ("1000.00", 999, 99_900_000, "999000.00")
    ])
    func arithmetic(price: String, quantity: Int, cents: Int, text: String) {
        let sut = makeSUT(priceText: price, quantity: quantity)
        #expect(sut.totalCents == cents)
        #expect(sut.totalText == text)
    }

    @Test("Totals at and just under the cap are allowed", arguments: [
        ("999999.99", 1, 99_999_999),
        ("499999.99", 2, 99_999_998),
        ("9999.99", 100, 99_999_900),
        ("1001.00", 999, 99_999_900)
    ])
    func atOrUnderCap(price: String, quantity: Int, cents: Int) {
        #expect(makeSUT(priceText: price, quantity: quantity).totalCents == cents)
    }

    @Test("Totals above the cap are rejected", arguments: [
        ("500000.00", 2),
        ("10000.00", 100),
        ("1001.01", 999),
        ("99999.99", 999),
        ("999999.99", 2),
        ("999999.99", 999)
    ])
    func overCap(price: String, quantity: Int) {
        let sut = makeSUT(priceText: price, quantity: quantity)
        #expect(sut.totalCents == nil)
        #expect(sut.totalText == nil)
    }

    @Test("Quantity outside 1...999 gives no total", arguments: [0, -1, 1000, 5000, Int.max, Int.min])
    func quantityBounds(quantity: Int) {
        let sut = makeSUT(priceText: "12.50", quantity: quantity)
        #expect(sut.totalCents == nil)
        #expect(sut.totalText == nil)
    }

    @Test("Quantity bounds 1 and 999 are accepted")
    func quantityEdges() {
        #expect(makeSUT(priceText: "1.00", quantity: 1).totalCents == 100)
        #expect(makeSUT(priceText: "1.00", quantity: 999).totalCents == 99_900)
    }

    @Test(
        "A zero, empty or invalid price gives no total",
        arguments: ["0", "0.00", "", "abc", "-1", "1.234", "1,5", "1000000.00"]
    )
    func badPrice(price: String) {
        let sut = makeSUT(priceText: price, quantity: 2)
        #expect(sut.totalCents == nil)
        #expect(sut.totalText == nil)
    }

    @Test("The total is independent of the toggle")
    func independentOfToggle() {
        let sut = makeSUT(priceText: "12.50", quantity: 3, wantsPurchase: false)
        #expect(sut.totalCents == 3750)
        #expect(sut.totalText == "37.50")
    }

    @Test("A comma-separator locale gives a comma and the text round-trips through the purchase form parser")
    func commaLocale() throws {
        let german = Locale(identifier: "de_DE")
        let sut = makeSUT(priceText: "12.50", quantity: 3, locale: german)
        let text = try #require(sut.totalText)
        #expect(text == "37,50")
        let parsed = try #require(RecordPurchaseFormState.parseTotalCost(text, locale: german))
        #expect(parsed == (Decimal(string: "37.50", locale: Locale(identifier: "en_US_POSIX")) ?? -1))
    }

    @Test("A period-separator locale round-trips, including a large total without grouping")
    func periodLocaleRoundTrip() throws {
        let us = Locale(identifier: "en_US")
        let sut = makeSUT(priceText: "999999.99", quantity: 1, locale: us)
        let text = try #require(sut.totalText)
        #expect(text == "999999.99")
        #expect(RecordPurchaseFormState.parseTotalCost(text, locale: us) != nil)
    }
}
