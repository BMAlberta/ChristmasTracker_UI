//
//  InactivityTracker.swift
//  ChristmasTracker
//
//  Tracks user inactivity using ContinuousClock.Instant — no Date dependency.
//  All time is injected so tests can exercise boundaries without real sleeps.
//
//  This type is intentionally nonisolated (not @MainActor) so it can be used
//  from any concurrency context, including synchronous test code.
//

import Foundation

/// Tracks inactivity and foreground/background transitions to determine
/// whether the app should lock due to user inactivity.
internal struct InactivityTracker {

    typealias Instant = ContinuousClock.Instant

    private let timeout: Duration
    private(set) var deadline: Instant
    private var backgroundEntryInstant: Instant?

    nonisolated internal init(policy: any LockTimeoutProviding) {
        self.timeout = .seconds(policy.timeoutMinutes * 60)
        self.deadline = ContinuousClock().now + .seconds(policy.timeoutMinutes * 60)
    }

    /// Resets the inactivity deadline to `now + timeout`.
    /// Only updates `deadline`; does not affect background state.
    nonisolated internal mutating func recordActivity(at now: Instant) {
        deadline = now + timeout
    }

    /// Records the moment the app entered the background.
    nonisolated internal mutating func enteredBackground(at now: Instant) {
        backgroundEntryInstant = now
    }

    /// Called when the app returns to the foreground.
    /// - Returns: `true` if the elapsed background time meets or exceeds the timeout.
    /// Resets the background entry instant and updates the deadline regardless of result.
    nonisolated internal mutating func becameActive(at now: Instant) -> Bool {
        let elapsed: Duration
        if let entry = backgroundEntryInstant {
            elapsed = now - entry
        } else {
            elapsed = .zero
        }
        backgroundEntryInstant = nil
        deadline = now + timeout
        return elapsed >= timeout
    }

    /// Returns `true` if `now` is at or beyond the inactivity deadline.
    nonisolated internal func isTimedOut(at now: Instant) -> Bool {
        now >= deadline
    }
}
