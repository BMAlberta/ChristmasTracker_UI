//
//  ItemDetailStateRemainingTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A (decision P24): the remaining-quantity text of the item detail now comes from the
//  server's `quantityRemaining` (max(0, requested - purchased), computed by the server) and from
//  nothing else. When the server does not send it (callers without gift activity), the state
//  shows nothing: it never derives a value from `totalQuantityPurchased` or the requested
//  quantity, and a hidden-activity viewer sees nothing even if a value slips through.
//
//  These expectations replace the I3c-D ones that derived the value from totalQuantityPurchased.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item detail remaining quantity Tests")
struct ItemDetailStateRemainingTests {

    private func makeSUT(
        requested: Int,
        totalPurchased: Int? = nil,
        quantityRemaining: Int?,
        persona: ItemFixtures.Persona = .owner
    ) -> ItemDetailState {
        let item = ItemFixtures.item(
            quantity: requested,
            totalQuantityPurchased: totalPurchased,
            quantityPurchased: quantityRemaining.map { max(0, requested - $0) },
            quantityRemaining: quantityRemaining
        )
        return ItemDetailState(item: item, capabilities: persona.capabilities,
                               currentUserId: ItemFixtures.currentUserId, currencyCode: "USD",
                               locale: Locale(identifier: "en_US"), now: ItemFixtures.nowDate)
    }

    @Test("The remaining quantity is exactly the server's quantityRemaining", arguments: [0, 1, 3, 5])
    func remainingComesFromServer(remaining: Int) {
        #expect(makeSUT(requested: 5, quantityRemaining: remaining).remainingQuantity == remaining)
    }

    @Test("An over-purchased item shows the server's zero, never a negative value")
    func overPurchaseShowsServerZero() {
        let sut = makeSUT(requested: 2, totalPurchased: 5, quantityRemaining: 0)
        #expect(sut.remainingQuantity == 0)
    }

    @Test("An absent quantityRemaining shows nothing, even when totalQuantityPurchased could be subtracted")
    func absentIsNotComputed() {
        let sut = makeSUT(requested: 5, totalPurchased: 2, quantityRemaining: nil)
        #expect(sut.remainingQuantity == nil)
    }

    @Test("A caller who cannot see gift activity sees no remaining quantity even if one is present",
          arguments: [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember])
    func hiddenStaysNil(persona: ItemFixtures.Persona) {
        #expect(makeSUT(requested: 2, totalPurchased: 5, quantityRemaining: 0, persona: persona).remainingQuantity == nil,
                "\(persona)")
    }

    @Test("A caller who can see gift activity sees the value for owner, co-owner and member",
          arguments: [ItemFixtures.Persona.owner, .coOwner, .member])
    func visibleForGiftActivityPersonas(persona: ItemFixtures.Persona) {
        #expect(makeSUT(requested: 4, quantityRemaining: 1, persona: persona).remainingQuantity == 1, "\(persona)")
    }
}
