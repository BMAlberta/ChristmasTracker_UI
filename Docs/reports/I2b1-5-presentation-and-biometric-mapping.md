# I2b-1 Story R2 Report: Synchronous Lock Presentation and Biometric Outcome Mapping

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R2 — Synchronous Lock Presentation and Biometric Outcome Mapping (rework)
**Branch:** feat/i2b1-inactivity-lock

---

## Defects Fixed

**D4 — Async lock presentation**: `.onChange(of: lockController.lockState)` in `ChristmasTrackerApp.body` delivered the lock window on the next SwiftUI render cycle (asynchronous), leaving a frame of app content visible between the privacy cover hiding and the lock appearing. Fixed: introduced `InactivityLockPresenting` protocol; `InactivityLockController` calls `lockPresenter?.presentLock()` / `lockPresenter?.dismissLock()` synchronously within the state-change methods. `LockCoordinator` conforms to the protocol. The `.onChange` path is removed.

**D5 — `.failed` biometric result permanently hides the biometric button**: `LockView.attemptBiometricUnlock()` mapped `BiometricResult.failed` to `showPasswordOnly = true`, hiding the biometric button after a transient failure (non-matching face, bad lighting, wet finger). Fixed: extracted `BiometricOutcome` enum with `.keepBiometric(hint:)` case; `.failed` now maps to `.keepBiometric(hint:)` with a "try again" hint, keeping the biometric button visible. Only `.userFallback`, `.lockedOut`, and `.unavailable` map to `.passwordOnly`.

---

## Files Changed

**Production (new):**

- `ChristmasTracker/ChristmasTracker/App/InactivityLockPresenting.swift` — `internal protocol InactivityLockPresenting: AnyObject` with `presentLock()` and `dismissLock()`.

**Production (modified):**

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift`
  - Added `var lockPresenter: (any InactivityLockPresenting)?`
  - `sceneDidBecomeActive()`: calls `lockPresenter?.presentLock()` synchronously after `lockState = .locked` (guarded: only when transitioning from `.unlocked`)
  - `checkTimeout()`: calls `lockPresenter?.presentLock()` synchronously after `lockState = .locked`
  - `unlock()`: calls `lockPresenter?.dismissLock()` synchronously after `lockState = .unlocked`, before rescheduling timer
  - `clearForSession()`: calls `lockPresenter?.dismissLock()` only when `lockState == .locked` at time of call

- `ChristmasTracker/ChristmasTracker/App/LockView.swift`
  - Added `internal enum BiometricOutcome: Equatable` with cases `unlock`, `keepBiometric(hint: String?)`, `passwordOnly`
  - Added `internal nonisolated func biometricOutcome(for:biometryTypeName:) -> BiometricOutcome` (`.failed` maps to `.keepBiometric(hint:)` with "try again" message, D5 fix)
  - Added `internal nonisolated func showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:) -> Bool`
  - Added `@State private var biometricHint: String?`
  - Rewrote `attemptBiometricUnlock()` to use `BiometricOutcome` dispatch; `.keepBiometric` sets `biometricHint`, keeps button visible
  - Added hint `Text` display (AppTypography/AppColors/AppSpacing tokens)

- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`
  - `LockCoordinator` now conforms to `InactivityLockPresenting`; added `presentLock()` and `dismissLock()` delegating to `handleLockStateChange`
  - In `init()`: set `lc.lockPresenter = lockCoordinator` after construction
  - Removed `.onChange(of: lockController.lockState)` from `body`

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift`
  - Added `var biometryTypeName: String { get }` to `BiometricAuthenticating` protocol
  - `LocalAuthenticationService` implements with switch on `LABiometryType`

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift`
  - Added `var biometryTypeName: String { "Face ID" }` to satisfy updated protocol

**Test (new files):**

- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockPresenterTests.swift` — 5 tests: presenter called synchronously in `sceneDidBecomeActive()`, `unlock()`, `clearForSession()` (locked), not called twice on double trigger, not called in `clearForSession()` when unlocked
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricOutcomeTests.swift` — 12 tests: all 7 `BiometricResult` mapping cases, hint contains "try again" and biometryTypeName for `.failed`, D5 regression guard, `showBiometricButton` function (4 input combinations)

---

## verify.sh Output (pre-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 227 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

| Stage | Total |
|---|---|
| After R1 | 208 |
| + InactivityLockPresenterTests (5 tests) | 213 |
| + BiometricOutcomeTests (12 tests) | 225 |
| + 2 extra (implementer additions) | 227 |
| **Final** | **227** |

---

## Gate 2 Results

**Convention reviewer: PASS**
- All 10 items pass: @Instrumented, naming, design tokens, no GCD/Combine, no force unwraps, free function annotations, BiometricOutcome enum, LockCoordinator conformance, biometryTypeName.
- One warning: `FakeBiometricAuthenticator.biometryTypeName` returns hardcoded `"Face ID"` with no configurable stub. Tests that use `biometricOutcome(for:biometryTypeName:)` as a free function can pass any string directly — the limitation is narrow. No fix required.

**Acceptance reviewer: PASS (APPROVED)**
- All 10 focus-list items verified with file:line evidence.
- All 15 D4/D5 acceptance criteria met.
- Noted limitation: `FakeBiometricAuthenticator.biometryTypeName` hardcoded — cosmetic inconsistency in previews only, not a production correctness issue.

**Stuck-detector log:** Attempt 1: Both reviewers PASS (warnings only, no hard blocks). No attempt 2 needed.

---

## Deviations from Gate 1 Spec

None. All type signatures, function names, and behavior match the R2 Gate 1 spec exactly.

---

## Known Limitations (non-blocking)

1. **`FakeBiometricAuthenticator.biometryTypeName`** is hardcoded to `"Face ID"`. If a future test needs to verify the hint text with Touch ID via the fake, it would need a `stubbedBiometryTypeName` property. The `biometricOutcome(for:biometryTypeName:)` free function is independently testable with any string today.
2. **Lock screen appearance unverified on simulator/device** — this was noted in the original handoff and remains true after R2.

---

## Not Done or Partial

None. All R2 acceptance criteria are met:
- D4 fixed: `lockPresenter?.presentLock()` called synchronously in `sceneDidBecomeActive()` and `checkTimeout()`; `dismissLock()` in `unlock()` and `clearForSession()` (guarded); `.onChange` path removed.
- D5 fixed: `.failed` maps to `.keepBiometric(hint:)`, not `.passwordOnly`; biometric button stays visible after transient failure.
- 227 tests passing, verify.sh green.
