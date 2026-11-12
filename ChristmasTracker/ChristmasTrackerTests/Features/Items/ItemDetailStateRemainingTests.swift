//
//  ItemDetailStateRemainingTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D, carried Story C finding: `remainingQuantity` was unclamped, so an over-purchased
//  item (more bought than requested) would print a negative remaining. Chosen contract
//  (Gate 1 addendum allows max(0, ...) or showing nothing): an over-purchase yields a
//  NON-NEGATIVE value or nil, never a negative number. The existing in-range expectations
//  (requested 5, bought 2 -> 3) are unchanged.
//
//  The over-purchase case fails today because the value is -3.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item detail remaining quantity Tests")
struct ItemDetailStateRemainingTests {

    private func makeSUT(requested: Int, purchased: Int?, persona: ItemFixtures.Persona = .owner) -> ItemDetailState {
        let item = ItemFixtures.item(quantity: requested, totalQuantityPurchased: purchased)
        return ItemDetailState(item: item, capabilities: persona.capabilities,
                               currentUserId: ItemFixtures.currentUserId, currencyCode: "USD",
                               locale: Locale(identifier: "en_US"), now: ItemFixtures.nowDate)
    }

    @Test("An over-purchase never yields a negative remaining", arguments: [(2, 5), (1, 2), (4, 100)])
    func overPurchaseNotNegative(requested: Int, purchased: Int) {
        let sut = makeSUT(requested: requested, purchased: purchased)
        #expect((sut.remainingQuantity ?? 0) >= 0, "requested \(requested), purchased \(purchased)")
    }

    @Test("Exactly fully purchased is zero or nil, never negative")
    func fullyPurchased() {
        let sut = makeSUT(requested: 3, purchased: 3)
        #expect((sut.remainingQuantity ?? 0) == 0)
    }

    @Test("A partial purchase still shows requested minus purchased")
    func partialUnchanged() {
        #expect(makeSUT(requested: 5, purchased: 2).remainingQuantity == 3)
    }

    @Test("A hidden-activity viewer still sees no remaining quantity, over-purchased or not")
    func hiddenStaysNil() {
        #expect(makeSUT(requested: 2, purchased: 5, persona: .blindOwner).remainingQuantity == nil)
    }
}
