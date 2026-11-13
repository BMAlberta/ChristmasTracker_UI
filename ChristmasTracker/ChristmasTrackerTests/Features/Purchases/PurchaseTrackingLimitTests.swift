//
//  PurchaseTrackingLimitTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-A: the 100 UTF-16 unit tracking limit on the shipping section state, measured on the
//  TRIMMED draft. 100 is allowed, 101 blocks Save, an emoji counts as two units at the boundary,
//  and a too-long set is blocked while clearing a too-long original is allowed.
//
//  These tests pin the trackingChange member of PurchaseShippingSectionState.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase tracking limit Tests")
struct PurchaseTrackingLimitTests {

    private func makeSUT(tracking: String? = nil) -> PurchaseShippingSectionState {
        PurchaseShippingSectionState(
            purchase: PurchaseFixtures.recordedPurchase(trackingNumber: tracking, shippingStatus: .shipped)
        )
    }

    private func units(_ count: Int) -> String { String(repeating: "A", count: count) }

    @Test("Exactly 100 units can be saved; 101 is blocked", arguments: [
        (100, false), (101, true), (99, false), (102, true)
    ])
    func boundary(count: Int, tooLong: Bool) {
        let sut = makeSUT().editing(tracking: units(count))
        #expect(sut.trackingTooLong == tooLong)
        #expect(sut.canSave == !tooLong)
        #expect(sut.trackingChange == .set(units(count)))
    }

    @Test("An emoji at the boundary counts as two UTF-16 units")
    func emojiBoundary() {
        let at100 = makeSUT().editing(tracking: units(98) + "\u{1F600}")
        #expect(!at100.trackingTooLong)
        #expect(at100.canSave)
        let at101 = makeSUT().editing(tracking: units(99) + "\u{1F600}")
        #expect(at101.trackingTooLong)
        #expect(!at101.canSave)
    }

    @Test("The limit is measured on the trimmed draft")
    func trimmed() {
        let sut = makeSUT().editing(tracking: "  " + units(100) + " \n")
        #expect(!sut.trackingTooLong)
        #expect(sut.canSave)
    }

    @Test("A too-long tracking blocks Save even when the status also changed")
    func tooLongWithStatusChange() {
        let sut = makeSUT().editing(status: .delivered, tracking: units(101))
        #expect(sut.update != nil)
        #expect(!sut.canSave)
    }

    @Test("Clearing a too-long original is allowed")
    func clearTooLongOriginal() {
        let sut = makeSUT(tracking: units(120)).editing(tracking: "")
        #expect(sut.trackingChange == .clear)
        #expect(!sut.trackingTooLong)
        #expect(sut.canSave)
    }
}
