# Story S3 Report — Enrollment Rules, Profile Toggle, and Lock Eligibility
**Package:** I2b-2a — Face ID / Touch ID sign-in
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** 54b63f9

---

## Files Added

- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/EnrollCurrentSessionTests.swift` (10 tests, E1–E8)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LockEligibilityTests.swift` (12 tests, L1–L5)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/ProfileToggleEnrollmentTests.swift` (8 tests, P1–P8)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricEnablementModelTests.swift` (6 tests, B1–B4 + regressions)

## Files Modified

- `AuthenticationService.swift`
  - Added `enrollCurrentSession() async throws` — authenticates via `biometricAuthenticator.authenticate()`, then stores the refresh token with `credentialStore.enroll(refreshToken:userId:firstName:)`. SentrySDK span added. No-op when session is nil.
  - Added `revokeEnrollment() throws` — calls `credentialStore.delete()`.
  - Added `enrolledUser: (userId: String, firstName: String)?` — forwarded from `credentialStore.enrolledUser()`.
  - Added `enrolledUserMatchesSession: Bool` — `enrolledUser?.userId == currentUser?.id`.
  - Updated `handleAuthSuccess` — silently rotates the credential store token when enrolled user matches the signed-in user.
  - Updated `login()` — the pending enablement offer only fires when the enrolled user does NOT match the new session user.

- `InactivityLockController.swift`
  - Replaced `var preference: (any BiometricUnlockPreferring)?` with `var biometricEligibility: (() -> Bool)?`.

- `LockView.swift`
  - Both `preferenceEnabled` arguments changed from `controller.preference?.biometricUnlockEnabled ?? false/true` to `controller.biometricEligibility?() ?? false`.

- `BiometricEnablementModel.swift`
  - Replaced `init(authenticator:preference:)` with `init(authenticator:enrollAction:)`.
  - `enable()` calls `try await enrollAction()` after successful authentication; on throw sets `state = .failed(...)`.

- `ProfileBiometricToggleModel.swift` — complete rewrite
  - `init(authService: AuthenticationService)`
  - `isDisabledForOtherUser: Bool` — true when enrolled user exists but doesn't match session.
  - `disabledMessage: String?` — "Face ID is set up for another account on this device." when `isDisabledForOtherUser`.
  - `toggle(to:)` — guard on `isDisabledForOtherUser`; OFF calls `revokeEnrollment()`; ON calls `enrollCurrentSession()`.
  - SentrySDK span on `toggle(to:)`.

- `ProfileView.swift`
  - Toggle gains `.disabled(toggleModel.isDisabledForOtherUser)`.
  - `disabledMessage` caption rendered below the toggle using `AppCaption1` and `textMutedColor` tokens.
  - `toggleModel` is now `@State private var toggleModel: ProfileBiometricToggleModel?`, lazy-initialized in `.task` to avoid stale-init from `@State` declaration.

- `BiometricSetupView.swift`
  - Preview updated to use `enrollAction:` parameter.

- `ChristmasTrackerApp.swift`
  - `lockController.biometricEligibility` wired as `{ [weak authService] in authService?.enrolledUserMatchesSession ?? false }`.
  - Offer guard changed from `!preference.biometricSetupOfferShown` to `authService.shouldShowBiometricEnablementAfterLogin`.
  - `BiometricEnablementModel` construction updated to use `enrollAction:` closure calling `authService.enrollCurrentSession()`.
  - `onComplete` simplified to `showBiometricSetup = false` (no preference writes).
  - Removed `@State private var preference` and `lc.preference = BiometricUnlockPreference()`.

## Files Deleted

- `LockControllerPreferenceTests.swift` — tests the removed `preference` property on `InactivityLockController`; superseded by `LockEligibilityTests.swift`.
- `ProfileBiometricToggleModelTests.swift` — tests the removed `init(preference:enablementModel:)` API; superseded by `ProfileToggleEnrollmentTests.swift`.

---

## scripts/verify.sh — Before commit

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 388 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## scripts/verify.sh — After commit (54b63f9)

Same output — 388 passed, 0 failed, 0 skipped.

---

## Test arithmetic

Baseline (after S2): 373 tests

New tests:
- `EnrollCurrentSessionTests.swift`: 10 tests
- `LockEligibilityTests.swift`: 12 tests
- `ProfileToggleEnrollmentTests.swift`: 8 tests
- `BiometricEnablementModelTests.swift`: 6 tests (net new: replaced 0 existing tests)

Retired tests:
- `LockControllerPreferenceTests.swift`: 5 tests (tested removed `preference` property)
- `ProfileBiometricToggleModelTests.swift`: 16 tests (tested removed `init(preference:enablementModel:)` API)

Net: 373 + 36 − 5 − 16 = **388 passed**

---

## Gate 2 results

**Convention reviewer**: APPROVE (first attempt, no violations)
- All instrumentation checks passed: `enrollCurrentSession()` has SentrySDK span + comment; `toggle(to:)` has span + comment; `enable()` span preserved from S1; `revokeEnrollment()` correctly has no instrumentation.
- No Combine, no GCD, no force unwraps, correct Swift 6 concurrency throughout.
- Design tokens used in all new view lines.

**Acceptance reviewer**: REJECT then APPROVE
- Initial rejection: `ProfileView.swift` SettingsSectionView rendered the Toggle without `.disabled(toggleModel.isDisabledForOtherUser)` and without displaying `toggleModel.disabledMessage` (AC 11).
- Fix applied: added `.disabled(toggleModel.isDisabledForOtherUser)` to Toggle; added `if let message = toggleModel.disabledMessage { Text(message)... }` caption with AppCaption1 + textMutedColor tokens.
- Re-review verdict: **APPROVE** — all criteria E1–E8, L1–L5, P1–P8, B1–B4 pass.

**Stuck-detector log**: 1 convention-review attempt (approved). 1 acceptance attempt (rejected on view), 1 fix pass, 1 acceptance re-review (approved). Stuck detector not triggered.

---

## Deviations

1. **`ProfileView.swift` and `BiometricSetupView.swift` modified outside Gate 1 scope**: Both required updates to compile after the `ProfileBiometricToggleModel` and `BiometricEnablementModel` API changes. `ProfileView.swift` received the lazy-init fix and the disabled/message view changes. `BiometricSetupView.swift` received a preview-only update. These are necessary scope expansions.

2. **`LockControllerPreferenceTests.swift` and `ProfileBiometricToggleModelTests.swift` deleted**: Both tested APIs that were removed in this story. Their coverage is superseded by the new test files.

3. **`BiometricUnlockPreference` still exists**: The `BiometricUnlockPreferring` protocol and `BiometricUnlockPreference` struct are no longer used for lock eligibility or enrollment offer tracking. They remain in the codebase but are now effectively dead. Removal is deferred to avoid accidental breakage of any remaining reference; a future cleanup story can remove them.

---

## Not done or partial

The following items were not done in S3 and were identified as defects during rework:

- **D2 — Enrollment offer logic incomplete**: `shouldShowBiometricEnablementAfterLogin` was only set when `pendingBiometricEnablement && !enrolledUserMatchesSession` — an impossible combination because `pendingBiometricEnablement` could only be true from `pendBiometricEnablementRequest()`, which required the user to already be on the login screen without enrollment. No per-user offer-shown markers, no silent re-enrollment, no race protection. Corrected in R2.
- **D4 — `enrolledUser` was a live Keychain read**: The computed property called `credentialStore.enrolledUser()` on every access, making SwiftUI observations unreliable and potentially prompting the user. Corrected in R1 (observable snapshot).
