//
//  SpendingCacheInvalidator.swift
//  ChristmasTracker
//
//  The hook that tells the stats and budget caches that spending changed (a purchase was recorded
//  or deleted). It marks data stale only: nothing is cleared or fetched, so the Statistics screen
//  keeps showing what it has and refetches the next time it appears.
//

import Foundation

protocol SpendingCacheInvalidating: AnyObject {
    @MainActor func markSpendingStale()
}

/// Marks both session-safe services stale. Holds no data of its own.
@MainActor
final class SpendingCacheInvalidator: SpendingCacheInvalidating {

    private let statsService: StatsService
    private let budgetService: BudgetService

    init(statsService: StatsService, budgetService: BudgetService) {
        self.statsService = statsService
        self.budgetService = budgetService
    }

    func markSpendingStale() {
        statsService.markSpendingStale()
        budgetService.markSpendingStale()
    }
}
