//
//  ItemMappingTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the pure mapping from the generated item schemas to the domain `ListItem`.
//
//  Fixtures are generated-type values (Components.Schemas.Item, PurchaseSummary, PersonRef and
//  the getItem DataPayload) built with the generated memberwise initialisers, shaped like the
//  server responses of Docs/privacy-matrix.md and Docs/client-guide.md 5.4 / 6.x:
//   - blind owner, blind co-owner, VIEWER-role member and PUBLIC non-member receive every item
//     AVAILABLE with no updatedAt, no purchases and no off-list items;
//   - owner, co-owner and MEMBER see real status, updatedAt and (canSeeOffList) off-list items.
//  The mapper itself is flag-free: it must never invent a value, so absent stays nil.
//
//  Fails today because mapListItem, ListItem, ListItemPerson, ListItemPurchaseSummary and the
//  new ItemError cases do not exist yet.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("Item mapping Tests")
struct ItemMappingTests {

    // MARK: - Factory

    private func makeSUT(_ item: Components.Schemas.Item) throws -> ListItem {
        try mapListItem(item)
    }

    private func makeDetail(
        _ item: Components.Schemas.Item,
        purchases: [Components.Schemas.PurchaseSummary]? = nil,
        totalQuantityPurchased: Int? = nil
    ) throws -> ListItem {
        try mapListItem(ItemFixtures.wireDetail(item, purchases: purchases, totalQuantityPurchased: totalQuantityPurchased))
    }

    // MARK: - Field mapping

    @Test("Every field of a full item maps one to one")
    func fullItemMaps() throws {
        let wire = ItemFixtures.wireItem(
            id: "item-77", listId: "list-9", name: "Fake Lamp", description: "A fake lamp",
            url: "https://example.com/lamp", imageUrl: "https://example.com/lamp.png",
            price: 19.99, quantity: 3, priority: 8, status: .partial, offList: false,
            createdBy: ItemFixtures.wirePerson(id: "user-5", displayName: "Pat Owner"),
            createdAt: ItemFixtures.createdDate, updatedAt: ItemFixtures.updatedDate
        )
        let item = try makeSUT(wire)
        #expect(item.id == "item-77")
        #expect(item.listId == "list-9")
        #expect(item.name == "Fake Lamp")
        #expect(item.description == "A fake lamp")
        #expect(item.url == "https://example.com/lamp")
        #expect(item.imageUrl == "https://example.com/lamp.png")
        #expect(item.expectedUnitPrice == ItemFixtures.decimal("19.99"))
        #expect(item.quantityRequested == 3)
        #expect(item.priority == 8)
        #expect(item.status == .partial)
        #expect(item.offList == false)
        #expect(item.createdBy.id == "user-5")
        #expect(item.createdBy.displayName == "Pat Owner")
        #expect(item.createdAt == ItemFixtures.createdDate)
        #expect(item.updatedAt == ItemFixtures.updatedDate)
    }

    @Test("A list-endpoint item never carries purchases or a purchased quantity")
    func listItemHasNoPurchaseInformation() throws {
        let item = try makeSUT(ItemFixtures.wireItem(status: .purchased, updatedAt: ItemFixtures.updatedDate))
        #expect(item.purchases == nil)
        #expect(item.totalQuantityPurchased == nil)
    }

    @Test("Absent optional fields stay nil and nothing is invented")
    func absentOptionalsStayNil() throws {
        let item = try makeSUT(ItemFixtures.wireItem(url: nil, imageUrl: nil, price: nil, updatedAt: nil))
        #expect(item.url == nil)
        #expect(item.imageUrl == nil)
        #expect(item.expectedUnitPrice == nil)
        #expect(item.updatedAt == nil)
        #expect(item.purchases == nil)
        #expect(item.totalQuantityPurchased == nil)
    }

    // MARK: - Privacy scenarios

