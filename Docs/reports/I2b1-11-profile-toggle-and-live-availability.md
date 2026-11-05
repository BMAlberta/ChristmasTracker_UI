# I2b-1 R10 Report: Profile Toggle, Live Availability, Lock Auto-Prompt Guard

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R10 — Profile toggle, live availability, lock auto-prompt guard (Rework 3)
**Branch:** feat/i2b1-inactivity-lock
**Commit:** 23a9c32 — I2b-1: verify biometrics before the Profile toggle turns on, keep availability live, and guard the lock prompt with the real app state

---

## Defects Fixed

- **C2a** — Profile toggle was a plain `$preference.biometricUnlockEnabled` binding; turning ON never ran a biometric check.
- **C2b** — `refreshBiometricAvailability()` was called only at init and after login; availability was stale when returning to the app or navigating to ProfileView.
- **C3** — `LockView` used `@Environment(\.scenePhase)` for the auto-attempt guard, but `LockView` is hosted in its own `UIWindow` and scene-phase propagation is unreliable there.

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Profile/Services/ProfileBiometricToggleModel.swift` — `@MainActor @Observable final class`; `var isEnabled: Bool` initialized from `preference.biometricUnlockEnabled`; `var errorMessage: String?`; `toggle(to newValue: Bool) async` — if `newValue == false` immediately clears preference and state; if `newValue == true` calls `enablementModel.enable()` and sets `isEnabled = true` / writes preference only on `.succeeded`; manual SentrySDK span (actor-isolated, `@Instrumented` not applicable).
- `ChristmasTracker/ChristmasTrackerTests/Features/Profile/ProfileBiometricToggleModelTests.swift` — 8 tests covering success, failure, cancellation, toggle-off, enable-not-called-on-off, initial state from preference true/false, preference-only-after-success.

## Files Changed

- `AuthenticationService.swift` — `biometricAuthenticator` visibility changed from `private` to `internal` so `ProfileView` can supply it to `BiometricEnablementModel`.
- `ChristmasTrackerApp.swift` — Added `auth?.refreshBiometricAvailability()` inside the `UIScene.didActivateNotification` `MainActor.assumeIsolated` block.
- `ProfileView.swift` — `@State private var toggleModel` declared as a non-optional `ProfileBiometricToggleModel` eagerly initialized at declaration time (using `LocalAuthenticationService()` and `BiometricUnlockPreference()` defaults); `SettingsSectionView` takes `toggleModel: ProfileBiometricToggleModel` (non-optional); `Toggle` unconditionally uses the model binding; `.task` calls only `authService.refreshBiometricAvailability()`; `.alert` surfaces `toggleModel.errorMessage`.
- `LockView.swift` — Removed `@Environment(\.scenePhase)`; replaced `scenePhase == .active` with `UIApplication.shared.applicationState == .active` in the `shouldAutoAttemptBiometrics` guard.
- `LockAutoAttemptTests.swift` — Added 32-case parameterized truth table for `shouldAutoAttemptBiometrics` and 8-case parameterized truth table for `showBiometricButton` using `@Test(arguments:)`.

---

## Gate 2 Rework (1 cycle)

Initial Gate 2 acceptance review rejected on criterion 6: `toggleModel` was `ProfileBiometricToggleModel?` (nil default), constructed lazily inside `.task`. The raw `$preference.biometricUnlockEnabled` binding was live while the model was nil. Fixed by converting to a non-optional `@State` initialized eagerly at declaration time and removing the fallback raw-binding branch.

---

## verify.sh Output (pre-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 281 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## verify.sh Output (post-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 281 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

**Test count note:** xcodebuild reports each `@Test(arguments:)` method as 1 test entry regardless of argument count. The 32-case and 8-case parameterized tables count as 2 test entries, plus 8 `ProfileBiometricToggleModelTests` = 10 new tests (271 → 281).

---

## Gate 2 Results

**Convention reviewer:** PASS (all 13 hard blocks). No warnings raised.

**Acceptance reviewer (initial):** REJECT — criterion 6 (lazy init race window). Rework applied.

**Acceptance reviewer (re-review):** PASS. All 8 criteria verified, no regressions from rework.

---

## Deviations

- Gate 2 rework: initial `ProfileView` lazy-initialized `toggleModel` in `.task`; corrected to eager `@State` declaration before commit.
- `@Instrumented` not applied to `ProfileBiometricToggleModel.toggle(to:)` because it is `@MainActor`-isolated. Manual SentrySDK span used per coding-standards.md convention for actor-isolated methods.

---

## Not Done or Partial

None. All R10 acceptance criteria met.
