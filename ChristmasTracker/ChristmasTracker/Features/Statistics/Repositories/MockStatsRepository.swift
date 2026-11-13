//
//  MockStatsRepository.swift
//  ChristmasTracker
//
//  Deterministic in-memory year statistics for mock mode and previews, read from the same
//  MockBudgetStore as the mock budgets, so a budget created, changed or deleted there shows in the
//  next answer. The spend rows never move (documented limitation of the store). Intentionally
//  uninstrumented (a mock).
//

import Foundation

nonisolated final class MockStatsRepository: StatsLoading, Sendable {

    private let store: MockBudgetStore

    init(store: MockBudgetStore) {
        self.store = store
    }

    func yearStats(year: Int) async throws -> StatsYear {
        await store.yearStats(year: year)
    }
}
