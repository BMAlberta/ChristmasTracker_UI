//
//  PurchaseHistoryServiceHarness.swift
//  ChristmasTrackerTests
//
//  PH1-H1: shared construction and helpers for the PurchaseHistoryService tests.
//
//  The service under test is built over the gated fake:
//      PurchaseHistoryService(repository: GatedPurchaseHistoryLoader)
//  and registered with a SessionManager, so teardown runs the way the app does it
//  (`SessionManager.teardown(reason:)` calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct PurchaseHistoryServiceSUT {
    let service: PurchaseHistoryService
    let loader: GatedPurchaseHistoryLoader
    let manager: SessionManager
}

@MainActor
func makePurchaseHistoryServiceSUT(honorsCancellation: Bool = false) async -> PurchaseHistoryServiceSUT {
    let loader = GatedPurchaseHistoryLoader()
    loader.gate.honorsCancellation = honorsCancellation
    let service = PurchaseHistoryService(repository: loader)
    let manager = SessionManager(initialClearables: [])
    await manager.register(service)
    return PurchaseHistoryServiceSUT(service: service, loader: loader, manager: manager)
}

/// Starts one service call in a task.
@MainActor
func startPurchaseHistoryLoad(
    _ service: PurchaseHistoryService,
    filter: PurchaseHistoryFilter = PurchaseHistoryFilter(),
    cursor: String? = nil
) -> Task<PurchaseHistoryPage, any Error> {
    Task { @MainActor in try await service.loadPage(filter: filter, cursor: cursor) }
}

/// Records an issue unless the result is a CancellationError (never a page, never a PurchaseHistoryError).
func expectCancellation(
    _ result: Result<PurchaseHistoryPage, any Error>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    switch result {
    case .success(let page):
        Issue.record("expected CancellationError, got a page with \(page.rows.count) rows", sourceLocation: sourceLocation)
    case .failure(let error):
        #expect(error is CancellationError, "expected CancellationError, got \(error)", sourceLocation: sourceLocation)
        #expect(!(error is PurchaseHistoryError), "a cancelled call must not become a typed error", sourceLocation: sourceLocation)
    }
}
