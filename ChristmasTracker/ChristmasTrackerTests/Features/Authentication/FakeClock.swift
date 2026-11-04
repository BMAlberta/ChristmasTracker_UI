//
//  FakeClock.swift
//  ChristmasTrackerTests
//
//  Test-only fake clock for Story R1.
//  Provides a controllable ContinuousClock.Instant that the controller's clockNow
//  closure captures, so tests can advance time without real sleeps.
//

import Foundation
@testable import ChristmasTracker

@MainActor
final class FakeClock {
    var now: ContinuousClock.Instant
    init(startingAt instant: ContinuousClock.Instant = ContinuousClock().now) { self.now = instant }
    func advance(by duration: Duration) { now = now + duration }
}
