//
//  StatsServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: StatsService is session-safe exactly like PurchaseService (one generation counter,
//  one in-flight registry). Stale data from a previous session or user is impossible after teardown,
//  a user switch or caller cancellation, and nothing is written after the session ended.
//
//  Rules under test:
//   - after `clearForSession()` an in-flight load or refresh writes NOTHING (no data, no loadFailure,
//     no isLoading change) whatever the repository returned or threw;
//   - teardown cancels the in-flight tasks, empties the cache, clears loadFailure and resets isLoading,
//     for every teardown reason;
//   - cancelling the caller discards the result: nothing written, loadFailure not set;
//   - after a user switch (clear, then a new call) the new call works and A's late result never
//     reaches B's cache; a year cached by A is not served to B;
//   - the generation changes when the session is cleared and at no other time.
//
//  Teardown is driven the way the app does it: SessionManager.teardown(reason:). Determinism: gated
//  fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsService session safety Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsServiceSessionSafetyTests {

    nonisolated static let reasons: [TeardownReason] = [.userLogout, .sessionExpired, .forcedUpdate, .lockFallback]

    // MARK: Teardown during a call

    @Test("a result that arrives after teardown writes nothing",
          arguments: StatsOp.allCases, [false, true])
    func successAfterTeardownIsDiscarded(op: StatsOp, honorsCancellation: Bool) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(StatsFix.year(2026, spent: "666"), held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.statsByYear.isEmpty, "a stale result must not be stored")
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failure that arrives after teardown sets no loadFailure",
          arguments: StatsOp.allCases, [false, true])
    func failureAfterTeardownIsDiscarded(op: StatsOp, honorsCancellation: Bool) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueueFailure(BudgetError.network, held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.loadFailure == nil, "a stale failure must not reach the next session")
        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.isLoading == false)
    }

    @Test("clearForSession directly discards an in-flight call", arguments: StatsOp.allCases, [false, true])
    func clearForSessionDiscardsTheCall(op: StatsOp, honorsCancellation: Bool) async throws {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("teardown for every reason discards an in-flight call", arguments: reasons)
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.loadFailure == nil)
    }

    @Test("teardown discards every in-flight call at once")
    func teardownDiscardsAllInFlight() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025), held: true)
        sut.loader.enqueue(StatsFix.year(2026), held: true)
        let first = startStats(sut.service, .load, year: 2025)
        await sut.loader.gate.nextHeldCall()
        let second = startStats(sut.service, .refresh, year: 2026)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()
        await first.value
        await second.value

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.isLoading == false)
    }

    // MARK: In-flight tasks are cancelled at teardown

    @Test("teardown cancels the in-flight task: a repository that honors cancellation ends without any release",
          arguments: StatsOp.allCases)
    func teardownCancelsTheInFlightTask(op: StatsOp) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: true)
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        // No release: the call can only end because the service cancelled its task.
        await task.value

        #expect(sut.loader.cancelledCallCount == 1)
        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.loadFailure == nil)
    }

    // MARK: Teardown empties everything

    @Test("teardown empties the cache, clears loadFailure and resets isLoading", arguments: reasons)
    func teardownEmptiesState(reason: TeardownReason) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2025, spent: "25"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "26"))
        await sut.service.load(year: 2025)
        await sut.service.load(year: 2026)
        sut.loader.enqueueFailure(BudgetError.network)
        await sut.service.refresh(year: 2026)
        #expect(sut.service.loadFailure == .network, "precondition")
        #expect(sut.service.statsByYear.count == 2, "precondition")

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.stats(for: 2025) == nil)
        #expect(sut.service.stats(for: 2026) == nil)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("teardown resets isLoading even while a fetch is held")
    func teardownResetsIsLoading() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()
        #expect(sut.service.isLoading == true, "precondition")

        await sut.manager.teardown(reason: .userLogout)

        #expect(sut.service.isLoading == false)
        sut.loader.gate.releaseAll()
        await task.value
    }

    // MARK: Generation

    @Test("A session clear changes the generation; every further clear changes it again")
    func clearChangesGeneration() async {
        let sut = await makeStatsServiceSUT()
        let first = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)
        let second = sut.service.sessionGeneration
        await sut.manager.teardown(reason: .userLogout)
        let third = sut.service.sessionGeneration

        #expect(second > first)
        #expect(third > second)
    }

    @Test("Two services start independent and a clear of one leaves the other alone")
    func servicesAreIndependent() async {
        let one = await makeStatsServiceSUT()
        let two = await makeStatsServiceSUT()
        two.loader.enqueue(StatsFix.year(2026, spent: "5"))
        await two.service.load(year: 2026)
        let before = two.service.sessionGeneration

        await one.manager.teardown(reason: .userLogout)

        #expect(two.service.sessionGeneration == before)
        #expect(two.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("5"))
    }

    // MARK: User switch

    @Test("user switch: A's result, released late, never reaches B and B's call works",
          arguments: StatsOp.allCases)
    func userSwitchLateResult(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"), held: true)   // user A
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"))               // user B
        let userA = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await op.run(sut.service, year: 2026)
        sut.loader.gate.releaseAll()
        await userA.value

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"), "only B's data is present")
        #expect(sut.service.loadFailure == nil)
    }

    @Test("user switch: A's late failure sets no loadFailure for B")
    func userSwitchLateFailure() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.forbidden, held: true)
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"))
        let userA = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.load(year: 2026)
        sut.loader.gate.releaseAll()
        await userA.value

        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"))
    }

    @Test("a year cached by user A is never served to user B: B's load fetches again")
    func cachedYearIsNotServedToTheNextUser() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "111"))
        await sut.service.load(year: 2026)
        await sut.manager.teardown(reason: .userLogout)
        #expect(sut.service.stats(for: 2026) == nil, "precondition: B sees nothing before loading")
        sut.loader.enqueue(StatsFix.year(2026, spent: "222"))

        await sut.service.load(year: 2026)

        #expect(sut.loader.callCount == 2, "B must not be served from A's cache")
        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("222"))
    }

    @Test("a call after teardown works normally in the new session", arguments: StatsOp.allCases)
    func callAfterTeardownWorks(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.loader.enqueue(StatsFix.year(2026, spent: "9"))

        await op.run(sut.service, year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("9"))
        #expect(sut.service.loadFailure == nil)
    }

    @Test("a typed failure in the new session after teardown sets loadFailure")
    func failureAfterTeardownInNewSession() async {
        let sut = await makeStatsServiceSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.service.load(year: 2026)

        #expect(sut.service.loadFailure == .network)
    }

    @Test("clearForSession on an idle service is harmless and repeatable, and calls still work")
    func clearForSessionIdle() async throws {
        let sut = await makeStatsServiceSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        sut.loader.enqueue(StatsFix.year(2026, spent: "4"))
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("4"))
    }

    @Test("markSpendingStale after teardown is harmless and the next load fetches")
    func staleAfterTeardown() async {
        let sut = await makeStatsServiceSUT()
        await sut.manager.teardown(reason: .userLogout)

        sut.service.markSpendingStale()
        sut.loader.enqueue(StatsFix.year(2026, spent: "6"))
        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("6"))
    }

    // MARK: Caller cancellation

    @Test("cancelling the caller discards the result: nothing written and loadFailure not set",
          arguments: StatsOp.allCases, [false, true])
    func cancellingTheCaller(op: StatsOp, honorsCancellation: Bool) async {
        let sut = await makeStatsServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.statsByYear.isEmpty)
        #expect(sut.service.loadFailure == nil)
        #expect(sut.service.isLoading == false)
    }

    @Test("cancelling the caller drops a late typed failure too", arguments: StatsOp.allCases)
    func cancellingTheCallerDropsALateError(op: StatsOp) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueueFailure(BudgetError.server, held: true)
        let task = startStats(sut.service, op)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.loadFailure == nil)
    }

    @Test("a cancelled load does not break the next load")
    func nextLoadAfterCancellation() async {
        let sut = await makeStatsServiceSUT(honorsCancellation: true)
        sut.loader.enqueue(StatsFix.year(2026, spent: "1"), held: true)
        let task = startStats(sut.service)
        await sut.loader.gate.nextHeldCall()
        task.cancel()
        sut.loader.gate.releaseAll()
        await task.value
        sut.loader.enqueue(StatsFix.year(2026, spent: "2"))

        await sut.service.load(year: 2026)

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("2"))
        #expect(sut.service.isLoading == false)
    }

    @Test("a cancelled load keeps the data that was cached before it")
    func cancelledLoadKeepsCachedData() async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year(2026, spent: "10"))
        await sut.service.load(year: 2026)
        sut.loader.enqueue(StatsFix.year(2026, spent: "99"), held: true)
        let task = startStats(sut.service, .refresh)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        await task.value

        #expect(sut.service.stats(for: 2026)?.totalSpent == BudgetFixtures.dec("10"))
        #expect(sut.service.loadFailure == nil)
    }

    // MARK: Production registration

    @Test("SessionManager.teardown clears a service registered as a clearable", arguments: reasons)
    func registeredServiceIsCleared(reason: TeardownReason) async {
        let sut = await makeStatsServiceSUT()
        sut.loader.enqueue(StatsFix.year())
        await sut.service.load(year: 2026)

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.statsByYear.isEmpty)
    }
}
