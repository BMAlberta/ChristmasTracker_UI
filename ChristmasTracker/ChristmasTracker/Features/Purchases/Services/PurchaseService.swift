//
//  PurchaseService.swift
//  ChristmasTracker
//
//  Session-safe service for recording a purchase. The typed RecordPurchaseError goes to the
//  initiating view and nothing is published: the service has no error property. The confirmation
//  token is an argument of one call and is kept nowhere. No id, amount, name, token or raw error
//  value is ever logged.
//

import Foundation
import Observation
import Sentry

@MainActor
@Observable
final class PurchaseService {

    // MARK: - Dependencies

    private nonisolated let repository: any PurchaseRecording
    private nonisolated let management: any PurchaseManaging

    // MARK: - Published State

    /// True while any record call runs.
    private(set) var isMutating: Bool = false

    // MARK: - Session safety

    /// Incremented every time the session is cleared. Every call captures it before its first
    /// await and drops its result (and any error) if it changed.
    private var generation = 0

    /// Cancel handles of the repository calls that are in flight.
    private var inFlight: [UUID: () -> Void] = [:]

    /// Number of calls in flight; isMutating is true while it is above zero.
    private var mutationCount = 0

    // MARK: - Initialization

    init(repository: any PurchaseRecording) {
        self.repository = repository
        self.management = InertPurchaseManager()
    }

    init(repository: any PurchaseRecording, management: any PurchaseManaging) {
        self.repository = repository
        self.management = management
    }

    // MARK: - Record

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method, so a
    // manual SentrySDK span is used. No purchase data goes into the span.
    func recordPurchase(
        itemId: String,
        draft: PurchaseDraft,
        confirmationToken: String?
    ) async throws -> PurchaseOutcome {
        let span = SentrySDK.startTransaction(
            name: "service.purchases.recordPurchase",
            operation: "service.purchases.recordPurchase"
        )
        defer { span.finish() }

        let gen = generation
        beginCall()
        defer { endCall(generation: gen) }

        do {
            let repository = self.repository
            let outcome = try await perform {
                try await repository.createPurchase(
                    itemId: itemId,
                    draft: draft,
                    confirmationToken: confirmationToken
                )
            }
            try ensureCurrent(gen)
            return outcome
        } catch {
            throw failure(error, generation: gen)
        }
    }

    // MARK: - Manage
    //
    // Management calls throw PurchaseManagementError (or CancellationError), publish nothing and do
    // not touch isMutating, which stays the Record screen's flag. They share the generation, the
    // in-flight registry and the stale-result check with the record call.

    // Actor-isolated (@MainActor): @Instrumented cannot be applied here, so a manual SentrySDK span
    // is used in runManagement. No purchase data goes into the span.
    func fetchPurchase(id: String) async throws -> RecordedPurchase {
        try await runManagement(spanName: "service.purchases.fetchPurchase") { management in
            try await management.fetchPurchase(id: id)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see fetchPurchase.
    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase {
        try await runManagement(spanName: "service.purchases.updateNotes") { management in
            try await management.updateNotes(id: id, update: update)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see fetchPurchase.
    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase {
        try await runManagement(spanName: "service.purchases.updateShipping") { management in
            try await management.updateShipping(id: id, update: update)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see fetchPurchase.
    func deletePurchase(id: String) async throws -> RecordedPurchase {
        try await runManagement(spanName: "service.purchases.deletePurchase") { management in
            try await management.deletePurchase(id: id)
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight calls, bumps the generation so late results
    /// are discarded, and clears the flag.
    // Actor-isolated (@MainActor): manual SentrySDK span, see recordPurchase.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.purchases.clearForSession",
            operation: "service.purchases.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        isMutating = false
        mutationCount = 0
    }

    // MARK: - Private Functions

    /// Shared body of the four management calls: a manual span (no data in it), the generation
    /// captured before the first await, the cancellable `perform`, and the stale-result check.
    // Actor-isolated (@MainActor): manual SentrySDK span instead of @Instrumented.
    private func runManagement(
        spanName: String,
        _ work: @escaping @Sendable (any PurchaseManaging) async throws -> RecordedPurchase
    ) async throws -> RecordedPurchase {
        let span = SentrySDK.startTransaction(name: spanName, operation: spanName)
        defer { span.finish() }

        let gen = generation
        do {
            let management = self.management
            let purchase = try await perform { try await work(management) }
            try ensureCurrent(gen)
            return purchase
        } catch {
            throw managementFailure(error, generation: gen)
        }
    }

    /// The error a management call rethrows: the typed PurchaseManagementError, or CancellationError
    /// when the call was cancelled or its session ended. Never stored in the service.
    private func managementFailure(_ error: any Error, generation gen: Int) -> any Error {
        if error is CancellationError || gen != generation || Task.isCancelled { return CancellationError() }
        LogError("purchase management failed", category: .business)
        return (error as? PurchaseManagementError) ?? PurchaseManagementError.server
    }

    private func beginCall() {
        mutationCount += 1
        isMutating = true
    }

    /// Clears isMutating only when no other call is running. Ignores a session that ended.
    private func endCall(generation gen: Int) {
        guard gen == generation else { return }
        mutationCount = max(0, mutationCount - 1)
        isMutating = mutationCount > 0
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

    /// The error a call rethrows: the typed RecordPurchaseError, or CancellationError when the call
    /// was cancelled or its session ended. Never stored in the service.
    private func failure(_ error: any Error, generation gen: Int) -> any Error {
        if error is CancellationError || gen != generation || Task.isCancelled { return CancellationError() }
        LogError("record purchase failed", category: .business)
        return (error as? RecordPurchaseError) ?? RecordPurchaseError.server
    }
}

// MARK: - SessionClearable

extension PurchaseService: SessionClearable {}
