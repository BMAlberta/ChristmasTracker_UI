# Story R2 Report — Enrollment Offer Rules
**Package:** I2b-2a — Face ID / Touch ID sign-in (rework)
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** 59d2bcf

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricOfferAction.swift`
  - `BiometricOfferAction` enum: `.none`, `.silentlyReplaceToken`, `.silentlyReenroll`, `.showEnablementScreen`
  - `biometricOfferAction(readiness:enrolledUserId:signedInUserId:previouslyEnrolledUserId:offerShownForUser:pendingRequest:)` pure nonisolated function (7-rule precedence mapping)
  - `EnrollmentHistoryStoring` protocol
  - `UserDefaultsEnrollmentHistory` struct

- `ChristmasTrackerTests/Features/Authentication/BiometricOfferActionTests.swift` (15 tests)
- `ChristmasTrackerTests/Features/Authentication/EnrollmentHistoryTests.swift` (10 tests)
- `ChristmasTrackerTests/Features/Authentication/BiometricOfferIntegrationTests.swift` (8 tests)

## Files Modified

- `AuthenticationService.swift`
  - Added `private let enrollmentHistory: any EnrollmentHistoryStoring` dependency (default: `UserDefaultsEnrollmentHistory()`)
  - Added `private(set) var biometricOfferAction: BiometricOfferAction = .none`
  - `shouldShowBiometricEnablementAfterLogin` converted to computed property: `biometricOfferAction == .showEnablementScreen` (preserves `ChristmasTrackerApp.swift` compatibility)
  - `login()`: computes offer action before `handleAuthSuccess`, executes silent enrollment/re-enrollment, marks offer shown when `.showEnablementScreen`; added manual SentrySDK span with explaining comment
  - Added `clearBiometricOfferAction()`, `clearPreviouslyEnrolledUserId()` public methods

- `ProfileBiometricToggleModel.swift`
  - `toggle(to: false)`: calls `authService.clearPreviouslyEnrolledUserId()` after `revokeEnrollment()` to clear the previously-enrolled marker

## Files Deleted

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricUnlockPreference.swift`
- `ChristmasTrackerTests/Features/Authentication/BiometricUnlockPreferenceTests.swift` (11 tests removed)

Deleted test names:
1. "biometricUnlockEnabled defaults to false on a fresh suite"
2. "biometricSetupOfferShown defaults to false on a fresh suite"
3. "biometricUnlockEnabled persists across instances using the same suite"
4. "biometricSetupOfferShown persists across instances using the same suite"
5. "Setting biometricUnlockEnabled = true then creating a new instance reads true"
6. "enabledKey and offerShownKey are distinct — writing one does not affect the other"
7. "Static key constants are non-empty and distinct strings"
8. "FakeBiometricUnlockPreference: biometricUnlockEnabled defaults to false"
9. "FakeBiometricUnlockPreference: biometricSetupOfferShown defaults to false"
10. "FakeBiometricUnlockPreference: setting and reading biometricUnlockEnabled"
11. "FakeBiometricUnlockPreference: setting and reading biometricSetupOfferShown"

---

## scripts/verify.sh

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 437 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Baseline (after R1): 415 tests
Deleted: 11 (BiometricUnlockPreferenceTests)
New: 15 + 10 + 8 = 33
New total: **437 passed**

---

## Gate 2 results

**Convention reviewer**: REJECT then APPROVE
- Rejection: `login()` was modified but lacked a manual SentrySDK span (modified `@MainActor async` function in service layer)
- Fix: Added `SentrySDK.startTransaction` span + `defer { span.finish() }` + explaining comment at top of `login()`
- Re-review verdict: **APPROVE**

**Acceptance reviewer**: APPROVE (first attempt, all 12 criteria passed)

**Stuck-detector log**: 1 implementation attempt (green first pass). 2 convention attempts (reject→approve after span fix). 1 acceptance attempt (approved). Stuck detector not triggered.

---

## Deviations

1. **`login()` SentrySDK span added**: Not specified in Gate 1 scope but required by coding standards when modifying `async` service methods. Additive change.

2. **`shouldShowBiometricEnablementAfterLogin` retained as computed property**: Gate 1 spec mentioned removing it; it was preserved as `biometricOfferAction == .showEnablementScreen` to avoid modifying `ChristmasTrackerApp.swift` (outside R2 scope). The behavior is equivalent.

---

## Not done or partial

None. All R2 acceptance criteria met and committed.
