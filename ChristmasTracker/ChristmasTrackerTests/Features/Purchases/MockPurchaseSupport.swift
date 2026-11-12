//
//  MockPurchaseSupport.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: shared construction and helpers for the MockPurchaseRecorder tests.
//
//  The mock's access rule is injected, so the tests decide per item id:
//    "item-1", "item-2", "item-3"  -> allowed, recipient Pat (user-1)
//    "item-b"                      -> allowed, recipient Robin (user-2)
//    "item-own"                    -> ownList      "item-forbidden" -> forbidden
//    anything else                 -> unknown
//  The clock is a PurchaseTestClock (fixed start date, explicit offsets, no real time).
//
//  Budget arithmetic of the documented mock data: recipientBudgetLimit 50 and totalBudgetLimit 50,
//  so a purchase is over budget when the recipient spend or the total spend plus the amount is
//  GREATER than 50. Because both limits are equal, a recipient overage always comes with a total
//  overage; a total-only overage needs spend on two different recipients.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum MockPurchaseKit {

    static let pat = ListItemPerson(id: "user-1", displayName: "Pat Recipient")
    static let robin = ListItemPerson(id: "user-2", displayName: "Robin Other")

    static func access(for itemId: String) -> MockPurchaseAccess {
        switch itemId {
        case "item-1", "item-2", "item-3": .allowed(recipient: pat)
        case "item-b": .allowed(recipient: robin)
        case "item-own": .ownList
        case "item-forbidden": .forbidden
        default: .unknown
        }
    }

    static func dec(_ text: String) -> Decimal {
        PurchaseFixtures.decimal(text)
    }
}

struct MockPurchaseSUT {
    let recorder: MockPurchaseRecorder
    let clock: PurchaseTestClock

    @discardableResult
    func create(
        itemId: String = "item-1",
        quantity: Int = 1,
        amount: String = "20",
        token: String? = nil,
        storeName: String? = nil,
        notes: String? = nil,
        confirmationNumber: String? = nil,
        trackingNumber: String? = nil
    ) async throws -> PurchaseOutcome {
        let draft = PurchaseFixtures.draft(
            quantity: quantity, totalCost: amount, storeName: storeName, notes: notes,
            confirmationNumber: confirmationNumber, trackingNumber: trackingNumber
        )
        return try await recorder.createPurchase(itemId: itemId, draft: draft, confirmationToken: token)
    }

    /// The created purchase, or a recorded issue and nil.
    func created(
        itemId: String = "item-1",
        quantity: Int = 1,
        amount: String = "20",
        token: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> RecordedPurchase? {
        let outcome = try await create(itemId: itemId, quantity: quantity, amount: amount, token: token)
        guard case .created(let purchase) = outcome else {
            Issue.record("expected .created, got \(outcome)", sourceLocation: sourceLocation)
            return nil
        }
        return purchase
    }

    /// The confirmation, or a recorded issue and nil.
    func confirmation(
        itemId: String = "item-1",
        quantity: Int = 1,
        amount: String = "60",
        token: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> (warnings: [BudgetWarning], token: String)? {
        let outcome = try await create(itemId: itemId, quantity: quantity, amount: amount, token: token)
        guard case .confirmationRequired(let warnings, let issued) = outcome else {
            Issue.record("expected .confirmationRequired, got \(outcome)", sourceLocation: sourceLocation)
            return nil
        }
        return (warnings, issued)
    }
}

func makeMockPurchaseSUT(buyer: ListItemPerson? = nil) -> MockPurchaseSUT {
    let clock = PurchaseTestClock()
    let access: @Sendable (String) -> MockPurchaseAccess = { MockPurchaseKit.access(for: $0) }
    let recorder: MockPurchaseRecorder
    if let buyer {
        recorder = MockPurchaseRecorder(access: access, buyer: buyer, now: clock.provider)
    } else {
        recorder = MockPurchaseRecorder(access: access, now: clock.provider)
    }
    return MockPurchaseSUT(recorder: recorder, clock: clock)
}

/// Runs the body and returns the RecordPurchaseError it threw (nil when it threw nothing or
/// something else).
func capturePurchaseError(_ body: () async throws -> Void) async -> RecordPurchaseError? {
    do {
        try await body()
        return nil
    } catch {
        return error as? RecordPurchaseError
    }
}
