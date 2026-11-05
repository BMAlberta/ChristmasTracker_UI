# iOS Handoff — I2b-2a: Face ID / Touch ID Sign-In
**Date:** 2026-11-05
**Branch:** feat/i2b2a-face-id-sign-in (not yet merged to master — Brian pushes and merges)
**Commits (original):** 7a07c44 → 4775f59 → b56c40e → 6468c5a → 54b63f9 → 84b169c
**Commits (rework):** 46ce117 (Gate 1 spec) → e24cd34 (R1) → 59d2bcf (R2) → 72848e7 (R3)
**Commits (fix pass):** 8885d1c (Gate 1 spec) → f693b59 (F1) → cf7b7fa (F2) → ca3b686 (F3) → 933d02c (F4)
**Verify:** 486 passed, 0 failed, build green

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

### Fix pass stories (F1–F3, correcting defects E1–E7 found after rework)
- **F1** — `enrollCurrentSession()` now calls `enrollmentHistory.setPreviouslyEnrolledUserId(user.id)` after enrolling (E1); both silent login paths do the same; `register()` gains the same offer logic as `login()` (E2); `enrollCurrentSession()` no longer calls `biometricAuthenticator.authenticate()` — authentication is the caller's responsibility; `ProfileBiometricToggleModel.toggle(to: true)` authenticates once before calling `enrollCurrentSession()` (E4). `EphemeralEnrollmentHistory` added as the default for `AuthenticationService.init()` to prevent cross-test UserDefaults contamination; production code passes `UserDefaultsEnrollmentHistory()` explicitly.
- **F2** — `KeychainBiometricCredentialStore.readRefreshToken` now calls `context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)` before the Keychain query; `localizedFallbackTitle = ""` hides the passcode fallback; the same pre-evaluated `LAContext` is passed as `kSecUseAuthenticationContext` so exactly one biometric prompt fires (E5).
- **F3** — `LoginBiometricModel.autoAttemptIfNeeded()` now consumes `hasAutoAttempted` on the first appearance regardless of button state (E6); `ChristmasTrackerApp.body` sheet is now driven by `.onChange(of: authService.biometricOfferAction)` checking `.showEnablementScreen` instead of `shouldShowBiometricEnablementAfterLogin` (E3); `BiometricType.none.displayName` returns `"Face ID or Touch ID"` instead of `"None"` (E7).

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
- The `biometricLogin` method on the iOS `AuthenticationRepository` protocol is dead code. The endpoint it called does not exist in the spec or the server, so there is nothing for the API team to retire. I2b-2b removes the method from the iOS protocol. No API action is needed.

---

## Known remaining items (not in this package)

- Registration code and the generated-client mapping → I2b-2b (blocked on contract sync).
- The dead `biometricLogin` repository method is intentionally kept per safety constraints.

---

## Open Risks

The following risks were identified during the rework and are unresolved or accepted:

1. **`KeychainBiometricCredentialStore.enrolledUser()` with `interactionNotAllowed`**: The `errSecInteractionNotAllowed` path returns nil without deleting the item. If the item exists but the device is locked, the login screen will show "not enrolled" state instead of the enrolled button. This is intentional (avoid Keychain prompt during view rendering) but means the first biometric button appearance after a device lock may show "not enrolled" until the user interacts. Mitigated by calling `refreshBiometricState()` on scene activation.

2. **`LoginBiometricModel.hasAutoAttempted` is a process-level static flag**: It is consumed on the FIRST appearance of the login screen regardless of biometric state (E6 fix). It is never reset by logout, re-login, or the lock screen. A user who arrives at the login screen with `.hidden` or `.showNotEnrolled` state will consume the flag on that first appearance; a later appearance in the same process (e.g. after logout + re-login) will NOT auto-prompt even if the state becomes `.showEnrolled`. This is intentional (avoid annoying repeat prompts) but means biometric auto-prompt fires at most once per process regardless of session changes.

