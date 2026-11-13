//
//  GeneratedClientPurchaseRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: GeneratedClientPurchaseRepository.createPurchase through the REAL factory-built
//  client with a fake transport and guide-accurate literal JSON (client guide 7.6, full `meta`).
//  This file covers the two success outcomes; the request shape is in
//  GeneratedClientPurchaseRequestTests and every failure in GeneratedClientPurchaseRepositoryErrorTests.
//
//  Rules under test:
//   - 201 created maps to `.created(RecordedPurchase)` with money as an exact Decimal.
//   - 200 confirmation_required (body `purchase: null`) maps to `.confirmationRequired(warnings,
//     token)` with all details, ONE shared token, and NEVER to a created purchase.
//   - A 200 whose body carries `created` maps to `.created` (the purchase exists).
//
//  These tests do not compile until the implementer adds PurchaseRecording and
//  GeneratedClientPurchaseRepository.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseRepository", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseRepositoryTests {

    // MARK: 201 created

    @Test("201 created maps every field of a full purchase")
    func createdMapsEveryField() async throws {
        let sut = try makePurchaseRepoSUT()
        let purchase = PurchaseWire.purchaseJSON(
            id: "purchase-7", itemId: "item-4", quantity: 3, totalCost: "1234.50",
            storeName: "Fake Store", notes: "Gift wrap please", confirmationNumber: "CONF-1",
            trackingNumber: "TRK-1", shippingStatus: "SHIPPED",
            shippedAt: "2026-01-06T09:00:00.000Z", deliveredAt: "2026-01-08T09:00:00.000Z"
        )
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope(purchase: purchase))

        let outcome = try await sut.create(itemId: "item-4")

        guard case .created(let recorded) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
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
        #expect(recorded.purchasedAt == PurchaseWire.date("2026-01-05T08:30:00.000Z"))
        #expect(recorded.createdAt == PurchaseWire.date("2026-01-05T08:30:01.000Z"))
        #expect(recorded.updatedAt == PurchaseWire.date("2026-01-05T08:30:02.000Z"))
    }

    @Test("201 created with null optional fields maps them to nil and invents nothing")
    func createdWithNullOptionals() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope())

        let outcome = try await sut.create()

        guard case .created(let recorded) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
        #expect(recorded.storeName == nil)
        #expect(recorded.notes == nil)
        #expect(recorded.confirmationNumber == nil)
        #expect(recorded.trackingNumber == nil)
        #expect(recorded.shippedAt == nil)
        #expect(recorded.deliveredAt == nil)
        #expect(recorded.shippingStatus == .notTracked)
    }

    @Test("Money crosses the boundary as an exact Decimal (79.99 round trip and the other two-decimal values)",
          arguments: ["79.99", "10", "0.5", "0.01", "999999.99", "1234.5", "19.9"])
    func moneyIsExactDecimal(text: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: 201, json: PurchaseWire.createdEnvelope(purchase: PurchaseWire.purchaseJSON(totalCost: text))
        )

        let outcome = try await sut.create()

        guard case .created(let recorded) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
        #expect(recorded.totalCost == PurchaseFixtures.decimal(text), "\(text)")
    }

    @Test("Every shipping status maps to the domain status of the same meaning", arguments: [
        ("NOT_TRACKED", PurchaseShippingStatus.notTracked), ("NOT_SHIPPED", .notShipped),
        ("SHIPPED", .shipped), ("DELIVERED", .delivered)
    ])
    func shippingStatuses(raw: String, expected: PurchaseShippingStatus) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: 201, json: PurchaseWire.createdEnvelope(purchase: PurchaseWire.purchaseJSON(shippingStatus: raw))
        )

        let outcome = try await sut.create()

        guard case .created(let recorded) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
        #expect(recorded.shippingStatus == expected, "\(raw)")
    }

    // MARK: 200 confirmation_required

    @Test("200 confirmation_required with one warning maps to confirmationRequired with all details and the token")
    func confirmationWithOneWarning() async throws {
        let sut = try makePurchaseRepoSUT()
        let warning = PurchaseWire.warningJSON(
            level: "recipient", recipientName: "Tommy", limit: "500", spent: "450", amount: "349.99", overage: "299.99"
        )
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [warning]))

        let outcome = try await sut.create()

        let expected = BudgetWarning(
            level: .recipient, recipientName: "Tommy",
            budgetLimit: PurchaseFixtures.decimal("500"), currentSpent: PurchaseFixtures.decimal("450"),
            purchaseAmount: PurchaseFixtures.decimal("349.99"), overage: PurchaseFixtures.decimal("299.99")
        )
        #expect(outcome == .confirmationRequired(warnings: [expected], token: PurchaseWire.token))
    }

    @Test("200 confirmation_required with two warnings sharing one token keeps both, in order, with that one token")
    func confirmationWithTwoWarnings() async throws {
        let sut = try makePurchaseRepoSUT()
        let recipient = PurchaseWire.warningJSON(
            level: "recipient", recipientName: "Tommy", limit: "100", spent: "90", amount: "25.50", overage: "15.50"
        )
        let total = PurchaseWire.warningJSON(
            level: "total", limit: "1500.00", spent: "1490.00", amount: "25.50", overage: "15.50"
        )
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [recipient, total]))

        let outcome = try await sut.create()

        guard case .confirmationRequired(let warnings, let token) = outcome else {
            Issue.record("expected .confirmationRequired, got \(outcome)")
            return
        }
        #expect(token == PurchaseWire.token)
        #expect(warnings.map(\.level) == [.recipient, .total])
        #expect(warnings.first?.recipientName == "Tommy")
        #expect(warnings.last?.recipientName == nil, "a total-level warning names no recipient")
        #expect(warnings.last?.budgetLimit == PurchaseFixtures.decimal("1500.00"))
        #expect(warnings.last?.currentSpent == PurchaseFixtures.decimal("1490.00"))
        #expect(warnings.last?.purchaseAmount == PurchaseFixtures.decimal("25.50"))
        #expect(warnings.last?.overage == PurchaseFixtures.decimal("15.50"))
    }

    @Test("A confirmation_required never becomes a created purchase, whatever the null purchase looks like")
    func confirmationIsNeverCreated() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [PurchaseWire.warningJSON()])
        )

        let outcome = try await sut.create()

        if case .created = outcome {
            Issue.record("a 200 confirmation_required must not create a purchase")
        }
    }

    @Test("The token of the first warning with a non-empty token is used")
    func firstNonEmptyTokenWins() async throws {
        let sut = try makePurchaseRepoSUT()
        let blank = PurchaseWire.warningJSON(level: "recipient", token: "")
        let real = PurchaseWire.warningJSON(level: "total", token: PurchaseWire.secondToken)
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [blank, real]))

        let outcome = try await sut.create()

        guard case .confirmationRequired(let warnings, let token) = outcome else {
            Issue.record("expected .confirmationRequired, got \(outcome)")
            return
        }
        #expect(token == PurchaseWire.secondToken)
        #expect(warnings.count == 2)
    }

    @Test("Warning amounts cross the boundary as exact Decimals", arguments: ["349.99", "0.01", "999999.99", "1234.5"])
    func warningMoneyIsExact(text: String) async throws {
        let sut = try makePurchaseRepoSUT()
        let warning = PurchaseWire.warningJSON(amount: text, overage: text)
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [warning]))

        let outcome = try await sut.create()

        guard case .confirmationRequired(let warnings, _) = outcome else {
            Issue.record("expected .confirmationRequired, got \(outcome)")
            return
        }
        #expect(warnings.first?.purchaseAmount == PurchaseFixtures.decimal(text), "\(text)")
        #expect(warnings.first?.overage == PurchaseFixtures.decimal(text), "\(text)")
    }

    // The generated 200 payload requires a top-level `warnings` array, so the real client cannot
    // decode a 200 envelope that is a `created` body without `warnings`. The contract never sends
    // that combination. (The pure mapping rule "created maps to created" is pinned in the mapping tests.)
    @Test("A 200 created envelope without warnings is an invalid response")
    func okCreatedWithoutWarningsIsInvalid() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: 200, json: PurchaseWire.createdEnvelope(purchase: PurchaseWire.purchaseJSON(id: "purchase-9"))
        )

        await #expect(throws: PurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    @Test("A 200 created envelope WITH a warnings array decodes and maps to created")
    func okCreatedWithWarningsMapsToCreated() async throws {
        let sut = try makePurchaseRepoSUT()
        let body = """
        {
          "success": true,
          "data": { "status": "created", "purchase": \(PurchaseWire.purchaseJSON(id: "purchase-9")), "requiresConfirmation": false },
          "warnings": [],
          "meta": \(ListWire.metaJSON)
        }
        """
        await sut.transport.enqueue(status: 200, json: body)

        let outcome = try await sut.create()

        guard case .created(let recorded) = outcome else {
            Issue.record("expected .created, got \(outcome)")
            return
        }
        #expect(recorded.id == "purchase-9")
    }
}
