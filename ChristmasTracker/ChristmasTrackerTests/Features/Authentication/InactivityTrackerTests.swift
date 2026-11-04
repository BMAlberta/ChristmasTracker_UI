//
//  InactivityTrackerTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-1: inactivity lock — InactivityTracker semantics.
//
//  These tests are intentionally written against the Gate 1 interface contract.
//  They will fail to compile until InactivityTracker and LockTimeoutProviding are implemented.
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

    @Test("Background return after > timeout → becameActive returns true")
    func backgroundReturnAfterTimeoutLocks() {
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        sut.enteredBackground(at: t0)
        let returnInstant = t0 + .seconds(121)
        let shouldLock = sut.becameActive(at: returnInstant)
        #expect(shouldLock == true)
    }

    @Test("Background return after < timeout → becameActive returns false")
    func backgroundReturnBeforeTimeoutDoesNotLock() {
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        sut.enteredBackground(at: t0)
        let returnInstant = t0 + .seconds(60)
        let shouldLock = sut.becameActive(at: returnInstant)
        #expect(shouldLock == false)
    }

    @Test("Tracker compiles and operates using only ContinuousClock.Instant — no Date dependency")
    func trackerUsesOnlyInstant() {
        // This test verifies type-level correctness: InactivityTracker accepts
        // ContinuousClock.Instant, not Date. If the implementation accepted Date,
        // this would fail to compile.
        var sut = makeSUT()
        let now: ContinuousClock.Instant = ContinuousClock().now
        sut.recordActivity(at: now)
        sut.enteredBackground(at: now)
        let _ = sut.becameActive(at: now + .seconds(1))
        let _ = sut.isTimedOut(at: now + .seconds(1))
        // No assertion needed — compilation success is the assertion.
        #expect(Bool(true))
    }

    @Test("enteredBackground then recordActivity does not affect becameActive result")
    func enteredBackgroundThenRecordActivityDoesNotAffectBecameActive() {
        // Semantics: becameActive checks elapsed time since enteredBackground,
        // not since last activity. A recordActivity between background and foreground
        // should not suppress the lock.
        var sut = makeSUT(timeoutMinutes: 2)
        let t0 = base
        sut.recordActivity(at: t0)
        sut.enteredBackground(at: t0)
        // Simulate a background activity record — should not reset the background clock
        sut.recordActivity(at: t0 + .seconds(10))
        // Return after > timeout from background entry
        let returnInstant = t0 + .seconds(130)
        let shouldLock = sut.becameActive(at: returnInstant)
        #expect(shouldLock == true)
    }
}
