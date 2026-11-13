//
//  EnvironmentValues+BudgetService.swift
//  ChristmasTracker
//
//  Two environment values for budgets. The service default is built from the inert manager: a view
//  that reads the service without the app injecting one gets a failed load, never fake data. The
//  spending cache invalidator defaults to nil (no hook until the app sets it), so a purchase screen
//  without one simply skips the invalidation step.
//

import SwiftUI

private struct BudgetServiceKey: EnvironmentKey {
    static let defaultValue: BudgetService = BudgetService(repository: InertBudgetManager())
}

private struct SpendingCacheInvalidatorKey: EnvironmentKey {
    static let defaultValue: (any SpendingCacheInvalidating)? = nil
}

extension EnvironmentValues {
    var budgetService: BudgetService {
        get { self[BudgetServiceKey.self] }
        set { self[BudgetServiceKey.self] = newValue }
    }

    var spendingCacheInvalidator: (any SpendingCacheInvalidating)? {
        get { self[SpendingCacheInvalidatorKey.self] }
        set { self[SpendingCacheInvalidatorKey.self] = newValue }
    }
}
