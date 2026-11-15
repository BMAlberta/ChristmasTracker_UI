//
//  GatedPurchaseHistoryLoader.swift
//  ChristmasTrackerTests
//
//  PH1-H1: a scripted, optionally gated PurchaseHistoryLoading fake for the PurchaseHistoryService
//  tests. It follows GatedStatsLoader exactly.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step (an empty script answers
//  PurchaseHistoryError.server). A step marked `held` suspends the call on a gate until the test
//  releases it and announces itself through `gate.nextHeldCall()` (a continuation handshake), so a test
//  can wait until the service has really entered the repository, act (for example clear the session),
//  and then release.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its task is
//  cancelled (and counts it in `cancelledCallCount`); otherwise it keeps waiting until released (the
//  stale-result case).
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedPurchaseHistoryLoader: PurchaseHistoryLoading, Sendable {

    /// What the service handed to the repository.
    struct Call: Equatable, Sendable {
        let filter: PurchaseHistoryFilter
        let cursor: String?
    }

    struct Step: Sendable {
        var outcome: Result<PurchaseHistoryPage, any Error>
        var held: Bool
    }

    private struct State: Sendable {
        var steps: [Step] = []
        var calls: [Call] = []
        var cancelled = 0
    }

    let gate: HeldCallGate<Call>
    private let state = Mutex(State())

    @MainActor
    init() {
        gate = HeldCallGate<Call>()
    }

    // MARK: Script

    func enqueue(_ page: PurchaseHistoryPage, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(page), held: held)) }
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .failure(error), held: held)) }
    }

    // MARK: Recorded calls

    var calls: [Call] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    /// How many held calls ended early because their task was cancelled.
    var cancelledCallCount: Int { state.withLock { $0.cancelled } }

    // MARK: PurchaseHistoryLoading

    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage {
        let call = Call(filter: filter, cursor: cursor)
        let step: Step = state.withLock { state in
            state.calls.append(call)
            if state.steps.isEmpty {
                return Step(outcome: .failure(PurchaseHistoryError.server), held: false)
            }
            return state.steps.removeFirst()
        }
        if step.held {
            do {
                try await gate.hold(call)
            } catch {
                state.withLock { $0.cancelled += 1 }
                throw error
            }
        }
        return try step.outcome.get()
    }
}
