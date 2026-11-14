//
//  GatedStatsLoader.swift
//  ChristmasTrackerTests
//
//  I5a Story B: a scripted, optionally gated StatsLoading fake for the StatsService tests. It follows
//  GatedPurchaseManager exactly.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step (an empty script answers
//  BudgetError.server). A step marked `held` suspends the call on a gate until the test releases it,
//  and announces itself through `gate.nextHeldCall()` (a continuation handshake, see HeldCallGate),
//  so a test can wait until the service has really entered the repository, act (for example tear the
//  session down), and then release.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its task is
//  cancelled (and counts it in `cancelledCallCount`); otherwise it keeps waiting until released (the
//  stale-result case).
//
//  StatsLoading is nonisolated and Sendable, so this fake is a nonisolated final class whose script
//  and call log sit behind a Mutex. The gate is MainActor (HeldCallGate), so it is created in a
//  MainActor initializer and awaited from the nonisolated call.
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedStatsLoader: StatsLoading, Sendable {

    /// What the service handed to the repository.
    enum Call: Equatable, Sendable {
        case yearStats(year: Int)
    }

    struct Step: Sendable {
        var outcome: Result<StatsYear, any Error>
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

    func enqueue(_ stats: StatsYear, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(stats), held: held)) }
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .failure(error), held: held)) }
    }

    // MARK: Recorded calls

    var calls: [Call] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    /// How many held calls ended early because their task was cancelled.
    var cancelledCallCount: Int { state.withLock { $0.cancelled } }

    // MARK: StatsLoading

    func yearStats(year: Int) async throws -> StatsYear {
        let call = Call.yearStats(year: year)
        let step: Step = state.withLock { state in
            state.calls.append(call)
            if state.steps.isEmpty {
                return Step(outcome: .failure(BudgetError.server), held: false)
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
