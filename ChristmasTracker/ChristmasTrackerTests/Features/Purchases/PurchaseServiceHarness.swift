//
//  PurchaseServiceHarness.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: shared construction and helpers for the PurchaseService tests.
//
//  Teardown is driven the way the app does it: the service is registered with a SessionManager
//  and `SessionManager.teardown(reason:)` runs (which calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct PurchaseServiceSUT {
    let service: PurchaseService
    let repo: GatedPurchaseRecorder
    let manager: SessionManager
}

func makePurchaseServiceSUT(honorsCancellation: Bool = false) async -> PurchaseServiceSUT {
    let repo = GatedPurchaseRecorder()
    repo.gate.honorsCancellation = honorsCancellation
    let service = PurchaseService(repository: repo)
    let manager = SessionManager(initialClearables: [])
    await manager.register(service)
    return PurchaseServiceSUT(service: service, repo: repo, manager: manager)
}

/// Starts a record call in a task and hands back what it returned or threw.
func startRecord(
    _ service: PurchaseService,
    itemId: String = "item-1",
    draft: PurchaseDraft = PurchaseFixtures.draft(),
    token: String? = nil
) -> Task<Result<PurchaseOutcome, any Error>, Never> {
    Task { @MainActor in
        do {
            return .success(try await service.recordPurchase(itemId: itemId, draft: draft, confirmationToken: token))
        } catch {
            return .failure(error)
        }
    }
}

extension Result where Success == PurchaseOutcome, Failure == any Error {
    /// The error when the call failed, nil when it succeeded.
    var thrown: (any Error)? {
        if case .failure(let error) = self { return error }
        return nil
    }

    /// The outcome when the call succeeded, nil when it failed.
    var outcome: PurchaseOutcome? {
        if case .success(let outcome) = self { return outcome }
        return nil
    }
}

/// Cheap constructors for service tests.
enum PurchaseServiceFix {
    static func created(_ id: String = "purchase-1") -> PurchaseOutcome {
        .created(PurchaseFixtures.recordedPurchase(id: id))
    }

    static func confirmation(token: String = PurchaseWire.token) -> PurchaseOutcome {
        .confirmationRequired(
            warnings: [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()], token: token
        )
    }
}
