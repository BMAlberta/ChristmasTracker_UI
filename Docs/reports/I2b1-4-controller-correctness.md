# I2b-1 Story R1 Report: Controller and Tracker Correctness

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R1 — Controller and Tracker Correctness (rework)
**Branch:** feat/i2b1-inactivity-lock

---

## Defects Fixed

**D1 — unlock() relock loop**: `unlock()` did not reset the tracker deadline. The timer would fire immediately because the deadline was still in the past. Fixed: `unlock()` now calls `tracker.recordActivity(at: clockNow())` before restarting the timer, pushing the deadline to `now + timeout`.

**D2 — Scene events unguarded before start()**: `sceneDidBecomeActive()`, `sceneWillResignActive()`, and `recordActivity()` fired even when the controller was never started (e.g., on the login screen). Fixed: added `private(set) var isRunning: Bool = false`; all three methods guard on `isRunning`. `clearForSession()` now sets `isRunning = false`. `start()` sets `isRunning = true`.

**D3 — becameActive reset deadline, losing foreground idle time**: `InactivityTracker.becameActive(at:)` previously reset `deadline = now + timeout` and cleared `backgroundEntryInstant`, losing accumulated foreground idle time and treating brief interruptions (Control Center, Face ID prompt) as activity. Fixed: removed `enteredBackground(at:)` and `backgroundEntryInstant` from `InactivityTracker`; simplified `becameActive(at:)` to `return isTimedOut(at: now)` — a pure read with no side effects. Inactivity is now measured cumulatively from the last `recordActivity()` call.

---

## Files Changed

**Production:**

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityTracker.swift`
  - Added `nonisolated` to struct declaration and `: Sendable` conformance (required for Swift 6 to allow test access from non-isolated contexts)
  - Removed `backgroundEntryInstant: Instant?` stored property
  - Removed `enteredBackground(at:)` mutating method
  - Changed `becameActive(at:)` from a mutating deadline-resetting method to a pure non-mutating read (`return isTimedOut(at: now)`)

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift`
  - Added `clockNow: @MainActor () -> ContinuousClock.Instant` injection seam (default: `ContinuousClock().now`)
  - Added `sleepUntil: @MainActor (ContinuousClock.Instant) async throws -> Void` injection seam (default: `Task.sleep(until:clock:)`)
  - Added `private(set) var isRunning: Bool = false`
  - Fixed `start()`: sets `isRunning = true`, resets deadline via `tracker.recordActivity(at: clockNow())`
  - Fixed `stop()`: sets `isRunning = false`
  - Fixed `unlock()`: calls `tracker.recordActivity(at: clockNow())` before restarting timer (D1 fix)
  - Fixed `sceneWillResignActive()`: guards on `isRunning`; now a deliberate no-op when running (D2/D3 fix — no more `enteredBackground` call)
  - Fixed `sceneDidBecomeActive()`: guards on `isRunning`; uses `clockNow()` (D2 fix)
  - Fixed `recordActivity()`: guards on both `isRunning` and `lockState == .unlocked`
  - Fixed `clearForSession()`: sets `isRunning = false` (D2 fix)
  - Replaced inline timer loop with `scheduleTimerTask()` / `checkTimeout()` helpers that use the injected `sleepUntil` closure

**Test (new files):**

- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FakeClock.swift` — `@MainActor` clock with `advance(by:)` for deterministic time control in tests
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FakeSleeper.swift` — `@MainActor` sleeper using `CheckedContinuation`; `release()` resumes the timer task; `nonisolated(unsafe)` on `pending` for the cancellation handler

**Test (modified files):**

- `InactivityTrackerTests.swift` — deleted 3 tests using removed APIs; rewrote `trackerUsesOnlyInstant`; added `becameActiveAtExactDeadlineLocks` and `becameActiveOneNanosecondBeforeDeadlineDoesNotLock`
- `InactivityLockControllerTests.swift` — deleted 5 vacuous/redundant tests; rewrote 5 locked-state injection tests to use FakeClock+FakeSleeper; added 11 new controller tests (R1-1 through R1-11)
- `BiometricAuthenticatingTests.swift` — rewrote `makeLockedController()` helper to use FakeClock+FakeSleeper instead of `enteredBackground`
- `InactivityLockIntegrationTests.swift` — rewrote `lockControllerConformsToSessionClearable` to use FakeClock+FakeSleeper

---

## verify.sh Output (pre-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 208 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

| Stage | Total |
|---|---|
| Before R1 (post P1 precondition commit) | 203 |
| − 3 deleted tracker tests | 200 |
| − 5 deleted controller tests | 195 |
| + 2 new tracker tests | 197 |
| + 11 new controller tests | 208 |
| **Final** | **208** |

(5 controller rewrites, 1 tracker rewrite, 1 integration rewrite, `makeLockedController()` rewrite in BiometricAuthenticatingTests — these replace existing @Test functions and do not change the count.)

---

## Gate 2 Results

**Convention reviewer: PASS**
- One warning: `@MainActor` on `clockNow` and `sleepUntil` closure types is redundant (the closures are only called from within the `@MainActor` controller), but not harmful. Not a hard block.
- Pre-commit state correctly flagged as expected workflow. All other items pass.

**Acceptance reviewer: PASS (APPROVED)**
- All 10 focus-list items verified with file:line evidence.
- All 10 acceptance criteria met.
- No divergences from Gate 1 spec requiring logging.

**Stuck-detector log:** Attempt 1: Both reviewers PASS (one warning, no hard blocks). No attempt 2 needed.

---

## Deviations from Gate 1 Spec

1. **`@MainActor` vs `@Sendable` on closure types**: Gate 1 spec wrote `@escaping @Sendable` for `clockNow` and `sleepUntil`. Implementer used `@MainActor` to allow `FakeClock` (which is `@MainActor`) to be captured in the `clockNow` closure from test code. `@MainActor` implies `@Sendable` for actors. No behavior difference; accepted.

---

## Not Done or Partial

None. All R1 acceptance criteria are met:
- D1 fixed: `unlock()` resets deadline before rescheduling timer.
- D2 fixed: all scene methods and `recordActivity()` guard on `isRunning`; `clearForSession()` sets `isRunning = false`.
- D3 fixed: `becameActive(at:)` is a pure read; `enteredBackground(at:)` removed; cumulative inactivity preserved.
- FakeClock and FakeSleeper implemented and used in all relevant tests.
- 208 tests passing, verify.sh green.