    @Test("Owner: real status, updatedAt and an off-list item the owner may see all map")
    func ownerScenario() throws {
        let regular = try makeSUT(ItemFixtures.wireItem(
            id: "regular", price: 19.99, status: .wrapped, offList: false,
            createdBy: ItemFixtures.wirePerson(id: "user-1", displayName: "Robin Owner"),
            updatedAt: ItemFixtures.updatedDate
        ))
        let surprise = try makeSUT(ItemFixtures.wireItem(
            id: "surprise", status: .purchased, offList: true,
            createdBy: ItemFixtures.wirePerson(id: "user-2", displayName: "Casey Member"),
            updatedAt: ItemFixtures.updatedDate
        ))
        #expect(regular.status == .wrapped)
        #expect(regular.updatedAt == ItemFixtures.updatedDate)
        #expect(surprise.offList == true)
        #expect(surprise.status == .purchased)
        #expect(surprise.createdBy.id == "user-2")
    }

    @Test("Blind owner: every item AVAILABLE, no updatedAt, no purchases, no off-list, nothing invented")
    func blindOwnerScenario() throws {
        let item = try makeSUT(ItemFixtures.wireItem(price: 19.99, status: .available, offList: false, updatedAt: nil))
        #expect(item.status == .available)
        #expect(item.offList == false)
        #expect(item.updatedAt == nil)
        #expect(item.purchases == nil)
        #expect(item.totalQuantityPurchased == nil)
        let detail = try makeDetail(ItemFixtures.wireItem(status: .available, updatedAt: nil))
        #expect(detail.purchases == nil)
        #expect(detail.totalQuantityPurchased == nil)
        #expect(detail.updatedAt == nil)
    }

    @Test("Co-owner: real status and updatedAt map; blind co-owner: available with nothing else")
    func coOwnerScenarios() throws {
        let coOwner = try makeSUT(ItemFixtures.wireItem(status: .gifted, updatedAt: ItemFixtures.updatedDate))
        #expect(coOwner.status == .gifted)
        #expect(coOwner.updatedAt == ItemFixtures.updatedDate)
        let blind = try makeSUT(ItemFixtures.wireItem(status: .available, updatedAt: nil))
        #expect(blind.status == .available)
        #expect(blind.updatedAt == nil)
        #expect(blind.purchases == nil)
    }

    @Test("MEMBER-role member: their own off-list item and another member's off-list item both map")
    func memberScenario() throws {
        let own = try makeSUT(ItemFixtures.wireItem(
            id: "mine", offList: true, createdBy: ItemFixtures.wirePerson(id: "user-1", displayName: "Me Member")
        ))
        let others = try makeSUT(ItemFixtures.wireItem(
            id: "theirs", offList: true, createdBy: ItemFixtures.wirePerson(id: "user-3", displayName: "Sam Member")
        ))
        #expect(own.offList == true)
        #expect(own.createdBy.id == "user-1")
        #expect(others.offList == true)
        #expect(others.createdBy.id == "user-3")
        #expect(own.createdBy != others.createdBy)
    }

    @Test("VIEWER-role member and PUBLIC non-member: available, no updatedAt, no purchases")
    func viewerAndPublicScenarios() throws {
        for id in ["viewer-item", "public-item"] {
            let item = try makeSUT(ItemFixtures.wireItem(id: id, status: .available, offList: false, updatedAt: nil))
            #expect(item.status == .available, "\(id)")
            #expect(item.updatedAt == nil, "\(id)")
            #expect(item.purchases == nil, "\(id)")
            #expect(item.totalQuantityPurchased == nil, "\(id)")
        }
    }

    // MARK: - Money

    @Test("Money maps to the exact two-decimal Decimal",
          arguments: [(19.99, "19.99"), (0.10, "0.10"), (1234.50, "1234.50"), (0.0, "0"), (999_999.99, "999999.99")])
    func moneyMapsExactly(value: Double, expected: String) throws {
        let item = try makeSUT(ItemFixtures.wireItem(price: value))
        #expect(item.expectedUnitPrice == ItemFixtures.decimal(expected))
    }

