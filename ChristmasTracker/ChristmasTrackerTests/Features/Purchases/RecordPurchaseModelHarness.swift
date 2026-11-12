//
//  RecordPurchaseModelHarness.swift
//  ChristmasTrackerTests
//
//  Story I4a-C: shared construction and helpers for the RecordPurchaseModel tests.
//
//  The model is built over a REAL PurchaseService backed by the GatedPurchaseRecorder fake (the
//  same service harness the service tests use), so a teardown is driven the way the app does it
//  (SessionManager.teardown). The clock is the injected PurchaseTestClock; no real time passes.
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//
//  Mock mode note: nothing here assumes that counts, statuses or quantities change after a
//  purchase. The fakes only script what the service returns.
//
//  The confirmation tokens are distinctive fakes.
//

import Foundation
import Testing
@testable import ChristmasTracker

enum RecordPurchaseTestToken {
    static let first = "tok-DISTINCT-123"
    static let second = "tok-DISTINCT-456"
}

enum RecordPurchaseTestCaps {
    /// canPurchase and canSeeGiftActivity (a non-blind owner, co-owner or active member).
    static let buyer = ItemFixtures.capabilities(canSeeGiftActivity: true, canPurchase: true)
    /// canPurchase without canSeeGiftActivity (not a persona the server produces; it isolates the
    /// "quantities are known only with gift activity" rule).
    static let buyerWithoutActivity = ItemFixtures.capabilities(canSeeGiftActivity: false, canPurchase: true)
}

@MainActor
struct RecordPurchaseModelSUT {
    let model: RecordPurchaseModel
    let service: PurchaseService
    let repo: GatedPurchaseRecorder
    let manager: SessionManager
    let clock: PurchaseTestClock
}

/// A model over a real service and a scripted recorder. The total cost is NOT filled in; call `fill`.
@MainActor
func makeRecordPurchaseModelSUT(
    item: ListItem = ItemFixtures.item(id: "item-1", quantity: 3),
    capabilities: ListCapabilities = RecordPurchaseTestCaps.buyer
) async -> RecordPurchaseModelSUT {
    let base = await makePurchaseServiceSUT()
    let clock = PurchaseTestClock()
    let model = RecordPurchaseModel(
        item: item,
        context: ItemListContext(capabilities: capabilities),
        service: base.service,
        now: clock.provider,
        currencyCode: "USD",
        locale: Locale(identifier: "en_US")
    )
    return RecordPurchaseModelSUT(model: model, service: base.service, repo: base.repo, manager: base.manager, clock: clock)
}

extension RecordPurchaseModelSUT {
    /// Types a valid total cost into the form.
    func fill(cost: String = "25.50") {
        model.input.totalCostText = cost
    }

    /// Scripts a confirmation_required answer (one recipient and one total warning) with this token.
    func enqueueConfirmation(token: String, spent: String = "90.00") {
        repo.enqueue(.success(.confirmationRequired(
            warnings: [
                PurchaseFixtures.recipientWarning(spent: spent),
                PurchaseFixtures.totalWarning()
            ],
            token: token
        )))
    }

    /// Drives the first submit into awaitingConfirmation with this token.
    func driveToAwaiting(token: String = RecordPurchaseTestToken.first) async {
        fill()
        enqueueConfirmation(token: token)
        await model.recordTapped()
    }
}
