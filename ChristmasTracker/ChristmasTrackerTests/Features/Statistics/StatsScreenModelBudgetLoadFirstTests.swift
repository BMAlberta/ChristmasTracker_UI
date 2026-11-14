//
//  StatsScreenModelBudgetLoadFirstTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 (I5a review finding A, model level): when the stats response shows a budget but the
//  budget cache lacks that year, Edit Budget and Duplicate first load the budgets with
//  budgetService.loadBudgets(force: true) instead of doing nothing. On success the sheet opens; on
//  failure the model sets a retryable budgetCardBanner and opens nothing.
//
//  The entry points are the existing presentEdit() and presentDuplicate(); the tests `await` them
//  because they now suspend while the budgets load.
//
//  Determinism: gated fakes. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The two sheet entry points that need the budget of the selected year.
nonisolated enum BudgetSheetEntry: CaseIterable, Sendable, CustomTestStringConvertible {
    case edit, duplicate

    var testDescription: String {
        switch self {
        case .edit: "presentEdit"
        case .duplicate: "presentDuplicate"
        }
    }

    @MainActor
    func present(_ model: StatsScreenModel) async {
        switch self {
        case .edit: await model.presentEdit()
        case .duplicate: await model.presentDuplicate()
        }
    }

    @MainActor
    func sheet(for budget: Budget) -> StatsScreenModel.Sheet {
        switch self {
        case .edit: .edit(budget)
        case .duplicate: .duplicate(budget)
        }
    }
}