    @Test("A NaN or infinite price throws invalidResponse", arguments: [Double.nan, .infinity, -.infinity])
    func nonFinitePriceThrows(value: Double) {
        #expect(throws: ItemError.invalidResponse) {
            _ = try makeSUT(ItemFixtures.wireItem(price: value))
        }
    }

    @Test("A NaN or infinite purchase total in the detail throws invalidResponse",
          arguments: [Double.nan, .infinity, -.infinity])
    func nonFinitePurchaseTotalThrows(value: Double) {
        #expect(throws: ItemError.invalidResponse) {
            _ = try makeDetail(
                ItemFixtures.wireItem(),
                purchases: [ItemFixtures.wirePurchase(totalCost: value)],
                totalQuantityPurchased: 1
            )
        }
    }

    // MARK: - Status

    @Test("Every generated ItemStatus maps to the domain status of the same name",
          arguments: Components.Schemas.ItemStatus.allCases)
    func statusMapsOneToOne(wire: Components.Schemas.ItemStatus) throws {
        let expected: ItemStatus
        switch wire {
        case .available: expected = .available
        case .partial: expected = .partial
        case .purchased: expected = .purchased
        case .wrapped: expected = .wrapped
        case .gifted: expected = .gifted
        }
        let item = try makeSUT(ItemFixtures.wireItem(status: wire))
        #expect(item.status == expected)
        #expect(item.status.rawValue == wire.rawValue)
    }

    @Test("The domain status has exactly the five generated cases")
    func statusCaseCount() {
        #expect(Components.Schemas.ItemStatus.allCases.count == 5)
        for wire in Components.Schemas.ItemStatus.allCases {
            #expect(ItemStatus(rawValue: wire.rawValue) != nil, "\(wire.rawValue)")
        }
    }

    // MARK: - Detail

    @Test("Detail mapping takes purchases and totalQuantityPurchased from value2")
    func detailMapsPurchases() throws {
        let wireItem = ItemFixtures.wireItem(price: 19.99, quantity: 3, status: .partial, updatedAt: ItemFixtures.updatedDate)
        let purchases = [
            ItemFixtures.wirePurchase(
                id: "p-1", quantity: 1, totalCost: 19.99,
                purchaser: ItemFixtures.wirePerson(id: "user-3", displayName: "Sam Buyer"),
                purchasedAt: ItemFixtures.purchasedDate
            ),
            ItemFixtures.wirePurchase(id: "p-2", quantity: 2, totalCost: 1234.50)
        ]
        let item = try makeDetail(wireItem, purchases: purchases, totalQuantityPurchased: 3)
        #expect(item.id == wireItem.id)
        #expect(item.status == .partial)
        #expect(item.totalQuantityPurchased == 3)
        let mapped = try #require(item.purchases)
        #expect(mapped.count == 2)
        #expect(mapped[0].id == "p-1")
        #expect(mapped[0].quantity == 1)
        #expect(mapped[0].totalCost == ItemFixtures.decimal("19.99"))
        #expect(mapped[0].purchaser.id == "user-3")
        #expect(mapped[0].purchaser.displayName == "Sam Buyer")
        #expect(mapped[0].purchasedAt == ItemFixtures.purchasedDate)
        #expect(mapped[1].id == "p-2")
        #expect(mapped[1].totalCost == ItemFixtures.decimal("1234.50"))
    }

    @Test("Detail mapping keeps absent value2 fields nil and an empty purchase list empty")
    func detailAbsentAndEmpty() throws {
        let absent = try makeDetail(ItemFixtures.wireItem(), purchases: nil, totalQuantityPurchased: nil)
        #expect(absent.purchases == nil)
        #expect(absent.totalQuantityPurchased == nil)

        let empty = try makeDetail(ItemFixtures.wireItem(), purchases: [], totalQuantityPurchased: 0)
        #expect(empty.purchases == [])
        #expect(empty.totalQuantityPurchased == 0)
    }

    @Test("Detail mapping applies the same field and money rules to value1")
    func detailMapsValue1() throws {
        let wire = ItemFixtures.wireItem(price: 0.10, offList: true, updatedAt: nil)
        let item = try makeDetail(wire)
        #expect(item.expectedUnitPrice == ItemFixtures.decimal("0.10"))
        #expect(item.offList == true)
        #expect(item.updatedAt == nil)
    }

    @Test("Detail mapping of a NaN price throws invalidResponse")
    func detailNaNPriceThrows() {
        #expect(throws: ItemError.invalidResponse) {
            _ = try makeDetail(ItemFixtures.wireItem(price: .nan))
        }
    }
}
