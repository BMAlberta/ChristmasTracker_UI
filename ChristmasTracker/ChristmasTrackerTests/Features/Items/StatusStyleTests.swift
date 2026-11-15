//
//  StatusStyleTests.swift
//  ChristmasTrackerTests
//
//  TH1-T3: the pure status style layer. StatusKind maps item and shipping statuses; StatusStyle
//  gives the fill token, the words, and the label color per mode (from ThemeStatusLabelTable).
//  Every label must reach 4.5:1 against its fill in both modes.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatusStyle")
struct StatusStyleTests {

    private struct Expected {
        let kind: StatusKind
        let fill: ThemeToken
        let shortLabel: String
        let lightLabel: ThemeLabel
        let darkLabel: ThemeLabel
    }

    private let expectations: [Expected] = [
        Expected(kind: .available, fill: .statusAvailable, shortLabel: "Available",
                 lightLabel: .white, darkLabel: .token(.backgroundPrimary)),
        Expected(kind: .partial, fill: .statusPartial, shortLabel: "Partial",
                 lightLabel: .token(.textPrimary), darkLabel: .token(.backgroundPrimary)),
        Expected(kind: .purchased, fill: .statusPurchased, shortLabel: "Purchased",
                 lightLabel: .white, darkLabel: .token(.backgroundPrimary)),
        Expected(kind: .shipped, fill: .statusShipped, shortLabel: "Shipped",
                 lightLabel: .white, darkLabel: .token(.backgroundPrimary)),
        Expected(kind: .wrapped, fill: .statusWrapped, shortLabel: "Wrapped",
                 lightLabel: .white, darkLabel: .token(.backgroundPrimary)),
        Expected(kind: .gifted, fill: .statusGifted, shortLabel: "Gifted",
                 lightLabel: .token(.textPrimary), darkLabel: .token(.backgroundPrimary))
    ]

    // MARK: - Coverage

    @Test func thereAreSixKinds() {
        #expect(StatusKind.allCases.count == 6)
        #expect(Set(StatusKind.allCases) == Set(expectations.map(\.kind)))
    }

    // MARK: - Per kind

    @Test func styleCarriesItsKind() {
        for kind in StatusKind.allCases {
            #expect(StatusStyle.style(for: kind).kind == kind)
        }
    }

    @Test func fillTokenPerKind() {
        for expected in expectations {
            #expect(StatusStyle.style(for: expected.kind).fill == expected.fill, "\(expected.kind)")
        }
    }

    @Test func shortLabelPerKind() {
        for expected in expectations {
            #expect(StatusStyle.style(for: expected.kind).shortLabel == expected.shortLabel, "\(expected.kind)")
        }
    }

    @Test func accessibilityLabelPerKind() {
        for expected in expectations {
            #expect(
                StatusStyle.style(for: expected.kind).accessibilityLabel == "Status: \(expected.shortLabel)",
                "\(expected.kind)"
            )
        }
    }

    @Test func lightLabelPerKind() {
        for expected in expectations {
            #expect(StatusStyle.style(for: expected.kind).label(for: .light) == expected.lightLabel, "\(expected.kind)")
        }
    }

    @Test func darkLabelPerKind() {
        for expected in expectations {
            #expect(StatusStyle.style(for: expected.kind).label(for: .dark) == expected.darkLabel, "\(expected.kind)")
        }
    }

    @Test func labelEqualsTheLabelTableForTheFill() {
        for kind in StatusKind.allCases {
            let style = StatusStyle.style(for: kind)
            for mode in ThemeMode.allCases {
                #expect(style.label(for: mode) == ThemeStatusLabelTable.label(onFill: style.fill, mode: mode))
            }
        }
    }

    @Test func styleIsEquatableAndStable() {
        for kind in StatusKind.allCases {
            #expect(StatusStyle.style(for: kind) == StatusStyle.style(for: kind))
        }
        #expect(StatusStyle.style(for: .available) != StatusStyle.style(for: .gifted))
    }

    // MARK: - Contrast

    @Test func everyLabelReachesFourPointFiveAgainstItsFillInBothModes() {
        for kind in StatusKind.allCases {
            let style = StatusStyle.style(for: kind)
            for mode in ThemeMode.allCases {
                let fill = ThemeTokenTable.rgb(style.fill, mode)
                let label = ThemeStatusLabelTable.rgb(style.label(for: mode), mode)
                let ratio = ThemeContrast.ratio(label, fill)
                #expect(ratio >= 4.5, "\(kind) \(mode) ratio \(ratio)")
            }
        }
    }

    // MARK: - ItemStatus mapping

    @Test func itemStatusAvailableMaps() { #expect(StatusKind(ItemStatus.available) == .available) }
    @Test func itemStatusPartialMaps() { #expect(StatusKind(ItemStatus.partial) == .partial) }
    @Test func itemStatusPurchasedMaps() { #expect(StatusKind(ItemStatus.purchased) == .purchased) }
    @Test func itemStatusWrappedMaps() { #expect(StatusKind(ItemStatus.wrapped) == .wrapped) }
    @Test func itemStatusGiftedMaps() { #expect(StatusKind(ItemStatus.gifted) == .gifted) }

    @Test func noItemStatusMapsToShipped() {
        let all: [ItemStatus] = [.available, .partial, .purchased, .wrapped, .gifted]
        for status in all {
            #expect(StatusKind(status) != .shipped, "\(status)")
        }
    }

    // MARK: - Shipping mapping

    @Test func shippedShippingStatusMapsToShipped() {
        #expect(StatusKind(shipping: .shipped) == .shipped)
    }

    @Test func everyOtherShippingStatusIsNil() {
        for status in PurchaseShippingStatus.allCases where status != .shipped {
            #expect(StatusKind(shipping: status) == nil, "\(status)")
        }
    }

    @Test func onlyShippedIsNonNilAcrossAllShippingCases() {
        let mapped = PurchaseShippingStatus.allCases.compactMap { StatusKind(shipping: $0) }
        #expect(mapped == [.shipped])
    }

    // MARK: - displayName unchanged

    @Test func displayNamesAreUnchanged() {
        #expect(ItemStatus.available.displayName == "Available")
        #expect(ItemStatus.partial.displayName == "Partially Purchased")
        #expect(ItemStatus.purchased.displayName == "Purchased")
        #expect(ItemStatus.wrapped.displayName == "Wrapped")
        #expect(ItemStatus.gifted.displayName == "Gifted")
    }
}
