//
//  GeneratedClientItemRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: GeneratedClientItemRepository through the REAL factory-built client with a fake
//  transport and guide-accurate literal JSON (full `meta` object). This file covers the success
//  mapping and the request shape; GeneratedClientItemRepositoryErrorTests covers every failure.
//
//  Privacy fixtures follow Docs/client-guide.md 6.2 to 6.4 and Docs/privacy-matrix.md: blind
//  viewers, VIEWER-role members and PUBLIC non-members receive every item AVAILABLE with no
//  updatedAt and no off-list items; the list endpoint never carries purchases.
//
//  These tests do not compile until the implementer adds GeneratedClientItemRepository and moves
//  ItemRepository to the ListItem-typed signatures.
//

import Testing
import Foundation
import HTTPTypes
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientItemRepository", .timeLimit(.minutes(1)))
struct GeneratedClientItemRepositoryTests {

    // MARK: fetchItems success

    @Test("fetchItems maps every field of a fully visible item (status, updatedAt, off-list, creator)")
    func fetchItemsMapsFullyVisibleItems() async throws {
        let sut = try makeItemRepoSUT()
        let regular = ItemWire.itemJSON(
            id: "item-1", name: "Fake Lamp", description: "A fake lamp",
            url: "https://example.com/lamp", imageUrl: "https://example.com/lamp.png", price: "19.99",
            quantity: 3, priority: 8, status: "PARTIAL", offList: false,
            createdById: "user-1", createdByName: "Robin Owner", updatedAt: "2026-01-06T09:45:00.000Z"
        )
        let surprise = ItemWire.itemJSON(
            id: "item-2", name: "Fake Scarf", status: "WRAPPED", offList: true,
            createdById: "user-2", createdByName: "Casey Member", updatedAt: "2026-01-06T09:45:00.000Z"
        )
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([regular, surprise]))

        let items = try await sut.repo.fetchItems(listId: "list-1")

