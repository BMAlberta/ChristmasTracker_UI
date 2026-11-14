//
//  StatsScreenModelLifecycleFailureTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 (I5a review findings B and C at the model level):
//   - C: a load that completes after onDisappear sets no failure and no banner (the model owns its
//     in-flight loads, onDisappear cancels them and clears the failure);
//   - C: a failed load of the previous year never shows on the newly selected year (the failure the
//     model shows is statsService.failure(forYear: selectedYear));
//   - B: after a successful delete the budget block of that year is dropped from the stats cache
//     locally, before the follow-up refresh, even if that refresh fails.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The model entry points that load.
nonisolated enum StatsModelLoad: CaseIterable, Sendable, CustomTestStringConvertible {
    case onAppear, refresh, tryAgain

    var testDescription: String {
        switch self {
        case .onAppear: "onAppear"
        case .refresh: "refresh"
        case .tryAgain: "tryAgain"
        }
    }

    @MainActor
    func run(_ model: StatsScreenModel) async {
        switch self {
        case .onAppear: await model.onAppear()
        case .refresh: await model.refresh()
        case .tryAgain: await model.tryAgain()
        }
    }
}

@Suite("StatsScreenModel lifecycle and failure scoping Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelLifecycleFailureTests {

    // MARK: A load that finishes after the screen disappeared (finding C)

    @Test("a stats load that FAILS after onDisappear sets no failure and no banner", arguments: StatsModelLoad.allCases)
    func statsFailureAfterDisappearSetsNothing(load: StatsModelLoad) async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.network, held: true)
        let task = Task { @MainActor in await load.run(sut.model) }
        await sut.loader.gate.nextHeldCall()

        sut.model.onDisappear()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.stats.loadFailure == nil)
        #expect(sut.stats.failure(forYear: 2026) == nil)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanner == nil)
    }

    @Test("a stale-data load that FAILS after onDisappear shows no stale banner", arguments: [StatsModelLoad.refresh, .tryAgain])
    func staleFailureAfterDisappearSetsNothing(load: StatsModelLoad) async {
        let sut = await makeLoadedStatsScreenSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        sut.loader.enqueueFailure(BudgetError.server, held: true)
        let task = Task { @MainActor in await load.run(sut.model) }
        await sut.loader.gate.nextHeldCall()

        sut.model.onDisappear()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.stats.loadFailure == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.loadPhase == .content, "the saved data is still on screen")
    }

    @Test("a budget list load that FAILS after onDisappear sets no failure and no banner")
    func budgetListFailureAfterDisappearSetsNothing() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueFailure(BudgetError.network, held: true)
        let task = Task { @MainActor in await sut.model.onAppear() }
        await sut.manager.gate.nextHeldCall()

        sut.model.onDisappear()
        sut.manager.gate.releaseAll()
        await task.value

        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.stats.loadFailure == nil)
    }

    @Test("after leaving and coming back, the screen loads normally and shows its data")
    func reappearAfterDisappearLoadsNormally() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.network, held: true)
        let first = Task { @MainActor in await sut.model.onAppear() }
        await sut.loader.gate.nextHeldCall()
        sut.model.onDisappear()
        sut.loader.gate.releaseAll()
        await first.value
        sut.scriptAppear(stats: StatsFix.year(2026, spent: "55"), budgets: [BudgetServiceFix.budget(2026)])

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
    }

    // MARK: A failed load of the previous year (finding C)

    @Test("a failed load of year A does not show on year B after the user switches to B")
    func previousYearFailureDoesNotShowOnSelectedYear() async {
        let sut = await makeLoadedStatsScreenSUT()          // 2026 cached
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        sut.loader.enqueueFailure(BudgetError.network)      // 2025 cannot be loaded

        await sut.model.select(year: 2025)

        #expect(sut.model.selectedYear == 2025)
        #expect(sut.stats.failure(forYear: 2025) == .network, "precondition")
        #expect(sut.model.failureBanner != nil, "2025 has nothing cached: it shows its own failure")

        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        await sut.model.select(year: 2026)

        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.staleBanner == nil, "2026 loaded fine; the failure belonged to 2025")
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.screenState?.year == 2026)
    }

    @Test("a year-A load that fails late, after the user already selected year B, does not show on B")
    func lateFailureOfPreviousYearDoesNotShowOnSelectedYear() async {
        let sut = await makeLoadedStatsScreenSUT()          // 2026 cached
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        sut.loader.enqueueFailure(BudgetError.network, held: true)   // 2025, fails late
        let previous = Task { @MainActor in await sut.model.select(year: 2025) }
        await sut.loader.gate.nextHeldCall()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        let next = Task { @MainActor in await sut.model.select(year: 2026) }

        sut.loader.gate.releaseAll()
        await previous.value
        await next.value

        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.staleBanner == nil, "the failure of 2025 must not become a stale banner on 2026")
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.loadPhase == .content)
    }

    @Test("the failure shown for the selected year is the one the stats service keeps for that year")
    func selectedYearFailureComesFromTheKeyedFailure() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh(with: .network)

        #expect(sut.stats.failure(forYear: 2026) == .network)
        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner)

        sut.model.onDisappear()

        #expect(sut.stats.failure(forYear: 2026) == nil)
        #expect(sut.model.staleBanner == nil)
    }

    // MARK: Delete drops the budget locally (finding B)

    @Test("after a successful delete the budget is gone from the screen even when the follow-up refresh fails")
    func deleteDropsBudgetWhenRefreshFails() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        #expect(sut.model.screenState?.kind == .budgeted, "precondition")
        sut.manager.enqueueDeleted()
        sut.loader.enqueueFailure(BudgetError.network)

        sut.model.requestDelete()
        await sut.model.confirmDelete()

        #expect(sut.budgets.budget(for: 2026) == nil)
        #expect(sut.stats.stats(for: 2026)?.budget == nil, "the deleted budget is dropped from the stats cache")
        #expect(sut.model.screenState?.budgetCard == nil)
        #expect(sut.model.screenState?.kind == .purchasesWithoutBudget)
        #expect(sut.model.showsCreateBudget == true)
        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.stats.failure(forYear: 2026) == .network, "the refresh failure is still reported")
        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner)
    }

    @Test("the budget is dropped from the stats cache before the follow-up refresh lands")
    func deleteDropsBudgetBeforeRefresh() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        sut.manager.enqueueDeleted()
        sut.loader.enqueue(StatsScreenTest.statsWithoutBudget(), held: true)

        let task = Task { @MainActor in await sut.model.confirmDelete() }
        await sut.loader.gate.nextHeldCall()

        #expect(sut.stats.stats(for: 2026)?.budget == nil, "dropped locally while the refresh is still in flight")
        #expect(sut.model.screenState?.budgetCard == nil)
        sut.loader.gate.releaseAll()
        await task.value
        #expect(sut.model.screenState?.kind == .purchasesWithoutBudget)
    }

    @Test("a failed delete does not drop the budget from the stats cache")
    func failedDeleteKeepsBudgetInStats() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])

        await sut.showCardBanner()

        #expect(sut.stats.stats(for: 2026)?.budget != nil)
        #expect(sut.budgets.budget(for: 2026) != nil)
        #expect(sut.model.screenState?.budgetCard != nil)
    }

    @Test("a cancelled delete does not drop the budget from the stats cache")
    func cancelledDeleteKeepsBudgetInStats() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        sut.manager.enqueueFailure(CancellationError())

        await sut.model.confirmDelete()

        #expect(sut.stats.stats(for: 2026)?.budget != nil)
        #expect(sut.model.screenState?.budgetCard != nil)
    }
}
