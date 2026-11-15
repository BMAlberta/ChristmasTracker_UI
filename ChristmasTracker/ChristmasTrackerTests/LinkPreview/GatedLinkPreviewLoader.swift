//
//  GatedLinkPreviewLoader.swift
//  ChristmasTrackerTests
//
//  IMG1-P1: a scripted, optionally gated LinkPreviewLoading fake for the LinkPreviewService tests.
//  It follows GatedStatsLoader exactly: each call pops one scripted step (an empty script answers
//  nil); a `held` step suspends on the HeldCallGate until released and announces itself through
//  `gate.nextHeldCall()`. With `gate.honorsCancellation` a held call ends with CancellationError
//  when its task is cancelled and is counted in `cancelledCallCount`.
//
//  Determinism: no sleeps, no polling.
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedLinkPreviewLoader: LinkPreviewLoading, Sendable {

    struct Step: Sendable {
        var outcome: Result<String?, any Error>
        var held: Bool
    }

    private struct State: Sendable {
        var steps: [Step] = []
        var calls: [String] = []
        var cancelled = 0
    }

    let gate: HeldCallGate<String>
    private let state = Mutex(State())

    @MainActor
    init() {
        gate = HeldCallGate<String>()
    }

    // MARK: Script

    func enqueue(_ value: String?, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(value), held: held)) }
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .failure(error), held: held)) }
    }

    // MARK: Recorded calls

    /// The page URLs the service handed to the repository, in order.
    var calls: [String] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    /// How many held calls ended early because their task was cancelled.
    var cancelledCallCount: Int { state.withLock { $0.cancelled } }

    // MARK: LinkPreviewLoading

    func imageUrl(for pageURL: String) async throws -> String? {
        let step: Step = state.withLock { state in
            state.calls.append(pageURL)
            if state.steps.isEmpty {
                return Step(outcome: .success(nil), held: false)
            }
            return state.steps.removeFirst()
        }
        if step.held {
            do {
                try await gate.hold(pageURL)
            } catch {
                state.withLock { $0.cancelled += 1 }
                throw error
            }
        }
        return try step.outcome.get()
    }
}
