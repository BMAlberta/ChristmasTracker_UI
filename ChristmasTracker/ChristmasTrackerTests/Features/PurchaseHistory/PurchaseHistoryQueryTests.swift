//
//  PurchaseHistoryQueryTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC1: the pure query builder. year, recipientId, shippingStatus, limit (20) and cursor are set
//  from the arguments; listId and itemId are never set; unset filters and a nil cursor stay nil.
//  (The request actually sent is pinned in GeneratedClientPurchaseHistoryRequestTests.)
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("makePurchaseHistoryQuery", .timeLimit(.minutes(1)))
struct PurchaseHistoryQueryTests {

    private func wireStatus(_ status: PurchaseShippingStatus?) -> Components.Schemas.ShippingStatus? {
        guard let status else { return nil }
        return PurchaseHistoryFix.shippingPairs.first { $0.0 == status }?.1
    }

    @Test("the page limit is 20")
    func pageLimitIsTwenty() {
        #expect(GeneratedClientPurchaseHistoryRepository.pageLimit == 20)
    }

    @Test("every filter combination with and without a cursor maps field for field",
          arguments: PurchaseHistoryFix.allFilterCombinations, [String?.none, "cursor-abc"])
    func mapsEveryCombination(filter: PurchaseHistoryFilter, cursor: String?) {
        let query = makePurchaseHistoryQuery(filter: filter, cursor: cursor)

        #expect(query.year == filter.year)
        #expect(query.recipientId == filter.recipientId)
        #expect(query.shippingStatus == wireStatus(filter.shippingStatus))
        #expect(query.cursor == cursor)
        #expect(query.limit == GeneratedClientPurchaseHistoryRepository.pageLimit)
        #expect(query.listId == nil)
        #expect(query.itemId == nil)
    }

    @Test("the default filter with no cursor sets only the limit")
    func defaultFilterSendsOnlyTheLimit() {
        let query = makePurchaseHistoryQuery(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(query == Operations.ListPurchases.Input.Query(limit: 20))
    }

    @Test("all years sends no year at all")
    func allYearsHasNoYear() {
        let query = makePurchaseHistoryQuery(filter: PurchaseHistoryFilter(year: nil, shippingStatus: .shipped), cursor: nil)

        #expect(query.year == nil)
        #expect(query.shippingStatus == .shipped)
    }

    @Test("each shipping status maps to its wire value", arguments: PurchaseHistoryFix.shippingPairs.map(\.0))
    func shippingMapping(status: PurchaseShippingStatus) {
        let query = makePurchaseHistoryQuery(filter: PurchaseHistoryFilter(shippingStatus: status), cursor: nil)

        #expect(query.shippingStatus == wireStatus(status))
    }

    @Test("the cursor is passed through exactly as given, without any change")
    func cursorIsOpaque() {
        let cursor = "eyJwIjoiMjAyNi0wMS0wNSIsImlkIjoiYWJjIn0="
        let query = makePurchaseHistoryQuery(filter: PurchaseHistoryFilter(), cursor: cursor)

        #expect(query.cursor == cursor)
    }

    @Test("the builder is pure: the same arguments give the same query")
    func isPure() {
        let filter = PurchaseHistoryFilter(year: 2026, recipientId: "user-1", shippingStatus: .delivered)

        #expect(makePurchaseHistoryQuery(filter: filter, cursor: "c") == makePurchaseHistoryQuery(filter: filter, cursor: "c"))
    }
}
