//
//  ShippingStatusStyleTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: the style table of the four shipping statuses (dot fill, words, accessibility label).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Shipping status style")
struct ShippingStatusStyleTests {

    @Test("Shipped uses the statusShipped token, like the theme's shipped status")
    func shippedToken() {
        #expect(ShippingStatusStyle.style(for: .shipped).fill == .statusShipped)
        #expect(ShippingStatusStyle.style(for: .shipped).fill == StatusStyle.style(for: .shipped).fill)
    }

    @Test("The other three use neutral tokens")
    func neutralTokens() {
        #expect(ShippingStatusStyle.style(for: .notTracked).fill == .border)
        #expect(ShippingStatusStyle.style(for: .notShipped).fill == .textMuted)
        #expect(ShippingStatusStyle.style(for: .delivered).fill == .primary)
    }

    @Test("Not tracked and Not shipped differ from Shipped and Delivered, and all four differ")
    func fillsDiffer() {
        let fills = PurchaseShippingStatus.allCases.map { ShippingStatusStyle.style(for: $0).fill }

        #expect(Set(fills).count == 4)
    }

    @Test("The short label is the display name", arguments: PurchaseShippingStatus.allCases)
    func shortLabel(status: PurchaseShippingStatus) {
        #expect(ShippingStatusStyle.style(for: status).shortLabel == status.displayName)
    }

    @Test("The accessibility label is Shipping: and the words")
    func accessibilityLabels() {
        #expect(ShippingStatusStyle.style(for: .notTracked).accessibilityLabel == "Shipping: Not tracked")
        #expect(ShippingStatusStyle.style(for: .notShipped).accessibilityLabel == "Shipping: Not shipped")
        #expect(ShippingStatusStyle.style(for: .shipped).accessibilityLabel == "Shipping: Shipped")
        #expect(ShippingStatusStyle.style(for: .delivered).accessibilityLabel == "Shipping: Delivered")
    }

    @Test("The edge follows the table-driven rule for weak fills")
    func edgeRule() {
        let needing = ThemeEdgeRule.fillsNeedingEdge()
        for status in PurchaseShippingStatus.allCases {
            let style = ShippingStatusStyle.style(for: status)
            #expect(style.needsEdge == needing.contains(style.fill))
            #expect(style.edge == (needing.contains(style.fill) ? StatusStyle.edgeToken : nil))
        }
    }

    @Test("The style carries its status")
    func carriesStatus() {
        for status in PurchaseShippingStatus.allCases {
            #expect(ShippingStatusStyle.style(for: status).status == status)
        }
    }
}
