//
//  BudgetServiceMutationDuringLoadTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B (Gate 2 fix F1): a successful mutation write that lands while a loadBudgets call is in
//  flight must not be overwritten by that older load.
//
//  Rule under test: a load captures a mutation counter before it fetches. If any successful mutation
//  write happened since, the load discards its server list (no write to budgetsByYear), leaves the
//  cache as the mutation left it, does NOT mark the cache fresh (the next non-forced load refetches)
//  and returns nil. A failed mutation does not count. A load with no mutation in between still writes
//  and marks fresh. A mutation after the load completed behaves as before.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. The load is held, the mutation runs to
//  completion, then the load is released. No sleeps, no yield loops. A wrong implementation fails an
//  assertion; nothing waits on a gate that is never released.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetService mutation during load Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetServiceMutationDuringLoadTests {

    // MARK: Helpers

    /// A service whose cache was loaded (and is fresh) with `cached`.
    private func makeLoadedSUT(cached: [Budget]) async -> BudgetServiceSUT {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList(cached)
        await sut.service.loadBudgets(force: false)
        return sut
    }

    /// Starts a forced load that the repository holds, and waits until it is inside the repository.
    private func startHeldLoad(_ sut: BudgetServiceSUT, answering list: [Budget]) async -> Task<BudgetError?, Never> {
        sut.manager.enqueueList(list, held: true)
        let load = startLoadBudgets(sut.service, force: true)
        await sut.manager.gate.nextHeldCall()
        return load
    }

    // MARK: Create, update and duplicate

    @Test("a create, update or duplicate that lands during a load is not overwritten by the older list",
          arguments: BudgetStoringOp.allCases)
    func storingMutationDuringLoadSurvives(op: BudgetStoringOp) async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2026, total: "1000")])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026, total: "1000")])
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "777"))

        let stored = try await op.call(on: sut.service)
        sut.manager.gate.releaseAll()
        let failure = await load.value

        #expect(stored.totalBudget == BudgetFixtures.dec("777"), "precondition")
        #expect(failure == nil)
        #expect(sut.service.budget(for: op.year)?.totalBudget == BudgetFixtures.dec("777"),
                "the older load must not overwrite or drop the mutation's budget")
        #expect(sut.service.isLoading == false)
    }

    @Test("a create that lands during a load stays in the cache and the next cache-first load fetches again")
    func createDuringLoadKeepsBudgetAndStaysStale() async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2025, total: "500")])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2025, total: "500")])
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "777"))

        _ = try await sut.service.create(BudgetServiceFix.createRequest())
        sut.manager.gate.releaseAll()
        _ = await load.value
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("777"), "precondition for the refetch check")
        let callsBefore = sut.manager.callCount
        sut.manager.enqueueList([BudgetServiceFix.budget(2025, total: "500"), BudgetServiceFix.budget(2026, total: "777")])

        await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == callsBefore + 1, "the discarded load did not mark the cache fresh")
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("777"))
        #expect(sut.service.budget(for: 2025) != nil)
    }

    @Test("the same holds for a first load: a discarded load leaves the cache unfresh and the next load fetches",
          arguments: BudgetStoringOp.allCases)
    func discardedFirstLoadDoesNotMarkFresh(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2020, total: "1")])
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "777"))

        _ = try await op.call(on: sut.service)
        sut.manager.gate.releaseAll()
        _ = await load.value
        let callsBefore = sut.manager.callCount
        sut.manager.enqueueList([BudgetServiceFix.budget(op.year, total: "777")])
        await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == callsBefore + 1, "the next non-forced load refetches")
        #expect(sut.service.budget(for: 2020) == nil, "the discarded list never reached the cache")
    }

    @Test("an update that lands during a load is not reverted by the older list")
    func updateDuringLoadIsNotReverted() async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2026, total: "1000")])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026, total: "1000")])
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "1200"))

        _ = try await sut.service.update(BudgetServiceFix.updateRequest())
        sut.manager.gate.releaseAll()
        _ = await load.value

        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("1200"))
    }

    // MARK: Delete

    @Test("a delete that lands during a load is not resurrected by the older list")
    func deleteDuringLoadIsNotResurrected() async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2026), BudgetServiceFix.budget(2025)])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026), BudgetServiceFix.budget(2025)])
        sut.manager.enqueueDeleted()

        try await sut.service.delete(year: 2026)
        sut.manager.gate.releaseAll()
        let failure = await load.value

        #expect(failure == nil)
        #expect(sut.service.budget(for: 2026) == nil, "the deleted year stays deleted")
        #expect(sut.service.budget(for: 2025) != nil)
    }

    @Test("a delete that lands during a load leaves the cache unfresh: the next cache-first load fetches")
    func deleteDuringLoadStaysStale() async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2026)])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026)])
        sut.manager.enqueueDeleted()

        try await sut.service.delete(year: 2026)
        sut.manager.gate.releaseAll()
        _ = await load.value
        let callsBefore = sut.manager.callCount
        sut.manager.enqueueList([])
        await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == callsBefore + 1)
        #expect(sut.service.budgetsByYear.isEmpty)
    }

    // MARK: A failed mutation does not discard the load

    @Test("a mutation that fails during a load does not discard the load: the load still writes and marks fresh",
          arguments: BudgetMutation.allCases)
    func failedMutationDuringLoadDoesNotDiscardTheLoad(mutation: BudgetMutation) async {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2020, total: "1")])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026, total: "555")])
        sut.manager.enqueueFailure(BudgetError.network)

        let thrown = await startMutation(sut.service, mutation).value
        sut.manager.gate.releaseAll()
        let failure = await load.value
        let callsBefore = sut.manager.callCount
        await sut.service.loadBudgets(force: false)

        #expect(thrown as? BudgetError == .network, "precondition")
        #expect(failure == nil)
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("555"), "the load wrote its list")
        #expect(sut.service.budget(for: 2020) == nil)
        #expect(sut.manager.callCount == callsBefore, "the load marked the cache fresh")
    }

    // MARK: Regressions

    @Test("a load with no mutation in between still writes and marks fresh")
    func loadWithoutMutationWritesAndMarksFresh() async {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2020, total: "1")])
        let load = await startHeldLoad(sut, answering: [BudgetServiceFix.budget(2026, total: "555")])

        sut.manager.gate.releaseAll()
        let failure = await load.value
        let callsBefore = sut.manager.callCount
        await sut.service.loadBudgets(force: false)

        #expect(failure == nil)
        #expect(sut.service.budgetsByYear.count == 1)
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("555"))
        #expect(sut.service.hasLoaded == true)
        #expect(sut.manager.callCount == callsBefore, "cache-first: fresh, no fetch")
    }

    @Test("a mutation that completed before the load started does not discard that load",
          arguments: BudgetStoringOp.allCases)
    func mutationBeforeLoadDoesNotDiscardIt(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "777"))
        _ = try await op.call(on: sut.service)
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "888")])

        let failure = await sut.service.loadBudgets(force: false)
        let callsBefore = sut.manager.callCount
        await sut.service.loadBudgets(force: false)

        #expect(failure == nil)
        #expect(sut.service.budget(for: 2026)?.totalBudget == BudgetFixtures.dec("888"), "the load wrote its list")
        #expect(sut.manager.callCount == callsBefore, "and marked the cache fresh")
    }

    @Test("a mutation after the load completed writes as before and leaves the cache fresh",
          arguments: BudgetStoringOp.allCases)
    func mutationAfterLoadBehavesAsBefore(op: BudgetStoringOp) async throws {
        let sut = await makeLoadedSUT(cached: [BudgetServiceFix.budget(2026, total: "1000")])
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "777"))

        _ = try await op.call(on: sut.service)
        let callsBefore = sut.manager.callCount
        await sut.service.loadBudgets(force: false)

        #expect(sut.service.budget(for: op.year)?.totalBudget == BudgetFixtures.dec("777"))
        #expect(sut.manager.callCount == callsBefore, "a mutation does not make the cache stale")
    }
}
