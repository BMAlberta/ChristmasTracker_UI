//
//  PurchaseDetailModelHarness.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: shared construction and helpers for the PurchaseDetailModel tests.
//
//  The model is built over a REAL PurchaseService backed by the GatedPurchaseManager fake (the same
//  service harness the management service tests use), so a teardown is driven the way the app does it
//  (SessionManager.teardown). Determinism: gated fakes with the nextHeldCall() handshake. No sleeps,
//  no yield loops.
//
//  Mock mode note: nothing here assumes that item counts or statuses change after a save or a
//  delete. The fakes only script what the service returns.
//
//  All ids, names, tracking numbers and amounts are fake.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum PurchaseDetailTest {
    static let userId = "user-3"
    static let otherUserId = "user-9"
    static let purchaseId = "purchase-1"
    static let itemId = "item-1"
    static let listId = "list-1"
    static let locale = Locale(identifier: "en_US")

    /// A purchase made by the signed-in user.
    static func own(
        notes: String? = nil,
        trackingNumber: String? = nil,
        status: PurchaseShippingStatus = .notTracked
    ) -> RecordedPurchase {
        PurchaseFixtures.recordedPurchase(
            id: purchaseId, itemId: itemId, quantity: 2, totalCost: PurchaseFixtures.decimal("42.50"),
            storeName: "Fake Store", notes: notes, confirmationNumber: "CONF-FAKE-1",
            trackingNumber: trackingNumber, shippingStatus: status,
            purchaser: PurchaseFixtures.person(id: userId, name: "Sam Buyer"),
            item: PurchaseFixtures.fakeItemReference
        )
    }

    /// A purchase made by somebody else.
    static func foreign() -> RecordedPurchase {
        PurchaseFixtures.recordedPurchase(
            id: purchaseId, itemId: itemId,
            purchaser: PurchaseFixtures.person(id: otherUserId, name: "Alex Other"),
            item: PurchaseFixtures.fakeItemReference
        )
    }

    /// The banner a retryable error shows: its plain message, Try Again, Dismiss.
    static func retryableBanner(_ error: PurchaseManagementError) -> InlineErrorBannerState {
        InlineErrorBannerState(message: error.userMessage, canRetry: true, isDismissible: true)
    }

    static let retryableErrors: [PurchaseManagementError] = [.network, .server, .rateLimited(retryAfter: 30), .invalidResponse]
}

@MainActor
struct PurchaseDetailSUT {
    let model: PurchaseDetailModel
    let service: PurchaseService
    let management: GatedPurchaseManager
    let recorder: GatedPurchaseRecorder
    let manager: SessionManager
}

/// A model over a real service and a scripted management fake. Nothing is loaded yet.
@MainActor
func makePurchaseDetailSUT(
    currentUserId: String? = PurchaseDetailTest.userId,
    honorsCancellation: Bool = false
) async -> PurchaseDetailSUT {
    let base = await makeManagementServiceSUT(honorsCancellation: honorsCancellation)
    let model = PurchaseDetailModel(
        purchaseId: PurchaseDetailTest.purchaseId,
        itemId: PurchaseDetailTest.itemId,
        listId: PurchaseDetailTest.listId,
        currentUserId: currentUserId,
        service: base.service,
        currencyCode: "USD",
        locale: PurchaseDetailTest.locale
    )
    return PurchaseDetailSUT(
        model: model, service: base.service, management: base.management,
        recorder: base.recorder, manager: base.manager
    )
}

/// A model that has loaded `purchase` (the fetch is scripted and awaited).
@MainActor
func makeLoadedPurchaseDetailSUT(
    purchase: RecordedPurchase = PurchaseDetailTest.own()
) async -> PurchaseDetailSUT {
    let sut = await makePurchaseDetailSUT()
    sut.management.enqueue(purchase)
    await sut.model.load()
    return sut
}

extension PurchaseDetailSUT {

    /// Types into the shipping section. An omitted argument keeps the current draft value.
    func setShipping(status: PurchaseShippingStatus? = nil, tracking: String? = nil) {
        let current = model.shipping
        model.editShipping(
            status: status ?? current?.draftStatus ?? .notTracked,
            tracking: tracking ?? current?.draftTracking ?? ""
        )
    }

    func setNotes(_ text: String) {
        model.editNotes(text: text)
    }

    /// The calls the management fake saw, without the initial fetch.
    var callsAfterLoad: [GatedPurchaseManager.Call] {
        Array(management.calls.dropFirst())
    }

    /// True when no banner of any kind is showing.
    var hasNoBanner: Bool {
        model.loadBanner == nil && model.shippingBanner == nil && model.notesBanner == nil && model.deleteBanner == nil
    }
}

extension PurchaseDetailModel {
    var phaseIsLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    var phaseIsFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    var phaseLoadedState: PurchaseDetailState? {
        if case .loaded(let state) = phase { return state }
        return nil
    }
}
