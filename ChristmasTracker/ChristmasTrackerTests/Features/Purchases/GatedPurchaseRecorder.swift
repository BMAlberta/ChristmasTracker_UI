//
//  GatedPurchaseRecorder.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: a scripted, optionally gated PurchaseRecording fake for the PurchaseService tests.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step (an empty script answers
//  PurchaseError.server). A step marked `held` suspends the call on a gate until the test
//  releases it, and announces itself through `gate.nextHeldCall()` (a continuation handshake, see
//  HeldCallGate), so a test can wait until the service has really entered the repository, act (for
//  example tear the session down), and then release.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its
//  task is cancelled; otherwise it keeps waiting until released (the stale-result case).
//
//  PurchaseRecording is nonisolated, so this fake is a nonisolated final class whose script and
//  call log sit behind a Mutex. The gate itself is MainActor (HeldCallGate), so it is created in a
//  MainActor initializer and awaited from the nonisolated call.
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedPurchaseRecorder: PurchaseRecording, Sendable {

    /// What the service handed to the repository, for the pass-through assertions.
    struct Call: Equatable, Sendable {
        let itemId: String
        let draft: PurchaseDraft
        let token: String?
    }

    struct Step: Sendable {
        var outcome: Result<PurchaseOutcome, any Error>
        var held: Bool
    }

    private struct State: Sendable {
        var steps: [Step] = []
        var calls: [Call] = []
    }

    let gate: HeldCallGate<Call>
    private let state = Mutex(State())

    @MainActor
    init() {
        gate = HeldCallGate<Call>()
    }

    // MARK: Script

    func enqueue(_ outcome: Result<PurchaseOutcome, any Error>, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: outcome, held: held)) }
    }

    func enqueue(created purchase: RecordedPurchase, held: Bool = false) {
        enqueue(.success(.created(purchase)), held: held)
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        enqueue(.failure(error), held: held)
    }

    // MARK: Recorded calls

    var calls: [Call] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    // MARK: PurchaseRecording

    func createPurchase(itemId: String, draft: PurchaseDraft, confirmationToken: String?) async throws -> PurchaseOutcome {
        let call = Call(itemId: itemId, draft: draft, token: confirmationToken)
        let step: Step = state.withLock { state in
            state.calls.append(call)
            if state.steps.isEmpty {
                return Step(outcome: .failure(PurchaseError.server), held: false)
            }
            return state.steps.removeFirst()
        }
        if step.held { try await gate.hold(call) }
        return try step.outcome.get()
    }
}
