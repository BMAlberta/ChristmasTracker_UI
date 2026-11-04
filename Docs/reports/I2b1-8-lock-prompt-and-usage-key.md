# I2b-1 R6 Report: Auto-Prompt Biometrics on Lock Appear and Declare Face ID Usage

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R6 — Lock screen auto-prompt and NSFaceIDUsageDescription
**Branch:** feat/i2b1-inactivity-lock
**Commit:** 62b9ebc — I2b-1: prompt for biometrics automatically when the lock appears and declare the Face ID usage

---

## Defects Fixed

- **B3** — Lock screen never auto-prompted biometrics on appear. Fixed by adding `shouldAutoAttemptBiometrics(...)` pure function and `.onAppear` logic in `LockView`.
- **B4** — `NSFaceIDUsageDescription` missing from Info.plist, causing a crash on Face ID attempt. Fixed by adding the key; `scripts/check-config.sh` enforces its presence.

---

## Files Changed

- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — Added pure nonisolated free function `shouldAutoAttemptBiometrics(isAvailable:preferenceEnabled:isPasswordOnly:alreadyAttempted:appIsActive:) -> Bool`; `@State private var hasAutoAttempted: Bool = false`; `@Environment(\.scenePhase) private var scenePhase`; `.onAppear` checks `shouldAutoAttemptBiometrics` and calls `attemptBiometricUnlock()` with `hasAutoAttempted = true`.
- `ChristmasTracker/ChristmasTracker/Info.plist` — Added `NSFaceIDUsageDescription`: `"Use Face ID to unlock Christmas Tracker."`.
- `scripts/check-config.sh` — Added grep check for `NSFaceIDUsageDescription`; script fails if absent.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LockAutoAttemptTests.swift` (new) — 6 tests for `shouldAutoAttemptBiometrics`.

---

## verify.sh Output (post-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 249 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Results

**Convention reviewer:** PASS
**Acceptance reviewer:** PASS

---

## Deviations

None.

---

## Not Done or Partial

None. All R6 acceptance criteria met.
