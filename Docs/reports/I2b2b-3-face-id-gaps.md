# I2b-2b C3 Report: Face ID Gaps

**Story:** C3 — The Face ID gaps  
**Package:** I2b-2b  
**Date:** 2026-11-06  
**Branch:** feat/i2b2b-generated-auth  
**Commit:** (see below)

---

## What Changed

### Modified production files
- `BiometricCredentialStoring.swift` — Added `nonisolated(unsafe) var policyEvaluator: ((LAPolicy, String) async throws -> Void)? = nil` to `KeychainBiometricCredentialStore`. In `readRefreshToken(reason:)`: replaced direct `context.evaluatePolicy` call with an injectable seam (if/else on `policyEvaluator`); expanded LAError catch block to map `.authenticationFailed → .biometricFailed`, `.systemCancel`/`.appCancel → .userCancelled`, `.userCancel`/`.biometryLockout → .lockedOut`. `@Instrumented` preserved.
- `LoginBiometricModel.swift` — `autoAttemptIfNeeded()` signature extended to `autoAttemptIfNeeded(appIsActive: @escaping @Sendable () -> Bool = { true }) async`. Guard `appIsActive()` inserted BEFORE `hasAutoAttempted = true` so the flag is not consumed when the app is backgrounded.
- `ChristmasTrackerApp.swift` — `.sheet(isPresented: $showBiometricSetup)` changed to a custom `Binding<Bool>` whose `set` closure calls `authService.clearBiometricOfferAction()` when set to `false`. Removed the explicit `clearBiometricOfferAction()` call from the `onComplete` handler (the binding setter now owns it, guaranteeing exactly one call per dismissal path).
- `AuthenticationService.swift` — Extracted the ~15-line biometric offer block shared between `login()` and `register()` into a new `private func applyBiometricOffer(session: AuthSession)`. Both methods call it instead of duplicating the inline block. `computeOfferAction` now has exactly one call site.

### New test file
- `BiometricFaceIDGapTests.swift` — 11 tests: 2 service-layer regression guards for `clearBiometricOfferAction` (C1-S1, C1-S2); 6 LAError mapping tests covering all 5 specified codes plus a Keychain-not-reached guard (C2-M1 through C2-M6); 3 `autoAttemptIfNeeded` appIsActive tests (C3-A1 inactive no-consume, C3-A2 inactive-then-active, C3-A3 active enrolled).

---

## Commands and Raw Output

**Pre-commit verify.sh:**
```
=== verify: unit tests ===
--- tests: 609 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed
=== verify: OK ===
```

**Test delta from C2 baseline (598 app):**
- Added: 11 (BiometricFaceIDGapTests) = +11
- Deleted: 0
- Net: 598 + 11 = 609 ✓

---

## Gate 2 Verdicts

**Convention-reviewer:** PASS  
No hard blocks. `@Instrumented` confirmed on `readRefreshToken`. `applyBiometricOffer` is sync — no instrumentation needed. `nonisolated(unsafe)` on `policyEvaluator` accepted for `@unchecked Sendable` class with explaining comment.

**Acceptance-reviewer:** PASS  
All 4 criteria met on first pass: custom binding setter owns `clearBiometricOfferAction` exactly once (C1); LAError mapping complete and Keychain not reached on evaluatePolicy failure (C2); `appIsActive` guard precedes flag consumption (C3); `applyBiometricOffer` is single call site for `computeOfferAction` in both login and register (C4).

---

## Deviations

None. All 4 gaps from the I2b-2a handoff closed as specified.

---

## Not Done or Partial

None.
