//
//  InactivityTracker.swift
//  ChristmasTracker
//
//  Tracks user inactivity using a monotonic ContinuousClock.Instant.
//  All time is injected so tests can exercise boundaries without real sleeps.
//
//  R1 rework: removed enteredBackground(at:) and backgroundEntryInstant.
//  becameActive(at:) is now a pure read with no side effects — equivalent to isTimedOut(at:).
//  Cumulative time (foreground idle + background) is captured by the deadline alone:
//  the deadline is only ever reset by recordActivity(at:), so elapsed time continues
//  to accumulate across background/foreground transitions.
//
//  This type is intentionally nonisolated (not @MainActor) so it can be used
//  from any concurrency context, including synchronous test code.
//

import Foundation

/// Tracks inactivity to determine whether the app should lock due to user inactivity.
nonisolated internal struct InactivityTracker: Sendable {

    typealias Instant = ContinuousClock.Instant

    private let timeout: Duration
    private(set) var deadline: Instant

    nonisolated internal init(policy: any LockTimeoutProviding) {
        timeout = .seconds(policy.timeoutMinutes * 60)
        deadline = ContinuousClock().now + timeout
    }

    /// Resets the inactivity deadline to `now + timeout`.
    nonisolated internal mutating func recordActivity(at now: Instant) {
        deadline = now + timeout
    }

    /// Pure read — no side effects. Returns `true` if the deadline has been reached.
    nonisolated internal func becameActive(at now: Instant) -> Bool {
        return isTimedOut(at: now)
    }

    /// Returns `true` if `now` is at or beyond the inactivity deadline.
    nonisolated internal func isTimedOut(at now: Instant) -> Bool {
        return now >= deadline
    }
}
