# I2b-1 Story 3 Report: Biometric Unlock Preference

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** 3 — Biometric unlock preference and profile toggle
**Branch:** feat/i2b1-inactivity-lock
**Commits:** 28be971 — I2b-1: add biometric unlock preference and profile toggle; post-Gate-2 nonisolated fix

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricUnlockPreference.swift` — `BiometricUnlockPreferring` protocol and `BiometricUnlockPreference` struct; `biometricUnlockEnabled` and `biometricSetupOfferShown` backed by `UserDefaults` keys `"biometricUnlock.enabled"` and `"biometricUnlock.offerShown"`; `nonisolated static let` keys (required because `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` would otherwise isolate them to `@MainActor`, breaking the `nonisolated` computed properties).
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricUnlockPreferenceTests.swift` — 12 tests: defaults, persistence, round-trip, key distinctness, `FakeBiometricUnlockPreference` behavior. Uses isolated `UserDefaults` suite per test.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LockControllerPreferenceTests.swift` — 5 tests: `preference` nil default, nil preference does not constrain biometric, readable with enabled/disabled, replaceable.

## Files Changed

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift` — Added `var preference: (any BiometricUnlockPreferring)?`.
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — `showBiometricButton` now also gates on `controller.preference?.biometricUnlockEnabled ?? true` (nil = no constraint = show button).
- `ChristmasTracker/ChristmasTracker/Features/Profile/Views/ProfileView.swift` — `SettingsSectionView` gains `@Binding var preference: BiometricUnlockPreference`; TODO biometric row replaced with `Toggle` bound to `$preference.biometricUnlockEnabled`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/BiometricSetupView.swift` — Added `var onComplete: ((Bool) -> Void)?`; called with `true` on enable success, `false` on "Not Now".
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — Added `@State private var preference = BiometricUnlockPreference()`; sets `lockController.preference = preference`; after first login (if `!biometricSetupOfferShown && isBiometricAvailable`), presents `BiometricSetupView` as a sheet; `onComplete` sets `biometricSetupOfferShown = true`, `biometricUnlockEnabled = enabled`, and re-assigns `lockController.preference`.

---

## verify.sh Output

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 203 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

| Stage | Total |
|---|---|
| Story 2 final | 186 |
| + BiometricUnlockPreferenceTests (12 tests) | 198 |
| + LockControllerPreferenceTests (5 tests) | 203 |
| **Final** | **203** |

---

## Gate 2 Results

**Convention reviewer (first pass): PASS**
- Warnings (not hard blocks):
  - W1: `nonisolated(unsafe) static let` on `String` constants unnecessary — fixed post-Gate-2: changed to `nonisolated static let` (removes `unsafe`; `String` is `Sendable` and `nonisolated` alone is correct under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Verify.sh re-run: 203 tests, OK.
  - W2: `ProfileView` creates its own `BiometricUnlockPreference()` instance instead of injecting from environment. Accepted: both instances read `UserDefaults` live (no caching); writes from the toggle are reflected on the lock screen's next read. `lockController.preference` is also explicitly updated in the app-level `onComplete` callback. Logged here as a known architectural simplification appropriate for family scale.
  - W3: `UserDefaults(suiteName:)!` force-unwrap in test helper (test target only). Accepted.

**Acceptance reviewer (first pass): PASS**
- All 10 acceptance criteria met.
- One noted deviation: `SettingsSectionView` hides the biometric toggle entirely when `isBiometricAvailable == false` (using `if isBiometricAvailable { ... }`) rather than showing it as `.disabled` with a note. Equivalent UX outcome at family scale.

**Stuck-detector log:** Attempt 1: Both reviewers PASS (warnings only, no hard blocks). No attempt 2 needed.

---

## Deviations from Gate 1 Spec

1. **Toggle hidden vs disabled**: `SettingsSectionView` hides the biometric Toggle when biometrics are unavailable instead of showing it disabled. Gate 1 spec said `.disabled(!isBiometricAvailable)`. Equivalent from a user perspective — the toggle cannot be interacted with either way.
2. **`nonisolated static let` on keys**: Implementer initially wrote `nonisolated(unsafe) static let` on `String` constants — corrected post-review to plain `nonisolated static let` (the `unsafe` is unnecessary and misleading for immutable `Sendable` values).
3. **Preference sync via shared UserDefaults**: ProfileView owns its own `BiometricUnlockPreference` instance rather than sharing the app-level one. Accepted because both read UserDefaults live (no caching) and the app-level instance is re-assigned in `onComplete`.

---

## Not Done or Partial

None. All Story 3 acceptance criteria are met:
- `BiometricUnlockPreference` defined with two UserDefaults-backed flags, tested in isolation.
- `InactivityLockController.preference` property added.
- `LockView` biometric button gated on both biometric availability and preference flag.
- Profile toggle present for biometric unlock (hidden, not disabled, when unavailable — accepted deviation).
- `BiometricSetupView.onComplete` callback added; called on both "Enable" and "Not Now" paths.
- First-login offer logic wired in `ChristmasTrackerApp`.
- 203 tests passing, verify.sh green.
