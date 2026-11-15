//
//  PurchaseHistoryRowPresentationTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: how one history row reads (pure). Fixed locale and time zone, so the text is stable.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history row presentation")
struct PurchaseHistoryRowPresentationTests {

    private let locale = Locale(identifier: "en_US")

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = locale
        return calendar
    }

    /// 2026-01-05 12:00:00 UTC.
    private let noon = Date(timeIntervalSince1970: 1_767_614_400)

    private func makeSUT(
        itemName: String = "Fake Lamp",
        recipientName: String = "Pat Recipient",
        quantity: Int = 1,
        total: String = "19.99",
        shipping: PurchaseShippingStatus = .notTracked
    ) -> PurchaseHistoryRowPresentation {
        let row = PurchaseHistoryFix.row(
            itemName: itemName, recipientName: recipientName, purchasedAt: noon, quantity: quantity,
            totalCost: PurchaseHistoryFix.dec(total), shippingStatus: shipping
        )
        return PurchaseHistoryRowPresentation.make(row, locale: locale, calendar: calendar)
    }

    @Test("The item name is shown as is")
    func itemName() {
        #expect(makeSUT(itemName: "Wool scarf").itemName == "Wool scarf")
    }

    @Test("A blank item name reads Item", arguments: ["", "   ", " \n "])
    func blankItemName(name: String) {
        #expect(makeSUT(itemName: name).itemName == "Item")
    }

    @Test("The recipient line reads For and the name")
    func recipient() {
        #expect(makeSUT(recipientName: "Alex Rivera").recipientText == "For Alex Rivera")
    }

    @Test("The date is the medium date in the given locale and time zone")
    func date() {
        #expect(makeSUT().dateText == "Jan 5, 2026")
    }

    @Test("The date follows the time zone of the calendar")
    func dateTimeZone() {
        var tokyo = calendar
        tokyo.timeZone = TimeZone(secondsFromGMT: 14 * 3600) ?? .gmt
        let late = Date(timeIntervalSince1970: 1_767_614_400 + 11 * 3600)
        let row = PurchaseHistoryFix.row(purchasedAt: late)

        #expect(PurchaseHistoryRowPresentation.make(row, locale: locale, calendar: calendar).dateText == "Jan 5, 2026")
        #expect(PurchaseHistoryRowPresentation.make(row, locale: locale, calendar: tokyo).dateText == "Jan 6, 2026")
    }

    @Test("Quantity shows only above 1")
    func quantity() {
        #expect(makeSUT(quantity: 1).quantityText == nil)
        #expect(makeSUT(quantity: 2).quantityText == "Qty 2")
        #expect(makeSUT(quantity: 12).quantityText == "Qty 12")
    }

    @Test("The total is USD money from the Decimal, with two places")
    func total() {
        #expect(makeSUT(total: "19.99").totalText == "$19.99")
        #expect(makeSUT(total: "1234.5").totalText == "$1,234.50")
        #expect(makeSUT(total: "0").totalText == "$0.00")
    }

    @Test("The shipping words are the status display name")
    func shippingWords() {
        #expect(makeSUT(shipping: .notShipped).shippingWords == "Not shipped")
    }

    @Test("One accessibility label: item, for whom, date, total, shipping")
    func accessibilityLabel() {
        let sut = makeSUT(itemName: "Wool scarf", recipientName: "Alex Rivera", shipping: .shipped)

        #expect(sut.accessibilityLabel == "Wool scarf, for Alex Rivera, Jan 5, 2026, $19.99, Shipping: Shipped")
    }

    @Test("The accessibility label has the quantity above 1 and the Item fallback")
    func accessibilityLabelQuantity() {
        let sut = makeSUT(itemName: " ", recipientName: "Pat", quantity: 3, total: "60", shipping: .delivered)

        #expect(sut.accessibilityLabel == "Item, for Pat, Jan 5, 2026, quantity 3, $60.00, Shipping: Delivered")
    }
}
