//
//  GatedPurchaseManager.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: a scripted, optionally gated PurchaseManaging fake for the PurchaseService tests.
//  It follows GatedPurchaseRecorder exactly.
//
//  Determinism: no sleeps and no polling. Each call pops one scripted step (an empty script answers
//  PurchaseManagementError.server). A step marked `held` suspends the call on a gate until the test
//  releases it, and announces itself through `gate.nextHeldCall()` (a continuation handshake, see
//  HeldCallGate), so a test can wait until the service has really entered the repository, act (for
//  example tear the session down), and then release.
//
//  When `gate.honorsCancellation` is true a held call ends early with CancellationError if its
//  task is cancelled; otherwise it keeps waiting until released (the stale-result case).
//
//  PurchaseManaging is nonisolated and Sendable, so this fake is a nonisolated final class whose
//  script and call log sit behind a Mutex (the neighbouring GatedPurchaseRecorder pattern). The gate
//  itself is MainActor (HeldCallGate), so it is created in a MainActor initializer and awaited from
//  the nonisolated call.
//

import Foundation
import Synchronization
@testable import ChristmasTracker

nonisolated final class GatedPurchaseManager: PurchaseManaging, Sendable {

    /// What the service handed to the repository, for the pass-through assertions.
    enum Call: Equatable, Sendable {
        case fetch(id: String)
        case updateNotes(id: String, update: PurchaseNotesUpdate)
        case updateShipping(id: String, update: PurchaseShippingUpdate)
        case delete(id: String)
    }

    struct Step: Sendable {
        var outcome: Result<RecordedPurchase, any Error>
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

    func enqueue(_ purchase: RecordedPurchase, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .success(purchase), held: held)) }
    }

    func enqueueFailure(_ error: any Error, held: Bool = false) {
        state.withLock { $0.steps.append(Step(outcome: .failure(error), held: held)) }
    }

    // MARK: Recorded calls

    var calls: [Call] { state.withLock { $0.calls } }
    var callCount: Int { state.withLock { $0.calls.count } }

    // MARK: PurchaseManaging

    func fetchPurchase(id: String) async throws -> RecordedPurchase {
        try await run(.fetch(id: id))
    }

    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase {
        try await run(.updateNotes(id: id, update: update))
    }

    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase {
        try await run(.updateShipping(id: id, update: update))
    }

    func deletePurchase(id: String) async throws -> RecordedPurchase {
        try await run(.delete(id: id))
    }

    private func run(_ call: Call) async throws -> RecordedPurchase {
        let step: Step = state.withLock { state in
            state.calls.append(call)
            if state.steps.isEmpty {
                return Step(outcome: .failure(PurchaseManagementError.server), held: false)
            }
            return state.steps.removeFirst()
        }
        if step.held { try await gate.hold(call) }
        return try step.outcome.get()
    }
}
