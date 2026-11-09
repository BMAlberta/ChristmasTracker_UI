// DefaultSleeperTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// I3a-H2: DefaultSleeper's seconds-to-nanoseconds conversion must be safe for any Double.
// Converting a negative, NaN, infinite or too-large Double with UInt64(_:) traps, so the call
// itself is the assertion: if the conversion traps, the test process crashes (red).
//
// No seam is needed and no real long sleep happens: the sleep runs in a task that is cancelled
// before it is awaited, so Task.sleep throws at once (the conversion runs before the sleep).

import Testing
import Foundation
import TrackerAPI

@Suite("DefaultSleeper")
struct DefaultSleeperTests {

    private func sleepCancelled(seconds: TimeInterval) async {
        let sleeper = DefaultSleeper()
        let task = Task { await sleeper.sleep(seconds: seconds) }
        task.cancel()
        await task.value
    }

    @Test(
        "sleep(seconds:) does not trap for any Double (conversion is safe)",
        arguments: [
            -5.0, -0.0, -1e-300, -Double.greatestFiniteMagnitude, -Double.infinity,
            Double.nan, Double.infinity, Double.greatestFiniteMagnitude,
            1e300, 1e11, 1.8446744073709552e10, 1.8446744073709553e10, 0.0, 0.25,
        ]
    )
    func sleepDoesNotTrap(_ seconds: Double) async {
        await sleepCancelled(seconds: seconds)
        // Reaching this line means the conversion did not trap.
        #expect(Bool(true))
    }

    @Test("sleep(seconds: 0) and a negative wait return promptly without a long sleep")
    func zeroAndNegativeReturnPromptly() async {
        // Not cancelled: these must return on their own, so a regression to a huge wait would hang.
        let sleeper = DefaultSleeper()
        await sleeper.sleep(seconds: 0)
        await sleeper.sleep(seconds: -5)
        await sleeper.sleep(seconds: -Double.infinity)
        await sleeper.sleep(seconds: Double.nan)
        #expect(Bool(true))
    }
}
