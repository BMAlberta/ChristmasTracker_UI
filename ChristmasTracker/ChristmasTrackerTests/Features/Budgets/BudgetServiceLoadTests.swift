//
//  BudgetServiceLoadTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: BudgetService.loadBudgets caching and failure rules over the gated fake repository.
//
//  Rules under test:
//   - loadBudgets(force:) is cache-first: after one successful load a non-forced call does no fetch;
//     a forced call, or a call after markSpendingStale(), fetches;
//   - a successful load REPLACES the cache with the server list (a year that is gone disappears);
//   - a failure is RETURNED (typed BudgetError) and publishes nothing; the cache stays as it was;
//   - a CancellationError from the repository returns nil and writes nothing;
//   - markSpendingStale() keeps the budgets visible and makes the next load refetch.
//
//  Determinism: held steps and the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetService load Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetServiceLoadTests {

    nonisolated static let failures: [BudgetError] = [
        .network, .server, .forbidden, .notFound, .invalidResponse, .rateLimited(retryAfter: 3), .unauthorized
    ]

    private func total(_ service: BudgetService, _ year: Int) -> Decimal? {
        service.budget(for: year)?.totalBudget
    }

    // MARK: Initial state

    @Test("A new service is empty and idle")
    func initialState() async {
        let sut = await makeBudgetServiceSUT()

        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.budget(for: 2026) == nil)
        #expect(sut.service.hasLoaded == false)
        #expect(sut.service.isLoading == false)
        #expect(sut.manager.callCount == 0)
    }

    // MARK: Cache-first

    @Test("the first load fetches the list, files each budget under its year and marks the service loaded")
    func firstLoadFetches() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000"), BudgetServiceFix.budget(2025, total: "500")])

        let failure = await sut.service.loadBudgets(force: false)

        #expect(failure == nil)
        #expect(sut.manager.calls == [.list])
        #expect(sut.service.budget(for: 2026) == BudgetServiceFix.budget(2026, total: "1000"))
        #expect(sut.service.budget(for: 2025) == BudgetServiceFix.budget(2025, total: "500"))
        #expect(sut.service.budgetsByYear.count == 2)
        #expect(sut.service.hasLoaded == true)
        #expect(sut.service.isLoading == false)
    }

    @Test("a loaded service answers a non-forced load from the cache with no second fetch")
    func loadIsCacheFirst() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "9999")])

        _ = await sut.service.loadBudgets(force: false)
        let second = await sut.service.loadBudgets(force: false)
        let third = await sut.service.loadBudgets(force: false)

        #expect(second == nil)
        #expect(third == nil)
        #expect(sut.manager.callCount == 1)
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1000"))
    }

    @Test("a forced load fetches again and replaces the data")
    func forcedLoadFetches() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1500")])
        _ = await sut.service.loadBudgets(force: false)

        let failure = await sut.service.loadBudgets(force: true)

        #expect(failure == nil)
        #expect(sut.manager.callCount == 2)
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1500"))
    }

    @Test("a successful load replaces the cache with the server list: a year that is gone disappears")
    func loadReplacesTheCache() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026), BudgetServiceFix.budget(2025)])
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        _ = await sut.service.loadBudgets(force: false)

        _ = await sut.service.loadBudgets(force: true)

        #expect(sut.service.budget(for: 2025) == nil)
        #expect(sut.service.budgetsByYear.count == 1)
    }

    @Test("an empty server list empties the cache and still counts as loaded")
    func emptyListIsLoaded() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.enqueueList([])

        _ = await sut.service.loadBudgets(force: true)

        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.hasLoaded == true)
    }

    @Test("isLoading is true while a load is in flight and false when it ends")
    func isLoadingWhileInFlight() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget()], held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()
        #expect(sut.service.isLoading == true)

        sut.manager.gate.releaseAll()
        _ = await task.value

        #expect(sut.service.isLoading == false)
        #expect(sut.service.budget(for: 2026) != nil)
    }

    // MARK: Stale

    @Test("after markSpendingStale the budgets stay visible and the next load refetches")
    func staleKeepsDataAndRefetches() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        _ = await sut.service.loadBudgets(force: false)

        sut.service.markSpendingStale()
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1000"), "stale data stays visible")
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1100")], held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1000"), "old data visible during the refetch")
        sut.manager.gate.releaseAll()
        _ = await task.value

        #expect(sut.manager.callCount == 2)
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1100"))
    }

    @Test("once refetched the budgets are fresh again and the next load is cache-first")
    func freshAgainAfterRefetch() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1100")])
        _ = await sut.service.loadBudgets(force: false)
        sut.service.markSpendingStale()
        _ = await sut.service.loadBudgets(force: false)

        _ = await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == 2)
    }

    @Test("markSpendingStale on a service that never loaded is harmless and the next load fetches")
    func staleBeforeLoad() async {
        let sut = await makeBudgetServiceSUT()

        sut.service.markSpendingStale()
        sut.manager.enqueueList([BudgetServiceFix.budget()])
        _ = await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == 1)
        #expect(sut.service.budget(for: 2026) != nil)
    }

    // MARK: Failures

    @Test("a failed load RETURNS the typed error and caches nothing", arguments: failures)
    func failedLoadReturnsTheError(error: BudgetError) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(error)

        let failure = await sut.service.loadBudgets(force: false)

        #expect(failure == error)
        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failed forced load keeps the cached budgets and stays loaded", arguments: failures)
    func failedForcedLoadKeepsCache(error: BudgetError) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.enqueueFailure(error)

        let failure = await sut.service.loadBudgets(force: true)

        #expect(failure == error)
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1000"))
        #expect(sut.service.hasLoaded == true)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failed stale refetch keeps the stale budgets visible")
    func failedStaleRefetchKeepsData() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000")])
        _ = await sut.service.loadBudgets(force: false)
        sut.service.markSpendingStale()
        sut.manager.enqueueFailure(BudgetError.network)

        let failure = await sut.service.loadBudgets(force: false)

        #expect(failure == .network)
        #expect(total(sut.service, 2026) == BudgetFixtures.dec("1000"))
    }

    @Test("a load after a failure with nothing cached tries again")
    func loadRetriesAfterFailure() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.network)
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.enqueueList([BudgetServiceFix.budget()])

        let failure = await sut.service.loadBudgets(force: false)

        #expect(failure == nil)
        #expect(sut.manager.callCount == 2)
        #expect(sut.service.budget(for: 2026) != nil)
    }

    @Test("a CancellationError from the repository returns nil and writes nothing", arguments: [false, true])
    func repositoryCancellationReturnsNil(force: Bool) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(CancellationError())

        let failure = await sut.service.loadBudgets(force: force)

        #expect(failure == nil)
        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failed load changes no published state beyond the cache and flags: the failure is only returned")
    func failureIsOnlyReturned() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        _ = await sut.service.loadBudgets(force: false)
        let cacheBefore = sut.service.budgetsByYear
        sut.manager.enqueueFailure(BudgetError.server)

        let failure = await sut.service.loadBudgets(force: true)

        #expect(failure == .server)
        #expect(sut.service.budgetsByYear == cacheBefore)
        #expect(sut.service.hasLoaded == true)
        #expect(sut.service.isLoading == false)
    }

    @Test("the session generation does not change by loading or marking stale")
    func generationIsStableAcrossLoads() async {
        let sut = await makeBudgetServiceSUT()
        let before = sut.service.sessionGeneration
        sut.manager.enqueueList([BudgetServiceFix.budget()])
        sut.manager.enqueueFailure(BudgetError.network)

        _ = await sut.service.loadBudgets(force: false)
        _ = await sut.service.loadBudgets(force: true)
        sut.service.markSpendingStale()

        #expect(sut.service.sessionGeneration == before)
    }
}
