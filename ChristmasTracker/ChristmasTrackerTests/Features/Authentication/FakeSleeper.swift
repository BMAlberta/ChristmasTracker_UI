//
//  FakeSleeper.swift
//  ChristmasTrackerTests
//
//  Test-only fake sleeper for Story R1.
//  Captures the requested deadline and suspends until release() is called,
//  allowing tests to control when the timer task wakes up.
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
    // nonisolated(unsafe): accessed from @MainActor release() and the nonisolated
    // withTaskCancellationHandler.onCancel block. Safe because onCancel runs only
    // when the Task is being cancelled (exclusive access at that point).
    nonisolated(unsafe) private var pending: CheckedContinuation<Void, Error>?

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        requestedDeadline = deadline
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [self] c in self.pending = c }
        } onCancel: {
            self.pending?.resume(throwing: CancellationError())
            self.pending = nil
        }
        pending = nil
    }

    func release() {
        pending?.resume(returning: ())
        pending = nil
    }
}
