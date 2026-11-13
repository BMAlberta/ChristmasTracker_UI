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

// MARK: - I4c-C test support for the model's refresh dependency
//
// The shape of the real PurchaseDetailRefresh that this support builds on:
//
//   struct PurchaseDetailRefresh {
//       var run: @MainActor ([PurchaseRefreshStep], @MainActor () -> Bool) async -> Void
//       var currentItemsListId: @MainActor () -> String?
//   }
//   PurchaseDetailModel.init(..., refresh: PurchaseDetailRefresh)   // label `refresh:`, optional, defaulted
//
// `run` executes the steps in order, asking the continue-check before each step. The model passes the
// check `service.sessionGeneration == capturedGeneration && !Task.isCancelled`.

/// Builds the real PurchaseDetailRefresh from two closures.
@MainActor
func makeRefreshDependency(
    run: @escaping @MainActor ([PurchaseRefreshStep], @MainActor () -> Bool) async -> Void,
    currentItemsListId: @escaping @MainActor () -> String?
) -> PurchaseDetailRefresh {
    PurchaseDetailRefresh(run: run, currentItemsListId: currentItemsListId)
}

/// A scripted stand-in for the host's runner. It runs the steps in order like the real runner, asking
/// the continue-check before each one, and records everything. No sleeps; hooks give the tests the
/// deterministic points they need.
@MainActor
final class RefreshProbe {
    /// Every list of steps the model asked to run.
    private(set) var requested: [[PurchaseRefreshStep]] = []
    /// The steps that actually ran (the check answered true before them).
    private(set) var executed: [PurchaseRefreshStep] = []
    /// Every answer the continue-check gave, in order.
    private(set) var checkAnswers: [Bool] = []
    /// How many times the model read the item service's list id.
    private(set) var listIdReads = 0

    /// The list id the (fake) item service currently holds. Tests change it at will.
    var itemsListId: String?
    /// Called when a run starts, before the first check.
    var onRun: (@MainActor () -> Void)?
    /// Called after a step ran, before the next check.
    var afterStep: (@MainActor (PurchaseRefreshStep) async -> Void)?
    /// The task running confirmDelete, so a hook can cancel it.
    var runningTask: Task<Void, Never>?

    var dependency: PurchaseDetailRefresh {
        makeRefreshDependency(
            run: { [self] steps, shouldContinue in
                requested.append(steps)
                onRun?()
                for step in steps {
                    let answer = shouldContinue()
                    checkAnswers.append(answer)
                    guard answer else { return }
                    executed.append(step)
                    await afterStep?(step)
                }
            },
            currentItemsListId: { [self] in
                listIdReads += 1
                return itemsListId
            }
        )
    }
}

/// A model over a real service and a scripted management fake. Nothing is loaded yet.
@MainActor
func makePurchaseDetailSUT(
    currentUserId: String? = PurchaseDetailTest.userId,
    honorsCancellation: Bool = false,
    refresh: PurchaseDetailRefresh? = nil
) async -> PurchaseDetailSUT {
    let base = await makeManagementServiceSUT(honorsCancellation: honorsCancellation)
    // `refresh` is optional on the model's init; nil means no follow-up refresh.
    let model = PurchaseDetailModel(
        purchaseId: PurchaseDetailTest.purchaseId,
        itemId: PurchaseDetailTest.itemId,
        listId: PurchaseDetailTest.listId,
        currentUserId: currentUserId,
        service: base.service,
        currencyCode: "USD",
        locale: PurchaseDetailTest.locale,
        refresh: refresh
    )
    return PurchaseDetailSUT(
        model: model, service: base.service, management: base.management,
        recorder: base.recorder, manager: base.manager
    )
}

/// A model that has loaded `purchase` (the fetch is scripted and awaited).
@MainActor
func makeLoadedPurchaseDetailSUT(
    purchase: RecordedPurchase = PurchaseDetailTest.own(),
    refresh: PurchaseDetailRefresh? = nil
) async -> PurchaseDetailSUT {
    let sut = await makePurchaseDetailSUT(refresh: refresh)
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
