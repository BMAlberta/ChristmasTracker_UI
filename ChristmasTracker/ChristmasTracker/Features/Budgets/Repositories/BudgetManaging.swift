//
//  BudgetManaging.swift
//  ChristmasTracker
//
//  The seam for the caller's own budgets: list them, read one year, create, update, delete and
//  duplicate. Implementations throw `BudgetError`, or `CancellationError`, and nothing else.
//

import Foundation

nonisolated protocol BudgetManaging: Sendable {
    func listBudgets() async throws -> [Budget]
    func budget(year: Int) async throws -> Budget
    func create(_ request: CreateBudgetRequest) async throws -> Budget
    func update(_ request: UpdateBudgetRequest) async throws -> Budget
    func delete(year: Int) async throws
    func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget
}
