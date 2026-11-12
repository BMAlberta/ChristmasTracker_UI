//
//  ItemPurchaseRowStateTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the item purchase card rows. A row opens only for the signed-in purchaser
//  (PurchasePermissions.canManage on purchase.purchaser.id); the accessibility hint is
//  "Opens your purchase" exactly when it opens. Rows exist only when canSeeGiftActivity, so blind
//  owners, blind co-owners, viewer-role members and PUBLIC non-members get no rows at all. The
//  list status is not an input: archived lists behave the same.
//
//  Fails today because PurchaseRowState has no canOpen or accessibilityHint yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Item purchase row state Tests")
struct ItemPurchaseRowStateTests {

    private let ownPurchaserId = ItemFixtures.currentUserId

    private func makeSUT(
        capabilities: ListCapabilities,
        currentUserId: String? = ItemFixtures.currentUserId
    ) -> ItemDetailState {
        let item = ItemFixtures.item(
            id: "item-rich", name: "Fake Lamp", quantity: 4, status: .partial,
            purchases: [
                ItemFixtures.purchase(
                    id: "p-own", purchaser: ItemFixtures.person(id: ItemFixtures.currentUserId, displayName: "Pat Self")
                ),
                ItemFixtures.purchase(
                    id: "p-other", purchaser: ItemFixtures.person(id: ItemFixtures.thirdUserId, displayName: "Sam Buyer")
                )
            ],
            totalQuantityPurchased: 2, quantityPurchased: 2, quantityRemaining: 2
        )
        return ItemDetailState(
            item: item, capabilities: capabilities, currentUserId: currentUserId,
            currencyCode: "USD", locale: Locale(identifier: "en_US"), now: ItemFixtures.nowDate
        )
    }

    private func row(_ id: String, in state: ItemDetailState) -> PurchaseRowState? {
        state.purchases.first { $0.id == id }
    }

    private static let seeingPersonas: [ItemFixtures.Persona] = [.owner, .coOwner, .member]
    private static let blindPersonas: [ItemFixtures.Persona] = [.blindOwner, .blindCoOwner, .viewer, .publicNonMember]

    @Test("The caller's own purchase row opens with the hint; another user's row is read-only",
          arguments: seeingPersonas)
    func ownRowOpensActive(persona: ItemFixtures.Persona) throws {
        let sut = makeSUT(capabilities: persona.capabilities)
        let own = try #require(row("p-own", in: sut))
        let other = try #require(row("p-other", in: sut))
        #expect(own.canOpen, "\(persona)")
        #expect(own.accessibilityHint == "Opens your purchase", "\(persona)")
        #expect(!other.canOpen, "\(persona)")
        #expect(other.accessibilityHint == nil, "\(persona)")
    }

    @Test("The same on an archived list: the list status is not an input",
          arguments: seeingPersonas)
    func ownRowOpensArchived(persona: ItemFixtures.Persona) throws {
        let sut = makeSUT(capabilities: persona.archivedCapabilities)
        let own = try #require(row("p-own", in: sut))
        let other = try #require(row("p-other", in: sut))
        #expect(own.canOpen, "\(persona)")
        #expect(own.accessibilityHint == "Opens your purchase", "\(persona)")
        #expect(!other.canOpen, "\(persona)")
        #expect(other.accessibilityHint == nil, "\(persona)")
    }

    @Test("Blind owner, blind co-owner, viewer and PUBLIC get no rows at all, on active and archived lists",
          arguments: blindPersonas)
    func noRows(persona: ItemFixtures.Persona) {
        #expect(makeSUT(capabilities: persona.capabilities).purchases.isEmpty, "\(persona) active")
        #expect(makeSUT(capabilities: persona.archivedCapabilities).purchases.isEmpty, "\(persona) archived")
    }

    @Test("Without a signed-in user no row opens and no row has a hint", arguments: seeingPersonas)
    func noCurrentUser(persona: ItemFixtures.Persona) {
        for capabilities in [persona.capabilities, persona.archivedCapabilities] {
            let sut = makeSUT(capabilities: capabilities, currentUserId: nil)
            #expect(sut.purchases.count == 2, "\(persona)")
            #expect(sut.purchases.allSatisfy { !$0.canOpen && $0.accessibilityHint == nil }, "\(persona)")
        }
    }

    @Test("A different signed-in user opens only the rows they bought", arguments: seeingPersonas)
    func otherSignedInUser(persona: ItemFixtures.Persona) throws {
        let sut = makeSUT(capabilities: persona.capabilities, currentUserId: ItemFixtures.thirdUserId)
        let other = try #require(row("p-other", in: sut))
        let own = try #require(row("p-own", in: sut))
        #expect(other.canOpen)
        #expect(!own.canOpen)
    }

    @Test("Row state is identical on active and archived lists for every persona",
          arguments: ItemFixtures.Persona.allCases)
    func archivedMatchesActive(persona: ItemFixtures.Persona) {
        #expect(makeSUT(capabilities: persona.capabilities).purchases
                == makeSUT(capabilities: persona.archivedCapabilities).purchases, "\(persona)")
    }

    @Test("The existing row fields are unchanged by the new members")
    func existingFieldsKept() throws {
        let sut = makeSUT(capabilities: ItemFixtures.Persona.owner.capabilities)
        let own = try #require(row("p-own", in: sut))
        #expect(own.quantity == 1)
        #expect(own.totalCostText == "$19.99")
        #expect(own.purchaserName == "Pat Self")
    }
}
