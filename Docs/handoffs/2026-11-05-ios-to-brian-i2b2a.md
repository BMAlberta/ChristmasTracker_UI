# iOS Handoff — I2b-2a: Face ID / Touch ID Sign-In
**Date:** 2026-11-05
**Branch:** feat/i2b2a-face-id-sign-in (not yet merged to master — Brian pushes and merges)
**Commits:** 7a07c44 → 4775f59 → b56c40e → 6468c5a → 54b63f9
**Verify:** 388 passed, 0 failed, build green

---

## What changed

### New capability
iOS users can now sign in with Face ID or Touch ID. The login screen shows a biometric button when the device has biometric hardware. On a cold launch with an enrolled user, the prompt starts once automatically; the button is available for retries. The lock screen shows the biometric button only for the enrolled user.

### Stories completed
- **S1** — Biometric credential store (`BiometricCredentialStoring` protocol, `KeychainBiometricCredentialStore`, `InMemoryBiometricCredentialStore`), `BiometricReadiness` enum + mapping functions, per-email stable mock users. Deleted dead `loginWithBiometric()` and `setupBiometrics()`. Extended legacy cleanup to all 4 legacy keys.
- **S2** — `AuthenticationService.signInWithBiometric()`, single-flight token refresh, pending enrollment flag, local-first logout ordering, `LoginBiometricButtonState` free functions in `LoginView`. Deleted dead `LogoutRequest` struct from `NetworkAuthenticationRepository`.
- **S3** — `enrollCurrentSession()`, `revokeEnrollment()`, `enrolledUser`, `enrolledUserMatchesSession` on `AuthenticationService`; silent token rotation on same-user login; `InactivityLockController` now uses `biometricEligibility: (() -> Bool)?` closure instead of `preference`; `ProfileBiometricToggleModel` rewritten against `AuthenticationService`; `BiometricEnablementModel` takes `enrollAction` closure; `ProfileView` toggle disabled + message shown for other-user enrollment; `ChristmasTrackerApp` offer guard uses `shouldShowBiometricEnablementAfterLogin`.

### Key design decisions (implemented)
- Biometric login is local only: the stored refresh token is exchanged with POST /auth/refresh, never a dedicated biometric server endpoint.
- One enrollment per device. The enrolled user's id and first name are stored as non-secret Keychain attributes on the same item as the biometric-protected token (key: `"biometric.credential.v1"`, access: `.biometryCurrentSet`, `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`).
- Enrollment is kept across logout and other users signing in. It is deleted only on: (a) the enrolled user turns Face ID off in Profile; (b) a credential failure (invalidRefreshToken / sessionExpired / invalidCredentials) on the enrolled user's own refresh or biometric sign-in; (c) iOS invalidates the item (biometric set changed).
- Token rotation: every successful refresh for the enrolled user updates the credential store before the new token is used.
- Single-flight refresh: `[String: Task<AuthData, Error>]` coalescing on `AuthenticationService` — concurrent callers with the same token share one repository call.

---

## Contract issues found

None. This package operates entirely in PRE-CONFORMANCE mode. All biometric sign-in is implemented via the existing POST /auth/refresh endpoint with the hand-written `AuthenticationError` mapping (401 → `.invalidCredentials` / `.sessionExpired`). No new API endpoints are used.

No mismatches between the contract (`contract/openapi.json`) and observed server behavior were encountered during this package because no new server calls were made. The existing hand-written 401 mapping is a known placeholder (see I2b-2b for the generated-client replacement).

---

## What the API team must do

Nothing blocking for this package.

Background (for awareness):
- I2b-2b (next iOS package) will replace the hand-written `AuthenticationError` mapping with the generated client's error codes. The specific codes that map to credential failures (`REFRESH_TOKEN_EXPIRED`, `REFRESH_TOKEN_INVALID`, `INVALID_CREDENTIALS`) will drive the `isCredentialFailure(_:)` function. No server changes are needed; this is a client-side mapping update.
- The dead `biometricLogin` method on `AuthenticationRepository` (server endpoint that iOS no longer calls) remains in the protocol per the CLAUDE.md safety constraint. The API team can retire that endpoint at any time without an iOS code change being needed first.

---

## Known remaining items (not in this package)

- `BiometricUnlockPreference` / `BiometricUnlockPreferring` are now dead (no callers remain after S3 removed the last uses). They can be deleted in a future cleanup story.
- The `isCredentialFailure(_:)` free function in `LoginView.swift` is architecturally misplaced (called from `AuthenticationService`; lives in a view file). Deferred.
- The dead `biometricLogin` repository method is intentionally kept per safety constraints.
- Registration code and the generated-client mapping → I2b-2b (blocked on contract sync).

---

## Section 9 line for PROGRAM.md

> I2b-2a complete (2026-11-05): Face ID / Touch ID sign-in implemented — credential store, readiness mapping, signInWithBiometric, single-flight refresh, enrollment/revocation, lock eligibility, profile toggle; 388 tests green, PRE-CONFORMANCE respected; no contract issues found.
