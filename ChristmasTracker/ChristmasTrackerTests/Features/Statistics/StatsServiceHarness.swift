//
//  StatsServiceHarness.swift
//  ChristmasTrackerTests
//
//  I5a Story B: shared construction and helpers for the StatsService tests.
//
//  The service under test is built over the gated fake:
//      StatsService(repository: GatedStatsLoader)
//  Teardown is driven the way the app does it: the service is registered with a SessionManager and
//  `SessionManager.teardown(reason:)` runs (which calls `clearForSession()`).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct StatsServiceSUT {
    let service: StatsService
    let loader: GatedStatsLoader
    let manager: SessionManager
}

@MainActor
func makeStatsServiceSUT(honorsCancellation: Bool = false) async -> StatsServiceSUT {
    let loader = GatedStatsLoader()
    loader.gate.honorsCancellation = honorsCancellation
    let service = StatsService(repository: loader)
    let manager = SessionManager(initialClearables: [])
    await manager.register(service)
    return StatsServiceSUT(service: service, loader: loader, manager: manager)
}

/// Fake stats for a year; `spent` tells two answers apart.
nonisolated enum StatsFix {
    static func year(_ year: Int = 2026, spent: String = "100") -> StatsYear {
        BudgetFixtures.statsYear(
            year: year, totalSpent: spent, itemsPurchased: 2, purchaseCount: 1,
            spend: [BudgetFixtures.spend(id: "user-t", name: "Tommy", spent: spent, items: 2)],
            budget: BudgetFixtures.statsBudget(total: "1000", spent: spent),
            availableYears: [2025, 2026]
        )
    }
}

/// How a test starts a stats operation in a task.
nonisolated enum StatsOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case load, refresh

    var testDescription: String {
        switch self {
        case .load: "load"
        case .refresh: "refresh"
        }
    }

    @MainActor
    func run(_ service: StatsService, year: Int) async {
        switch self {
        case .load: await service.load(year: year)
        case .refresh: await service.refresh(year: year)
        }
    }
}

/// Starts a stats operation in a task.
@MainActor
func startStats(_ service: StatsService, _ op: StatsOp = .load, year: Int = 2026) -> Task<Void, Never> {
    Task { @MainActor in await op.run(service, year: year) }
}
