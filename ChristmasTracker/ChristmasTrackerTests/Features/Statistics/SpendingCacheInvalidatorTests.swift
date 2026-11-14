//
//  SpendingCacheInvalidatorTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: the concrete SpendingCacheInvalidator (the object the app hands to the purchase
//  refresh runner) marks BOTH session-safe services stale: every cached year of StatsService and the
//  budget list of BudgetService stay visible but the next non-forced load refetches.
//
//  Also pins the protocol: both services conform to SpendingCacheInvalidating themselves, and the
//  environment value `\.spendingCacheInvalidator` defaults to nil (no hook until the app sets it).
//

import Foundation
import SwiftUI
import Testing
@testable import ChristmasTracker

@Suite("SpendingCacheInvalidator Tests", .timeLimit(.minutes(1)))
@MainActor
struct SpendingCacheInvalidatorTests {

    private struct SUT {
        let invalidator: SpendingCacheInvalidator
        let statsService: StatsService
        let budgetService: BudgetService
        let stats: GatedStatsLoader
        let budgets: GatedBudgetManager
    }

    private func makeSUT() -> SUT {
        let stats = GatedStatsLoader()
        let budgets = GatedBudgetManager()
        let statsService = StatsService(repository: stats)
        let budgetService = BudgetService(repository: budgets)
        return SUT(
            invalidator: SpendingCacheInvalidator(statsService: statsService, budgetService: budgetService),
            statsService: statsService, budgetService: budgetService, stats: stats, budgets: budgets
        )
    }

    // MARK: Marks both stale

    @Test("markSpendingStale makes the next StatsService.load refetch and keeps the old data visible meanwhile")
    func statsRefetchesAfterInvalidation() async {
        let sut = makeSUT()
        sut.stats.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.statsService.load(year: 2026)
        await sut.statsService.load(year: 2026)
        #expect(sut.stats.callCount == 1, "precondition: cache-first before the invalidation")

        sut.invalidator.markSpendingStale()
        #expect(sut.statsService.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"), "the old data stays visible")
        sut.stats.enqueue(StatsFix.year(2026, spent: "35"))
        await sut.statsService.load(year: 2026)

        #expect(sut.stats.callCount == 2)
        #expect(sut.statsService.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("35"))
    }

    @Test("markSpendingStale makes the next non-forced loadBudgets refetch and keeps the old data visible")
    func budgetsRefetchAfterInvalidation() async {
        let sut = makeSUT()
        sut.budgets.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        _ = await sut.budgetService.loadBudgets(force: false)
        _ = await sut.budgetService.loadBudgets(force: false)
        #expect(sut.budgets.callCount == 1, "precondition: cache-first before the invalidation")

        sut.invalidator.markSpendingStale()
        #expect(sut.budgetService.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("1000"), "the old data stays visible")
        sut.budgets.enqueueList([BudgetServiceFix.budget(2026, total: "1100")])
        _ = await sut.budgetService.loadBudgets(force: false)

        #expect(sut.budgets.callCount == 2)
        #expect(sut.budgetService.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("1100"))
    }

    @Test("one markSpendingStale call marks both services")
    func marksBothServicesTogether() async {
        let sut = makeSUT()
        sut.stats.enqueue(StatsFix.year(2026, spent: "10"))
        sut.budgets.enqueueList([BudgetServiceFix.budget(2026)])
        await sut.statsService.load(year: 2026)
        _ = await sut.budgetService.loadBudgets(force: false)

        sut.invalidator.markSpendingStale()
        sut.stats.enqueue(StatsFix.year(2026, spent: "20"))
        sut.budgets.enqueueList([BudgetServiceFix.budget(2026, total: "1200")])
        await sut.statsService.load(year: 2026)
        _ = await sut.budgetService.loadBudgets(force: false)

        #expect(sut.stats.callCount == 2)
        #expect(sut.budgets.callCount == 2)
    }

    @Test("markSpendingStale on idle services is harmless")
    func harmlessWhenIdle() async {
        let sut = makeSUT()

        sut.invalidator.markSpendingStale()
        sut.invalidator.markSpendingStale()

        #expect(sut.statsService.statsByYear.isEmpty)
        #expect(sut.budgetService.budgetsByYear.isEmpty)
        #expect(sut.stats.callCount == 0)
        #expect(sut.budgets.callCount == 0)
    }

    // MARK: Protocol

    @Test("both services are SpendingCacheInvalidating themselves")
    func servicesConform() {
        let sut = makeSUT()

        #expect((sut.statsService as AnyObject) is any SpendingCacheInvalidating)
        #expect((sut.budgetService as AnyObject) is any SpendingCacheInvalidating)
        #expect((sut.invalidator as AnyObject) is any SpendingCacheInvalidating)
    }

    @Test("the environment value spendingCacheInvalidator defaults to nil and can be set")
    func environmentDefault() {
        var environment = EnvironmentValues()
        #expect(environment.spendingCacheInvalidator == nil)

        let recorder = RecordingSpendingInvalidator()
        environment.spendingCacheInvalidator = recorder
        environment.spendingCacheInvalidator?.markSpendingStale()

        #expect(recorder.markCount == 1)
    }

    @Test("the environment still has default stats and budget services that are idle")
    func environmentServiceDefaults() {
        let environment = EnvironmentValues()

        #expect(environment.statsService.statsByYear.isEmpty)
        #expect(environment.statsService.loadFailure == nil)
        #expect(environment.statsService.isLoading == false)
        #expect(environment.budgetService.budgetsByYear.isEmpty)
        #expect(environment.budgetService.hasLoaded == false)
        #expect(environment.budgetService.isLoading == false)
    }

    @Test("the environment services can be replaced")
    func environmentServiceOverride() {
        var environment = EnvironmentValues()
        let stats = StatsService(repository: GatedStatsLoader())
        let budgets = BudgetService(repository: GatedBudgetManager())

        environment.statsService = stats
        environment.budgetService = budgets

        #expect(environment.statsService === stats)
        #expect(environment.budgetService === budgets)
    }
}
