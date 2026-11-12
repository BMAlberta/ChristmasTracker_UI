//
//  PurchaseShippingStatusTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: PurchaseShippingStatus (replaces RecordedShippingStatus) has four cases in a
//  fixed CaseIterable order and plain display names.
//
//  Fails today because PurchaseShippingStatus does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase shipping status Tests")
struct PurchaseShippingStatusTests {

    @Test("CaseIterable lists the four statuses in picker order")
    func caseOrder() {
        #expect(PurchaseShippingStatus.allCases == [.notTracked, .notShipped, .shipped, .delivered])
    }

    @Test("Display names are plain words", arguments: [
        (PurchaseShippingStatus.notTracked, "Not tracked"),
        (PurchaseShippingStatus.notShipped, "Not shipped"),
        (PurchaseShippingStatus.shipped, "Shipped"),
        (PurchaseShippingStatus.delivered, "Delivered")
    ])
    func displayNames(status: PurchaseShippingStatus, expected: String) {
        #expect(status.displayName == expected)
    }

    @Test("Display names are pairwise different")
    func displayNamesDistinct() {
        let names = PurchaseShippingStatus.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }
}
