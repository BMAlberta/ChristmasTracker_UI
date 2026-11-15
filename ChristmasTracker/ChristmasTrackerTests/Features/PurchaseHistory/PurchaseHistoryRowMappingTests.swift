//
//  PurchaseHistoryRowMappingTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC5 and AC6: mapPurchaseHistoryRow. Every field is kept, money goes through the package
//  helper to an exact Decimal, NaN and infinity throw invalidResponse, the four shipping statuses map,
//  a blank item name is kept as is (the "Item" fallback is presentation), purchasedAt is kept exactly.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("mapPurchaseHistoryRow", .timeLimit(.minutes(1)))
struct PurchaseHistoryRowMappingTests {

    private func dec(_ text: String) -> Decimal { PurchaseHistoryFix.dec(text) }

    @Test("every field of the schema row is carried to the domain row")
    func mapsEveryField() throws {
        let when = Date(timeIntervalSince1970: 1_700_000_123.456)
        let api = PurchaseHistoryFix.apiRow(
            id: "purchase-7", itemId: "item-9", itemName: "Fake Train", listId: "list-3",
            recipientId: "user-5", recipientName: "Sam Recipient", purchasedAt: when,
            quantity: 3, totalCost: 45.5, shippingStatus: .shipped
        )

        let row = try mapPurchaseHistoryRow(api)

        #expect(row == PurchaseHistoryRow(
            id: "purchase-7", itemId: "item-9", itemName: "Fake Train", listId: "list-3",
            recipientId: "user-5", recipientName: "Sam Recipient", purchasedAt: when,
            quantity: 3, totalCost: dec("45.5"), shippingStatus: .shipped
        ))
        #expect(row.purchasedAt == when, "the timestamp is kept exactly as sent")
    }

    @Test("the row id is the purchase id, not the item id")
    func idIsThePurchaseId() throws {
        let row = try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(id: "purchase-A", itemId: "item-B"))

        #expect(row.id == "purchase-A")
        #expect(row.itemId == "item-B")
    }

    @Test("money is an exact Decimal", arguments: [
        (19.99, "19.99"), (0.0, "0"), (1234.5, "1234.5"), (0.01, "0.01"), (79.99, "79.99"), (999_999.99, "999999.99")
    ])
    func moneyIsExact(pair: (Double, String)) throws {
        let row = try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(totalCost: pair.0))

        #expect(row.totalCost == dec(pair.1))
    }

    @Test("a total that is NaN or infinite throws invalidResponse", arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteMoneyThrows(value: Double) {
        #expect(throws: PurchaseHistoryError.invalidResponse) {
            _ = try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(totalCost: value))
        }
    }

    @Test("each wire shipping status maps to the matching domain status", arguments: [0, 1, 2, 3])
    func shippingMapping(index: Int) throws {
        let pair = PurchaseHistoryFix.shippingPairs[index]

        let row = try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(shippingStatus: pair.1))

        #expect(row.shippingStatus == pair.0)
    }

    @Test("a blank item name is kept as is")
    func blankNameIsKept() throws {
        #expect(try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(itemName: "")).itemName == "")
        #expect(try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(itemName: "   ")).itemName == "   ")
    }

    @Test("quantity is kept, including the minimum of 1 and large values", arguments: [1, 2, 99])
    func quantityIsKept(quantity: Int) throws {
        #expect(try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow(quantity: quantity)).quantity == quantity)
    }

    @Test("the item image and the list name do not appear in the domain row")
    func extrasAreNotCarried() throws {
        let one = try mapPurchaseHistoryRow(PurchaseHistoryFix.apiRow())
        var changed = PurchaseHistoryFix.apiRow()
        changed.item.imageUrl = "https://img.example.com/other.png"
        changed.list.name = "Another List"
        changed.list.year = 1999

        #expect(try mapPurchaseHistoryRow(changed) == one, "only the carried fields make up the row")
    }
}
