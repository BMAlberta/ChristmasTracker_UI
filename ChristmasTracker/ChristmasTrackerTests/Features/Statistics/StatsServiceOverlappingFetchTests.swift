//
//  StatsServiceOverlappingFetchTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B (Gate 2 fix F2): fetches for the same year are ordered.
//
//  Rule under test: each fetch for a year takes a per-year sequence number when it starts. A fetch
//  whose sequence is older than the newest fetch of that year that has already landed must not write
//  (no data, no fresh mark, no failure). An older fetch that lands BEFORE a newer fetch of that year
//  landed may write its data for display, but the year is marked fresh only if no markSpendingStale
//  happened since that fetch started. Other years do not interfere. Teardown still discards everything.
//
//  Determinism: gated fakes with the nextHeldCall() handshake and release(at:) by arrival index. No
//  sleeps, no yield loops. Every held call is released by the test, so a wrong implementation fails
//  assertions instead of hanging.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsService overlapping fetch Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsServiceOverlappingFetchTests {

    // MARK: Older fetch lands after a newer one

    @Test("an older fetch that lands after a newer one writes nothing: the newer data stays and the year stays fresh",
          arguments: StatsOp.allCases)
    func olderFetchLandingLateIsDiscarded(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)   // A
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"), held: true)   // B
        let fetchA = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()
        sut.service.markSpendingStale()
        let fetchB = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 1)
        await fetchB.value
        sut.loader.gate.release(at: 0)
        await fetchA.value
        let callsBefore = sut.loader.callCount
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"), "B's data is not replaced by A's")
        #expect(sut.loader.callCount == callsBefore, "the year is still fresh: a cache-first load does not fetch")
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("in order: A lands first, then B: B's data wins and the year is fresh after B",
          arguments: StatsOp.allCases)
    func olderFetchLandingFirstThenNewer(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)   // A
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"), held: true)   // B
        let fetchA = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()
        sut.service.markSpendingStale()
        let fetchB = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 0)
        await fetchA.value
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("111"), "A may be shown until B lands")
        sut.loader.gate.release(at: 1)
        await fetchB.value
        let callsBefore = sut.loader.callCount
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"))
        #expect(sut.loader.callCount == callsBefore, "B started after the stale mark, so the year is fresh")
        #expect(sut.service.loadFailure == nil)
    }

    // MARK: Older fetch alone after a stale mark

    @Test("a fetch that started before markSpendingStale and lands alone shows its data but the year is not fresh",
          arguments: StatsOp.allCases)
    func fetchStartedBeforeStaleMarkIsNotFresh(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)
        let fetchA = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()
        sut.service.markSpendingStale()

        sut.loader.gate.releaseAll()
        await fetchA.value
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("111"), "the data is visible")
        let callsBefore = sut.loader.callCount
        sut.loader.enqueue(StatsFix.year(2026, spent: "333"))
        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == callsBefore + 1, "the next load refetches")
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("333"))
    }

    @Test("an older fetch that lands before the newer one, with a stale mark in between, is not fresh by itself")
    func olderFetchLandingFirstIsNotFreshWhenStaleMarked() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)   // A
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"), held: true)   // B, never released before the check
        let fetchA = startStats(sut.service, .load)
        await sut.loader.gate.nextHeldCall()
        sut.service.markSpendingStale()
        let fetchB = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 0)
        await fetchA.value
        let callsBefore = sut.loader.callCount
        sut.loader.enqueue(StatsFix.year(2026, spent: "444"))
        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == callsBefore + 1, "A started before the stale mark: not fresh")
        sut.loader.gate.releaseAll()
        await fetchB.value
    }

    // MARK: Late failure

    @Test("a late failure of the older fetch after a newer one landed sets no loadFailure and keeps the newer data",
          arguments: StatsOp.allCases)
    func lateFailureOfOlderFetchIsDiscarded(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network, held: true)          // A
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"), held: true)   // B
        let fetchA = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()
        let fetchB = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 1)
        await fetchB.value
        sut.loader.gate.release(at: 0)
        await fetchA.value
        let callsBefore = sut.loader.callCount
        await sut.service.load(year: 2026)

        #expect(sut.service.loadFailure == nil, "an outdated failure is not reported")
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"))
        #expect(sut.loader.callCount == callsBefore, "the year stays fresh")
        #expect(sut.service.isLoading == false)
    }

    @Test("a failure of the newest fetch is still reported")
    func failureOfNewestFetchIsReported() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)   // A
        sut.loader.enqueueFailure(BudgetError.network, held: true)          // B
        let fetchA = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()
        let fetchB = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 0)
        await fetchA.value
        sut.loader.gate.release(at: 1)
        await fetchB.value

        #expect(sut.service.loadFailure == .network)
    }

    // MARK: Different years

    @Test("fetches for different years do not interfere: both write and both are fresh")
    func differentYearsDoNotInterfere() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "25"), held: true)    // A, year 2025
        sut.loader.enqueue(StatsFix.year(2026, spent: "26"), held: true)    // B, year 2026
        let fetchA = startStats(sut.service, .load, year: 2025)
        await sut.loader.gate.nextHeldCall()
        let fetchB = startStats(sut.service, .load, year: 2026)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 1)
        await fetchB.value
        sut.loader.gate.release(at: 0)
        await fetchA.value
        let callsBefore = sut.loader.callCount
        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2025)?.totalSpent == BudgetFixtures.dec("25"), "the older fetch of another year writes")
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("26"))
        #expect(sut.loader.callCount == callsBefore, "both years are fresh")
    }

    @Test("a failure of one year's older fetch does not affect another year's newer data")
    func failureOfOtherYearIsStillReported() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.network, held: true)          // A, year 2025
        sut.loader.enqueue(StatsFix.year(2026, spent: "26"), held: true)    // B, year 2026
        let fetchA = startStats(sut.service, .load, year: 2025)
        await sut.loader.gate.nextHeldCall()
        let fetchB = startStats(sut.service, .load, year: 2026)
        await sut.loader.gate.nextHeldCall()

        sut.loader.gate.release(at: 1)
        await fetchB.value
        sut.loader.gate.release(at: 0)
        await fetchA.value

        #expect(sut.service.loadFailure == .network, "2026 landing first does not outrank a 2025 fetch")
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("26"))
    }

    // MARK: Teardown (regression)

    @Test("teardown still discards both overlapping fetches of a year", arguments: [false, true])
    func teardownDiscardsOverlappingFetches(honorsCancellation: Bool) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"), held: true)
        let fetchA = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()
        let fetchB = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        await fetchB.value
        await fetchA.value

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("after teardown a new fetch of the same year writes and is fresh")
    func fetchAfterTeardownWorks() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"))
        await sut.service.refresh(year: 2026)
        await sut.manager.teardown(reason: .userLogout)
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"))

        await sut.service.load(year: 2026)
        let callsBefore = sut.loader.callCount
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"))
        #expect(sut.loader.callCount == callsBefore, "fresh after the new session's fetch")
    }
}
