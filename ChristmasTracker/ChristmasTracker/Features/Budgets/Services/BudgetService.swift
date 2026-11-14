//
//  BudgetService.swift
//  ChristmasTracker
//
//  Session-safe service for the caller's own budgets. It caches the budgets by year. Typed errors
//  go to the initiating view and nothing is published: a failed mutation is thrown as a BudgetError,
//  a failed load is returned, and the service has no error property. No amount, name, id or raw
//  error value is ever logged.
//

import Foundation
import Observation
import Sentry

@MainActor
@Observable
final class BudgetService {

    // MARK: - Dependencies

    private nonisolated let repository: any BudgetManaging

    // MARK: - Published State

    /// The cached budgets, by year.
    private(set) var budgetsByYear: [Int: Budget] = [:]

    /// True while a load runs (mutations do not touch it).
    private(set) var isLoading: Bool = false

    /// True once a load has succeeded in this session.
    private(set) var hasLoaded: Bool = false

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result (and any error) if it changed.
    private var generation = 0

    /// Read-only view of the session generation, so a follow-up task can stop when the session ended.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    /// Number of loads in flight; isLoading is true while it is above zero.
    private var loadCount = 0

    // MARK: - Freshness

    /// True while the loaded list is up to date. A stale list stays visible and the next
    /// non-forced load refetches it.
    private var isFresh = false

    /// Incremented by every markSpendingStale, so a load that started before it is not marked fresh.
    private var staleEpoch = 0

    /// Incremented by every successful mutation write, so a load that started before it discards its list.
    private var mutationCount = 0

    // MARK: - Initialization

    init(repository: any BudgetManaging) {
        self.repository = repository
    }

    // MARK: - Reads

    func budget(for year: Int) -> Budget? {
        budgetsByYear[year]
    }

    // MARK: - Load

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so a
    // manual SentrySDK span is used. No budget data goes into the span.
    /// Cache-first unless forced or stale. Replaces the cache with the server list. Returns the
    /// failure and publishes none; a stale or cancelled call returns nil and writes nothing.
    @discardableResult
    func loadBudgets(force: Bool) async -> BudgetError? {
        if !force && hasLoaded && isFresh { return nil }

        let span = SentrySDK.startTransaction(name: "service.budgets.load", operation: "service.budgets.load")
        defer { span.finish() }

        let gen = generation
        let epoch = staleEpoch
        let mutations = mutationCount
        loadCount += 1
        isLoading = true
        defer { endLoad(generation: gen) }

        do {
            let repository = self.repository
            let budgets = try await perform { try await repository.listBudgets() }
            try ensureCurrent(gen)
            // A mutation succeeded while this load was in flight: the server list may predate it.
            // Discard it and leave the cache not fresh so the next non-forced load refetches.
            if mutations != mutationCount {
                isFresh = false
                return nil
            }
            budgetsByYear = Dictionary(budgets.map { ($0.year, $0) }, uniquingKeysWith: { _, later in later })
            hasLoaded = true
            isFresh = epoch == staleEpoch
            return nil
        } catch {
            if error is CancellationError || gen != generation || Task.isCancelled { return nil }
            LogError("load budgets failed", category: .business)
            return (error as? BudgetError) ?? BudgetError.server
        }
    }

    // MARK: - Mutations
    //
    // Mutations throw BudgetError (or CancellationError), publish nothing and do not touch
    // isLoading. They share the generation, the in-flight registry and the stale-result check with
    // the load.

    // Actor-isolated (@MainActor): @Instrumented cannot be applied here, so a manual SentrySDK span
    // is used in store. No budget data goes into the span.
    func create(_ request: CreateBudgetRequest) async throws -> Budget {
        try await store(spanName: "service.budgets.create") { repository in
            try await repository.create(request)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see create.
    func update(_ request: UpdateBudgetRequest) async throws -> Budget {
        try await store(spanName: "service.budgets.update") { repository in
            try await repository.update(request)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see create.
    func duplicate(_ request: DuplicateBudgetRequest) async throws -> Budget {
        try await store(spanName: "service.budgets.duplicate") { repository in
            try await repository.duplicate(request)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see create.
    /// A success, or a notFound (already deleted), removes the year from the cache; any other error
    /// is rethrown with the cache untouched.
    func delete(year: Int) async throws {
        let span = SentrySDK.startTransaction(name: "service.budgets.delete", operation: "service.budgets.delete")
        defer { span.finish() }

        let gen = generation
        do {
            let repository = self.repository
            try await perform { try await repository.delete(year: year) }
            try ensureCurrent(gen)
            budgetsByYear[year] = nil
            mutationCount += 1
        } catch {
            let thrown = mutationFailure(error, generation: gen)
            guard let budgetError = thrown as? BudgetError, budgetError.isGone else { throw thrown }
            budgetsByYear[year] = nil
            mutationCount += 1
        }
    }

    /// Spending changed (a purchase was recorded or deleted): the budgets stay visible but the next
    /// non-forced load refetches them.
    func markSpendingStale() {
        isFresh = false
        staleEpoch += 1
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls, bumps the generation so late results
    /// are discarded, and empties everything.
    // Actor-isolated (@MainActor): manual SentrySDK span, see loadBudgets.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.budgets.clearForSession",
            operation: "service.budgets.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        budgetsByYear = [:]
        hasLoaded = false
        isFresh = false
        isLoading = false
        loadCount = 0
    }

    // MARK: - Private Functions

    /// Shared body of create, update and duplicate: a manual span (no data in it), the generation
    /// captured before the first await, the cancellable `perform`, the stale-result check, and the
    /// returned budget stored under its year.
    // Actor-isolated (@MainActor): manual SentrySDK span instead of @Instrumented.
    private func store(
        spanName: String,
        _ work: @escaping @Sendable (any BudgetManaging) async throws -> Budget
    ) async throws -> Budget {
        let span = SentrySDK.startTransaction(name: spanName, operation: spanName)
        defer { span.finish() }

        let gen = generation
        do {
            let repository = self.repository
            let budget = try await perform { try await work(repository) }
            try ensureCurrent(gen)
            budgetsByYear[budget.year] = budget
            mutationCount += 1
            return budget
        } catch {
            throw mutationFailure(error, generation: gen)
        }
    }

    /// Clears isLoading only when no other load is running. Ignores a session that ended.
    private func endLoad(generation gen: Int) {
        guard gen == generation else { return }
        loadCount = max(0, loadCount - 1)
        isLoading = loadCount > 0
    }

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Covered by the manual span of its public caller.
    private func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task { try await work() }
        let handle = UUID()
        inFlight[handle] = { task.cancel() }
        defer { inFlight[handle] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Stops a result that arrived after the session was cleared or the caller was cancelled.
    private func ensureCurrent(_ gen: Int) throws {
        if gen != generation || Task.isCancelled { throw CancellationError() }
    }

    /// The error a mutation rethrows: the typed BudgetError, or CancellationError when the call was
    /// cancelled or its session ended. Never stored in the service.
    private func mutationFailure(_ error: any Error, generation gen: Int) -> any Error {
        if error is CancellationError || gen != generation || Task.isCancelled { return CancellationError() }
        LogError("budget mutation failed", category: .business)
        return (error as? BudgetError) ?? BudgetError.server
    }
}

// MARK: - SessionClearable and SpendingCacheInvalidating

extension BudgetService: SessionClearable, SpendingCacheInvalidating {}
