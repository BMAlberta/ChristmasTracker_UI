# Story R1 Report — Observable Enrollment State and Sign-in Outcomes
**Package:** I2b-2a — Face ID / Touch ID sign-in (rework)
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** e24cd34

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricSignInState.swift`
  - `BiometricSignInState` enum: `.idle`, `.retryHint(String)`, `.passwordOnly(String)`, `.passwordRequired`, `.neutralError(String)`
  - `isCredentialFailure(_:)` free function (moved from `LoginView.swift`)
  - `biometricSignInOutcome(for: BiometricCredentialError, biometryTypeName:)` — pure nonisolated mapping
  - `biometricSignInOutcome(for: AuthenticationError, biometryTypeName:)` — pure nonisolated mapping

- `ChristmasTrackerTests/Features/Authentication/BiometricSignInStateTests.swift` (15 tests)
- `ChristmasTrackerTests/Features/Authentication/ObservableSnapshotTests.swift` (12 tests)

## Files Modified

- `AuthenticationService.swift`
  - Added `private(set) var enrolledUserSnapshot: (userId: String, firstName: String)? = nil` — stored observable replacing live Keychain read in view path
  - Added `private(set) var biometricSignInState: BiometricSignInState = .idle`
  - Changed `enrolledUser` computed property to return `enrolledUserSnapshot`
  - Updated `enrolledUserMatchesSession` to use `enrolledUserSnapshot`
  - Added `clearBiometricSignInState()` — resets state to `.idle`
  - Added `refreshBiometricState()` — reads availability, type, and `enrolledUserSnapshot` atomically
  - Made `refreshBiometricAvailability()` a thin alias for `refreshBiometricState()` (all existing call sites preserved)
  - Rewrote `signInWithBiometric()`: applies `biometricSignInOutcome` mapping, executes delete/refresh side effects, sets `biometricSignInState` on every failure path
  - Updated `enrollCurrentSession()`, `revokeEnrollment()`, and `handleAuthSuccess()` to call `refreshBiometricState()` after mutations

- `BiometricCredentialStoring.swift`
  - `KeychainBiometricCredentialStore.enrolledUser()`: added `LAContext` with `interactionNotAllowed = true`; treats `errSecInteractionNotAllowed` as nil without deleting the item
  - `InMemoryBiometricCredentialStore`: added per-declaration inline comments on `nonisolated(unsafe)` properties

- `LoginView.swift`
  - Removed `isCredentialFailure(_:)` free function (now lives in `BiometricSignInState.swift`)

---

## scripts/verify.sh

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 415 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Baseline (after S3): 388 tests
New tests: 15 (BiometricSignInStateTests) + 12 (ObservableSnapshotTests) = 27
New total: **415 passed**

Note: test-writer spec stated 14 + 12 = 26; the extra test (`lockedOutMessageDoesNotContainBiometryTypeName`) was additive coverage added during test writing.

---

## Gate 2 results

**Convention reviewer**: APPROVE (one non-blocking warning: `nonisolated(unsafe)` lacked per-declaration inline comments on `InMemoryBiometricCredentialStore` stored properties; fixed before commit)

**Acceptance reviewer**: APPROVE (first attempt, all 12 criteria passed)

**Stuck-detector log**: 1 implementation attempt (green first pass). 1 convention attempt (approved with one warning). 1 acceptance attempt (approved). Stuck detector not triggered.

---

## Deviations

1. **Test count 27 vs stated 26**: The pure mapping test file has 15 tests rather than the specified 14. The extra test adds coverage for the `lockedOut` message not containing the biometry type name. No defect.

---

## Not done or partial

None. All R1 acceptance criteria met and committed.
