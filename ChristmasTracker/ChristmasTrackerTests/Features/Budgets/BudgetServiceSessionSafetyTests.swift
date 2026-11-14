//
//  BudgetServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: BudgetService is session-safe exactly like PurchaseService (one generation counter,
//  one in-flight registry, one ensureCurrent check). Stale data from a previous session or user is
//  impossible after teardown, a user switch or caller cancellation, and nothing is written after the
//  session ended.
//
//  Rules under test:
//   - after `clearForSession()` an in-flight mutation ends with CancellationError whatever the
//     repository returned or threw (a stale success or a stale typed error is dropped; a typed error
//     is NOT thrown instead) and writes nothing;
//   - after `clearForSession()` an in-flight loadBudgets returns nil and writes nothing;
//   - cancelling the caller ends a mutation with CancellationError even when the repository keeps
//     running and later returns a result; a cancelled load returns nil and writes nothing;
//   - teardown cancels the in-flight tasks, empties the cache and resets hasLoaded and isLoading;
//   - after a user switch (clear, then a new call) the new call works and the old late result never
//     reaches it; a delete of A that ends late never removes B's budget;
//   - the generation changes when the session is cleared and at no other time.
//
//  Teardown is driven the way the app does it: SessionManager.teardown(reason:). Determinism: gated
//  fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetService session safety Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetServiceSessionSafetyTests {

    enum Scripted: CaseIterable, Sendable, CustomTestStringConvertible {
        case success, notFoundError, networkError, hasPurchasesError, sumError

        var testDescription: String {
            switch self {
            case .success: "success"
            case .notFoundError: "notFound error"
            case .networkError: "network error"
            case .hasPurchasesError: "hasPurchases error"
            case .sumError: "sum error"
            }
        }

        @MainActor
        func enqueue(for mutation: BudgetMutation, on manager: GatedBudgetManager, held: Bool) {
            switch self {
            case .success: mutation.enqueueSuccess(on: manager, held: held)
            case .notFoundError: manager.enqueueFailure(BudgetError.notFound, held: held)
            case .networkError: manager.enqueueFailure(BudgetError.network, held: held)
            case .hasPurchasesError: manager.enqueueFailure(BudgetError.hasPurchases(message: "Has purchases"), held: held)
            case .sumError: manager.enqueueFailure(BudgetError.sumExceedsTotal(message: "Sum too big"), held: held)
            }
        }
    }

    nonisolated static let reasons: [TeardownReason] = [.userLogout, .sessionExpired, .forcedUpdate, .lockFallback]

    // MARK: Teardown during a mutation

    @Test("a mutation that finishes after teardown throws CancellationError and writes nothing, whatever it returned or threw",
          arguments: BudgetMutation.allCases, Scripted.allCases)
    func mutationCompletesAfterTeardown(mutation: BudgetMutation, scripted: Scripted) async {
        await assertMutationCompletesAfterTeardown(mutation: mutation, scripted: scripted, honorsCancellation: false)
    }

    @Test("the same holds when the repository honors cancellation and ends early",
          arguments: Scripted.allCases, [false, true])
    func mutationCompletesAfterTeardownWhetherOrNotCancellationIsHonored(scripted: Scripted, honorsCancellation: Bool) async {
        await assertMutationCompletesAfterTeardown(mutation: .create, scripted: scripted, honorsCancellation: honorsCancellation)
    }

    private func assertMutationCompletesAfterTeardown(
        mutation: BudgetMutation, scripted: Scripted, honorsCancellation: Bool
    ) async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: honorsCancellation)
        scripted.enqueue(for: mutation, on: sut.manager, held: true)
        let task = startMutation(sut.service, mutation)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError, "a stale result ends as a cancellation, not as data or a typed error")
        #expect(sut.service.budgetsByYear.isEmpty, "nothing is written after the session ended")
        #expect(sut.service.isLoading == false)
    }

    @Test("clearForSession directly ends an in-flight mutation with CancellationError", arguments: BudgetMutation.allCases)
    func clearForSessionEndsTheMutation(mutation: BudgetMutation) async throws {
        let sut = await makeBudgetServiceSUT()
        mutation.enqueueSuccess(on: sut.manager, held: true)
        let task = startMutation(sut.service, mutation)
        await sut.manager.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    @Test("teardown for every reason ends an in-flight mutation", arguments: reasons)
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makeBudgetServiceSUT()
        BudgetMutation.create.enqueueSuccess(on: sut.manager, held: true)
        let task = startMutation(sut.service, .create)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: reason)
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    @Test("teardown ends every in-flight call at once: two mutations and a load")
    func teardownEndsAllInFlightCalls() async {
        let sut = await makeBudgetServiceSUT()
        BudgetMutation.create.enqueueSuccess(on: sut.manager, held: true)
        BudgetMutation.duplicate.enqueueSuccess(on: sut.manager, held: true)
        sut.manager.enqueueList([BudgetServiceFix.budget(2030)], held: true)
        let first = startMutation(sut.service, .create)
        await sut.manager.gate.nextHeldCall()
        let second = startMutation(sut.service, .duplicate)
        await sut.manager.gate.nextHeldCall()
        let load = startLoadBudgets(sut.service, force: true)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        sut.manager.gate.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value
        let loadResult = await load.value

        #expect(firstResult is CancellationError)
        #expect(secondResult is CancellationError)
        #expect(loadResult == nil)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    // MARK: Teardown during a load

    @Test("a load that finishes after teardown returns nil and writes nothing",
          arguments: [false, true], [false, true])
    func loadCompletesAfterTeardown(force: Bool, honorsCancellation: Bool) async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: honorsCancellation)
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "666")], held: true)
        let task = startLoadBudgets(sut.service, force: force)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        sut.manager.gate.releaseAll()
        let failure = await task.value

        #expect(failure == nil)
        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.hasLoaded == false)
        #expect(sut.service.isLoading == false)
    }

    @Test("a load whose failure arrives after teardown returns nil: a stale failure is not reported")
    func lateFailureAfterTeardown() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.network, held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        sut.manager.gate.releaseAll()
        let failure = await task.value

        #expect(failure == nil)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    // MARK: In-flight tasks are cancelled at teardown

    @Test("teardown cancels the in-flight task: a repository that honors cancellation ends without any release",
          arguments: BudgetMutation.allCases)
    func teardownCancelsTheInFlightMutation(mutation: BudgetMutation) async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: true)
        mutation.enqueueSuccess(on: sut.manager, held: true)
        let task = startMutation(sut.service, mutation)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        // No release: the call can only end because the service cancelled its task.
        let thrown = await task.value

        #expect(thrown is CancellationError)
        #expect(sut.manager.cancelledCallCount == 1)
    }

    @Test("teardown cancels an in-flight load without any release")
    func teardownCancelsTheInFlightLoad() async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: true)
        sut.manager.enqueueList([BudgetServiceFix.budget()], held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        let failure = await task.value

        #expect(failure == nil)
        #expect(sut.manager.cancelledCallCount == 1)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    // MARK: Teardown empties everything

    @Test("teardown empties the cache and resets hasLoaded and isLoading", arguments: reasons)
    func teardownEmptiesState(reason: TeardownReason) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026), BudgetServiceFix.budget(2025)])
        _ = await sut.service.loadBudgets(force: false)
        #expect(sut.service.budgetsByYear.count == 2, "precondition")
        #expect(sut.service.hasLoaded == true, "precondition")

        await sut.sessions.teardown(reason: reason)

        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.budget(for: 2026) == nil)
        #expect(sut.service.hasLoaded == false)
        #expect(sut.service.isLoading == false)
    }

    @Test("teardown resets isLoading even while a load is held")
    func teardownResetsIsLoading() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget()], held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()
        #expect(sut.service.isLoading == true, "precondition")

        await sut.sessions.teardown(reason: .userLogout)

        #expect(sut.service.isLoading == false)
        sut.manager.gate.releaseAll()
        _ = await task.value
    }

    // MARK: Generation

    @Test("A session clear changes the generation; every further clear changes it again")
    func clearChangesGeneration() async {
        let sut = await makeBudgetServiceSUT()
        let first = sut.service.sessionGeneration

        await sut.sessions.teardown(reason: .userLogout)
        let second = sut.service.sessionGeneration
        await sut.sessions.teardown(reason: .userLogout)
        let third = sut.service.sessionGeneration

        #expect(second > first)
        #expect(third > second)
    }

    @Test("Two services start independent and a clear of one leaves the other alone")
    func servicesAreIndependent() async {
        let one = await makeBudgetServiceSUT()
        let two = await makeBudgetServiceSUT()
        two.manager.enqueueList([BudgetServiceFix.budget(2026)])
        _ = await two.service.loadBudgets(force: false)
        let before = two.service.sessionGeneration

        await one.sessions.teardown(reason: .userLogout)

        #expect(two.service.sessionGeneration == before)
        #expect(two.service.budget(for: 2026) != nil)
    }

    // MARK: User switch

    @Test("user switch: A's mutation result, released late, never reaches B and B's call works",
          arguments: BudgetStoringOp.allCases)
    func userSwitchLateResult(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "111"), held: true)   // user A
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "222"))               // user B
        let userA = Task { @MainActor () -> (any Error)? in
            do {
                _ = try await op.call(on: sut.service)
                return nil
            } catch {
                return error
            }
        }
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        let budgetB = try await op.call(on: sut.service)
        sut.manager.gate.releaseAll()
        let resultA = await userA.value

        #expect(budgetB.totalBudget == BudgetFixtures.dec("222"))
        #expect(resultA is CancellationError)
        #expect(sut.service.budget(for: op.year)?.totalBudget == BudgetFixtures.dec("222"), "only B's budget is cached")
    }

    @Test("user switch: A's late load never overwrites B's list")
    func userSwitchLateLoad() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "111")], held: true)   // user A
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "222")])               // user B
        let userA = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.gate.releaseAll()
        let failureA = await userA.value

        #expect(failureA == nil)
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("222"))
        #expect(sut.service.budgetsByYear.count == 1)
    }

    @Test("user switch: A's late typed failure is a cancellation, not an error for B")
    func userSwitchLateFailure() async throws {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.forbidden, held: true)
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "222"))
        let userA = startMutation(sut.service, .create)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        let budgetB = try await sut.service.create(BudgetServiceFix.createRequest())
        sut.manager.gate.releaseAll()
        let resultA = await userA.value

        #expect(budgetB.totalBudget == BudgetFixtures.dec("222"))
        #expect(resultA is CancellationError)
    }

    @Test("user switch: A's delete that ends late never removes B's budget of that year")
    func userSwitchLateDelete() async throws {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueDeleted(held: true)                                                 // user A
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "222")])                 // user B
        let userA = startMutation(sut.service, .delete)
        await sut.manager.gate.nextHeldCall()

        await sut.sessions.teardown(reason: .userLogout)
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.gate.releaseAll()
        let resultA = await userA.value

        #expect(resultA is CancellationError)
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("222"), "B keeps its budget")
    }

    @Test("a budget list cached by user A is never served to user B: B's load fetches again")
    func cachedListIsNotServedToTheNextUser() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "111")])
        _ = await sut.service.loadBudgets(force: false)
        await sut.sessions.teardown(reason: .userLogout)
        #expect(sut.service.budget(for: 2026) == nil, "precondition: B sees nothing before loading")
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "222")])

        _ = await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == 2, "B must not be served from A's cache")
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("222"))
    }

    @Test("a mutation after teardown works normally in the new session", arguments: BudgetMutation.allCases)
    func mutationAfterTeardownWorks(mutation: BudgetMutation) async {
        let sut = await makeBudgetServiceSUT()
        await sut.sessions.teardown(reason: .userLogout)
        mutation.enqueueSuccess(on: sut.manager)

        let thrown = await startMutation(sut.service, mutation).value

        #expect(thrown == nil)
    }

    @Test("a typed error in the new session after teardown is thrown as the typed error")
    func typedErrorAfterTeardown() async {
        let sut = await makeBudgetServiceSUT()
        await sut.sessions.teardown(reason: .userLogout)
        sut.manager.enqueueFailure(BudgetError.alreadyExists(message: "Budget already exists"))

        let thrown = await startMutation(sut.service, .create).value

        #expect(thrown as? BudgetError == .alreadyExists(message: "Budget already exists"))
    }

    @Test("clearForSession on an idle service is harmless and repeatable, and calls still work")
    func clearForSessionIdle() async throws {
        let sut = await makeBudgetServiceSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "5"))
        let budget = try await sut.service.create(BudgetServiceFix.createRequest())

        #expect(budget.totalBudget == BudgetFixtures.dec("5"))
    }

    // MARK: Caller cancellation

    @Test("cancelling the caller ends a mutation with CancellationError even if the repository still returns a result",
          arguments: BudgetMutation.allCases, [false, true])
    func cancellingTheCallerEndsTheMutation(mutation: BudgetMutation, honorsCancellation: Bool) async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: honorsCancellation)
        mutation.enqueueSuccess(on: sut.manager, held: true)
        let task = startMutation(sut.service, mutation)
        await sut.manager.gate.nextHeldCall()

        task.cancel()
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError)
        #expect(sut.service.budgetsByYear.isEmpty, "a cancelled call writes nothing")
        #expect(sut.service.isLoading == false)
    }

    @Test("cancelling the caller turns a late typed error into CancellationError too", arguments: BudgetMutation.allCases)
    func cancellingTheCallerDropsALateError(mutation: BudgetMutation) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.server, held: true)
        let task = startMutation(sut.service, mutation)
        await sut.manager.gate.nextHeldCall()

        task.cancel()
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError)
    }

    @Test("a cancelled delete does not touch the cache even when the repository answered success")
    func cancelledDeleteKeepsTheBudget() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026)])
        _ = await sut.service.loadBudgets(force: false)
        sut.manager.enqueueDeleted(held: true)
        let task = startMutation(sut.service, .delete)
        await sut.manager.gate.nextHeldCall()

        task.cancel()
        sut.manager.gate.releaseAll()
        let thrown = await task.value

        #expect(thrown is CancellationError)
        #expect(sut.service.budget(for: 2026) != nil)
    }

    @Test("a cancelled load returns nil and writes nothing", arguments: [false, true])
    func cancelledLoad(honorsCancellation: Bool) async {
        let sut = await makeBudgetServiceSUT(honorsCancellation: honorsCancellation)
        sut.manager.enqueueList([BudgetServiceFix.budget()], held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()

        task.cancel()
        sut.manager.gate.releaseAll()
        let failure = await task.value

        #expect(failure == nil)
        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.hasLoaded == false)
        #expect(sut.service.isLoading == false)
    }

    @Test("a cancelled load whose repository failed returns nil, not the failure")
    func cancelledLoadDropsALateFailure() async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.server, held: true)
        let task = startLoadBudgets(sut.service, force: false)
        await sut.manager.gate.nextHeldCall()

        task.cancel()
        sut.manager.gate.releaseAll()
        let failure = await task.value

        #expect(failure == nil)
    }

    @Test("a cancelled call does not break the next call", arguments: BudgetStoringOp.allCases)
    func nextCallAfterCancellation(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT(honorsCancellation: true)
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "1"), held: true)
        let task = Task { @MainActor () -> (any Error)? in
            do {
                _ = try await op.call(on: sut.service)
                return nil
            } catch {
                return error
            }
        }
        await sut.manager.gate.nextHeldCall()
        task.cancel()
        sut.manager.gate.releaseAll()
        _ = await task.value
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "2"))

        let budget = try await op.call(on: sut.service)

        #expect(budget.totalBudget == BudgetFixtures.dec("2"))
        #expect(sut.service.budget(for: op.year)?.totalBudget == BudgetFixtures.dec("2"))
    }

    @Test("cancelling one caller does not cancel another running mutation")
    func cancellingOneCallerLeavesTheOther() async {
        let sut = await makeBudgetServiceSUT()
        BudgetMutation.create.enqueueSuccess(on: sut.manager, held: true)
        BudgetMutation.duplicate.enqueueSuccess(on: sut.manager, held: true)
        let first = startMutation(sut.service, .create)
        await sut.manager.gate.nextHeldCall()
        let second = startMutation(sut.service, .duplicate)
        await sut.manager.gate.nextHeldCall()

        first.cancel()
        sut.manager.gate.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult is CancellationError)
        #expect(secondResult == nil)
        #expect(sut.service.budget(for: 2027) != nil, "the second call's budget is stored")
        #expect(sut.service.budget(for: 2026) == nil, "the cancelled call's budget is not")
    }

    // MARK: Production registration

    @Test("SessionManager.teardown clears a service registered as a clearable", arguments: reasons)
    func registeredServiceIsCleared(reason: TeardownReason) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget()])
        _ = await sut.service.loadBudgets(force: false)

        await sut.sessions.teardown(reason: reason)

        #expect(sut.service.budgetsByYear.isEmpty)
    }
}