        #expect(items.map(\.id) == ["item-1", "item-2"])
        let first = try #require(items.first)
        #expect(first.listId == "list-1")
        #expect(first.name == "Fake Lamp")
        #expect(first.description == "A fake lamp")
        #expect(first.url == "https://example.com/lamp")
        #expect(first.imageUrl == "https://example.com/lamp.png")
        #expect(first.expectedUnitPrice == ItemFixtures.decimal("19.99"))
        #expect(first.quantityRequested == 3)
        #expect(first.priority == 8)
        #expect(first.status == .partial)
        #expect(first.offList == false)
        #expect(first.createdBy == ListItemPerson(id: "user-1", displayName: "Robin Owner"))
        #expect(first.updatedAt != nil)
        let second = try #require(items.last)
        #expect(second.status == .wrapped)
        #expect(second.offList == true)
        #expect(second.createdBy.id == "user-2")
    }

    @Test("fetchItems maps every item status one to one", arguments: [
        ("AVAILABLE", ItemStatus.available), ("PARTIAL", .partial), ("PURCHASED", .purchased),
        ("WRAPPED", .wrapped), ("GIFTED", .gifted)
    ])
    func fetchItemsMapsStatuses(raw: String, expected: ItemStatus) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([ItemWire.itemJSON(status: raw)]))

        let item = try #require(try await sut.repo.fetchItems(listId: "list-1").first)

        #expect(item.status == expected)
    }

    @Test("fetchItems for a blind viewer decodes: all AVAILABLE, updatedAt absent, no purchases, no off-list items")
    func fetchItemsBlindViewer() async throws {
        let sut = try makeItemRepoSUT()
        let body = ItemWire.listJSON([
            ItemWire.itemJSON(id: "item-1", price: "19.99", status: "AVAILABLE", updatedAt: nil),
            ItemWire.itemJSON(id: "item-2", status: "AVAILABLE", updatedAt: nil)
        ])
        await sut.transport.enqueue(status: 200, json: body)

        let items = try await sut.repo.fetchItems(listId: "list-1")

        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.status == .available })
        #expect(items.allSatisfy { $0.updatedAt == nil }, "an absent updatedAt stays nil, nothing is invented")
        #expect(items.allSatisfy { $0.purchases == nil })
        #expect(items.allSatisfy { $0.totalQuantityPurchased == nil })
        #expect(items.allSatisfy { !$0.offList })
    }

    @Test("fetchItems accepts an explicit JSON null for the optional fields")
    func fetchItemsAcceptsNulls() async throws {
        let sut = try makeItemRepoSUT()
        let item = ItemWire.itemJSON(extra: "\"url\": null, \"imageUrl\": null, \"expectedUnitPrice\": null, \"updatedAt\": null")
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([item]))

        let mapped = try #require(try await sut.repo.fetchItems(listId: "list-1").first)

        #expect(mapped.url == nil)
        #expect(mapped.imageUrl == nil)
        #expect(mapped.expectedUnitPrice == nil)
        #expect(mapped.updatedAt == nil)
    }

    @Test("fetchItems with an empty data array returns an empty array")
    func fetchItemsEmpty() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([]))

        let items = try await sut.repo.fetchItems(listId: "list-1")

        #expect(items.isEmpty)
    }

    @Test("fetchItems of an optional-free item has no price, url or image")
    func fetchItemsWithoutOptionals() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([ItemWire.itemJSON()]))

        let item = try #require(try await sut.repo.fetchItems(listId: "list-1").first)

        #expect(item.expectedUnitPrice == nil)
        #expect(item.url == nil)
        #expect(item.imageUrl == nil)
    }

    // MARK: Money (C11): JSON numbers with at most two decimals, no drift

    @Test("money in a list response round-trips with no drift", arguments: ["19.99", "0.10", "1234.50", "0", "0.01", "999999.99"])
    func moneyListResponse(price: String) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([ItemWire.itemJSON(price: price)]))

        let item = try #require(try await sut.repo.fetchItems(listId: "list-1").first)

        #expect(item.expectedUnitPrice == ItemFixtures.decimal(price))
    }

    @Test("money in a detail response and its purchase totals round-trip with no drift", arguments: ["19.99", "0.10", "1234.50"])
    func moneyDetailResponse(price: String) async throws {
        let sut = try makeItemRepoSUT()
        let body = ItemWire.detailEnvelope(
            item: ItemWire.itemJSON(price: price, status: "PURCHASED"),
            purchases: [ItemWire.purchaseJSON(totalCost: price)],
            totalQuantityPurchased: 1
        )
        await sut.transport.enqueue(status: 200, json: body)

        let item = try await sut.repo.fetchItemDetail(id: "item-1")

        #expect(item.expectedUnitPrice == ItemFixtures.decimal(price))
        #expect(item.purchases?.first?.totalCost == ItemFixtures.decimal(price))
    }

    @Test("money in a create and update response round-trips")
    func moneyCreateAndUpdateResponse() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 201, json: ItemWire.itemEnvelope(ItemWire.itemJSON(price: "0.10")))
        await sut.transport.enqueue(status: 200, json: ItemWire.itemEnvelope(ItemWire.itemJSON(price: "1234.50")))

        let created = try await sut.repo.createItem(listId: "list-1", sampleCreateItemInput(price: ItemFixtures.decimal("0.10")))
        let updated = try await sut.repo.updateItem(id: "item-1", UpdateItemInput(expectedUnitPrice: ItemFixtures.decimal("1234.50")))

        #expect(created.expectedUnitPrice == ItemFixtures.decimal("0.10"))
        #expect(updated.expectedUnitPrice == ItemFixtures.decimal("1234.50"))
    }

    @Test("money in a request is sent with no three-decimal drift", arguments: [
        ("19.99", "19.99"), ("0.10", "0.1"), ("1234.50", "1234.5"), ("0", "0"), ("999999.99", "999999.99")
    ])
    func moneyRequestBody(price: String, wire: String) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 201, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))
        await sut.transport.enqueue(status: 200, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))

        _ = try await sut.repo.createItem(listId: "list-1", sampleCreateItemInput(price: ItemFixtures.decimal(price)))
        _ = try await sut.repo.updateItem(id: "item-1", UpdateItemInput(expectedUnitPrice: ItemFixtures.decimal(price)))

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 2)
        for request in recorded {
            let number = try #require(request.jsonObject?["expectedUnitPrice"] as? NSNumber)
            #expect(number.stringValue == wire, "the price must reach the wire as exactly \(wire)")
        }
    }

    // MARK: fetchItemDetail success

    @Test("fetchItemDetail maps purchases and the purchased quantity")
    func fetchItemDetailMapsPurchases() async throws {
        let sut = try makeItemRepoSUT()
        let body = ItemWire.detailEnvelope(
            item: ItemWire.itemJSON(price: "19.99", quantity: 3, status: "PARTIAL", updatedAt: "2026-01-06T09:45:00.000Z"),
            purchases: [
                ItemWire.purchaseJSON(id: "purchase-1", quantity: 1, totalCost: "19.99", purchaserId: "user-3", purchaserName: "Sam Buyer"),
                ItemWire.purchaseJSON(id: "purchase-2", quantity: 1, totalCost: "20.50", purchaserId: "user-4", purchaserName: "Lee Buyer")
            ],
            totalQuantityPurchased: 2
        )
        await sut.transport.enqueue(status: 200, json: body)

        let item = try await sut.repo.fetchItemDetail(id: "item-1")

        #expect(item.status == .partial)
        #expect(item.totalQuantityPurchased == 2)
        let purchases = try #require(item.purchases)
        #expect(purchases.map(\.id) == ["purchase-1", "purchase-2"])
        #expect(purchases.first?.quantity == 1)
        #expect(purchases.first?.purchaser == ListItemPerson(id: "user-3", displayName: "Sam Buyer"))
        #expect(purchases.last?.totalCost == ItemFixtures.decimal("20.50"))
        #expect(item.updatedAt != nil)
    }

    @Test("fetchItemDetail for a blind viewer: no purchases key, no purchased quantity, no updatedAt")
    func fetchItemDetailBlindViewer() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.detailEnvelope(item: ItemWire.itemJSON(status: "AVAILABLE")))

        let item = try await sut.repo.fetchItemDetail(id: "item-1")

        #expect(item.status == .available)
        #expect(item.purchases == nil, "an absent purchases key stays nil, not an empty array")
        #expect(item.totalQuantityPurchased == nil)
        #expect(item.updatedAt == nil)
    }

    @Test("fetchItemDetail keeps an empty purchases array empty (not nil)")
    func fetchItemDetailEmptyPurchases() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(
            status: 200,
            json: ItemWire.detailEnvelope(item: ItemWire.itemJSON(), purchases: [], totalQuantityPurchased: 0)
        )

        let item = try await sut.repo.fetchItemDetail(id: "item-1")

        #expect(item.purchases?.isEmpty == true)
        #expect(item.totalQuantityPurchased == 0)
    }

    // MARK: create / update / delete success

    @Test("createItem 201 returns the mapped item, with the server-derived offList")
    func createItemSuccess() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(
            status: 201,
            json: ItemWire.itemEnvelope(ItemWire.itemJSON(id: "item-new", name: "Fake Lamp", offList: true))
        )

        let item = try await sut.repo.createItem(listId: "list-1", sampleCreateItemInput())

        #expect(item.id == "item-new")
        #expect(item.offList == true, "offList comes from the server response only")
    }

    @Test("updateItem 200 returns the mapped item")
    func updateItemSuccess() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(
            status: 200,
            json: ItemWire.itemEnvelope(ItemWire.itemJSON(name: "Renamed", updatedAt: "2026-01-08T09:45:00.000Z"))
        )

        let item = try await sut.repo.updateItem(id: "item-1", UpdateItemInput(name: "Renamed"))

        #expect(item.name == "Renamed")
        #expect(item.updatedAt != nil)
    }

    @Test("deleteItem 200 completes and returns nothing")
    func deleteItemSuccess() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.deletedJSON())

        try await sut.repo.deleteItem(id: "item-1")

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Request shape: method, path, headers, token

    @Test("every operation uses the right method and path", arguments: ItemRepoOp.allCases)
    func methodAndPath(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == op.method)
        #expect(recorded.pathOnly == op.path)
    }

    @Test("every request carries X-Platform, X-Build, X-App-Version, X-Client-Platform and the bearer token", arguments: ItemRepoOp.allCases)
    func requestHeaders(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.successJSON())

        try await op.run(sut.repo)

        let recorded = try #require(await sut.transport.lastRequest())
        let fields = recorded.request.headerFields
        let platform = try #require(ListWire.headerName("X-Platform"))
        let build = try #require(ListWire.headerName("X-Build"))
        let version = try #require(ListWire.headerName("X-App-Version"))
        let clientPlatform = try #require(ListWire.headerName("X-Client-Platform"))
        let cookie = try #require(ListWire.headerName("Cookie"))
        #expect(fields[platform] == "ios")
        #expect(fields[build] == "1")
        #expect(fields[version] == "1.0.0")
        #expect(fields[clientPlatform] == "ios")
        #expect(fields[.authorization] == "Bearer \(itemRepoAccessToken)")
        #expect(fields[cookie] == nil)
    }

    @Test("no operation sends a query string")
    func noQueryStrings() async throws {
        let sut = try makeItemRepoSUT()
        for op in ItemRepoOp.allCases {
            await sut.transport.enqueue(status: op.successStatus, json: op.successJSON())
            try await op.run(sut.repo)
        }

        let recorded = await sut.transport.recorded
        #expect(recorded.count == ItemRepoOp.allCases.count)
        #expect(recorded.allSatisfy { !$0.hasQuery })
    }

    @Test("fetchItems, fetchItemDetail and deleteItem send no request body")
    func noBodyOnGetAndDelete() async throws {
        let sut = try makeItemRepoSUT()
        for op in [ItemRepoOp.fetchItems, .fetchItemDetail, .deleteItem] {
            await sut.transport.enqueue(status: op.successStatus, json: op.successJSON())
            try await op.run(sut.repo)
        }

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 3)
        #expect(recorded.allSatisfy { ($0.bodyData ?? Data()).isEmpty })
    }

    // MARK: Request body: createItem

    @Test("createItem body has exactly the supplied fields when no optional is supplied, and NO offList key")
    func createItemBodyWithoutOptionals() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 201, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))

        _ = try await sut.repo.createItem(listId: "list-1", sampleCreateItemInput())

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["name", "description", "quantityRequested", "priority"])
        #expect(body["name"] as? String == "Fake Lamp")
        #expect(body["description"] as? String == "A fake lamp")
        #expect(body["quantityRequested"] as? Int == 2)
        #expect(body["priority"] as? Int == 7)
        #expect(body["offList"] == nil, "the server derives offList; the client must never send it")
    }

    @Test("createItem body adds url, imageUrl and expectedUnitPrice only when supplied")
    func createItemBodyWithOptionals() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 201, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))

        _ = try await sut.repo.createItem(
            listId: "list-1",
            sampleCreateItemInput(
                price: ItemFixtures.decimal("19.99"), url: "https://example.com/lamp", imageUrl: "https://example.com/lamp.png"
            )
        )

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == ["name", "description", "quantityRequested", "priority", "url", "imageUrl", "expectedUnitPrice"])
        #expect(body["url"] as? String == "https://example.com/lamp")
        #expect(body["imageUrl"] as? String == "https://example.com/lamp.png")
        #expect(body["offList"] == nil)
    }

    @Test("createItem never sends offList, status or createdBy", arguments: [false, true])
    func createItemBodyNeverHasForbiddenKeys(withOptionals: Bool) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 201, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))
        let input = withOptionals
            ? sampleCreateItemInput(price: ItemFixtures.decimal("1.50"), url: "https://example.com/a", imageUrl: "https://example.com/a.png")
            : sampleCreateItemInput()

        _ = try await sut.repo.createItem(listId: "list-1", input)

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        for forbidden in ["offList", "status", "createdBy", "listId", "id"] {
            #expect(body[forbidden] == nil, "\(forbidden) must not be sent on create")
        }
        let text = String(decoding: recorded.bodyData ?? Data(), as: UTF8.self)
        #expect(!text.contains("offList"))
    }

    // MARK: Request body: updateItem

    @Test("updateItem sends only the changed fields", arguments: [
        (UpdateItemInput(name: "New Name"), ["name"]),
        (UpdateItemInput(description: "New description"), ["description"]),
        (UpdateItemInput(url: "https://example.com/new"), ["url"]),
        (UpdateItemInput(imageUrl: "https://example.com/new.png"), ["imageUrl"]),
        (UpdateItemInput(expectedUnitPrice: Decimal(string: "9.99")), ["expectedUnitPrice"]),
        (UpdateItemInput(quantityRequested: 4), ["quantityRequested"]),
        (UpdateItemInput(priority: 9), ["priority"]),
        (UpdateItemInput(name: "N", quantityRequested: 2, priority: 3), ["name", "quantityRequested", "priority"]),
        (
            UpdateItemInput(
                name: "N", description: "D", url: "https://example.com/u", imageUrl: "https://example.com/i",
                expectedUnitPrice: Decimal(string: "1.25"), quantityRequested: 5, priority: 6
            ),
            ["name", "description", "url", "imageUrl", "expectedUnitPrice", "quantityRequested", "priority"]
        )
    ])
    func updateItemSendsOnlyChangedFields(input: UpdateItemInput, expectedKeys: [String]) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))

        _ = try await sut.repo.updateItem(id: "item-1", input)

        let recorded = try #require(await sut.transport.lastRequest())
        #expect(recorded.request.method == .patch)
        let body = try #require(recorded.jsonObject)
        #expect(Set(body.keys) == Set(expectedKeys))
        #expect(body["offList"] == nil)
        #expect(body["status"] == nil)
    }

    @Test("updateItem sends the values of the changed fields")
    func updateItemBodyValues() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.itemEnvelope(ItemWire.itemJSON()))

        _ = try await sut.repo.updateItem(
            id: "item-1",
            UpdateItemInput(name: "New Name", description: "New description", quantityRequested: 4, priority: 9)
        )

        let recorded = try #require(await sut.transport.lastRequest())
        let body = try #require(recorded.jsonObject)
        #expect(body["name"] as? String == "New Name")
        #expect(body["description"] as? String == "New description")
        #expect(body["quantityRequested"] as? Int == 4)
        #expect(body["priority"] as? Int == 9)
    }
}
