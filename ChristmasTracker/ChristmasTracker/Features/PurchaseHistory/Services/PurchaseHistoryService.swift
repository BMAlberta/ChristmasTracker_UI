//
//  PurchaseHistoryService.swift
//  ChristmasTracker
//
//  Session-safe service for the purchase history. It keeps no cache and publishes no data: it runs one
//  page request at a time for its caller, drops the result of a call whose session ended or whose
//  caller was cancelled (as a CancellationError), and turns every other failure into a typed
//  PurchaseHistoryError. No id, amount, name, cursor or raw error value is ever logged.
//

import Foundation
import Observation
import Sentry

@MainActor
@Observable
final class PurchaseHistoryService {

    // MARK: - Dependencies

    private nonisolated let repository: any PurchaseHistoryLoading

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result (and any error) if it changed.
    private var generation = 0

    /// Read-only view of the session generation, so a follow-up task can stop when the session ended.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    // MARK: - Initialization

    init(repository: any PurchaseHistoryLoading) {
        self.repository = repository
    }

    // MARK: - Load

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so a
    // manual SentrySDK span is used. No purchase data goes into the span.
    /// One page of the history. Throws `CancellationError` for a cancelled caller or an ended session,
    /// and a `PurchaseHistoryError` for every other failure.
    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage {
        let span = SentrySDK.startTransaction(
            name: "service.purchaseHistory.loadPage",
            operation: "service.purchaseHistory.loadPage"
        )
        defer { span.finish() }

        let gen = generation
        do {
            let repository = self.repository
            let page = try await perform { try await repository.loadPage(filter: filter, cursor: cursor) }
            try ensureCurrent(gen)
            return page
        } catch {
            throw failure(error, generation: gen)
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls and bumps the generation so late
    /// results are discarded.
    // Actor-isolated (@MainActor): manual SentrySDK span, see loadPage.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.purchaseHistory.clearForSession",
            operation: "service.purchaseHistory.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }
    }

    // MARK: - Private Functions

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

    /// The error to throw: a CancellationError when the call was cancelled or its session ended,
    /// the repository's typed error as is, and `.server` for anything else.
    private func failure(_ error: any Error, generation gen: Int) -> any Error {
        if error is CancellationError || gen != generation || Task.isCancelled { return CancellationError() }
        LogError("load purchase history failed", category: .business)
        return (error as? PurchaseHistoryError) ?? PurchaseHistoryError.server
    }
}

// MARK: - SessionClearable

extension PurchaseHistoryService: SessionClearable {}
