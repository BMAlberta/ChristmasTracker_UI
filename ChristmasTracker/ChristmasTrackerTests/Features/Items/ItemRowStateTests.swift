//
//  ItemRowStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the display state of one item row. The Gate 1 addendum fixes no public
//  initialiser for ItemRowState, so rows are obtained through ItemListState (the only
//  producer) and read back by id.
//
//  Fails today because ItemRowState and ItemListState do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item row state Tests")
struct ItemRowStateTests {

    // MARK: - Factory

    private func makeSUT(
        _ item: ListItem,
        capabilities: ListCapabilities,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) throws -> ItemRowState {
        let state = ItemListState(
            items: [item], capabilities: capabilities, currentUserId: ItemFixtures.currentUserId,
            currencyCode: currencyCode, locale: locale
        )
        return try #require(state.sections.flatMap(\.rows).first { $0.id == item.id },
                            "Row \(item.id) is missing from the list state")
    }

    private var owner: ListCapabilities { ItemFixtures.Persona.owner.capabilities }

    // MARK: - Basic fields

    @Test("The row carries the item id and name")
    func idAndName() throws {
        let row = try makeSUT(ItemFixtures.item(id: "item-42", name: "Fake Lamp"), capabilities: owner)
        #expect(row.id == "item-42")
        #expect(row.name == "Fake Lamp")
    }

    @Test("Quantity and priority texts are non-empty and show their numbers")
    func quantityAndPriorityText() throws {
        let row = try makeSUT(ItemFixtures.item(quantity: 7, priority: 9), capabilities: owner)
        #expect(!row.quantityText.isEmpty)
        #expect(row.quantityText.contains("7"))
        #expect(!row.priorityText.isEmpty)
        #expect(row.priorityText.contains("9"))
    }

    // MARK: - Price

    @Test("Price renders as currency in USD / en_US",
          arguments: [("19.99", "$19.99"), ("0.10", "$0.10"), ("1234.50", "$1,234.50"), ("0", "$0.00")])
    func priceText(price: String, expected: String) throws {
        let row = try makeSUT(ItemFixtures.item(price: ItemFixtures.decimal(price)), capabilities: owner)
        #expect(row.priceText == expected)
    }

    @Test("A missing price gives no price text")
    func nilPrice() throws {
        let row = try makeSUT(ItemFixtures.item(price: nil), capabilities: owner)
        #expect(row.priceText == nil)
    }

    @Test("Price text is not shown differently to a blind viewer (price is not gift activity)")
    func priceTextForBlindViewer() throws {
        let row = try makeSUT(
            ItemFixtures.item(price: ItemFixtures.decimal("19.99")),
            capabilities: ItemFixtures.Persona.viewer.capabilities
        )
        #expect(row.priceText == "$19.99")
    }

    // MARK: - Status marker and completion

    @Test("With gift activity the marker is the item status and completion follows purchased, wrapped, gifted",
          arguments: ItemStatus.allCasesForTests)
    func markerWithGiftActivity(status: ItemStatus) throws {
        let row = try makeSUT(ItemFixtures.item(status: status), capabilities: owner)
        #expect(row.statusMarker == status)
        switch status {
        case .purchased, .wrapped, .gifted:
            #expect(row.isCompleted == true)
        case .available:
            #expect(row.isCompleted == false)
        case .partial:
            break // whether a partial purchase counts as completed is not fixed by the addendum
        }
    }

    @Test("Without gift activity there is never a marker or completion, whatever the item status",
          arguments: ItemStatus.allCasesForTests)
    func noMarkerWithoutGiftActivity(status: ItemStatus) throws {
        for persona in [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember] {
            let row = try makeSUT(ItemFixtures.item(status: status), capabilities: persona.capabilities)
            #expect(row.statusMarker == nil, "\(persona) \(status)")
            #expect(row.isCompleted == false, "\(persona) \(status)")
        }
    }

    // MARK: - Off-list badge

    @Test("The off-list badge shows exactly when the item is off-list and canSeeOffList is true")
    func offListBadge() throws {
        let surprise = ItemFixtures.item(id: "surprise", offList: true)
        let regular = ItemFixtures.item(id: "regular", offList: false)
        let canSee = ItemFixtures.Persona.member.capabilities
        #expect(try makeSUT(surprise, capabilities: canSee).showsOffListBadge == true)
        #expect(try makeSUT(regular, capabilities: canSee).showsOffListBadge == false)
    }

    @Test("A blind viewer never gets an off-list badge (the item is filtered out before it)")
    func offListBadgeHiddenForBlindViewer() {
        let state = ItemListState(
            items: [ItemFixtures.item(id: "surprise", offList: true)],
            capabilities: ItemFixtures.Persona.blindOwner.capabilities,
            currentUserId: ItemFixtures.currentUserId
        )
        #expect(state.sections.flatMap(\.rows).isEmpty)
    }

    // MARK: - Equatable

    @Test("Equal items give equal rows")
    func equatable() throws {
        let item = ItemFixtures.item(price: ItemFixtures.decimal("5"))
        #expect(try makeSUT(item, capabilities: owner) == makeSUT(item, capabilities: owner))
        let other = ItemFixtures.item(name: "Different")
        #expect(try makeSUT(item, capabilities: owner) != makeSUT(other, capabilities: owner))
    }
}

private extension ItemStatus {
    /// The five domain cases, listed explicitly so the test does not depend on CaseIterable.
    nonisolated static var allCasesForTests: [ItemStatus] { [.available, .partial, .purchased, .wrapped, .gifted] }
}
