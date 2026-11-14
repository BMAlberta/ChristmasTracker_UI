//
//  BudgetServiceMutationTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: BudgetService create, update, duplicate and delete over the gated fake repository.
//
//  Rules under test:
//   - create, update and duplicate hand the request to the repository unchanged, return the budget
//     and store it in the cache under its year (replacing an older entry of that year);
//   - a failure is THROWN as the typed BudgetError and PUBLISHED NOWHERE: the cache, `hasLoaded` and
//     `isLoading` are exactly as they were (the service has no shared error property);
//   - delete removes the year from the cache on success; a notFound counts as deleted (the year is
//     removed and nothing is thrown); any other error is rethrown with the cache untouched;
//   - a mutation does not change the session generation.
//
//  Stale and cancelled mutations are in BudgetServiceSessionSafetyTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetService mutation Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetServiceMutationTests {

    nonisolated static let failures: [BudgetError] = [
        .validation(message: "Invalid price"), .alreadyExists(message: "Budget already exists"),
        .sumExceedsTotal(message: "Sum too big"), .hasPurchases(message: "Has purchases"), .notFound,
        .forbidden, .unauthorized, .rateLimited(retryAfter: 3), .network, .server, .invalidResponse
    ]

    /// Every failure a delete rethrows (a notFound counts as deleted, see the delete tests).
    nonisolated static let deleteFailures: [BudgetError] = failures.filter { $0 != .notFound }

    /// A service that already holds the budgets of 2025 and 2026.
    private func makeLoadedSUT() async -> BudgetServiceSUT {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueList([BudgetServiceFix.budget(2026, total: "1000"), BudgetServiceFix.budget(2025, total: "500")])
        _ = await sut.service.loadBudgets(force: false)
        return sut
    }

    // MARK: create, update, duplicate store the returned budget

    @Test("the call is handed to the repository unchanged and the returned budget is returned",
          arguments: BudgetStoringOp.allCases)
    func passThrough(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        let returned = BudgetServiceFix.budget(op.year, total: "777")
        sut.manager.enqueue(returned)

        let result = try await op.call(on: sut.service)

        #expect(result == returned)
        #expect(sut.manager.calls == [op.expectedCall])
    }

    @Test("the returned budget is stored in the cache under its year", arguments: BudgetStoringOp.allCases)
    func storesTheReturnedBudget(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        let returned = BudgetServiceFix.budget(op.year, total: "777")
        sut.manager.enqueue(returned)

        _ = try await op.call(on: sut.service)

        #expect(sut.service.budget(for: op.year) == returned)
        #expect(sut.service.budgetsByYear.count == 1)
        #expect(sut.service.isLoading == false)
    }

    @Test("the stored budget replaces an older entry of that year and leaves the other years alone",
          arguments: BudgetStoringOp.allCases)
    func replacesTheOlderEntry(op: BudgetStoringOp) async throws {
        let sut = await makeLoadedSUT()
        let before = sut.service.budgetsByYear
        let returned = BudgetServiceFix.budget(op.year, total: "777")
        sut.manager.enqueue(returned)

        _ = try await op.call(on: sut.service)

        #expect(sut.service.budget(for: op.year) == returned)
        for (year, budget) in before where year != op.year {
            #expect(sut.service.budget(for: year) == budget, "year \(year) must be untouched")
        }
    }

    @Test("a stored budget is visible to a later non-forced load without a new fetch", arguments: BudgetStoringOp.allCases)
    func storedBudgetSurvivesCacheFirstLoad(op: BudgetStoringOp) async throws {
        let sut = await makeLoadedSUT()
        sut.manager.enqueue(BudgetServiceFix.budget(op.year, total: "777"))
        _ = try await op.call(on: sut.service)
        let callsBefore = sut.manager.callCount

        _ = await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == callsBefore)
        #expect(sut.service.budget(for: op.year)?.totalBudget == BudgetFixtures.dec("777"))
    }

    // MARK: Failures are thrown, never published

    @Test("a failed create, update or duplicate throws the typed error and changes nothing",
          arguments: BudgetStoringOp.allCases, failures)
    func storingFailureIsThrown(op: BudgetStoringOp, error: BudgetError) async {
        let sut = await makeLoadedSUT()
        let cacheBefore = sut.service.budgetsByYear
        sut.manager.enqueueFailure(error)

        do {
            _ = try await op.call(on: sut.service)
            Issue.record("expected \(error)")
        } catch let thrown as BudgetError {
            #expect(thrown == error)
        } catch {
            Issue.record("expected a BudgetError, got \(error)")
        }

        #expect(sut.service.budgetsByYear == cacheBefore, "nothing is written on a failure")
        #expect(sut.service.hasLoaded == true)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failure on a service that never loaded leaves it empty and not loaded",
          arguments: BudgetMutation.allCases)
    func failureOnAnEmptyService(mutation: BudgetMutation) async {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.network)

        let thrown = await startMutation(sut.service, mutation).value

        #expect(thrown as? BudgetError == .network)
        #expect(sut.service.budgetsByYear.isEmpty)
        #expect(sut.service.hasLoaded == false)
        #expect(sut.service.isLoading == false)
    }

    @Test("a failure does not stick: the next success works", arguments: BudgetStoringOp.allCases)
    func successAfterFailure(op: BudgetStoringOp) async throws {
        let sut = await makeBudgetServiceSUT()
        sut.manager.enqueueFailure(BudgetError.server)
        _ = try? await op.call(on: sut.service)
        let returned = BudgetServiceFix.budget(op.year, total: "777")
        sut.manager.enqueue(returned)

        let result = try await op.call(on: sut.service)

        #expect(result == returned)
        #expect(sut.service.budget(for: op.year) == returned)
    }

    @Test("a failed mutation does not change the stale flag: a fresh cache stays cache-first")
    func failureKeepsFreshness() async {
        let sut = await makeLoadedSUT()
        sut.manager.enqueueFailure(BudgetError.server)
        _ = try? await sut.service.create(BudgetServiceFix.createRequest())
        let callsBefore = sut.manager.callCount

        _ = await sut.service.loadBudgets(force: false)

        #expect(sut.manager.callCount == callsBefore, "the cache is still fresh")
    }

    // MARK: delete

    @Test("delete hands the year to the repository and removes it from the cache")
    func deleteRemovesTheYear() async throws {
        let sut = await makeLoadedSUT()
        sut.manager.enqueueDeleted()

        try await sut.service.delete(year: 2026)

        #expect(sut.manager.calls.last == .delete(year: 2026))
        #expect(sut.service.budget(for: 2026) == nil)
        #expect(sut.service.budget(for: 2025)?.totalBudget == BudgetFixtures.dec("500"), "other years stay")
        #expect(sut.service.budgetsByYear.count == 1)
    }

    @Test("delete of a year that is not cached succeeds and leaves the cache alone")
    func deleteUncachedYear() async throws {
        let sut = await makeLoadedSUT()
        let before = sut.service.budgetsByYear
        sut.manager.enqueueDeleted()

        try await sut.service.delete(year: 2031)

        #expect(sut.service.budgetsByYear == before)
    }

    @Test("a notFound on delete counts as deleted: the year is removed and nothing is thrown")
    func deleteNotFoundCountsAsDeleted() async throws {
        let sut = await makeLoadedSUT()
        sut.manager.enqueueFailure(BudgetError.notFound)

        try await sut.service.delete(year: 2026)

        #expect(sut.service.budget(for: 2026) == nil)
        #expect(sut.service.budget(for: 2025) != nil)
    }

    @Test("any other delete error is rethrown and the cache is untouched", arguments: deleteFailures)
    func deleteFailureLeavesTheCache(error: BudgetError) async {
        let sut = await makeLoadedSUT()
        let before = sut.service.budgetsByYear
        sut.manager.enqueueFailure(error)

        do {
            try await sut.service.delete(year: 2026)
            Issue.record("expected \(error)")
        } catch let thrown as BudgetError {
            #expect(thrown == error)
        } catch {
            Issue.record("expected a BudgetError, got \(error)")
        }

        #expect(sut.service.budgetsByYear == before)
        #expect(sut.service.budget(for: 2026) != nil, "the budget stays")
        #expect(sut.service.isLoading == false)
    }

    @Test("a delete refused because the year has purchases keeps the budget and carries the server's message")
    func deleteRefusedKeepsTheBudget() async {
        let sut = await makeLoadedSUT()
        sut.manager.enqueueFailure(BudgetError.hasPurchases(message: "Cannot delete budget with existing purchases"))

        do {
            try await sut.service.delete(year: 2026)
            Issue.record("expected hasPurchases")
        } catch let error as BudgetError {
            #expect(error == .hasPurchases(message: "Cannot delete budget with existing purchases"))
            #expect(error.userMessage == "Cannot delete budget with existing purchases")
        } catch {
            Issue.record("expected a BudgetError, got \(error)")
        }

        #expect(sut.service.budget(for: 2026) != nil)
    }

    // MARK: Generation and mutating state

    @Test("mutations, successful or failed, do not change the session generation", arguments: BudgetMutation.allCases)
    func mutationsDoNotChangeGeneration(mutation: BudgetMutation) async {
        let sut = await makeBudgetServiceSUT()
        let before = sut.service.sessionGeneration
        mutation.enqueueSuccess(on: sut.manager)
        sut.manager.enqueueFailure(BudgetError.network)

        _ = await startMutation(sut.service, mutation).value
        _ = await startMutation(sut.service, mutation).value

        #expect(sut.service.sessionGeneration == before)
    }

    @Test("the service has no shared error property: a failure is observable only through the thrown error",
          arguments: BudgetMutation.allCases)
    func nothingIsPublishedOnFailure(mutation: BudgetMutation) async {
        let sut = await makeLoadedSUT()
        let cacheBefore = sut.service.budgetsByYear
        let loadedBefore = sut.service.hasLoaded
        let loadingBefore = sut.service.isLoading
        sut.manager.enqueueFailure(BudgetError.sumExceedsTotal(message: "Sum too big"))

        let thrown = await startMutation(sut.service, mutation).value

        #expect(thrown as? BudgetError == .sumExceedsTotal(message: "Sum too big"))
        #expect(sut.service.budgetsByYear == cacheBefore)
        #expect(sut.service.hasLoaded == loadedBefore)
        #expect(sut.service.isLoading == loadingBefore)
    }
}
