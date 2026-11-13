//
//  PurchaseServiceManagementHarness.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: shared construction and helpers for the PurchaseService MANAGEMENT tests
//  (fetchPurchase, updateNotes, updateShipping, deletePurchase).
//
//  The service under test is built with both fakes:
//      PurchaseService(repository: GatedPurchaseRecorder, management: GatedPurchaseManager)
//  Teardown is driven the way the app does it: the service is registered with a SessionManager and
//  `SessionManager.teardown(reason:)` runs (which calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct ManagementServiceSUT {
    let service: PurchaseService
    let management: GatedPurchaseManager
    let recorder: GatedPurchaseRecorder
    let manager: SessionManager
}

func makeManagementServiceSUT(honorsCancellation: Bool = false) async -> ManagementServiceSUT {
    let recorder = GatedPurchaseRecorder()
    let management = GatedPurchaseManager()
    management.gate.honorsCancellation = honorsCancellation
    recorder.gate.honorsCancellation = honorsCancellation
    let service = PurchaseService(repository: recorder, management: management)
    let manager = SessionManager(initialClearables: [])
    await manager.register(service)
    return ManagementServiceSUT(service: service, management: management, recorder: recorder, manager: manager)
}

extension ManagementOp {

    /// Runs this operation through the service with the default update inputs.
    @MainActor
    func call(on service: PurchaseService, id: String = ManagementWire.purchaseId) async throws -> RecordedPurchase {
        switch self {
        case .get: try await service.fetchPurchase(id: id)
        case .updateNotes: try await service.updateNotes(id: id, update: Self.defaultNotes)
        case .updateShipping: try await service.updateShipping(id: id, update: Self.defaultShipping)
        case .delete: try await service.deletePurchase(id: id)
        }
    }

    /// The call the management repository must see for this operation.
    nonisolated func expectedCall(id: String = ManagementWire.purchaseId) -> GatedPurchaseManager.Call {
        switch self {
        case .get: .fetch(id: id)
        case .updateNotes: .updateNotes(id: id, update: Self.defaultNotes)
        case .updateShipping: .updateShipping(id: id, update: Self.defaultShipping)
        case .delete: .delete(id: id)
        }
    }
}

/// Starts a management call in a task and hands back what it returned or threw.
func startManagement(
    _ service: PurchaseService,
    _ op: ManagementOp,
    id: String = ManagementWire.purchaseId
) -> Task<Result<RecordedPurchase, any Error>, Never> {
    Task { @MainActor in
        do {
            return .success(try await op.call(on: service, id: id))
        } catch {
            return .failure(error)
        }
    }
}

extension Result where Success == RecordedPurchase, Failure == any Error {
    /// The error when the call failed, nil when it succeeded.
    var managementThrown: (any Error)? {
        if case .failure(let error) = self { return error }
        return nil
    }

    /// The purchase when the call succeeded, nil when it failed.
    var managementValue: RecordedPurchase? {
        if case .success(let purchase) = self { return purchase }
        return nil
    }
}
