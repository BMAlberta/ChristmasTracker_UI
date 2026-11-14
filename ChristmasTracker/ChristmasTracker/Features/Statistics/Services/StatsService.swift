//
//  StatsService.swift
//  ChristmasTracker
//
//  Session-safe service for the year statistics of the Statistics screen. It caches each year
//  separately, serves a fresh cached year without a fetch, and keeps stale data visible while it
//  refetches. `loadFailure` is the Statistics screen's load error and nothing else: it is cleared by
//  a successful fetch, by `clearLoadFailure()` and at teardown. No amount, name, id or raw error
//  value is ever logged.
//

import Foundation
import Observation
import Sentry

@MainActor
@Observable
final class StatsService {

    // MARK: - Dependencies

    private nonisolated let repository: any StatsLoading

    // MARK: - Published State

    /// The cached statistics, by year.
    private(set) var statsByYear: [Int: StatsYear] = [:]

    /// The last load error of the Statistics screen; nil when the last fetch succeeded.
    private(set) var loadFailure: BudgetError?

    /// True while any fetch runs.
    private(set) var isLoading: Bool = false

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result (and any error) if it changed.
    private var generation = 0

    /// Read-only view of the session generation, so a follow-up task can stop when the session ended.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    /// Number of fetches in flight; isLoading is true while it is above zero.
    private var loadCount = 0

    // MARK: - Freshness

    /// The cached years that are up to date. A cached year outside this set is stale: it stays
    /// visible and the next `load` refetches it.
    private var freshYears: Set<Int> = []

    /// Incremented by every markSpendingStale, so a fetch that started before it is not marked fresh.
    private var staleEpoch = 0

    /// The newest sequence number handed to a fetch, per year.
    private var lastSequenceByYear: [Int: Int] = [:]

    /// The sequence number of the newest fetch that has landed its data, per year.
    private var landedSequenceByYear: [Int: Int] = [:]

    // MARK: - Initialization

    init(repository: any StatsLoading) {
        self.repository = repository
    }

    // MARK: - Reads

    func stats(for year: Int) -> StatsYear? {
        statsByYear[year]
    }

    // MARK: - Load

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so a
    // manual SentrySDK span is used in fetch. No statistics data goes into the span.
    /// Cache-first: a fresh cached year does no fetch; a missing or stale year fetches.
    func load(year: Int) async {
        if statsByYear[year] != nil, freshYears.contains(year) { return }
        await fetch(year: year, spanName: "service.stats.load")
    }

    // Actor-isolated (@MainActor): manual SentrySDK span in fetch, see load.
    /// Always fetches.
    func refresh(year: Int) async {
        await fetch(year: year, spanName: "service.stats.refresh")
    }

    func clearLoadFailure() {
        loadFailure = nil
    }

    /// Spending changed (a purchase was recorded or deleted): every cached year stays visible but
    /// the next `load` refetches it.
    func markSpendingStale() {
        freshYears.removeAll()
        staleEpoch += 1
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls, bumps the generation so late results
    /// are discarded, and empties everything.
    // Actor-isolated (@MainActor): manual SentrySDK span, see load.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.stats.clearForSession",
            operation: "service.stats.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        statsByYear = [:]
        freshYears = []
        lastSequenceByYear = [:]
        landedSequenceByYear = [:]
        loadFailure = nil
        isLoading = false
        loadCount = 0
    }

    // MARK: - Private Functions

    /// Shared body of load and refresh: a manual span (no data in it), the generation captured
    /// before the first await, the cancellable `perform`, and the stale-result check.
    // Actor-isolated (@MainActor): manual SentrySDK span instead of @Instrumented.
    private func fetch(year: Int, spanName: String) async {
        let span = SentrySDK.startTransaction(name: spanName, operation: spanName)
        defer { span.finish() }

        let gen = generation
        let epoch = staleEpoch
        let sequence = (lastSequenceByYear[year] ?? 0) + 1
        lastSequenceByYear[year] = sequence
        beginLoad()
        defer { endLoad(generation: gen) }

        do {
            let repository = self.repository
            let stats = try await perform { try await repository.yearStats(year: year) }
            try ensureCurrent(gen)
            // A newer fetch of this year already landed: this older result must not overwrite it.
            if sequence < (landedSequenceByYear[year] ?? 0) { return }
            landedSequenceByYear[year] = sequence
            statsByYear[year] = stats
            if epoch == staleEpoch { freshYears.insert(year) }
            loadFailure = nil
        } catch {
            guard let failure = failure(error, generation: gen) else { return }
            if sequence < (landedSequenceByYear[year] ?? 0) { return }
            loadFailure = failure
        }
    }

    private func beginLoad() {
        loadCount += 1
        isLoading = true
    }

    /// Clears isLoading only when no other fetch is running. Ignores a session that ended.
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

    /// The typed error to publish, or nil when the call was cancelled or its session ended (nothing
    /// is published then).
    private func failure(_ error: any Error, generation gen: Int) -> BudgetError? {
        if error is CancellationError || gen != generation || Task.isCancelled { return nil }
        LogError("load stats failed", category: .business)
        return (error as? BudgetError) ?? BudgetError.server
    }
}

// MARK: - SessionClearable and SpendingCacheInvalidating

extension StatsService: SessionClearable, SpendingCacheInvalidating {}
