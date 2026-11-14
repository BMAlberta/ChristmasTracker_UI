//
//  BudgetServiceHarness.swift
//  ChristmasTrackerTests
//
//  I5a Story B: shared construction and helpers for the BudgetService tests.
//
//  The service under test is built over the gated fake:
//      BudgetService(repository: GatedBudgetManager)
//  Teardown is driven the way the app does it: the service is registered with a SessionManager and
//  `SessionManager.teardown(reason:)` runs (which calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct BudgetServiceSUT {
    let service: BudgetService
    let manager: GatedBudgetManager
    let sessions: SessionManager
}

@MainActor
func makeBudgetServiceSUT(honorsCancellation: Bool = false) async -> BudgetServiceSUT {
    let manager = GatedBudgetManager()
    manager.gate.honorsCancellation = honorsCancellation
    let service = BudgetService(repository: manager)
    let sessions = SessionManager(initialClearables: [])
    await sessions.register(service)
    return BudgetServiceSUT(service: service, manager: manager, sessions: sessions)
}

/// Fake budgets; `total` tells two answers for the same year apart.
nonisolated enum BudgetServiceFix {

    static func budget(_ year: Int = 2026, total: String = "1000") -> Budget {
        BudgetFixtures.budget(
            year: year, total: total, spent: "100",
            recipients: [BudgetFixtures.recipientBudget(id: "user-t", name: "Tommy", max: "400", spent: "50")]
        )
    }

    static func createRequest(year: Int = 2026, total: String = "1000") -> CreateBudgetRequest {
        CreateBudgetRequest(
            year: year, totalBudget: BudgetFixtures.dec(total),
            recipients: [BudgetLimit(recipientId: "user-t", maxSpend: BudgetFixtures.dec("400"))]
        )
    }

    static func updateRequest(year: Int = 2026, total: String? = "1200") -> UpdateBudgetRequest {
        UpdateBudgetRequest(year: year, totalBudget: total.map(BudgetFixtures.dec), recipients: nil)
    }

    static func duplicateRequest(from: Int = 2026, to: Int = 2027) -> DuplicateBudgetRequest {
        DuplicateBudgetRequest(fromYear: from, toYear: to)
    }
}

/// The three mutations that store the returned budget, so one test can run against each.
nonisolated enum BudgetStoringOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case create, update, duplicate

    var testDescription: String {
        switch self {
        case .create: "create"
        case .update: "update"
        case .duplicate: "duplicate"
        }
    }

    /// The year the returned budget is filed under.
    var year: Int {
        switch self {
        case .create, .update: 2026
        case .duplicate: 2027
        }
    }

    @MainActor
    func call(on service: BudgetService) async throws -> Budget {
        switch self {
        case .create: try await service.create(BudgetServiceFix.createRequest())
        case .update: try await service.update(BudgetServiceFix.updateRequest())
        case .duplicate: try await service.duplicate(BudgetServiceFix.duplicateRequest())
        }
    }

    /// The call the repository must see for this operation.
    var expectedCall: GatedBudgetManager.Call {
        switch self {
        case .create: .create(BudgetServiceFix.createRequest())
        case .update: .update(BudgetServiceFix.updateRequest())
        case .duplicate: .duplicate(BudgetServiceFix.duplicateRequest())
        }
    }
}

/// All four mutations (the three that store, plus delete), for the failure and session tests.
nonisolated enum BudgetMutation: CaseIterable, Sendable, CustomTestStringConvertible {
    case create, update, duplicate, delete

    var testDescription: String {
        switch self {
        case .create: "create"
        case .update: "update"
        case .duplicate: "duplicate"
        case .delete: "delete"
        }
    }

    /// The year the mutation touches in the cache.
    var year: Int {
        switch self {
        case .create, .update, .delete: 2026
        case .duplicate: 2027
        }
    }

    @MainActor
    func call(on service: BudgetService) async throws {
        switch self {
        case .create: _ = try await service.create(BudgetServiceFix.createRequest())
        case .update: _ = try await service.update(BudgetServiceFix.updateRequest())
        case .duplicate: _ = try await service.duplicate(BudgetServiceFix.duplicateRequest())
        case .delete: try await service.delete(year: 2026)
        }
    }

    /// Scripts a success for this mutation.
    @MainActor
    func enqueueSuccess(on manager: GatedBudgetManager, held: Bool = false) {
        switch self {
        case .create, .update: manager.enqueue(BudgetServiceFix.budget(2026, total: "777"), held: held)
        case .duplicate: manager.enqueue(BudgetServiceFix.budget(2027, total: "777"), held: held)
        case .delete: manager.enqueueDeleted(held: held)
        }
    }
}

/// Starts a mutation in a task and hands back what it returned or threw.
@MainActor
func startMutation(
    _ service: BudgetService,
    _ mutation: BudgetMutation
) -> Task<(any Error)?, Never> {
    Task { @MainActor in
        do {
            try await mutation.call(on: service)
            return nil
        } catch {
            return error
        }
    }
}

/// Starts loadBudgets in a task and hands back the returned failure.
@MainActor
func startLoadBudgets(_ service: BudgetService, force: Bool) -> Task<BudgetError?, Never> {
    Task { @MainActor in await service.loadBudgets(force: force) }
}
