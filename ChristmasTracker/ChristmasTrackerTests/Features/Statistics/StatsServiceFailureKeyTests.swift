//
//  StatsServiceFailureKeyTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2 (I5a review findings B and C at the service level):
//   - the load failure is keyed by the year that failed: StatsLoadFailure(year:error:) and
//     failure(forYear:), which returns the stored error only for that year;
//   - a cancelled load records nothing;
//   - dropBudget(year:) removes the budget block of a cached year locally (no network, no generation
//     change), is a no-op when the year or the block is absent and leaves other years alone.
//
//  Determinism: held steps and the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsService failure key and dropBudget Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsServiceFailureKeyTests {

    // MARK: failure(forYear:)

    @Test("a failed load is keyed by its year: failure(forYear:) answers only for that year")
    func failureIsKeyedByYear() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.service.load(year: 2025)

        #expect(sut.service.loadFailure == StatsLoadFailure(year: 2025, error: .network))
        #expect(sut.service.failure(forYear: 2025) == .network)
        #expect(sut.service.failure(forYear: 2026) == nil, "another year never sees this failure")
    }

    @Test("failure(forYear:) is nil on a new service")
    func noFailureInitially() async {
        let sut = await makeStatsServiceSUT()

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    @Test("a failed refresh is keyed by its year too")
    func refreshFailureIsKeyedByYear() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(BudgetError.server)

        await sut.service.refresh(year: 2026)

        #expect(sut.service.failure(forYear: 2026) == .server)
        #expect(sut.service.failure(forYear: 2025) == nil)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"), "the cached data stays")
    }

    @Test("a successful load of the failed year clears the failure")
    func successOfSameYearClears() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.load(year: 2026)
        sut.loader.enqueue(StatsFix.year(2026))

        await sut.service.load(year: 2026)

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    @Test("clearLoadFailure clears the keyed failure for its year")
    func clearLoadFailureClearsKeyedFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.load(year: 2026)
        #expect(sut.service.failure(forYear: 2026) == .network, "precondition")

        sut.service.clearLoadFailure()

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    @Test("teardown clears the keyed failure", arguments: [TeardownReason.userLogout, .sessionExpired])
    func teardownClearsKeyedFailure(reason: TeardownReason) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.load(year: 2026)

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    // MARK: Cancelled load

    @Test("a cancelled load records no failure for its year", arguments: StatsOp.allCases, [false, true])
    func cancelledLoadRecordsNothing(op: StatsOp, honorsCancellation: Bool) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueueFailure(BudgetError.network, held: true)
        let task = startStats(sut.service, op, year: 2026)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    @Test("a repository CancellationError records no failure for its year", arguments: StatsOp.allCases)
    func repositoryCancellationRecordsNothing(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(CancellationError())

        await op.run(sut.service, year: 2026)

        #expect(sut.service.failure(forYear: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
    }

    // MARK: dropBudget(year:)

    @Test("dropBudget removes the budget block of the cached year and keeps the rest of the year's stats")
    func dropBudgetRemovesBlock() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "100"))
        await sut.service.load(year: 2026)
        #expect(sut.service.stats(for: 2026)?.budget != nil, "precondition")

        sut.service.dropBudget(year: 2026)

        let stats = sut.service.stats(for: 2026)
        #expect(stats != nil)
        #expect(stats?.budget == nil)
        #expect(stats?.totalSpent == BudgetFixtures.dec("100"))
        #expect(stats?.spendByRecipient == StatsFix.year(2026, spent: "100").spendByRecipient)
        #expect(stats?.availableYears == [2025, 2026])
        #expect(stats?.year == 2026)
    }

    @Test("dropBudget makes no network call")
    func dropBudgetIsLocal() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026))
        await sut.service.load(year: 2026)
        let calls = sut.loader.callCount

        sut.service.dropBudget(year: 2026)

        #expect(sut.loader.callCount == calls)
    }

    @Test("dropBudget of a year that is not cached is a no-op")
    func dropBudgetAbsentYear() async {
        let sut = await makeStatsServiceSUT()

        sut.service.dropBudget(year: 2026)

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.stats(for: 2026) == nil)
    }

    @Test("dropBudget of a cached year that has no budget block changes nothing")
    func dropBudgetWithoutBlock() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsScreenTest.statsWithoutBudget(year: 2026, spent: "70"))
        await sut.service.load(year: 2026)
        let before = sut.service.stats(for: 2026)

        sut.service.dropBudget(year: 2026)

        #expect(sut.service.stats(for: 2026) == before)
    }

    @Test("dropBudget leaves the other cached years untouched")
    func dropBudgetKeepsOtherYears() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "25"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "26"))
        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)
        let other = sut.service.stats(for: 2025)

        sut.service.dropBudget(year: 2026)

        #expect(sut.service.stats(for: 2025) == other)
        #expect(sut.service.stats(for: 2025)?.budget != nil)
        #expect(sut.service.stats(for: 2026)?.budget == nil)
    }

    @Test("dropBudget bumps no generation and clears no failure")
    func dropBudgetKeepsGenerationAndFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026))
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.refresh(year: 2026)
        let generation = sut.service.sessionGeneration

        sut.service.dropBudget(year: 2026)

        #expect(sut.service.sessionGeneration == generation)
        #expect(sut.service.failure(forYear: 2026) == .network)
    }

    @Test("dropBudget after the session changed is a no-op: the cache stays empty", arguments: [
        TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback
    ])
    func dropBudgetAfterSessionChange(reason: TeardownReason) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026))
        await sut.service.load(year: 2026)
        await sut.manager.teardown(reason: reason)
        let generation = sut.service.sessionGeneration

        sut.service.dropBudget(year: 2026)

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.sessionGeneration == generation)
    }
}
