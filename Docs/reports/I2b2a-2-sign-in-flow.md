# Story S2 Report — Sign-in flow: signInWithBiometric, single-flight refresh, pending enrollment
**Package:** I2b-2a — Face ID / Touch ID sign-in
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** 6468c5a

---

## Files Added

- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LoginBiometricButtonTests.swift` (28 tests)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SignInWithBiometricTests.swift` (25 tests)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/NetworkAuthRepositoryRequestTests.swift` (4 tests)

## Files Modified

- `AuthenticationService.swift`
  - Added `signInWithBiometric()` — reads refresh token from credential store (biometric prompt), calls `singleFlightRefresh`, rotates stored token with `updateRefreshToken` before surfacing auth state, calls `handleAuthSuccess`. SentrySDK span added.
  - Added `singleFlightRefresh(token:) private` — `[String: Task<AuthData, Error>]` coalescing; concurrent callers with the same token await the same in-flight repository call.
  - Added `pendBiometricEnablementRequest()` — sets `pendingBiometricEnablement = true`; consumed on the next successful `login()` to surface `shouldShowBiometricEnablementAfterLogin = true`.
  - Added `shouldShowBiometricEnablementAfterLogin: Bool` and `pendingBiometricEnablement: Bool` state.
  - Added `credentialStore: any BiometricCredentialStoring` dependency (default: `KeychainBiometricCredentialStore()`).
  - Added `inflightRefreshTasks: [String: Task<AuthData, Error>]` for single-flight.
  - Updated `refreshTokenIfNeeded()` — single-flight refresh; rotates stored credential when enrolled userId matches session userId; on credential failure (`invalidRefreshToken` / `sessionExpired` / `invalidCredentials`) deletes enrollment for matching user and calls `logout(.sessionExpired)`; non-credential errors keep session and enrollment alive. SentrySDK span added.
  - Updated `logout(reason:)` — local teardown (`sessionManager.teardown` + `clearAuthState` + `clearStoredTokens`) completes before the best-effort non-awaited server logout `Task`.
  - Updated `login()` — consumes pending biometric enablement flag on success.

- `NetworkAuthenticationRepository.swift`
  - Deleted dead private `LogoutRequest` struct from inside `logout(refreshToken:)` (no behaviour change).

- `LoginView.swift`
  - Added `LoginBiometricButtonState` enum (`.hidden`, `.showNotEnrolled`, `.showNeedsSetup(opensSettings:)`, `.showEnrolled(firstName:)`).
  - Added `loginBiometricButtonState(readiness:enrolledUser:biometryTypeName:)` nonisolated free function.
  - Added `shouldAutoAttemptBiometricLogin(readiness:hasEnrolledUser:alreadyAttemptedThisLaunch:appIsActive:)` nonisolated free function.
  - Added `isCredentialFailure(_:)` nonisolated free function.
  - **NOTE (corrected in rework):** `LoginBiometricButtonState`, `loginBiometricButtonState`, `shouldAutoAttemptBiometricLogin`, and `isCredentialFailure` free functions were added to `LoginView.swift`, but the view body did NOT call them — `BiometricOptionView` was wired independently and ignored the state functions. This was identified as defect D1 and corrected in rework story R3.

---

## scripts/verify.sh — Before commit

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 373 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## scripts/verify.sh — After commit (6468c5a)

Same output — 373 passed, 0 failed, 0 skipped.

---

## Test arithmetic

Baseline (after S1): 322 tests

New tests:
- `LoginBiometricButtonTests.swift`: 28 tests
- `SignInWithBiometricTests.swift`: 25 tests (includes single-flight, pending-enrollment, logout-ordering, credential-failure, A7 network-failure-keeps-session-alive)
- `NetworkAuthRepositoryRequestTests.swift`: 4 tests (logout shape × 2, refresh shape × 2)

New total: **373 passed**

---

## Gate 2 results

**Convention reviewer**: REJECT then APPROVE
- Initial rejection: (1) `signInWithBiometric` missing SentrySDK span; (2) `refreshTokenIfNeeded` missing SentrySDK span (substantially modified in S2). Both are `@MainActor`-isolated so `@Instrumented` cannot be used.
- Fixes applied: added manual `SentrySDK.startTransaction` span with `defer { transaction.finish() }` and explaining comment to both methods, matching the `clearForSession` pattern.
- Two warnings retained on record (not blocking): `singleFlightRefresh` private helper lacks a span; `isCredentialFailure` free function defined in `LoginView.swift` but called from `AuthenticationService`.
- Re-review verdict: **APPROVE**

**Acceptance reviewer**: REJECT then APPROVE
- Initial rejection: test `refreshTokenIfNeededNetworkFailureKeepsSessionAlive` did not assert `sut.isAuthenticated == true`; a misleading comment said "session ends" contradicting the A7 requirement.
- Fix applied: removed misleading comment, added `#expect(sut.isAuthenticated == true, "Network failure must not end the session")`.
- Re-review verdict: **APPROVE** — all nine criteria A1–A9 pass.

**Stuck-detector log**: 1 convention-review attempt (rejected), 1 fix pass, 1 convention re-review (approved). 1 acceptance attempt (rejected), 1 fix pass, 1 acceptance re-review (approved). Stuck detector not triggered.

---

## Deviations

1. **`updateRefreshToken` called before `handleAuthSuccess` in `signInWithBiometric`**: The Gate 1 criterion stated "runs handleAuthSuccess, calls updateRefreshToken". The implementation calls `updateRefreshToken` before `handleAuthSuccess`. This is intentionally safer: the new token is persisted before `isAuthenticated` is surfaced, so there is no window where the app is authenticated but still holds the old credential. The acceptance reviewer confirmed this is acceptable.

2. **`isCredentialFailure` placed in `LoginView.swift`**: This free function is called by both `LoginView` state logic and `AuthenticationService`. Placement in a view file creates an inverted dependency. Convention reviewer raised this as a warning (not a hard block). Moving it is deferred to avoid scope creep; it can be relocated in a future story.

---

## Not done or partial

The following items were not done in S2 and were identified as defects during rework:

- **D1 — Biometric button not wired into view body**: `loginBiometricButtonState`, `shouldAutoAttemptBiometricLogin`, and `isCredentialFailure` existed in `LoginView.swift` but the body never called them. `BiometricOptionView` was an independent, unused stub. Corrected in R3.
- **D3 — `signInWithBiometric()` returned silently on all failures**: No outcome state was set on any error path. Corrected in R1.
- **D5 — `KeychainBiometricCredentialStore.enrolledUser()` lacked `interactionNotAllowed` guard**: Could potentially prompt the user during a view-layer read. Corrected in R1.
- **`isCredentialFailure` architecturally misplaced**: Lived in a view file but was called from the service layer. Corrected in R1 (moved to `BiometricSignInState.swift`).
