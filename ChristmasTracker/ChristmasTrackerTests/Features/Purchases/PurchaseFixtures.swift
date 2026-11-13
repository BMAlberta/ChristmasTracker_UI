//
//  PurchaseFixtures.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: shared, fake-data fixtures for the purchase domain tests.
//
//  Domain side: the ONLY memberwise call sites of RecordedPurchase, BudgetWarning and
//  PurchaseDraft in the test target live here. Wire side: generated Components.Schemas values
//  built with the generated memberwise initialisers (the same way ItemFixtures builds items).
//  The generated PurchaseConfirmationRequiredData has no `purchase` member (the server's null
//  purchase is simply not modelled), so a confirmation payload is {status, requiresConfirmation}.
//
//  `PurchaseTestClock` is the injected flow clock: a Sendable box around a fixed Date that tests
//  move forward by explicit offsets (no real time passes in any test).
//
//  All ids, names and amounts are fake.
//

import Foundation
import Synchronization
import TrackerAPI
@testable import ChristmasTracker

nonisolated final class PurchaseTestClock: Sendable {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private let current = Mutex<Date>(PurchaseTestClock.start)

    var now: Date { current.withLock { $0 } }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }

    /// The closure handed to `RecordPurchaseFlow(now:)`.
    var provider: @Sendable () -> Date {
        { [self] in self.now }
    }
}

