//
//  ItemImageUrlStateTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T6: ItemRowState and ItemDetailState carry the item's imageUrl, unchanged.
//  Presentation only: the value is copied, not validated, at this layer.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item image url state Tests")
struct ItemImageUrlStateTests {

    private let capabilities = ItemFixtures.Persona.owner.capabilities
    private let fakeUrl = "https://example.test/a.png"

    private func makeRow(_ item: ListItem) throws -> ItemRowState {
        let state = ItemListState(items: [item], capabilities: capabilities, currentUserId: ItemFixtures.currentUserId)
        return try #require(state.sections.flatMap(\.rows).first { $0.id == item.id })
    }

    private func makeDetail(_ item: ListItem) -> ItemDetailState {
        ItemDetailState(item: item, capabilities: capabilities, currentUserId: ItemFixtures.currentUserId,
                        now: ItemFixtures.nowDate)
    }

    @Test("A row carries a nil imageUrl")
    func rowNil() throws {
        let row = try makeRow(ItemFixtures.item(imageUrl: nil))
        #expect(row.imageUrl == nil)
    }

    @Test("A row carries the item's imageUrl")
    func rowValue() throws {
        let row = try makeRow(ItemFixtures.item(imageUrl: fakeUrl))
        #expect(row.imageUrl == fakeUrl)
    }

    @Test("A detail state carries a nil imageUrl")
    func detailNil() {
        #expect(makeDetail(ItemFixtures.item(imageUrl: nil)).imageUrl == nil)
    }

    @Test("A detail state carries the item's imageUrl")
    func detailValue() {
        #expect(makeDetail(ItemFixtures.item(imageUrl: fakeUrl)).imageUrl == fakeUrl)
    }
}
