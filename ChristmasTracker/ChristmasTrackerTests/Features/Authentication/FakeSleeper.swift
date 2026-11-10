//
//  FakeSleeper.swift
//  ChristmasTrackerTests
//
//  Test-only fake sleeper for Story R1.
//  Captures the requested deadline and suspends until release() is called,
//  allowing tests to control when the timer task wakes up.
//
//  I3a-H2: deterministic handshake. A test must never assume that one Task.yield() lets the
//  controller's timer task reach sleep(until:). Instead, it awaits waitForSleepCount(_:), which
//  returns once that many sleeps have been entered and the latest one is suspended, so a
//  following release() always has a pending sleep to wake. A sleep entered on an already
//  cancelled task (a stale reschedule) throws at once and is not counted, so it cannot
//  overwrite requestedDeadline or leave a continuation that is never resumed.
//
//  nonisolated(unsafe) on pending: accessed from both @MainActor release() and the
//  nonisolated withTaskCancellationHandler.onCancel block. Safe because onCancel runs
//  only when the Task is being cancelled — exclusive access to pending at that point.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class FakeSleeper {
    private(set) var requestedDeadline: ContinuousClock.Instant?
    /// Number of sleeps entered (and suspended) so far.
    private(set) var sleepCallCount: Int = 0
    // nonisolated(unsafe): accessed from @MainActor release() and the nonisolated
    // withTaskCancellationHandler.onCancel block. Safe because onCancel runs only
    // when the Task is being cancelled (exclusive access at that point).
    nonisolated(unsafe) private var pending: CheckedContinuation<Void, Error>?
    private var countWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        // Main-actor isolated and no suspension before the continuation is stored, so a
        // cancellation cannot slip in between this check and the handler below.
        try Task.checkCancellation()
        requestedDeadline = deadline
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [self] c in
                self.sleepCallCount += 1
                self.pending = c
                self.resumeSatisfiedWaiters()
            }
        } onCancel: {
            self.pending?.resume(throwing: CancellationError())
            self.pending = nil
        }
    }

    func release() {
        pending?.resume(returning: ())
        pending = nil
    }

    /// Returns once at least `count` sleeps have been entered (immediately if already so).
    func waitForSleepCount(_ count: Int) async {
        guard sleepCallCount < count else { return }
        await withCheckedContinuation { continuation in
            countWaiters.append((count, continuation))
        }
    }

    private func resumeSatisfiedWaiters() {
        let ready = countWaiters.filter { sleepCallCount >= $0.count }
        countWaiters.removeAll { sleepCallCount >= $0.count }
        for waiter in ready { waiter.continuation.resume() }
    }
}
