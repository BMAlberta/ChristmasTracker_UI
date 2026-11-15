//
//  PurchaseHistoryFilterTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1: PurchaseHistoryFilter value semantics and isDefault(defaultYear:).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryFilter", .timeLimit(.minutes(1)))
struct PurchaseHistoryFilterTests {

    @Test("the default filter has no year, no recipient and no shipping status")
    func defaultInit() {
        let filter = PurchaseHistoryFilter()

        #expect(filter.year == nil)
        #expect(filter.recipientId == nil)
        #expect(filter.shippingStatus == nil)
    }

    @Test("the memberwise init keeps every value")
    func initKeepsValues() {
        let filter = PurchaseHistoryFilter(year: 2025, recipientId: "user-1", shippingStatus: .delivered)

        #expect(filter.year == 2025)
        #expect(filter.recipientId == "user-1")
        #expect(filter.shippingStatus == .delivered)
    }

    // MARK: isDefault

    @Test("isDefault is true when the year is the default year and nothing else is set")
    func defaultWhenYearMatches() {
        #expect(PurchaseHistoryFilter(year: 2026).isDefault(defaultYear: 2026))
    }

    @Test("isDefault is true for all years when the default year is nil")
    func defaultWhenBothNil() {
        #expect(PurchaseHistoryFilter().isDefault(defaultYear: nil))
    }

    @Test("isDefault is false when all years is chosen but a year is the default")
    func notDefaultWhenYearCleared() {
        #expect(!PurchaseHistoryFilter(year: nil).isDefault(defaultYear: 2026))
    }

    @Test("isDefault is false when a year is chosen but all years is the default")
    func notDefaultWhenYearSet() {
        #expect(!PurchaseHistoryFilter(year: 2026).isDefault(defaultYear: nil))
    }

    @Test("isDefault is false for a different year")
    func notDefaultWhenYearDiffers() {
        #expect(!PurchaseHistoryFilter(year: 2025).isDefault(defaultYear: 2026))
    }

    @Test("isDefault is false when a recipient is set, whatever the year")
    func notDefaultWithRecipient() {
        #expect(!PurchaseHistoryFilter(year: 2026, recipientId: "user-1").isDefault(defaultYear: 2026))
        #expect(!PurchaseHistoryFilter(year: nil, recipientId: "user-1").isDefault(defaultYear: nil))
    }

    @Test("isDefault is false when a shipping status is set, for every status", arguments: PurchaseShippingStatus.allCases)
    func notDefaultWithShipping(status: PurchaseShippingStatus) {
        #expect(!PurchaseHistoryFilter(year: 2026, shippingStatus: status).isDefault(defaultYear: 2026))
        #expect(!PurchaseHistoryFilter(year: nil, shippingStatus: status).isDefault(defaultYear: nil))
    }

    // MARK: Equatable and Hashable

    @Test("equal filters are equal and hash the same, different ones differ")
    func equalityAndHashing() {
        let one = PurchaseHistoryFilter(year: 2026, recipientId: "user-1", shippingStatus: .shipped)
        let same = PurchaseHistoryFilter(year: 2026, recipientId: "user-1", shippingStatus: .shipped)

        #expect(one == same)
        #expect(one.hashValue == same.hashValue)
        #expect(one != PurchaseHistoryFilter(year: 2025, recipientId: "user-1", shippingStatus: .shipped))
        #expect(one != PurchaseHistoryFilter(year: 2026, recipientId: "user-2", shippingStatus: .shipped))
        #expect(one != PurchaseHistoryFilter(year: 2026, recipientId: "user-1", shippingStatus: .delivered))
        #expect(Set([one, same]).count == 1)
    }

    @Test("all eight combinations are distinct")
    func combinationsAreDistinct() {
        #expect(Set(PurchaseHistoryFix.allFilterCombinations).count == 8)
    }
}
