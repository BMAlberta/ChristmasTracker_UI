//
//  MockBudgetRepository.swift
//  ChristmasTracker
//
//  Deterministic in-memory budgets for mock mode and previews. Every rule lives in the shared
//  MockBudgetStore; this class only forwards to it. Intentionally uninstrumented (a mock).
//

import Foundation

nonisolated final class MockBudgetRepository: BudgetManaging, Sendable {

    private let store: MockBudgetStore

    init(store: MockBudgetStore) {
        self.store = store
    }

    func listBudgets() async throws -> [Budget] {
        await store.allBudgets()
    }

    func budget(year: Int) async throws -> Budget {
        try await store.budget(year: year)
    }

    func create(_ request: CreateBudgetRequest) async throws -> Budget {
        try await store.create(request)
    }

    func update(_ request: UpdateBudgetRequest) async throws -> Budget {
        try await store.update(request)
    }

    func delete(year: Int) async throws {
        try await store.delete(year: year)
    }

    func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget {
        try await store.duplicate(request)
    }
}
