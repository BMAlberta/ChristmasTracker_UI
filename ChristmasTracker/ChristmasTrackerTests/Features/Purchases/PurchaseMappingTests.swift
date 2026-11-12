//
//  PurchaseMappingTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the pure mapping from the generated purchase schemas to the domain types.
//  Fixtures are generated-type values (Components.Schemas.Purchase, BudgetOverageWarning,
//  PurchaseResult) plus a few literal JSON bodies decoded through the generated Codable types
//  (client guide 7.6 shapes: a `purchase: null` on the 200, optional details fields absent).
//
//  Rules under test: money converts through doubleToDecimal and a non-finite value throws
//  RecordPurchaseError.invalidResponse; a 201 body must carry `created`; a 200 body carrying
//  confirmation_required needs at least one warning and a non-empty token (the first non-empty
//  token) and NEVER becomes `created`; a 200 body carrying `created` maps to `created`.
//
//  Fails today because the purchase domain and the mapping functions do not exist yet.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("Purchase mapping Tests")
struct PurchaseMappingTests {

    // MARK: - mapRecordedPurchase

    @Test("Every field of a full purchase maps one to one")
    func fullPurchase() throws {
        let wire = PurchaseFixtures.wirePurchase(
            id: "purchase-7", itemId: "item-4", quantity: 3, totalCost: 1234.50,
            storeName: "Fake Store", notes: "Gift wrap please", confirmationNumber: "CONF-1",
            trackingNumber: "TRK-1", shippingStatus: .shipped,
            shippedAt: PurchaseFixtures.shippedDate, deliveredAt: PurchaseFixtures.deliveredDate
        )
        let purchase = try mapRecordedPurchase(wire)
        #expect(purchase.id == "purchase-7")
        #expect(purchase.itemId == "item-4")
        #expect(purchase.quantity == 3)
        #expect(purchase.totalCost == PurchaseFixtures.decimal("1234.50"))
        #expect(purchase.storeName == "Fake Store")
        #expect(purchase.notes == "Gift wrap please")
        #expect(purchase.confirmationNumber == "CONF-1")
        #expect(purchase.trackingNumber == "TRK-1")
        #expect(purchase.shippingStatus == .shipped)
        #expect(purchase.shippedAt == PurchaseFixtures.shippedDate)
        #expect(purchase.deliveredAt == PurchaseFixtures.deliveredDate)
        #expect(purchase.purchaser == ListItemPerson(id: "user-3", displayName: "Sam Buyer"))
        #expect(purchase.recipient == ListItemPerson(id: "user-1", displayName: "Pat Recipient"))
        #expect(purchase.purchasedAt == PurchaseFixtures.purchasedDate)
        #expect(purchase.createdAt == PurchaseFixtures.createdDate)
        #expect(purchase.updatedAt == PurchaseFixtures.updatedDate)
    }

    @Test("Absent optional fields stay nil and nothing is invented")
    func absentOptionals() throws {
        let purchase = try mapRecordedPurchase(PurchaseFixtures.wirePurchase())
        #expect(purchase.storeName == nil)
        #expect(purchase.notes == nil)
        #expect(purchase.confirmationNumber == nil)
        #expect(purchase.trackingNumber == nil)
        #expect(purchase.shippedAt == nil)
        #expect(purchase.deliveredAt == nil)
    }

    @Test("Every generated shipping status maps to the domain status of the same meaning",
          arguments: Components.Schemas.ShippingStatus.allCases)
    func shippingStatusMapsOneToOne(wire: Components.Schemas.ShippingStatus) throws {
        let expected: RecordedShippingStatus
        switch wire {
        case .notTracked: expected = .notTracked
        case .notShipped: expected = .notShipped
        case .shipped: expected = .shipped
        case .delivered: expected = .delivered
        }
        let purchase = try mapRecordedPurchase(PurchaseFixtures.wirePurchase(shippingStatus: wire))
        #expect(purchase.shippingStatus == expected)
    }

    @Test("Money maps to the exact two-decimal Decimal",
          arguments: [(19.99, "19.99"), (0.10, "0.10"), (1234.50, "1234.50"), (0.01, "0.01"), (999_999.99, "999999.99")])
    func moneyMapsExactly(value: Double, expected: String) throws {
        let purchase = try mapRecordedPurchase(PurchaseFixtures.wirePurchase(totalCost: value))
        #expect(purchase.totalCost == PurchaseFixtures.decimal(expected))
    }