3. **Reinstall removes the enrollment:** the first-launch wipe deletes the Keychain item class-wide on a fresh install or reinstall, so a reinstall removes the Face ID enrollment. The per-user offer markers (UserDefaults) return to unset, so the enablement offer appears again. This is benign. The production app passes `UserDefaultsEnrollmentHistory()` explicitly; the service's default is the in-memory `EphemeralEnrollmentHistory` so that tests do not contaminate each other.

4. **Manual verification status:** Brian reported on 2026-11-05 that the simulator checklist (items a to g and i) passes after the fix pass. Item h (real device) has NOT been performed. The reports for the fix pass stories F1 to F3 were not written, and no Gate 2 verdicts for the fix pass are on disk; the orchestrator reverted one implementer change (an extra pre-evaluation that would have prompted twice), and the chat-side code review is the only independent check.

5. **Simulator limitation:** the iOS Simulator does not enforce biometric Keychain access control, so the one-prompt behavior comes from the explicit `evaluatePolicy` call in `readRefreshToken`, which then passes the same `LAContext` to the Keychain query. This must be confirmed on a real device (exactly ONE prompt per sign-in).

6. **The privacy cover may flash behind the Face ID dialog** on a real device (the system dialog makes the scene inactive).

7. **Presence, not identity:** Face ID and Touch ID prove that a biometric enrolled on the device is present, not which person. Anyone with a face or finger enrolled on the phone can sign in as the enrolled user.

8. **Server session after logout:** after an iOS logout the server session stays live until 7 days idle or the 90-day cap, because iOS sends no cookie and no body to `POST /auth/logout`. An admin reset (`npm run user:reset-password`) revokes every chain for a user; that is the lost-phone procedure.

9. **Long absence:** Face ID sign-in after more than 7 days idle fails with a 401 and falls back to the password screen with no error text.

10. **Real API prerequisites (I1):** the refresh response returns the body token only when `X-Client-Platform: ios` is sent, and the hand-written client does not send it. I1 must add the four headers in middleware and must disable cookie handling (`httpShouldSetCookies` false, no cookie storage, accept policy never) with unit tests, because a cookie sent with logout would revoke the stored token chain.

11. **Error mapping:** the hand-written `AuthenticationError` mapping does not recognize `REFRESH_TOKEN_EXPIRED` and `REFRESH_TOKEN_INVALID`; it turns a 401 into `invalidCredentials`. I2b-2b replaces it with the generated client's codes. The registration code and the generated-client auth mapping are also I2b-2b.

12. **Known gaps carried into I2b-2b:** (a) dismissing the enablement sheet by swiping down does not clear `biometricOfferAction`, so a later identical offer may not re-trigger the sheet; (b) `readRefreshToken` maps only user-cancel and lockout, so `authenticationFailed`, `systemCancel`, and `appCancel` become `.other` and show the neutral error instead of the retry hint or no message; (c) the evaluate-then-read ordering in `KeychainBiometricCredentialStore` has no test seam; (d) the cold-launch auto-prompt does not check whether the app is active, and `register()` duplicates `login()`'s offer logic instead of sharing it.

13. **Scope deviations:** `MockAuthenticationRepository` became an `@unchecked Sendable` class, and `AuthTypes.swift` and `User.swift` gained `nonisolated`, outside the original scope.

14. **Not implemented:** remote lock-timeout configuration (only the UserDefaults override slot exists), and the dedicated server-issued biometric credential (decision A9), which is a post-build-1 candidate.

---

## Section 9 line for PROGRAM.md

> I2b-2a complete (2026-11-05, rework 2026-11-05, fix pass 2026-11-05): Face ID / Touch ID sign-in fully implemented — credential store, readiness mapping, signInWithBiometric with single biometric prompt (evaluatePolicy before Keychain read), single-flight refresh, observable enrollment snapshot, 7-rule offer logic with enrollment history marker, registration offer, login screen button + first-appearance auto-prompt, profile toggle with single enroll prompt, lock eligibility; 486 tests green, PRE-CONFORMANCE respected; no contract issues found.
