# Story R3 Report — The Login Screen
**Package:** I2b-2a — Face ID / Touch ID sign-in (rework)
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** 72848e7

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginBiometricModel.swift`
  - `@MainActor @Observable final class LoginBiometricModel`
  - Computed `buttonState` (from `loginBiometricButtonState` with live service reads)
  - Computed `biometricSignInState` and `isLoading` (direct service reads)
  - Alert state: `showSetupAlert`, `showNotEnrolledAlert`, `setupMessage`, `setupOpensSettings`
  - `tap()`: routes to alert, `pendBiometricEnablementRequest()`, or `signInWithBiometric()` by button state
  - `autoAttemptIfNeeded()`: fires `signInWithBiometric()` once per process when enrolled + ready
  - `nonisolated(unsafe) static var hasAutoAttempted` with inline explaining comment
  - `static func resetAutoAttemptFlagForTesting()` (internal test hook)

- `ChristmasTrackerTests/Features/Authentication/LoginBiometricModelTests.swift` (13 tests)

## Files Modified

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginView.swift`
  - Added `@State private var biometricModel: LoginBiometricModel? = nil`
  - `.task` modifier: calls `refreshBiometricState()`, lazy-creates model, syncs, calls `autoAttemptIfNeeded()`
  - Two `.alert` modifiers: setup alert (with "Open Settings"/"Cancel") and not-enrolled alert (with "OK")
  - `.onChange(of: authService.biometricSignInState)` to sync model state
  - `BiometricButtonSection` private struct: SF Symbol (`faceid`/`touchid`), `minHeight: 44`, accessibility label+hint, first-name caption for `.showEnrolled`, outcome text for retryHint/passwordOnly/neutralError, `.disabled(model.isLoading)`, `DividerRow` separator
  - Deleted `BiometricOptionView`

---

## scripts/verify.sh

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 450 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Baseline (after R2): 437 tests
New: 13 (LoginBiometricModelTests)
New total: **450 passed**

---

## Gate 2 results

**Convention reviewer**: APPROVE (first attempt)
- One non-blocking warning: raw `cornerRadius: 12` in `BiometricButtonSection` (pre-existing pattern in file; shape parameter, not layout spacing)

**Acceptance reviewer**: APPROVE (first attempt, all 12 criteria passed with file+line evidence)

**Stuck-detector log**: 1 implementation attempt (green first pass). 1 convention attempt (approved). 1 acceptance attempt (approved). Stuck detector not triggered.

---

## Focus-list evidence (file+line)

| Item | File | Line |
|---|---|---|
| SF Symbol faceid/touchid | LoginView.swift | 308 |
| minHeight 44pt | LoginView.swift | 319 |
| accessibilityLabel | LoginView.swift | 325 |
| accessibilityHint | LoginView.swift | 326 |
| First-name caption (.showEnrolled) | LoginView.swift | 310–312 |
| Outcome text (retryHint/passwordOnly/neutralError) | LoginView.swift | 327–335 |
| .disabled(model.isLoading) | LoginView.swift | 324 |
| Setup alert | LoginView.swift | 87–103 |
| Not-enrolled alert | LoginView.swift | 105–115 |
| .task → refreshBiometricState | LoginView.swift | 124 |
| .task → autoAttemptIfNeeded | LoginView.swift | 129 |
| DividerRow in BiometricButtonSection | LoginView.swift | 303 |

---

## Deviations

1. **`LoginBiometricModel` is a separate file**: Placed in `Views/LoginBiometricModel.swift` rather than embedded in `LoginView.swift`. Both are in the same folder; either location was acceptable per the spec.

2. **Computed properties for service state**: `buttonState`, `biometricSignInState`, and `isLoading` are computed properties reading from `authService` directly (rather than stored + synced). This eliminates sync races and is simpler — `@Observable` on the service propagates changes automatically.

---

## Not done or partial

None. All R3 acceptance criteria met and committed.