    @Test("A NaN or infinite purchase total throws invalidResponse", arguments: PurchaseFixtures.nonFinite)
    func nonFinitePurchaseTotal(value: Double) {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapRecordedPurchase(PurchaseFixtures.wirePurchase(totalCost: value))
        }
    }

    // MARK: - mapBudgetWarning

    @Test("A recipient warning maps level, recipient name and the four Decimal amounts")
    func recipientWarning() throws {
        let warning = try mapBudgetWarning(PurchaseFixtures.wireWarning(
            level: .recipient, recipientName: "Pat Recipient", limit: 100.00, spent: 90.10, amount: 25.50, overage: 15.60
        ))
        #expect(warning.level == .recipient)
        #expect(warning.recipientName == "Pat Recipient")
        #expect(warning.budgetLimit == PurchaseFixtures.decimal("100"))
        #expect(warning.currentSpent == PurchaseFixtures.decimal("90.10"))
        #expect(warning.purchaseAmount == PurchaseFixtures.decimal("25.50"))
        #expect(warning.overage == PurchaseFixtures.decimal("15.60"))
    }

    @Test("A total warning maps to level total with no recipient name")
    func totalWarning() throws {
        let warning = try mapBudgetWarning(PurchaseFixtures.wireWarning(level: .total, limit: 1500, spent: 1490, overage: 15.50))
        #expect(warning.level == .total)
        #expect(warning.recipientName == nil)
        #expect(warning.budgetLimit == PurchaseFixtures.decimal("1500"))
        #expect(warning.overage == PurchaseFixtures.decimal("15.50"))
    }

    enum MoneyField: CaseIterable, Sendable { case limit, spent, amount, overage }

    @Test("A non-finite value in any money field of a warning throws invalidResponse",
          arguments: MoneyField.allCases, PurchaseFixtures.nonFinite)
    func nonFiniteWarningMoney(field: MoneyField, value: Double) {
        let wire = PurchaseFixtures.wireWarning(
            limit: field == .limit ? value : 100, spent: field == .spent ? value : 90,
            amount: field == .amount ? value : 25.50, overage: field == .overage ? value : 15.50
        )
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapBudgetWarning(wire)
        }
    }

    // MARK: - mapCreatedOutcome (the 201 body)

    @Test("A 201 body carrying created maps to created with the mapped purchase")
    func createdOutcome() throws {
        let outcome = try mapCreatedOutcome(PurchaseFixtures.wireCreated(PurchaseFixtures.wirePurchase(id: "purchase-5", quantity: 2)))
        guard case let .created(purchase) = outcome else {
            Issue.record("expected created, got \(outcome)")
            return
        }
        #expect(purchase.id == "purchase-5")
        #expect(purchase.quantity == 2)
    }

    @Test("A 201 body carrying confirmation_required is invalidResponse")
    func createdBodyWithConfirmationRequired() {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapCreatedOutcome(PurchaseFixtures.wireConfirmationRequired())
        }
    }

    @Test("A 201 body with a non-finite purchase total is invalidResponse", arguments: PurchaseFixtures.nonFinite)
    func createdNonFinite(value: Double) {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapCreatedOutcome(PurchaseFixtures.wireCreated(PurchaseFixtures.wirePurchase(totalCost: value)))
        }
    }

    // MARK: - mapConfirmationOutcome (the 200 body)

    @Test("A 200 confirmation_required with one warning maps to confirmationRequired with that token")
    func confirmationOneWarning() throws {
        let outcome = try mapConfirmationOutcome(
            PurchaseFixtures.wireConfirmationRequired(),
            warnings: [PurchaseFixtures.wireWarning(token: "tok-A")]
        )
        #expect(outcome == .confirmationRequired(warnings: [PurchaseFixtures.recipientWarning()], token: "tok-A"))
    }

    @Test("Two warnings sharing one token map to two warnings in order and that one token")
    func confirmationTwoWarningsShareToken() throws {
        let outcome = try mapConfirmationOutcome(
            PurchaseFixtures.wireConfirmationRequired(),
            warnings: [
                PurchaseFixtures.wireWarning(level: .recipient, token: "tok-SHARED"),
                PurchaseFixtures.wireWarning(level: .total, token: "tok-SHARED", limit: 1500, spent: 1490)
            ]
        )
        guard case let .confirmationRequired(warnings, token) = outcome else {
            Issue.record("expected confirmationRequired, got \(outcome)")
            return
        }
        #expect(token == "tok-SHARED")
        #expect(warnings.map(\.level) == [.recipient, .total])
    }

    @Test("The token of the first warning with a non-empty token is used")
    func firstNonEmptyTokenWins() throws {
        let outcome = try mapConfirmationOutcome(
            PurchaseFixtures.wireConfirmationRequired(),
            warnings: [
                PurchaseFixtures.wireWarning(level: .recipient, token: ""),
                PurchaseFixtures.wireWarning(level: .total, token: "tok-B"),
                PurchaseFixtures.wireWarning(level: .total, token: "tok-C")
            ]
        )
        guard case let .confirmationRequired(warnings, token) = outcome else {
            Issue.record("expected confirmationRequired, got \(outcome)")
            return
        }
        #expect(token == "tok-B")
        #expect(warnings.count == 3)
    }

    @Test("A 200 confirmation_required without warnings is invalidResponse")
    func confirmationEmptyWarnings() {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapConfirmationOutcome(PurchaseFixtures.wireConfirmationRequired(), warnings: [])
        }
    }

    @Test("A 200 confirmation_required whose warnings carry no token is invalidResponse")
    func confirmationMissingToken() {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapConfirmationOutcome(
                PurchaseFixtures.wireConfirmationRequired(),
                warnings: [PurchaseFixtures.wireWarning(token: ""), PurchaseFixtures.wireWarning(level: .total, token: "")]
            )
        }
    }

    @Test("A 200 confirmation_required NEVER becomes created, whatever the warnings look like",
          arguments: [0, 1, 2])
    func confirmationNeverCreated(warningCount: Int) {
        let warnings = (0..<warningCount).map { _ in PurchaseFixtures.wireWarning() }
        let outcome = try? mapConfirmationOutcome(PurchaseFixtures.wireConfirmationRequired(), warnings: warnings)
        if case .created = outcome {
            Issue.record("a confirmation_required body produced created")
        }
    }

    @Test("A 200 body that carries created maps to created, the purchase exists")
    func ok200WithCreated() throws {
        let outcome = try mapConfirmationOutcome(
            PurchaseFixtures.wireCreated(PurchaseFixtures.wirePurchase(id: "purchase-8")), warnings: []
        )
        guard case let .created(purchase) = outcome else {
            Issue.record("expected created, got \(outcome)")
            return
        }
        #expect(purchase.id == "purchase-8")
    }

    @Test("A non-finite money value in a 200 warning is invalidResponse", arguments: PurchaseFixtures.nonFinite)
    func confirmationNonFinite(value: Double) {
        #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try mapConfirmationOutcome(
                PurchaseFixtures.wireConfirmationRequired(),
                warnings: [PurchaseFixtures.wireWarning(overage: value)]
            )
        }
    }

    // MARK: - Guide-shaped JSON through the generated Codable types

    @Test("A guide-shaped 200 body with a null purchase and a total warning without recipient fields maps cleanly")
    func guideShapedConfirmationJSON() throws {
        let resultJSON = """
        { "status": "confirmation_required", "purchase": null, "requiresConfirmation": true }
        """
        let warningJSON = """
        { "code": 6002, "warningCode": "BUDGET_OVERAGE_WARNING", "level": "total",
          "message": "This purchase would put you over your total budget", "severity": "warning",
          "requiresConfirmation": true, "confirmationToken": "tok-JSON-FAKE",
          "details": { "year": 2026, "budgetLimit": 1500.00, "currentSpent": 1490.10,
                       "purchaseAmount": 25.50, "overage": 15.60 } }
        """
        let decoder = JSONDecoder()
        let result = try decoder.decode(Components.Schemas.PurchaseResult.self, from: Data(resultJSON.utf8))
        let warning = try decoder.decode(Components.Schemas.BudgetOverageWarning.self, from: Data(warningJSON.utf8))

        let outcome = try mapConfirmationOutcome(result, warnings: [warning])

        guard case let .confirmationRequired(warnings, token) = outcome else {
            Issue.record("expected confirmationRequired, got \(outcome)")
            return
        }
        #expect(token == "tok-JSON-FAKE")
        let mapped = try #require(warnings.first)
        #expect(mapped.level == .total)
        #expect(mapped.recipientName == nil)
        #expect(mapped.budgetLimit == PurchaseFixtures.decimal("1500.00"))
        #expect(mapped.currentSpent == PurchaseFixtures.decimal("1490.10"))
        #expect(mapped.purchaseAmount == PurchaseFixtures.decimal("25.50"))
        #expect(mapped.overage == PurchaseFixtures.decimal("15.60"))
    }
}
