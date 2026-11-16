//
//  GeneratedClientPurchaseHistoryResponseTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC2, AC5, AC6: the 200 outcomes of loadPage through the real factory-built client with a fake
//  transport and contract-accurate JSON. Rows keep the server's order (no re-sort), `meta.nextCursor`
//  becomes page.nextCursor (null or absent -> nil), an empty `data` is an empty page, money is an exact
//  Decimal, and a 200 whose body cannot be read is `.invalidResponse`.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseHistoryRepository 200", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseHistoryResponseTests {

    private func dec(_ text: String) -> Decimal { PurchaseHistoryFix.dec(text) }

    @Test("a 200 maps every field of a row")
    func mapsEveryField() async throws {
        let sut = try makePurchaseHistorySUT()
        let body = PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(
            id: "purchase-7", itemId: "item-9", itemName: "Fake Train", listId: "list-3",
            recipientId: "user-5", recipientName: "Sam Recipient", quantity: 3, totalCost: "45.5",
            shippingStatus: "DELIVERED"
        )], nextCursor: nil)
        await sut.transport.enqueue(status: 200, json: body)

        let page = try await sut.load()

        #expect(page.rows == [PurchaseHistoryRow(
            id: "purchase-7", itemId: "item-9", itemName: "Fake Train", listId: "list-3",
            recipientId: "user-5", recipientName: "Sam Recipient",
            purchasedAt: PurchaseHistoryWire.date(), quantity: 3, totalCost: dec("45.5"),
            shippingStatus: .delivered
        )])
        #expect(page.nextCursor == nil)
    }

    @Test("rows come back in the server's order, never re-sorted")
    func keepsServerOrder() async throws {
        let sut = try makePurchaseHistorySUT()
        let rows = [
            PurchaseHistoryWire.rowJSON(id: "b", purchasedAt: "2026-01-02T00:00:00.000Z"),
            PurchaseHistoryWire.rowJSON(id: "c", purchasedAt: "2026-03-09T00:00:00.000Z"),
            PurchaseHistoryWire.rowJSON(id: "a", purchasedAt: "2025-12-01T00:00:00.000Z")
        ]
        await sut.transport.enqueue(status: 200, json: PurchaseHistoryWire.envelope(rows, nextCursor: nil))

        let page = try await sut.load()

        #expect(page.rows.map(\.id) == ["b", "c", "a"])
    }

    @Test("meta.nextCursor becomes the page cursor, unchanged")
    func cursorIsCarried() async throws {
        let sut = try makePurchaseHistorySUT()
        let cursor = "eyJwIjoiMjAyNi0wMS0wNSJ9"
        await sut.transport.enqueue(
            status: 200, json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON()], nextCursor: cursor)
        )

        let page = try await sut.load()

        #expect(page.nextCursor == cursor)
    }

    @Test("a null nextCursor maps to nil")
    func nullCursorIsNil() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200, json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON()], nextCursor: nil)
        )

        #expect(try await sut.load().nextCursor == nil)
    }

    @Test("a nextCursor key that is absent maps to nil")
    func absentCursorIsNil() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200, json: PurchaseHistoryWire.envelopeWithoutCursorKey([PurchaseHistoryWire.rowJSON()])
        )

        #expect(try await sut.load().nextCursor == nil)
    }

    @Test("an empty data array maps to an empty page, with or without a cursor", arguments: [String?.none, "cursor-x"])
    func emptyPage(cursor: String?) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: PurchaseHistoryWire.envelope([], nextCursor: cursor))

        let page = try await sut.load()

        #expect(page.rows.isEmpty)
        #expect(page.nextCursor == cursor)
    }

    @Test("two pages in a row: the second request carries the first page's cursor and ends with no cursor")
    func multiplePages() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope(
                [PurchaseHistoryWire.rowJSON(id: "p1"), PurchaseHistoryWire.rowJSON(id: "p2")], nextCursor: "page-2"
            )
        )
        await sut.transport.enqueue(
            status: 200, json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(id: "p3")], nextCursor: nil)
        )

        let first = try await sut.load()
        let second = try await sut.load(cursor: first.nextCursor)

        #expect(first.rows.map(\.id) == ["p1", "p2"])
        #expect(first.nextCursor == "page-2")
        #expect(second.rows.map(\.id) == ["p3"])
        #expect(second.nextCursor == nil)
        let recorded = await sut.transport.recorded
        #expect(recorded.last?.request.path?.contains("cursor=page-2") == true)
    }

    @Test("money is an exact Decimal", arguments: ["19.99", "0", "1234.5", "79.99", "0.01", "999999.99"])
    func moneyIsExact(text: String) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(totalCost: text)], nextCursor: nil)
        )

        let page = try await sut.load()

        #expect(page.rows.first?.totalCost == dec(text))
    }

    @Test("each wire shipping status maps to the matching domain status", arguments: [0, 1, 2, 3])
    func shippingStatuses(index: Int) async throws {
        let pair = PurchaseHistoryFix.shippingPairs[index]
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(shippingStatus: pair.2)], nextCursor: nil)
        )

        #expect(try await sut.load().rows.first?.shippingStatus == pair.0)
    }

    @Test("a row with no item image still maps")
    func noImage() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(imageUrl: nil)], nextCursor: nil)
        )

        #expect(try await sut.load().rows.count == 1)
    }

    @Test("a blank item name is kept as is")
    func blankItemName() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(itemName: "")], nextCursor: nil)
        )

        #expect(try await sut.load().rows.first?.itemName == "")
    }

    // MARK: Unreadable 200

    @Test("a 200 whose body cannot be read throws invalidResponse", arguments: [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": [], \"meta\": { \"timestamp\": \"2026-11-02T00:00:00.000Z\" } }",
        "{ \"success\": true, \"data\": [ { \"id\": \"p1\" } ], \"meta\": \(ListWire.metaJSON) }"
    ])
    func unreadableBody(body: String) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: body)

        await #expect(throws: PurchaseHistoryError.invalidResponse) {
            _ = try await sut.load()
        }
    }

    @Test("a 200 with an unknown shipping status throws invalidResponse")
    func unknownShippingStatus() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: 200,
            json: PurchaseHistoryWire.envelope(
                [PurchaseHistoryWire.rowJSON(shippingStatus: "LOST_AT_SEA")], nextCursor: nil
            )
        )

        await #expect(throws: PurchaseHistoryError.invalidResponse) {
            _ = try await sut.load()
        }
    }

    @Test("a 200 with no body at all throws invalidResponse")
    func emptyBody() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueEmpty(status: 200)

        await #expect(throws: PurchaseHistoryError.invalidResponse) {
            _ = try await sut.load()
        }
    }
}
