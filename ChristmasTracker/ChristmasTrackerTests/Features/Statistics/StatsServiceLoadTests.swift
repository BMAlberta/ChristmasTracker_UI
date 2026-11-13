//
//  StatsServiceLoadTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: StatsService caching and load failure rules over the gated fake repository.
//
//  Rules under test:
//   - load(year:) is cache-first: a fresh cached year does no fetch; a missing or stale year fetches;
//   - years are cached independently;
//   - refresh(year:) always fetches;
//   - markSpendingStale() keeps every cached year visible but makes the next load refetch it;
//   - a failed load or refresh keeps the cached data and sets `loadFailure` (the Statistics screen's
//     load error only); a successful fetch and clearLoadFailure() clear it;
//   - a CancellationError from the repository sets nothing.
//
//  Determinism: held steps and the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsService load Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsServiceLoadTests {

    nonisolated static let failures: [BudgetError] = [
        .network, .server, .forbidden, .notFound, .invalidResponse, .rateLimited(retryAfter: 3), .unauthorized
    ]

    // MARK: Initial state

    @Test("A new service is empty, idle and has no failure")
    func initialState() async {
        let sut = await makeStatsServiceSUT()

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
        #expect(sut.loader.callCount == 0)
    }

    // MARK: Cache-first

    @Test("load fetches a missing year, asks the repository for that year and stores the result")
    func loadFetchesMissingYear() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "123.45"))

        await sut.service.load(year: 2026)

        #expect(sut.loader.calls == [.yearStats(year: 2026)])
        #expect(sut.service.stats(for: 2026) == StatsFix.year(2026, spent: "123.45"))
        #expect(sut.service.statsByYear[2026]?.totalSpent == BudgetFixtures.dec("123.45"))
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("load of a fresh cached year does no second fetch and keeps the data")
    func loadIsCacheFirst() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "99"))

        await sut.service.load(year: 2026)
        await sut.service.load(year: 2026)
        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 1)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"))
    }

    @Test("years are cached independently: each missing year fetches once and a cached year does not refetch")
    func yearsAreIndependent() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "25"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "26"))

        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)
        await sut.service.load(year: 2025)

        #expect(sut.loader.calls == [.yearStats(year: 2025), .yearStats(year: 2026)])
        #expect(sut.service.stats(for: 2025)?.totalSpent == BudgetFixtures.dec("25"))
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("26"))
        #expect(sut.service.statsByYear.count == 2)
    }

    @Test("isLoading is true while a fetch is in flight and false when it ends")
    func isLoadingWhileInFlight() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()
        #expect(sut.service.isLoading == true)

        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.isLoading == false)
        #expect(sut.service.stats(for: 2026) != nil)
    }

    // MARK: Refresh

    @Test("refresh always fetches, even for a fresh cached year, and replaces the data")
    func refreshForcesAFetch() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "20"))
        await sut.service.load(year: 2026)

        await sut.service.refresh(year: 2026)

        #expect(sut.loader.callCount == 2)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("20"))
        #expect(sut.loader.calls.last == .yearStats(year: 2026))
    }

    @Test("refresh of an uncached year fetches and stores it")
    func refreshUncachedYear() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2027, spent: "7"))

        await sut.service.refresh(year: 2027)

        #expect(sut.service.stats(for: 2027)?.totalSpent == BudgetFixtures.dec("7"))
    }

    @Test("a refresh keeps the old data visible while it is in flight")
    func refreshKeepsOldDataVisible() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueue(StatsFix.year(2026, spent: "20"), held: true)
        let task = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"), "old data stays visible")
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("20"))
    }

    // MARK: Stale

    @Test("after markSpendingStale the old data stays visible and the next load refetches")
    func staleKeepsDataAndRefetches() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)

        sut.service.markSpendingStale()
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"), "stale data stays visible")
        sut.loader.enqueue(StatsFix.year(2026, spent: "55"), held: true)
        let task = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"), "old data visible during the refetch")
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.loader.callCount == 2)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("55"))
    }

    @Test("once refetched, the year is fresh again and the next load is cache-first")
    func freshAgainAfterRefetch() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "55"))
        await sut.service.load(year: 2026)
        sut.service.markSpendingStale()
        await sut.service.load(year: 2026)

        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 2)
    }

    @Test("markSpendingStale makes every cached year stale, not just one")
    func staleCoversEveryYear() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "1"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "2"))
        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)

        sut.service.markSpendingStale()
        sut.loader.enqueue(StatsFix.year(2025, spent: "11"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "22"))
        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 4)
        #expect(sut.service.stats(for: 2025)?.totalSpent == BudgetFixtures.dec("11"))
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("22"))
    }

    @Test("markSpendingStale on an empty service is harmless and a later load fetches normally")
    func staleOnEmptyService() async {
        let sut = await makeStatsServiceSUT()

        sut.service.markSpendingStale()
        sut.loader.enqueue(StatsFix.year(2026, spent: "3"))
        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 1)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("3"))
    }

    @Test("a stale year whose refetch fails keeps its data visible and sets loadFailure")
    func staleRefetchFailureKeepsData() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.service.markSpendingStale()
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"))
        #expect(sut.service.loadFailure == .network)
    }

    // MARK: Failures

    @Test("a failed load with nothing cached sets loadFailure to the typed error and caches nothing",
          arguments: failures)
    func failedLoadSetsLoadFailure(error: BudgetError) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(error)

        await sut.service.load(year: 2026)

        #expect(sut.service.loadFailure == error)
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failed refresh keeps the cached data and sets loadFailure", arguments: failures)
    func failedRefreshKeepsCachedData(error: BudgetError) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(error)

        await sut.service.refresh(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"))
        #expect(sut.service.loadFailure == error)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failure for one year leaves the other cached years alone")
    func failureLeavesOtherYears() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "25"))
        await sut.service.load(year: 2025)
        sut.loader.enqueueFailure(BudgetError.server)

        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2025)?.totalSpent == BudgetFixtures.dec("25"))
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.loadFailure == .server)
    }

    @Test("a load after a failure with nothing cached tries again")
    func loadRetriesAfterFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.load(year: 2026)
        sut.loader.enqueue(StatsFix.year(2026, spent: "8"))

        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 2)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("8"))
    }

    @Test("a CancellationError from the repository sets no failure and caches nothing", arguments: StatsOp.allCases)
    func repositoryCancellationSetsNothing(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(CancellationError())

        await op.run(sut.service, year: 2026)

        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.isLoading == false)
    }

    // MARK: loadFailure lifecycle

    @Test("a new successful load clears loadFailure")
    func successfulLoadClearsFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.load(year: 2026)
        #expect(sut.service.loadFailure == .network)
        sut.loader.enqueue(StatsFix.year())

        await sut.service.load(year: 2026)

        #expect(sut.service.loadFailure == nil)
    }

    @Test("a successful refresh clears loadFailure")
    func successfulRefreshClearsFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(BudgetError.server)
        await sut.service.refresh(year: 2026)
        #expect(sut.service.loadFailure == .server)
        sut.loader.enqueue(StatsFix.year(2026, spent: "12"))

        await sut.service.refresh(year: 2026)

        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("12"))
    }

    @Test("clearLoadFailure clears the failure and keeps the cached data")
    func clearLoadFailureClears() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.refresh(year: 2026)
        #expect(sut.service.loadFailure == .network)

        sut.service.clearLoadFailure()

        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"))
    }

    @Test("clearLoadFailure with no failure is harmless")
    func clearLoadFailureWithoutFailure() async {
        let sut = await makeStatsServiceSUT()

        sut.service.clearLoadFailure()

        #expect(sut.service.loadFailure == nil)
    }

    @Test("the session generation does not change by loading, refreshing or marking stale")
    func generationIsStableAcrossCalls() async {
        let sut = await makeStatsServiceSUT()
        let before = sut.service.sessionGeneration
        sut.loader.enqueue(StatsFix.year())
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.service.load(year: 2026)
        await sut.service.refresh(year: 2026)
        sut.service.markSpendingStale()
        sut.service.clearLoadFailure()

        #expect(sut.service.sessionGeneration == before)
    }
}
