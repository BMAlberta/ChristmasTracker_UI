//
//  PurchaseHistoryModelSUT.swift
//  ChristmasTrackerTests
//
//  PH1-H2: shared construction and helpers for the PurchaseHistoryModel tests. The model is built over a
//  real PurchaseHistoryService on the gated fake loader (see PurchaseHistoryServiceHarness).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
@testable import ChristmasTracker

@MainActor
struct PurchaseHistoryModelSUT {
    let model: PurchaseHistoryModel
    let service: PurchaseHistoryService
    let loader: GatedPurchaseHistoryLoader

    /// Runs one model event in a task, so a test can act while a held request is in flight.
    func start(_ event: @escaping @MainActor (PurchaseHistoryModel) async -> Void) -> Task<Void, Never> {
        let model = self.model
        return Task { @MainActor in await event(model) }
    }

    /// Waits until the next held request has entered the loader.
    @discardableResult
    func nextHeld() async -> GatedPurchaseHistoryLoader.Call {
        await loader.gate.nextHeldCall()
    }

    func rowIds() -> [String] { model.rows.map(\.id) }
}

@MainActor
func makePurchaseHistoryModelSUT(
    defaultYear: Int = 2026,
    preselected: PurchaseHistoryRecipient? = nil,
    honorsCancellation: Bool = false
) async -> PurchaseHistoryModelSUT {
    let base = await makePurchaseHistoryServiceSUT(honorsCancellation: honorsCancellation)
    let model = PurchaseHistoryModel(
        service: base.service,
        defaultYear: defaultYear,
        preselectedRecipient: preselected
    )
    return PurchaseHistoryModelSUT(model: model, service: base.service, loader: base.loader)
}

/// Rows with the given ids; every row has the same recipient unless one is given.
nonisolated func phRows(
    _ ids: [String],
    recipientId: String = "user-r1",
    recipientName: String = "Pat Recipient"
) -> [PurchaseHistoryRow] {
    ids.map { PurchaseHistoryFix.row(id: $0, recipientId: recipientId, recipientName: recipientName) }
}

nonisolated func phPage(_ ids: [String], next: String? = nil) -> PurchaseHistoryPage {
    PurchaseHistoryFix.page(phRows(ids), nextCursor: next)
}
