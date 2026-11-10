//
//  GiftListProgressTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: GiftList.progress and ListDetail.progress are derived from the counts that
//  are present. They are nil when either count is absent or itemCount is 0 (a blind viewer
//  must not be shown a fake 0 percent).
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("GiftList progress Tests")
struct GiftListProgressTests {

    private func makeSUT(itemCount: Int?, purchasedCount: Int?) -> GiftList {
        ListFixtures.giftList(itemCount: itemCount, purchasedCount: purchasedCount)
    }

    @Test("Progress is purchased over items when both counts are present")
    func progressFromPresentCounts() throws {
        let progress = try #require(makeSUT(itemCount: 4, purchasedCount: 1).progress)
        #expect(abs(progress - 0.25) < 0.000_001)
    }

    @Test("Progress is 1.0 when everything is purchased")
    func progressComplete() throws {
        let progress = try #require(makeSUT(itemCount: 3, purchasedCount: 3).progress)
        #expect(abs(progress - 1.0) < 0.000_001)
    }

    @Test("Progress is 0.0 (not nil) when there are items and none purchased")
    func progressZeroPurchased() throws {
        let progress = try #require(makeSUT(itemCount: 5, purchasedCount: 0).progress)
        #expect(abs(progress) < 0.000_001)
    }

    @Test("Progress is nil when both counts are absent")
    func progressNilWhenBothAbsent() {
        #expect(makeSUT(itemCount: nil, purchasedCount: nil).progress == nil)
    }

    @Test("Progress is nil when only itemCount is present")
    func progressNilWhenPurchasedAbsent() {
        #expect(makeSUT(itemCount: 5, purchasedCount: nil).progress == nil)
    }

    @Test("Progress is nil when only purchasedCount is present")
    func progressNilWhenItemCountAbsent() {
        #expect(makeSUT(itemCount: nil, purchasedCount: 2).progress == nil)
    }

    @Test("Progress is nil when itemCount is 0 (no division by zero)")
    func progressNilWhenNoItems() {
        #expect(makeSUT(itemCount: 0, purchasedCount: 0).progress == nil)
    }

    @Test("ListDetail progress follows the same rules")
    func detailProgress() throws {
        let present = ListFixtures.listDetail(itemCount: 10, purchasedCount: 5)
        let value = try #require(present.progress)
        #expect(abs(value - 0.5) < 0.000_001)
        #expect(ListFixtures.listDetail(itemCount: nil, purchasedCount: nil).progress == nil)
        #expect(ListFixtures.listDetail(itemCount: 0, purchasedCount: 0).progress == nil)
        #expect(ListFixtures.listDetail(itemCount: 4, purchasedCount: nil).progress == nil)
    }
}
