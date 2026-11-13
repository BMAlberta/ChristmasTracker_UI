//
//  StatsScreenModelHarness.swift
//  ChristmasTrackerTests
//
//  I5a Story C: shared construction and helpers for the StatsScreenModel tests.
//
//  The model is built over a REAL StatsService and a REAL BudgetService backed by the gated fakes of
//  Story B (GatedStatsLoader, GatedBudgetManager), with an injected clock and calendar. Determinism:
//  gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops. Every held call is
//  released by the test that holds it.
//
//  SPEC GAP (reported to the Orchestrator): the Gate 1 init of StatsScreenModel has no ListService, but
//  makeEditorModel(for:) must hand one to BudgetEditorModel. This harness ASSUMES
//      StatsScreenModel(statsService:budgetService:listService:now:calendar:currencyCode:locale:)
//  and that makeEditorModel(for:) keeps the signature of the brief. The construction and the editor call
//  live only in `makeStatsScreenSUT` and `StatsScreenSUT.editorModel(for:)`, so a different final shape is a
//  one-place fix here.
//
//  All names, ids and amounts are fake.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum StatsScreenTest {
    static let locale = Locale(identifier: "en_US")

    /// 2026-06-15 12:00 UTC, so the current year is 2026 in the UTC calendar below.
    static let now = Date(timeIntervalSince1970: 1_781_524_800)
    static let currentYear = 2026

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        return calendar
    }()

    static let staleMessage = "Couldn't update. Showing saved data."

    /// The stale-data banner of the brief: message plus Try Again and Dismiss.
    static let staleBanner = InlineErrorBannerState(message: staleMessage, actions: [.tryAgain, .dismiss])

    /// Year stats that have purchases but NO budget block.
    static func statsWithoutBudget(year: Int = 2026, spent: String = "100") -> StatsYear {
        BudgetFixtures.statsYear(
            year: year, totalSpent: spent, itemsPurchased: 2, purchaseCount: 1,
            spend: [BudgetFixtures.spend(id: "user-t", name: "Tommy", spent: spent, items: 2)],
            budget: nil,
            availableYears: [2025, 2026]
        )
    }

    /// Year stats with no purchases and no budget.
    static func emptyStats(year: Int = 2026) -> StatsYear {
        BudgetFixtures.statsYear(year: year, availableYears: [2026])
    }

    /// What the screen must show for these inputs (the pure Story A state with the model's formatting).
    static func expectedState(year: Int, stats: StatsYear, budget: Budget?) -> StatsScreenState {
        StatsScreenState.make(year: year, stats: stats, budget: budget, currencyCode: "USD", locale: locale)
    }
}

@MainActor
struct StatsScreenSUT {
    let model: StatsScreenModel
    let stats: StatsService
    let budgets: BudgetService
    let loader: GatedStatsLoader
    let manager: GatedBudgetManager
    let lists: ListService
    let listRepo: GatedListRepository

    /// Scripts the two repositories for one appearance: the budget list, then the year stats.
    func scriptAppear(stats year: StatsYear = StatsFix.year(2026), budgets list: [Budget] = []) {
        manager.enqueueList(list)
        loader.enqueue(year)
    }

    /// The single place that calls makeEditorModel (see the spec gap in the header).
    func editorModel(for sheet: StatsScreenModel.Sheet) -> BudgetEditorModel? {
        model.makeEditorModel(for: sheet)
    }
}

@MainActor
func makeStatsScreenSUT() -> StatsScreenSUT {
    let loader = GatedStatsLoader()
    let manager = GatedBudgetManager()
    let listRepo = GatedListRepository()
    let stats = StatsService(repository: loader)
    let budgets = BudgetService(repository: manager)
    let lists = ListService(repository: listRepo, dataStore: ListDataStore())
    let model = StatsScreenModel(
        statsService: stats,
        budgetService: budgets,
        listService: lists,
        now: { StatsScreenTest.now },
        calendar: StatsScreenTest.calendar,
        currencyCode: "USD",
        locale: StatsScreenTest.locale
    )
    return StatsScreenSUT(
        model: model, stats: stats, budgets: budgets, loader: loader, manager: manager,
        lists: lists, listRepo: listRepo
    )
}

/// A model that has appeared once: year 2026 stats and the given budgets are cached.
@MainActor
func makeLoadedStatsScreenSUT(
    stats: StatsYear = StatsFix.year(2026),
    budgets: [Budget] = [BudgetServiceFix.budget(2026)]
) async -> StatsScreenSUT {
    let sut = makeStatsScreenSUT()
    sut.scriptAppear(stats: stats, budgets: budgets)
    await sut.model.onAppear()
    return sut
}

extension StatsScreenSUT {
    /// Runs a refresh that fails on the stats call while the budget list succeeds, so the failure
    /// belongs to the stats load.
    func failRefresh(with error: BudgetError = .network) async {
        manager.enqueueList([BudgetServiceFix.budget(2026)])
        loader.enqueueFailure(error)
        await model.refresh()
    }

    /// Fails a delete with `hasPurchases` so the card banner shows.
    func showCardBanner(message: String = "Delete the purchases first.") async {
        manager.enqueueFailure(BudgetError.hasPurchases(message: message))
        model.requestDelete()
        await model.confirmDelete()
    }
}
