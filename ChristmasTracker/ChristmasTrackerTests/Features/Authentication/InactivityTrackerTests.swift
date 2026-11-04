//
//  InactivityTrackerTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1 / R1: InactivityTracker semantics.
//
//  Deleted (R1 rework — API removed):
//    - backgroundReturnAfterTimeoutLocks          (tested enteredBackground/becameActive old API)
//    - backgroundReturnBeforeTimeoutDoesNotLock   (same)
//    - enteredBackgroundThenRecordActivityDoesNotAffectBecameActive (same)
//
//  Rewritten:
//    - trackerUsesOnlyInstant — enteredBackground/becameActive calls replaced with
//      new API: recordActivity(at:), becameActive(at:), isTimedOut(at:)
//
//  Added (R1 new semantics — will compile once enteredBackground is removed and
//  becameActive gains no-side-effect semantics):
//    - becameActiveAtExactDeadlineLocks
//    - becameActiveOneNanosecondBeforeDeadlineDoesNotLock
//
//  All time is injected via ContinuousClock.Instant — no real sleeps.
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Fake

/// Minimal in-test fake policy with a configurable timeout.
private struct FakeLockTimeoutProvider: LockTimeoutProviding {
    let timeoutMinutes: Int
}

// MARK: - Suite

@Suite("InactivityTracker Tests")
struct InactivityTrackerTests {

    // MARK: - Factory

    private func makeSUT(timeoutMinutes: Int = 2) -> InactivityTracker {
        let policy = FakeLockTimeoutProvider(timeoutMinutes: timeoutMinutes)
        return InactivityTracker(policy: policy)
    }

    /// Provides a stable base instant from ContinuousClock.
    private var base: ContinuousClock.Instant { ContinuousClock().now }

    // MARK: - Tests

    @Test("Exactly at timeout (120s elapsed since last activity) → isTimedOut returns true")
    func exactlyAtTimeoutIsTimedOut() {
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        let atTimeout = t0 + .seconds(120)
        #expect(sut.isTimedOut(at: atTimeout) == true)
    }

    @Test("One second before timeout (119s elapsed) → isTimedOut returns false")
    func oneSecondBeforeTimeoutIsNotTimedOut() {
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        let beforeTimeout = t0 + .seconds(119)
        #expect(sut.isTimedOut(at: beforeTimeout) == false)
    }

    @Test("Activity resets the deadline: second activity at T=100 means not timed out at T=150")
    func activityResetsDeadline() {
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        // First activity at T=0, deadline = T+120
        let t100 = t0 + .seconds(100)
        sut.recordActivity(at: t100)
        // New deadline = T=100+120 = T=220
        let t150 = t0 + .seconds(150)
        #expect(sut.isTimedOut(at: t150) == false)
    }

    // MARK: - trackerUsesOnlyInstant (rewritten — R1)
    // enteredBackground and old becameActive calls removed.
    // Uses only the new simplified API: recordActivity(at:), becameActive(at:), isTimedOut(at:).

    @Test("Tracker compiles and operates using only ContinuousClock.Instant — no Date dependency")
    func trackerUsesOnlyInstant() {
        // This test verifies type-level correctness: InactivityTracker accepts
        // ContinuousClock.Instant, not Date. If the implementation accepted Date,
        // this would fail to compile.
        var sut = makeSUT()
        let now: ContinuousClock.Instant = ContinuousClock().now
        sut.recordActivity(at: now)
        // R1: becameActive(at:) is now a pure read — no enteredBackground needed.
        let _ = sut.becameActive(at: now + .seconds(1))
        let _ = sut.isTimedOut(at: now + .seconds(1))
        // No assertion needed — compilation success is the assertion.
        #expect(Bool(true))
    }

    // MARK: - New tests (R1) — becameActive boundary semantics

    // T-new-1: becameActive at exactly the deadline returns true.
    // Will compile once becameActive(at:) is simplified to `return isTimedOut(at: now)`.
    @Test("becameActive at exactly the deadline returns true")
    func becameActiveAtExactDeadlineLocks() {
        var sut = makeSUT(timeoutMinutes: 10)
        let t0 = base
        sut.recordActivity(at: t0)
        let deadline = t0 + .seconds(10 * 60)
        // R1: becameActive(at: deadline) == isTimedOut(at: deadline) == (deadline >= deadline) == true
        let result = sut.becameActive(at: deadline)
        #expect(result == true,
                "becameActive(at: deadline) must return true when now == deadline")
    }

    // T-new-2: becameActive one nanosecond before the deadline returns false,
    // AND does NOT reset the deadline (new no-side-effect contract).
    // Fails to compile until enteredBackground is removed (old `becameActive` reset deadline).
    @Test("becameActive one nanosecond before deadline returns false and does not reset deadline")
    func becameActiveOneNanosecondBeforeDeadlineDoesNotLock() {
        var sut = makeSUT(timeoutMinutes: 10)
        let t0 = base
        sut.recordActivity(at: t0)
        let deadline = t0 + .seconds(10 * 60)
        let oneNsBefore = deadline - .nanoseconds(1)
        // Capture deadline before the call.
        let deadlineBefore = sut.deadline
        // R1: becameActive(at:) is a pure read — no side effects, does not reset deadline.
        let result = sut.becameActive(at: oneNsBefore)
        #expect(result == false,
                "becameActive one nanosecond before deadline must return false")
        // Deadline must be unchanged — becameActive must not reset it.
        #expect(sut.deadline == deadlineBefore,
                "becameActive must not change the deadline (no side effects)")
    }
}
