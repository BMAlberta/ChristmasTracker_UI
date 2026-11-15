//
//  PurchaseHistoryRouteTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: the route from the Statistics entry points to the history (pure).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history route")
struct PurchaseHistoryRouteTests {

    private func spendRow(id: String = "recipient-7", name: String = "Jordan Sample") -> SpendRowState {
        SpendRowState(
            id: id, name: name, spentText: "$10.00", itemsText: "1 item",
            accessibilityLabel: "\(name), $10.00, 1 item"
        )
    }

    @Test("The Purchase History row passes the selected year, the year choices and no person")
    func historyRow() {
        let route = PurchaseHistoryRoute.fromHistoryRow(year: 2025, yearChoices: [2026, 2025])

        #expect(route.year == 2025)
        #expect(route.yearChoices == [2026, 2025])
        #expect(route.recipient == nil)
    }

    @Test("A spend row passes the selected year and the row id as the recipient id, with its name")
    func spendRowRoute() {
        let route = PurchaseHistoryRoute.fromSpendRow(spendRow(), year: 2026, yearChoices: [2026, 2025])

        #expect(route.year == 2026)
        #expect(route.yearChoices == [2026, 2025])
        #expect(route.recipient == PurchaseHistoryRecipient(id: "recipient-7", name: "Jordan Sample"))
    }

    @Test("Two spend rows with the same name keep their own ids")
    func sameNameKeepsId() {
        let first = PurchaseHistoryRoute.fromSpendRow(spendRow(id: "a", name: "Sam"), year: 2026, yearChoices: [])
        let second = PurchaseHistoryRoute.fromSpendRow(spendRow(id: "b", name: "Sam"), year: 2026, yearChoices: [])

        #expect(first.recipient?.id == "a")
        #expect(second.recipient?.id == "b")
        #expect(first != second)
    }

    @Test("Routes with equal values are equal and hash alike")
    func hashable() {
        let one = PurchaseHistoryRoute.fromHistoryRow(year: 2026, yearChoices: [2026])
        let two = PurchaseHistoryRoute.fromHistoryRow(year: 2026, yearChoices: [2026])

        #expect(one == two)
        #expect(Set([one, two]).count == 1)
    }
}