@Suite("StatsScreenModel Edit and Duplicate load the budget first Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelBudgetLoadFirstTests {

    /// The stats of 2026 show a budget block, but the budget cache has no budget for 2026.
    private func makeSUTWithoutCachedBudget() async -> StatsScreenSUT {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026), budgets: [])
        #expect(sut.budgets.budget(for: 2026) == nil, "precondition: the budget cache lacks the year")
        #expect(sut.stats.stats(for: 2026)?.budget != nil, "precondition: the stats show a budget")
        return sut
    }

    // MARK: Success

    @Test("with the budget missing from the cache the sheet opens after the budgets were loaded",
          arguments: BudgetSheetEntry.allCases)
    func loadsFirstThenOpensSheet(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])
        let callsBefore = sut.manager.callCount

        await entry.present(sut.model)

        #expect(sut.manager.callCount == callsBefore + 1, "exactly one budget load")
        #expect(sut.manager.calls.last == .list)
        #expect(sut.model.presentedSheet == entry.sheet(for: budget))
        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.budgets.budget(for: 2026) == budget, "the loaded budget is cached")
    }

    @Test("the load is forced: it goes to the repository", arguments: BudgetSheetEntry.allCases)
    func loadIsForced(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        let listCallsBefore = sut.manager.calls.filter { $0 == .list }.count

        await entry.present(sut.model)

        #expect(sut.manager.calls.filter { $0 == .list }.count == listCallsBefore + 1)
    }

    @Test("with the budget already cached nothing is loaded and the sheet opens at once",
          arguments: BudgetSheetEntry.allCases)
    func cachedBudgetLoadsNothing(entry: BudgetSheetEntry) async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])
        let callsBefore = sut.manager.callCount

        await entry.present(sut.model)

        #expect(sut.manager.callCount == callsBefore)
        #expect(sut.model.presentedSheet == entry.sheet(for: budget))
        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("a successful load-first clears an earlier card banner", arguments: BudgetSheetEntry.allCases)
    func successClearsEarlierBanner(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        #expect(sut.model.budgetCardBanner != nil, "precondition")
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])

        await entry.present(sut.model)

        #expect(sut.model.presentedSheet == entry.sheet(for: budget))
        #expect(sut.model.budgetCardBanner == nil)
    }

    // MARK: Failure

    @Test("when the budgets cannot be loaded no sheet opens and a retryable banner is set",
          arguments: BudgetSheetEntry.allCases, [BudgetError.network, .server, .rateLimited(retryAfter: 3)])
    func failureSetsRetryableBanner(entry: BudgetSheetEntry, error: BudgetError) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(error)

        await entry.present(sut.model)

        #expect(sut.model.presentedSheet == nil)
        let banner = sut.model.budgetCardBanner
        #expect(banner != nil)
        #expect(banner?.actions.contains(.tryAgain) == true, "the banner is retryable")
        #expect(banner?.actions.contains(.dismiss) == true)
    }

    @Test("a load-first failure is a card banner only: no stats failure, no stale banner, the content stays",
          arguments: BudgetSheetEntry.allCases)
    func failureIsScopedToTheCardBanner(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.server)

        await entry.present(sut.model)

        #expect(sut.stats.loadFailure == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.loadPhase == .content)
    }

    @Test("the load-first banner can be dismissed and is cleared when the screen disappears",
          arguments: BudgetSheetEntry.allCases)
    func bannerLifetime(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        #expect(sut.model.budgetCardBanner != nil, "precondition")

        sut.model.dismissBudgetCardBanner()
        #expect(sut.model.budgetCardBanner == nil)

        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        #expect(sut.model.budgetCardBanner != nil, "precondition")

        sut.model.onDisappear()
        #expect(sut.model.budgetCardBanner == nil)
    }

    // MARK: Try Again (retryBudgetCardAction)

    @Test("Try Again after a failed load-first repeats the step: the sheet opens and the banner clears",
          arguments: BudgetSheetEntry.allCases)
    func retrySucceedsOpensSheet(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        #expect(sut.model.budgetCardBanner != nil, "precondition")
        #expect(sut.model.presentedSheet == nil, "precondition")
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])
        let callsBefore = sut.manager.callCount

        await sut.model.retryBudgetCardAction()

        #expect(sut.manager.callCount == callsBefore + 1, "the budget load is repeated")
        #expect(sut.manager.calls.last == .list)
        #expect(sut.model.presentedSheet == entry.sheet(for: budget), "the SAME step: edit stays edit, duplicate stays duplicate")
        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("a Try Again that fails again keeps a retryable banner and opens nothing",
          arguments: BudgetSheetEntry.allCases)
    func retryFailsAgainKeepsRetryableBanner(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        sut.manager.enqueueFailure(BudgetError.server)

        await sut.model.retryBudgetCardAction()

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.budgetCardBanner?.actions.contains(.tryAgain) == true)
        #expect(sut.model.budgetCardBanner?.actions.contains(.dismiss) == true)
    }

    @Test("after a second failure a further Try Again can still succeed", arguments: BudgetSheetEntry.allCases)
    func retryTwice(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        sut.manager.enqueueFailure(BudgetError.network)
        await sut.model.retryBudgetCardAction()
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])

        await sut.model.retryBudgetCardAction()

        #expect(sut.model.presentedSheet == entry.sheet(for: budget))
        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("Try Again repeats the failed step, not the other one: a failed edit never opens the duplicate sheet")
    func retryRepeatsEditNotDuplicate() async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await sut.model.presentEdit()
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])

        await sut.model.retryBudgetCardAction()

        #expect(sut.model.presentedSheet == .edit(budget))
        #expect(sut.model.presentedSheet != .duplicate(budget))
    }

    @Test("Try Again repeats the failed step, not the other one: a failed duplicate never opens the edit sheet")
    func retryRepeatsDuplicateNotEdit() async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await sut.model.presentDuplicate()
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])

        await sut.model.retryBudgetCardAction()

        #expect(sut.model.presentedSheet == .duplicate(budget))
        #expect(sut.model.presentedSheet != .edit(budget))
    }

    @Test("a retry failure is still a card banner only: no stats failure and no stale banner",
          arguments: BudgetSheetEntry.allCases)
    func retryFailureIsScoped(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network)
        await entry.present(sut.model)
        sut.manager.enqueueFailure(BudgetError.network)

        await sut.model.retryBudgetCardAction()

        #expect(sut.stats.loadFailure == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.loadPhase == .content)
    }

    // REWRITTEN (F4, UX1a U2 review): this test used to pin "no sheet and no banner" when the forced
    // load succeeds but the year is still missing. That silent no-op is the bug finding A was about, so
    // the model now shows a retryable banner.
    @Test("when the loaded budgets still have no budget for the year no sheet opens and a retryable banner shows",
          arguments: BudgetSheetEntry.allCases)
    func loadedWithoutTheYearShowsRetryableBanner(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueList([BudgetServiceFix.budget(2025)])

        await entry.present(sut.model)

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.budgetCardBanner == InlineErrorBannerState(
            message: "Couldn't find that budget. Try again.", actions: [.tryAgain, .dismiss]
        ))
    }

    @Test("Try Again after a 'still missing' answer repeats the same step and opens the sheet",
          arguments: BudgetSheetEntry.allCases)
    func retryAfterStillMissing(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueList([BudgetServiceFix.budget(2025)])
        await entry.present(sut.model)
        let budget = BudgetServiceFix.budget(2026)
        sut.manager.enqueueList([budget])

        await sut.model.retryBudgetCardAction()

        #expect(sut.model.presentedSheet == entry.sheet(for: budget))
        #expect(sut.model.budgetCardBanner == nil)
    }

    // MARK: select(year:) cancels a pending load-first (F3)

    @Test("selecting another year while the load-first is in flight: a late success opens no sheet and sets no banner",
          arguments: BudgetSheetEntry.allCases)
    func lateSuccessAfterYearChange(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)], held: true)
        let loadFirst = Task { @MainActor in await entry.present(sut.model) }
        await sut.manager.gate.nextHeldCall()
        sut.manager.enqueueList([])
        sut.loader.enqueue(StatsFix.year(2025))

        let change = Task { @MainActor in await sut.model.select(year: 2025) }
        sut.manager.gate.releaseAll()
        await loadFirst.value
        await change.value

        #expect(sut.model.selectedYear == 2025)
        #expect(sut.model.presentedSheet == nil, "the late completion of year 2026's step must not open a sheet")
        #expect(sut.model.budgetCardBanner == nil)
        await expectPendingStepCleared(sut)
    }

    @Test("selecting another year while the load-first is in flight: a late failure sets no banner",
          arguments: BudgetSheetEntry.allCases)
    func lateFailureAfterYearChange(entry: BudgetSheetEntry) async {
        let sut = await makeSUTWithoutCachedBudget()
        sut.manager.enqueueFailure(BudgetError.network, held: true)
        let loadFirst = Task { @MainActor in await entry.present(sut.model) }
        await sut.manager.gate.nextHeldCall()
        sut.manager.enqueueList([])
        sut.loader.enqueue(StatsFix.year(2025))

        let change = Task { @MainActor in await sut.model.select(year: 2025) }
        sut.manager.gate.releaseAll()
        await loadFirst.value
        await change.value

        #expect(sut.model.selectedYear == 2025)
        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.budgetCardBanner == nil, "no banner for a year other than the selected one")
        await expectPendingStepCleared(sut)
    }

    /// A retry after the year change has no pending step: it loads nothing and opens nothing.
    private func expectPendingStepCleared(_ sut: StatsScreenSUT) async {
        let calls = sut.manager.callCount
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])

        await sut.model.retryBudgetCardAction()

        #expect(sut.manager.callCount == calls, "the pending step was cleared by select(year:)")
        #expect(sut.model.presentedSheet == nil)
    }
}
