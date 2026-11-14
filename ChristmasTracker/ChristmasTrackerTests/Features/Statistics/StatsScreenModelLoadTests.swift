//
//  StatsScreenModelLoadTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the load side of StatsScreenModel: the initial year, the year choices, the load phase
//  (loading, failed, content), the full-screen failure banner, cache-first appearance, pull to refresh,
//  year selection, and the screen state kinds. Real services over gated fakes, injected clock.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenModel load Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelLoadTests {

    // MARK: Initial state and year choices

    @Test("the initial selected year is the current year of the injected clock, before anything loads")
    func initialYear() {
        let sut = makeStatsScreenSUT()

        #expect(sut.model.currentYear == 2026)
        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.yearChoices == [2026], "the current year is always a choice")
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.screenState == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.model.isShowingDeleteConfirmation == false)
        #expect(sut.model.presentedSheet == nil)
    }

    @Test("the selected year stays the current year when the server's available years do not include it")
    func currentYearNotInAvailableYears() async {
        let stats = BudgetFixtures.statsYear(year: 2026, availableYears: [2024, 2025])
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: [])

        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.yearChoices == [2026, 2025, 2024])
    }

    @Test("the year choices are the union of the available years, the budget years and the current year, newest first")
    func yearChoicesUnion() async {
        let stats = BudgetFixtures.statsYear(year: 2026, availableYears: [2025, 2024, 2025])
        let budgets = [BudgetServiceFix.budget(2027), BudgetServiceFix.budget(2023), BudgetServiceFix.budget(2025)]
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: budgets)

        #expect(sut.model.yearChoices == [2027, 2026, 2025, 2024, 2023])
    }

    // MARK: Load phase

    @Test("the phase is loading while the first fetch is held, then content")
    func loadingThenContent() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueue(StatsFix.year(2026), held: true)

        let appear = Task { @MainActor in await sut.model.onAppear() }
        await sut.loader.gate.nextHeldCall()
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.screenState == nil)
        #expect(sut.model.failureBanner == nil)

        sut.loader.gate.releaseAll()
        await appear.value
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.screenState != nil)
    }

    @Test("a retryable failure with nothing cached is a failed phase whose banner offers Try Again")
    func failedRetryable() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.model.onAppear()

        let message = BudgetError.network.userMessage
        #expect(sut.model.loadPhase == .failed(message: message))
        #expect(sut.model.failureBanner == InlineErrorBannerState(message: message, actions: [.tryAgain]))
        #expect(sut.model.screenState == nil)
        #expect(sut.model.staleBanner == nil, "the stale banner is only for saved data")
    }

    // REWRITTEN (UX1a U3): the full error now comes from LoadFailurePolicy through LoadBannerPresentation,
    // which knows no per-error retryability: every full error offers Try Again (and no Dismiss, as
    // before for retryable errors). The message and the failed phase are unchanged.
    @Test("a non-retryable failure with nothing cached is a failed phase whose banner offers Try Again only")
    func failedNotRetryable() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.forbidden)

        await sut.model.onAppear()

        let message = BudgetError.forbidden.userMessage
        #expect(sut.model.loadPhase == .failed(message: message))
        #expect(sut.model.failureBanner == InlineErrorBannerState(message: message, actions: [.tryAgain]))
    }

    @Test("Try Again after a failed first load recovers to content and removes the failure banner")
    func tryAgainRecovers() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.server)
        sut.loader.enqueue(StatsFix.year(2026))
        await sut.model.onAppear()
        #expect(sut.model.failureBanner != nil)

        await sut.model.tryAgain()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.screenState != nil)
    }

    @Test("a budget list failure with stats on screen keeps the content and shows the stale banner")
    func budgetListFailureIsALoadFailure() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueFailure(BudgetError.network)
        sut.loader.enqueue(StatsFix.year(2026))

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner)
        #expect(sut.model.failureBanner == nil)
    }

    @Test("the model's own budget list failure is cleared by the next successful load")
    func budgetListFailureClearsOnNextLoad() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueFailure(BudgetError.network)
        sut.loader.enqueue(StatsFix.year(2026))
        await sut.model.onAppear()
        #expect(sut.model.staleBanner != nil)

        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        await sut.model.onAppear()

        #expect(sut.model.staleBanner == nil)
        #expect(sut.budgets.budget(for: 2026) != nil)
    }

    // MARK: Cache first and pull to refresh

    @Test("a second appearance does not refetch while the data is fresh")
    func secondAppearanceIsCacheFirst() async {
        let sut = await makeLoadedStatsScreenSUT()
        #expect(sut.loader.callCount == 1)
        #expect(sut.manager.callCount == 1)

        await sut.model.onAppear()

        #expect(sut.loader.callCount == 1, "fresh stats are not refetched")
        #expect(sut.manager.callCount == 1, "fresh budgets are not refetched")
        #expect(sut.model.loadPhase == .content)
    }

    @Test("after a purchase marks the spending caches stale, the next appearance refetches both")
    func appearanceAfterSpendingChange() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"))
        let invalidator = SpendingCacheInvalidator(statsService: sut.stats, budgetService: sut.budgets)

        invalidator.markSpendingStale()
        sut.scriptAppear(stats: StatsFix.year(2026, spent: "250"), budgets: [BudgetServiceFix.budget(2026)])
        await sut.model.onAppear()

        #expect(sut.loader.calls == [.yearStats(year: 2026), .yearStats(year: 2026)])
        #expect(sut.manager.calls == [.list, .list])
        let expected = StatsScreenTest.expectedState(
            year: 2026, stats: StatsFix.year(2026, spent: "250"), budget: BudgetServiceFix.budget(2026)
        )
        #expect(sut.model.screenState == expected)
    }

    @Test("pull to refresh forces both fetches even when the data is fresh and shows the new data")
    func pullToRefreshForces() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"))
        sut.scriptAppear(stats: StatsFix.year(2026, spent: "300"), budgets: [BudgetServiceFix.budget(2026, total: "1500")])

        await sut.model.refresh()

        #expect(sut.loader.calls == [.yearStats(year: 2026), .yearStats(year: 2026)])
        #expect(sut.manager.calls == [.list, .list])
        let expected = StatsScreenTest.expectedState(
            year: 2026, stats: StatsFix.year(2026, spent: "300"), budget: BudgetServiceFix.budget(2026, total: "1500")
        )
        #expect(sut.model.screenState == expected)
    }

    // MARK: Year selection

    @Test("selecting a year loads it cache-first and shows it; a cached year is not fetched again")
    func selectYear() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [])
        sut.loader.enqueue(StatsFix.year(2025, spent: "40"))

        await sut.model.select(year: 2025)

        #expect(sut.model.selectedYear == 2025)
        #expect(sut.model.screenState?.year == 2025)
        #expect(sut.loader.calls == [.yearStats(year: 2026), .yearStats(year: 2025)])

        await sut.model.select(year: 2026)
        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.screenState?.year == 2026)
        #expect(sut.loader.callCount == 2, "2026 was cached and fresh")
    }

    @Test("a selected year that is still loading shows the loading phase, not the previous year")
    func selectedYearLoadingPhase() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [])
        sut.loader.enqueue(StatsFix.year(2025), held: true)

        let select = Task { @MainActor in await sut.model.select(year: 2025) }
        await sut.loader.gate.nextHeldCall()

        #expect(sut.model.selectedYear == 2025)
        #expect(sut.model.screenState == nil, "nothing is cached for 2025 yet")
        #expect(sut.model.loadPhase == .loading)

        sut.loader.gate.releaseAll()
        await select.value
        #expect(sut.model.loadPhase == .content)
    }

    // MARK: Screen state kinds

    @Test("no purchases and no budget: the nothing state with the Create Budget button")
    func screenStateNothing() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.emptyStats(), budgets: [])

        #expect(sut.model.screenState?.kind == .nothing)
        #expect(sut.model.screenState?.budgetCard == nil)
        #expect(sut.model.screenState?.emptyMessage != nil)
        #expect(sut.model.showsCreateBudget == true)
        #expect(sut.model.createBudgetTitle == "Create Budget")
    }

    @Test("purchases without a budget: the summary, the No budget card and the Create Budget button")
    func screenStatePurchasesWithoutBudget() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.statsWithoutBudget(), budgets: [])

        #expect(sut.model.screenState?.kind == .purchasesWithoutBudget)
        #expect(sut.model.screenState?.noBudgetTitle == "No budget for 2026")
        #expect(sut.model.screenState?.summary != nil)
        #expect(sut.model.showsCreateBudget == true)
    }

    @Test("a budget in the stats response without a cached budget is the budgeted state")
    func screenStateBudgetedFromStats() async {
        let stats = StatsFix.year(2026)
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: [])

        #expect(sut.model.screenState == StatsScreenTest.expectedState(year: 2026, stats: stats, budget: nil))
        #expect(sut.model.screenState?.kind == .budgeted)
        #expect(sut.model.showsCreateBudget == false)
    }

    @Test("the cached budget wins over the stats budget block for the card")
    func screenStateCachedBudgetWins() async {
        let stats = StatsFix.year(2026)
        let cached = BudgetServiceFix.budget(2026, total: "800")
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: [cached])

        #expect(sut.model.screenState == StatsScreenTest.expectedState(year: 2026, stats: stats, budget: cached))
        #expect(sut.model.screenState?.budgetCard?.totalText == "$800.00")
    }

    @Test("a cached budget makes a year with no purchases budgeted")
    func screenStateCachedBudgetWithoutPurchases() async {
        let cached = BudgetServiceFix.budget(2026, total: "800")
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.emptyStats(), budgets: [cached])

        #expect(sut.model.screenState?.kind == .budgeted)
        #expect(sut.model.showsCreateBudget == false)
    }

    // MARK: Over budget text, in every over case the model exposes

    @Test("over the total (cached budget): the card says Over by, in text")
    func overTotalFromCachedBudget() async {
        let over = BudgetFixtures.budget(year: 2026, total: "100", spent: "150")
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026), budgets: [over])

        let card = sut.model.screenState?.budgetCard
        #expect(card?.isOver == true)
        #expect(card?.statusText == "Over by $50.00")
    }

    @Test("over the total (stats budget block only): the card says Over by, in text")
    func overTotalFromStatsBudget() async {
        let stats = BudgetFixtures.statsYear(
            year: 2026, totalSpent: "150", itemsPurchased: 3, purchaseCount: 2,
            spend: [BudgetFixtures.spend(id: "user-t", name: "Tommy", spent: "150", items: 3)],
            budget: BudgetFixtures.statsBudget(total: "100", spent: "150"),
            availableYears: [2026]
        )
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: [])

        let card = sut.model.screenState?.budgetCard
        #expect(card?.isOver == true)
        #expect(card?.statusText == "Over by $50.00")
    }

    @Test("a person over their limit (cached budget): the row says Over by while the total stays under")
    func personOverFromCachedBudget() async {
        let over = BudgetFixtures.budget(
            year: 2026, total: "1000", spent: "80",
            recipients: [BudgetFixtures.recipientBudget(id: "user-t", name: "Tommy", max: "50", spent: "80")]
        )
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026), budgets: [over])

        let rows = sut.model.screenState?.budgetCard?.rows ?? []
        #expect(rows.count == 1)
        #expect(rows.first?.isOver == true)
        #expect(rows.first?.statusText == "Over by $30.00")
        #expect(sut.model.screenState?.budgetCard?.isOver == false)
    }

    @Test("a person over their limit (stats budget block only): the row says Over by")
    func personOverFromStatsBudget() async {
        let recipient = BudgetFixtures.statsRecipientBudget(id: "user-t", name: "Tommy", budget: "50", spent: "80")
        let stats = BudgetFixtures.statsYear(
            year: 2026, totalSpent: "80", itemsPurchased: 2, purchaseCount: 1,
            spend: [BudgetFixtures.spend(id: "user-t", name: "Tommy", spent: "80", items: 2)],
            budget: BudgetFixtures.statsBudget(total: "1000", spent: "80", recipients: [recipient]),
            availableYears: [2026]
        )
        let sut = await makeLoadedStatsScreenSUT(stats: stats, budgets: [])

        let rows = sut.model.screenState?.budgetCard?.rows ?? []
        #expect(rows.first?.isOver == true)
        #expect(rows.first?.statusText == "Over by $30.00")
    }
}
