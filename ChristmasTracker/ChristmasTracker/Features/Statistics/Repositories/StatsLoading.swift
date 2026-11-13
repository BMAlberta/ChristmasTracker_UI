//
//  StatsLoading.swift
//  ChristmasTracker
//
//  The seam for the caller's own year statistics. Implementations throw `BudgetError`, or
//  `CancellationError`, and nothing else.
//

import Foundation

nonisolated protocol StatsLoading: Sendable {
    func yearStats(year: Int) async throws -> StatsYear
}
