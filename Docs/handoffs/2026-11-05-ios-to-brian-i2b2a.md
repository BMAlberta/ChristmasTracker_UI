# iOS Handoff — I2b-2a: Face ID / Touch ID Sign-In
**Date:** 2026-11-05
**Branch:** feat/i2b2a-face-id-sign-in (not yet merged to master — Brian pushes and merges)
**Commits (original):** 7a07c44 → 4775f59 → b56c40e → 6468c5a → 54b63f9 → 84b169c
**Commits (rework):** 46ce117 (Gate 1 spec) → e24cd34 (R1) → 59d2bcf (R2) → 72848e7 (R3)
**Verify:** 450 passed, 0 failed, build green

---

## What changed

### New capability
iOS users can sign in with Face ID or Touch ID. The login screen shows a biometric button when the device has biometric hardware. On a cold launch with an enrolled user, the prompt starts once automatically; the button is available for retries. The lock screen shows the biometric button only for the enrolled user. If another user logs in, they are offered Face ID setup once; if they opt out, the offer does not repeat unless they explicitly tap the not-enrolled button again.

### Stories completed (original pass)
- **S1** — Biometric credential store (`BiometricCredentialStoring` protocol, `KeychainBiometricCredentialStore`, `InMemoryBiometricCredentialStore`), `BiometricReadiness` enum + mapping functions, per-email stable mock users. Deleted dead `loginWithBiometric()` and `setupBiometrics()`. Extended legacy cleanup to all 4 legacy keys.
- **S2** — `AuthenticationService.signInWithBiometric()`, single-flight token refresh, pending enrollment flag, local-first logout ordering, `LoginBiometricButtonState` enum + free functions. Deleted dead `LogoutRequest` struct.
- **S3** — `enrollCurrentSession()`, `revokeEnrollment()`, `enrolledUser`, `enrolledUserMatchesSession` on `AuthenticationService`; silent token rotation on same-user login; `InactivityLockController` now uses `biometricEligibility: (() -> Bool)?` closure; `ProfileBiometricToggleModel` rewritten; `BiometricEnablementModel` takes `enrollAction` closure; `ProfileView` toggle disabled + message for other-user enrollment.

### Rework stories (R1–R3, correcting defects D1–D5 from the original pass)
- **R1** — `BiometricSignInState` enum + pure mapping function; `enrolledUserSnapshot` observable stored property on `AuthenticationService` (replaces live Keychain read); `refreshBiometricState()` refreshes snapshot + availability atomically; `signInWithBiometric()` sets state on every path; stale items deleted; `KeychainBiometricCredentialStore.enrolledUser()` hardened with `interactionNotAllowed = true` LAContext; `isCredentialFailure` moved from `LoginView.swift` to service layer.
- **R2** — `BiometricOfferAction` enum + 7-rule pure function; `EnrollmentHistoryStoring` protocol + `UserDefaultsEnrollmentHistory`; `AuthenticationService.login()` computes offer action before `handleAuthSuccess`, executes silent enrollment/re-enrollment, marks offer shown; `ProfileBiometricToggleModel.toggle(off)` clears previously-enrolled marker; `BiometricUnlockPreference.swift` and `BiometricUnlockPreferring` deleted.
- **R3** — `LoginBiometricModel` view model (`@MainActor @Observable`); `LoginView.body` wired with biometric button, two alerts, outcome text, auto-prompt on appear; `BiometricOptionView` deleted.

### Key design decisions (implemented)
- Biometric login is local only: the stored refresh token is exchanged with POST /auth/refresh, never a dedicated biometric server endpoint.
- One enrollment per device. The enrolled user's id and first name are stored as non-secret Keychain attributes on the same item as the biometric-protected token (key: `"biometric.credential.v1"`, access: `.biometryCurrentSet`, `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`).
- Enrollment is kept across logout and other users signing in. It is deleted only on: (a) the enrolled user turns Face ID off in Profile; (b) a credential failure (invalidRefreshToken / sessionExpired / invalidCredentials) on the enrolled user's own refresh or biometric sign-in; (c) iOS invalidates the item (biometric set changed).
- Token rotation: every successful refresh for the enrolled user updates the credential store before the new token is used.
- Single-flight refresh: `[String: Task<AuthData, Error>]` coalescing on `AuthenticationService` — concurrent callers with the same token share one repository call.
- Enrollment offer shown once per user per device. Second login for the same user (after the offer was shown or declined) does not show the sheet again unless `pendBiometricEnablementRequest()` is called (the "not enrolled" button tap). Silent re-enrollment fires when the previously-enrolled user logs back in after their credential was deleted (e.g. by iOS biometric-set change). Turning Face ID off in Profile clears the previously-enrolled marker so silent re-enrollment does not fire.

---

## Contract issues found

None. This package operates entirely in PRE-CONFORMANCE mode; no new API endpoints are used.

---

## What the API team must do

Nothing blocking for this package.

Background (for awareness):
- I2b-2b (next iOS package) will replace the hand-written `AuthenticationError` mapping with the generated client's error codes. The specific codes that map to credential failures (`REFRESH_TOKEN_EXPIRED`, `REFRESH_TOKEN_INVALID`, `INVALID_CREDENTIALS`) will drive `isCredentialFailure(_:)`. No server changes are needed; this is a client-side mapping update.
- The dead `biometricLogin` method on `AuthenticationRepository` (server endpoint that iOS no longer calls) remains in the protocol per the CLAUDE.md safety constraint. The API team can retire that endpoint at any time.

---

## Known remaining items (not in this package)

- Registration code and the generated-client mapping → I2b-2b (blocked on contract sync).
- The dead `biometricLogin` repository method is intentionally kept per safety constraints.

---

## Open Risks

The following risks were identified during the rework and are unresolved or accepted:

1. **`KeychainBiometricCredentialStore.enrolledUser()` with `interactionNotAllowed`**: The `errSecInteractionNotAllowed` path returns nil without deleting the item. If the item exists but the device is locked, the login screen will show "not enrolled" state instead of the enrolled button. This is intentional (avoid Keychain prompt during view rendering) but means the first biometric button appearance after a device lock may show "not enrolled" until the user interacts. Mitigated by calling `refreshBiometricState()` on scene activation.

2. **`LoginBiometricModel.hasAutoAttempted` is a process-level static flag**: It is never reset by logout, re-login, or the lock screen. A user who fails biometric sign-in on cold launch, then uses password, will NOT be auto-prompted again in the same process even if they log out and log back in. This is intentional (avoid annoying repeat prompts) but means biometric auto-prompt fires at most once per process regardless of session changes.

3. **`EnrollmentHistoryStoring` defaults to `.standard` UserDefaults**: If the app is reinstalled, enrollment history is cleared but the Keychain item may survive (Keychain is not wiped on reinstall by default). A user may be enrolled with a live credential but `hasSeenOffer` returns false, causing the offer to show again. This is benign — the offer will simply re-appear, and accepting it will silently replace the token.

---

## Section 9 line for PROGRAM.md

> I2b-2a complete (2026-11-05, rework 2026-11-05): Face ID / Touch ID sign-in fully implemented — credential store, readiness mapping, signInWithBiometric with outcome state, single-flight refresh, observable enrollment snapshot, 7-rule offer logic, enrollment history, login screen button + auto-prompt, profile toggle, lock eligibility; 450 tests green, PRE-CONFORMANCE respected; no contract issues found.
