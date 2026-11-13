//
//  GeneratedClientPurchaseManagementRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: the 200 outcomes of getPurchase, updatePurchase, updatePurchaseShipping and
//  deletePurchase through the REAL factory-built client with a fake transport and guide-accurate
//  literal JSON (client guide 7.6, 7.7, full `meta`, purchase shape with item {id, name, listId}).
//  The request shape is in GeneratedClientPurchaseManagementRequestTests and every failure in
//  GeneratedClientPurchaseManagementErrorTests.
//
//  Rules under test (Gate 1 Story B interface item 2):
//   - a 200 maps through `mapRecordedPurchase`: every field, the item reference, money as an exact
//     Decimal, all four shipping statuses;
//   - the DELETED purchase (200 of deletePurchase) decodes to the same shape;
//   - a 200 whose body cannot be read or mapped is `.invalidResponse` (for these operations a failed
//     read never means unconfirmed).
//
//  These tests do not compile until the implementer adds PurchaseManaging and
//  GeneratedClientPurchaseManagementRepository.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseManagementRepository", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseManagementRepositoryTests {

    // MARK: 200 maps every field

    @Test("200 maps every field of a full purchase, including the item reference", arguments: ManagementOp.allCases)
    func okMapsEveryField(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        let purchase = PurchaseWire.purchaseJSON(
            id: "purchase-7", itemId: "item-4", quantity: 3, totalCost: "1234.50",
            storeName: "Fake Store", notes: "Gift wrap please", confirmationNumber: "CONF-1",
            trackingNumber: "TRK-1", shippingStatus: "SHIPPED",
            shippedAt: "2026-01-06T09:00:00.000Z", deliveredAt: "2026-01-08T09:00:00.000Z"
        )
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope(purchase))

        let recorded = try await sut.run(op, id: "purchase-7")

        #expect(recorded.id == "purchase-7")
        #expect(recorded.itemId == "item-4")
        #expect(recorded.quantity == 3)
        #expect(recorded.totalCost == PurchaseFixtures.decimal("1234.50"))
        #expect(recorded.storeName == "Fake Store")
        #expect(recorded.notes == "Gift wrap please")
        #expect(recorded.confirmationNumber == "CONF-1")
        #expect(recorded.trackingNumber == "TRK-1")
        #expect(recorded.shippingStatus == .shipped)
        #expect(recorded.shippedAt == PurchaseWire.date("2026-01-06T09:00:00.000Z"))
        #expect(recorded.deliveredAt == PurchaseWire.date("2026-01-08T09:00:00.000Z"))
        #expect(recorded.purchaser == ListItemPerson(id: "user-3", displayName: "Sam Buyer"))
        #expect(recorded.recipient == ListItemPerson(id: "user-1", displayName: "Pat Recipient"))
        #expect(recorded.item == PurchaseItemReference(id: "item-4", name: "Fake Lamp", listId: "list-1"))
        #expect(recorded.purchasedAt == PurchaseWire.date("2026-01-05T08:30:00.000Z"))
        #expect(recorded.createdAt == PurchaseWire.date("2026-01-05T08:30:01.000Z"))
        #expect(recorded.updatedAt == PurchaseWire.date("2026-01-05T08:30:02.000Z"))
    }

    @Test("200 with null optional fields maps them to nil and invents nothing", arguments: ManagementOp.allCases)
    func okWithNullOptionals(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope())

        let recorded = try await sut.run(op)

        #expect(recorded.storeName == nil)
        #expect(recorded.notes == nil)
        #expect(recorded.confirmationNumber == nil)
        #expect(recorded.trackingNumber == nil)
        #expect(recorded.shippedAt == nil)
        #expect(recorded.deliveredAt == nil)
        #expect(recorded.shippingStatus == .notTracked)
    }

    @Test("Money crosses the boundary as an exact Decimal",
          arguments: ManagementOp.allCases, ["79.99", "10", "0.5", "0.01", "999999.99", "1234.5", "19.9"])
    func moneyIsExactDecimal(op: ManagementOp, text: String) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(
            status: 200, json: ManagementWire.purchaseEnvelope(PurchaseWire.purchaseJSON(totalCost: text))
        )

        let recorded = try await sut.run(op)

        #expect(recorded.totalCost == PurchaseFixtures.decimal(text), "\(op) \(text)")
    }

    @Test("Every shipping status maps to the domain status of the same meaning",
          arguments: ManagementOp.allCases, [
        ("NOT_TRACKED", PurchaseShippingStatus.notTracked), ("NOT_SHIPPED", PurchaseShippingStatus.notShipped),
        ("SHIPPED", PurchaseShippingStatus.shipped), ("DELIVERED", PurchaseShippingStatus.delivered)
    ])
    func shippingStatuses(op: ManagementOp, pair: (String, PurchaseShippingStatus)) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(
            status: 200, json: ManagementWire.purchaseEnvelope(PurchaseWire.purchaseJSON(shippingStatus: pair.0))
        )

        let recorded = try await sut.run(op)

        #expect(recorded.shippingStatus == pair.1, "\(op) \(pair.0)")
    }

    // MARK: The deleted purchase

    @Test("The deleted purchase (200 of deletePurchase) decodes with its item reference and Decimal money")
    func deletedPurchaseDecodes() async throws {
        let sut = try makePurchaseManagementSUT()
        let purchase = PurchaseWire.purchaseJSON(
            id: "purchase-9", itemId: "item-2", quantity: 2, totalCost: "49.98",
            storeName: "Fake Store", trackingNumber: "TRK-9", shippingStatus: "NOT_SHIPPED"
        )
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope(purchase))

        let deleted = try await sut.repo.deletePurchase(id: "purchase-9")

        #expect(deleted.id == "purchase-9")
        #expect(deleted.itemId == "item-2")
        #expect(deleted.quantity == 2)
        #expect(deleted.totalCost == PurchaseFixtures.decimal("49.98"))
        #expect(deleted.trackingNumber == "TRK-9")
        #expect(deleted.shippingStatus == .notShipped)
        #expect(deleted.item == PurchaseItemReference(id: "item-2", name: "Fake Lamp", listId: "list-1"))
    }

    // MARK: 200 that cannot be read

    @Test("a 200 whose body cannot be read throws invalidResponse, never unconfirmed",
          arguments: ManagementOp.allCases, [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": { \"id\": \"purchase-1\", \"itemId\": \"item-1\" }, \"meta\": \(ListWire.metaJSON) }"
    ])
    func unreadableOkBody(op: ManagementOp, body: String) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: body)

        await #expect(throws: PurchaseManagementError.invalidResponse) {
            _ = try await sut.run(op)
        }
    }

    @Test("a 200 with no body at all throws invalidResponse", arguments: ManagementOp.allCases)
    func emptyOkBody(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueEmpty(status: 200)

        await #expect(throws: PurchaseManagementError.invalidResponse) {
            _ = try await sut.run(op)
        }
    }

    @Test("a 200 purchase with an unknown shipping status throws invalidResponse", arguments: ManagementOp.allCases)
    func unknownShippingStatus(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        let purchase = PurchaseWire.purchaseJSON(shippingStatus: "TELEPORTED")
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope(purchase))

        await #expect(throws: PurchaseManagementError.invalidResponse) {
            _ = try await sut.run(op)
        }
    }
}