nonisolated enum PurchaseFixtures {

    // MARK: - Constants

    static let purchasedDate = Date(timeIntervalSince1970: 1_767_650_000)
    static let createdDate = Date(timeIntervalSince1970: 1_767_650_100)
    static let updatedDate = Date(timeIntervalSince1970: 1_767_650_200)
    static let shippedDate = Date(timeIntervalSince1970: 1_767_700_000)
    static let deliveredDate = Date(timeIntervalSince1970: 1_767_800_000)

    static func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal.nan
    }

    static let nonFinite: [Double] = [.nan, .infinity, -.infinity]

    /// One value of every PurchaseError case.
    static let allErrors: [PurchaseError] = [
        .notFound, .unauthorized, .forbidden, .cannotPurchaseOwnList,
        .validation(message: "Total cost must be positive"), .invalidPrice,
        .rateLimited(retryAfter: 30), .sessionEnded, .network, .invalidResponse, .server
    ]

    /// Every PurchaseError case including the I4b `unconfirmed`.
    static let allErrorsWithUnconfirmed: [PurchaseError] = allErrors + [.unconfirmed]

    // MARK: - Domain

    static func person(id: String, name: String) -> ListItemPerson {
        ListItemPerson(id: id, displayName: name)
    }

    static func recordedPurchase(
        id: String = "purchase-1",
        itemId: String = "item-1",
        quantity: Int = 1,
        totalCost: Decimal = decimal("19.99"),
        storeName: String? = nil,
        notes: String? = nil,
        confirmationNumber: String? = nil,
        trackingNumber: String? = nil,
        shippingStatus: PurchaseShippingStatus = .notTracked,
        shippedAt: Date? = nil,
        deliveredAt: Date? = nil,
        purchaser: ListItemPerson? = nil,
        item: PurchaseItemReference? = nil,
        purchasedAt: Date? = nil
    ) -> RecordedPurchase {
        RecordedPurchase(
            id: id, itemId: itemId, quantity: quantity, totalCost: totalCost,
            storeName: storeName, notes: notes, confirmationNumber: confirmationNumber,
            trackingNumber: trackingNumber, shippingStatus: shippingStatus,
            shippedAt: shippedAt, deliveredAt: deliveredAt,
            purchaser: purchaser ?? person(id: "user-3", name: "Sam Buyer"),
            recipient: person(id: "user-1", name: "Pat Recipient"),
            item: item,
            purchasedAt: purchasedAt ?? purchasedDate, createdAt: createdDate, updatedAt: updatedDate
        )
    }

    static let fakeItemReference = PurchaseItemReference(id: "item-1", name: "Fake Lamp", listId: "list-1")

    static func recipientWarning(
        name: String? = "Pat Recipient",
        limit: String = "100.00",
        spent: String = "90.00",
        amount: String = "25.50",
        overage: String = "15.50"
    ) -> BudgetWarning {
        BudgetWarning(
            level: .recipient, recipientName: name,
            budgetLimit: decimal(limit), currentSpent: decimal(spent),
            purchaseAmount: decimal(amount), overage: decimal(overage)
        )
    }

    static func totalWarning(
        limit: String = "1500.00",
        spent: String = "1490.00",
        amount: String = "25.50",
        overage: String = "15.50"
    ) -> BudgetWarning {
        BudgetWarning(
            level: .total, recipientName: nil,
            budgetLimit: decimal(limit), currentSpent: decimal(spent),
            purchaseAmount: decimal(amount), overage: decimal(overage)
        )
    }

    static func draft(
        quantity: Int = 1,
        totalCost: String = "25.50",
        storeName: String? = nil,
        notes: String? = nil,
        confirmationNumber: String? = nil,
        trackingNumber: String? = nil
    ) -> PurchaseDraft {
        PurchaseDraft(
            quantity: quantity, totalCost: decimal(totalCost), storeName: storeName, notes: notes,
            confirmationNumber: confirmationNumber, trackingNumber: trackingNumber
        )
    }

    // MARK: - Wire

    static func wirePerson(id: String, name: String) -> Components.Schemas.PersonRef {
        Components.Schemas.PersonRef(id: id, displayName: name)
    }

    static func wirePurchase(
        id: String = "purchase-1",
        itemId: String = "item-1",
        quantity: Int = 1,
        totalCost: Double = 19.99,
        storeName: String? = nil,
        notes: String? = nil,
        confirmationNumber: String? = nil,
        trackingNumber: String? = nil,
        shippingStatus: Components.Schemas.ShippingStatus = .notTracked,
        shippedAt: Date? = nil,
        deliveredAt: Date? = nil,
        itemName: String = "Fake Lamp",
        listId: String = "list-1"
    ) -> Components.Schemas.Purchase {
        Components.Schemas.Purchase(
            id: id, itemId: itemId, quantity: quantity, totalCost: totalCost,
            storeName: storeName, notes: notes, confirmationNumber: confirmationNumber,
            trackingNumber: trackingNumber, shippingStatus: shippingStatus,
            shippedAt: shippedAt, deliveredAt: deliveredAt,
            purchaser: wirePerson(id: "user-3", name: "Sam Buyer"),
            recipient: wirePerson(id: "user-1", name: "Pat Recipient"),
            item: .init(id: itemId, name: itemName, listId: listId),
            purchasedAt: purchasedDate, createdAt: createdDate, updatedAt: updatedDate
        )
    }

    static func wireWarning(
        level: Components.Schemas.BudgetOverageWarning.LevelPayload = .recipient,
        recipientName: String? = "Pat Recipient",
        token: String = "tok-A",
        limit: Double = 100.00,
        spent: Double = 90.00,
        amount: Double = 25.50,
        overage: Double = 15.50
    ) -> Components.Schemas.BudgetOverageWarning {
        Components.Schemas.BudgetOverageWarning(
            code: 6002, warningCode: "BUDGET_OVERAGE_WARNING", level: level,
            message: "This purchase would put you over budget", severity: .warning,
            requiresConfirmation: true, confirmationToken: token,
            details: .init(
                recipientId: level == .recipient ? "user-1" : nil,
                recipientName: level == .recipient ? recipientName : nil,
                year: level == .total ? 2026 : nil,
                budgetLimit: limit, currentSpent: spent, purchaseAmount: amount, overage: overage
            )
        )
    }

    static func wireCreated(
        _ purchase: Components.Schemas.Purchase? = nil
    ) -> Components.Schemas.PurchaseResult {
        .created(.init(status: .created, purchase: purchase ?? wirePurchase(), requiresConfirmation: false))
    }

    static func wireConfirmationRequired() -> Components.Schemas.PurchaseResult {
        .confirmationRequired(.init(status: .confirmationRequired, requiresConfirmation: true))
    }
}
