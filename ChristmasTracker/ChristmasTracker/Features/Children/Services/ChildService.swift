//
//  ChildService.swift
//  ChristmasTracker
//
//  Holds the signed-in user's children for the Children screen and the create-list recipient
//  picker. Session-safe like ListService: every operation captures the session generation before
//  its first await and drops its result (and any error) if the session was cleared meanwhile, and
//  clearForSession() cancels work in flight and empties everything. Nothing is logged here:
//  children's names and ids are personal data.
//

import Foundation
import Sentry

@MainActor
@Observable
final class ChildService {
    // MARK: - Dependencies
    private nonisolated let repository: any ChildRepository

    // MARK: - Published State
    private(set) var children: [Child] = []
    private(set) var phase: ChildrenLoadPhase = .idle
    /// True only while addChild or deleteChild runs.
    private(set) var isMutating: Bool = false
    // `phase` is the Children screen's load channel: `.failed` is its load failure value. Add and
    // delete failures are thrown and stored nowhere.

    // MARK: - Session safety

    /// Incremented every time the session is cleared; stale results are dropped.
    private var generation = 0

    /// Read-only view of the session generation, so a coordinator can tell that the session was
    /// cleared (a user switch) between its steps.
    var sessionGeneration: Int { generation }

    /// Cancel handles of the repository calls that are in flight, keyed by call.
    private var inFlight: [UUID: () -> Void] = [:]

    // MARK: - Initialization
    init(repository: any ChildRepository) {
        self.repository = repository
    }

    // MARK: - Public Methods

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual SentrySDK span is used. No child data goes into the span.
    func loadChildren() async {
        let span = SentrySDK.startTransaction(
            name: "service.children.loadChildren",
            operation: "service.children.loadChildren"
        )
        defer { span.finish() }

        let gen = generation
        let previousPhase = phase
        phase = .loading

        do {
            let repository = self.repository
            let fetched = try await perform { try await repository.fetchChildren() }
            guard gen == generation else { return }
            children = fetched
            phase = .loaded
        } catch {
            guard gen == generation else { return }
            if error is CancellationError {
                // Not shown to the user: the phase goes back to what it was.
                phase = previousPhase
                return
            }
            // A failed load keeps the previous children out of the picker.
            children = []
            phase = .failed(childError(error))
        }
    }

    /// Turns a failed Children load back into idle (the screen calls it when it disappears). A
    /// loaded or loading state is left alone, so it never clears the list.
    func clearLoadFailure() {
        if case .failed = phase { phase = .idle }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadChildren.
    func addChild(_ input: CreateChildInput) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.children.addChild",
            operation: "service.children.addChild"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }

        do {
            let repository = self.repository
            let created = try await perform { try await repository.createChild(input) }
            try ensureCurrent(gen)
            children.append(created)
        } catch {
            throw failure(error, generation: gen)
        }
    }

    // Actor-isolated (@MainActor): manual SentrySDK span, see loadChildren.
    func deleteChild(id: String) async throws {
        let span = SentrySDK.startTransaction(
            name: "service.children.deleteChild",
            operation: "service.children.deleteChild"
        )
        defer { span.finish() }

        let gen = generation
        isMutating = true
        defer { if gen == generation { isMutating = false } }

        do {
            let repository = self.repository
            try await perform { try await repository.deleteChild(id: id) }
            try ensureCurrent(gen)
            children.removeAll { $0.id == id }
        } catch {
            // The child is already gone on the server: drop it locally too.
            if gen == generation, (error as? ChildError) == .childNotFound {
                children.removeAll { $0.id == id }
            }
            throw failure(error, generation: gen)
        }
    }

    // MARK: - SessionClearable

    /// Ends this service's session: cancels in-flight work, bumps the generation so late results
    /// are discarded, and empties the published state.
    // Actor-isolated (@MainActor): @Instrumented cannot be applied to this @MainActor method,
    // so a manual span is used. No data goes into the span.
    func clearForSession() async throws {
        let span = SentrySDK.startTransaction(
            name: "service.children.clearForSession",
            operation: "service.children.clearForSession"
        )
        defer { span.finish() }

        generation += 1
        let cancellers = inFlight.values
        inFlight.removeAll()
        for cancel in cancellers { cancel() }

        children = []
        phase = .idle
        isMutating = false
    }

    // MARK: - Private Functions

    /// Runs a repository call in a task the service can cancel at teardown. Cancelling the caller
    /// cancels the call too.
    // Covered by the manual spans of its public callers.
    private func perform<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task { try await work() }
        let token = UUID()
        inFlight[token] = { task.cancel() }
        defer { inFlight[token] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Stops a write that finished after the session was cleared.
    private func ensureCurrent(_ gen: Int) throws {
        if gen != generation { throw CancellationError() }
    }

    /// Anything that is not a ChildError is an unexpected failure.
    private func childError(_ error: any Error) -> ChildError {
        (error as? ChildError) ?? .server
    }

    /// The error a throwing operation rethrows: the typed ChildError (stored nowhere), or
    /// CancellationError when the call was cancelled or its session ended.
    private func failure(_ error: any Error, generation gen: Int) -> any Error {
        if error is CancellationError || gen != generation {
            return CancellationError()
        }
        return childError(error)
    }
}

// MARK: - SessionClearable

extension ChildService: SessionClearable {}
