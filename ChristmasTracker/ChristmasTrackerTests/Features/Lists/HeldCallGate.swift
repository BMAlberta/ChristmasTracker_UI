//
//  HeldCallGate.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the handshake used by the gated repository fakes, extracted so the member and
//  child fakes share it (GatedListRepository keeps its own copy and is not changed).
//
//  Determinism: no sleeps and no polling. A call that is held announces itself through
//  `nextHeldCall()` (a continuation handshake) and then suspends on a gate until the test
//  releases it. When `honorsCancellation` is true a held call ends early with CancellationError
//  if its task is cancelled; otherwise it keeps waiting until released (the stale-result case).
//

import Foundation

@MainActor
final class HeldCallGate<Call: Sendable> {

    var honorsCancellation = false

    private var unclaimedHeld: [Call] = []
    private var heldWaiters: [CheckedContinuation<Call, Never>] = []
    private var gates: [AsyncStream<Void>.Continuation] = []
    private var released: [Bool] = []

    /// Suspends until a held call has entered the repository (or returns at once if one already
    /// has and nobody has claimed it yet). Each held call is claimed exactly once, in order.
    @discardableResult
    func nextHeldCall() async -> Call {
        if !unclaimedHeld.isEmpty {
            return unclaimedHeld.removeFirst()
        }
        return await withCheckedContinuation { heldWaiters.append($0) }
    }

    /// Releases the oldest held call that has not been released yet. No-op when there is none.
    func releaseNext() {
        guard let index = released.firstIndex(of: false) else { return }
        release(at: index)
    }

    /// Releases the held call with the given zero-based arrival index. No-op when out of range or
    /// already released.
    func release(at index: Int) {
        guard gates.indices.contains(index), !released[index] else { return }
        released[index] = true
        gates[index].yield(())
        gates[index].finish()
    }

    /// Releases every held call that is still waiting.
    func releaseAll() {
        for index in gates.indices {
            release(at: index)
        }
    }

    /// Called by a fake for a held step: announces the call, then waits for the release.
    func hold(_ call: Call) async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        gates.append(continuation)
        released.append(false)
        if heldWaiters.isEmpty {
            unclaimedHeld.append(call)
        } else {
            heldWaiters.removeFirst().resume(returning: call)
        }
        if honorsCancellation {
            // Iterating an AsyncStream ends early when the task is cancelled.
            for await _ in stream { break }
            try Task.checkCancellation()
        } else {
            // An unstructured task is not cancelled with its parent, so this keeps waiting.
            await Task { for await _ in stream { break } }.value
        }
    }
}
