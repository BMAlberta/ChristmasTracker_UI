# iOS Handoff — I2b-1: Inactivity Lock (Local Half)
**Date:** 2026-11-04
**From:** iOS agent (Orchestrator)
**To:** Brian

---

## Contract Issues Found

None. This package makes no networking, API model, or token-persistence changes. Contract status remains PRE-CONFORMANCE.

---

## What Changed

**New production files:**

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LockPolicy.swift` — `LockTimeoutProviding` protocol and `LockPolicy` struct; reads `INACTIVITY_LOCK_MINUTES` from Info.plist (xcconfig-sourced) with a `UserDefaults` override key `inactivityLockMinutesOverride`; clamped to 1–30.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityTracker.swift` — Pure value type; monotonic `ContinuousClock.Instant` only; `recordActivity`, `enteredBackground`, `becameActive`, `deadline`, `isTimedOut`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift` — `@MainActor @Observable` controller; `SessionClearable` conformance; foreground idle timer via `Task.sleep(until:clock:)`; `preference: (any BiometricUnlockPreferring)?` property.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift` — `BiometricResult` enum (7 cases) + `BiometricAuthenticating` protocol + `LocalAuthenticationService` (LAContext-backed, `@Instrumented`).
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift` — Protocol fake in production module (per testing-conventions).
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricUnlockPreference.swift` — `BiometricUnlockPreferring` protocol and `BiometricUnlockPreference` struct; two `UserDefaults`-backed flags (`biometricUnlock.enabled`, `biometricUnlock.offerShown`).
- `ChristmasTracker/ChristmasTracker/App/AppWindowLevels.swift` — `UIWindow.Level` extensions: `.inactivityLockLevel = .alert + 0.5`, `.privacyCoverLevel = .alert + 1`.
- `ChristmasTracker/ChristmasTracker/App/InactivityTouchRecognizer.swift` — Passive `UIGestureRecognizer`; `cancelsTouchesInView = false`; always fails; wired to `lockController.recordActivity()` on each scene's main window.
- `ChristmasTracker/ChristmasTracker/App/LockWindowAdapter.swift` — UIKit adapter for the lock window; `showLock`/`hideLock`; window at `.inactivityLockLevel`.
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — SwiftUI lock screen; DesignSystem tokens only; biometric button (gated on availability + preference); "Use password" always shown; 44pt targets; VoiceOver.

**New test files** (79 new tests; 124 baseline → 203 total):

- `LockPolicyTests.swift` (12), `InactivityTrackerTests.swift` (7), `InactivityLockControllerTests.swift` (15) — Story 1
- `BiometricAuthenticatingTests.swift` (18), `InactivityLockIntegrationTests.swift` (10), `SessionTeardownTests.swift` (+1 delta) — Story 2
- `BiometricUnlockPreferenceTests.swift` (12), `LockControllerPreferenceTests.swift` (5) — Story 3

**Modified production files:**

- `SessionClearable.swift` — `TeardownReason.lockFallback` case; `makeProductionClearables` gains `lockController:` as 6th parameter.
- `ChristmasTrackerApp.swift` — `lockController`, `LockCoordinator` (per-scene lock windows + touch recognizers), scene notification wiring, auth-state-driven start/stop, `BiometricSetupView` first-login offer.
- `BiometricSetupView.swift` — `onComplete: ((Bool) -> Void)?` callback added.
- `ProfileView.swift` — `SettingsSectionView` gains `preference: Binding<BiometricUnlockPreference>`; TODO biometric row replaced with Toggle.
- `Config.xcconfig`, `Config-Debug.xcconfig`, `Config-QA.xcconfig` — `INACTIVITY_LOCK_MINUTES = 10`.
- `Info.plist` — `INACTIVITY_LOCK_MINUTES` key.
- `scripts/check-config.sh` — adds `INACTIVITY_LOCK_MINUTES = 10` check for all three configurations.

---

## Commit Hashes (master..HEAD)

```
552ba0e I2b-1: fix nonisolated static let keys; add Story 3 report
28be971 I2b-1: add biometric unlock preference and profile toggle
46de473 I2b-1: add Story 2 report
7c13445 I2b-1: attach touch recognizer, fix token violations, add internal modifiers
a11a210 I2b-1: add lock screen, biometric gate, and wiring
eb68701 I2b-1: add Story 1 report
61d1778 I2b-1: add lock policy, inactivity tracker, and controller
001c575 I2b-1: add epic brief and inventory
```

## git diff --stat master...HEAD

```
26 files changed, 2360 insertions(+), 19 deletions(-)
```

---

## What the API Team Must Do

Nothing. This package has no API dependencies.

---

## Open Risks and Manual Verification Needed

1. **Lock screen appearance — simulator/device not verified** — `LockView`, `LockWindowAdapter`, and the window-level ordering (lock below privacy cover, above app content) have not been verified on a simulator or device. Brian must run the app, trigger the lock (set `-inactivityLockMinutesOverride 1` as a launch argument), and verify: (a) lock screen appears over sheets, (b) privacy cover still appears over the lock screen in the app switcher, (c) biometric unlock works, (d) "Use password" triggers login screen.

2. **Face ID flash** — When the system Face ID prompt appears during biometric unlock, the scene may briefly become inactive, triggering the privacy cover behind the Face ID dialog. If visually disruptive, add a suppression flag to `PrivacyCoverCoordinator` while `lockController.lockState == .locked`.

3. **Touch recognizer on additional windows** — `InactivityTouchRecognizer` is added only to the `.normal`-level window, not to sheets or any secondary window. Touches on a sheet open over the main content reset the timer correctly (sheets are presented in the main window's hierarchy). Touches on the lock window itself do NOT reset the timer — this is intentional.

4. **BiometricUnlockPreference sync** — `ProfileView` holds its own `BiometricUnlockPreference()` instance (backed by `.standard` UserDefaults). The lock screen's `controller.preference` is a separate instance pointing to the same UserDefaults keys; since all reads are live (no caching), the toggle change is reflected on the lock screen's next render. However, `controller.preference` is not `@Observable`, so the lock screen will not reactively hide the biometric button while remaining on screen. The button will reflect the current preference correctly when the lock screen first appears.

5. **BiometricSetupView first-login offer** — Presented once after the first successful login if `isBiometricAvailable`. The existing `BiometricSetupView` Keychain-storage behavior is preserved; only the `onComplete` callback was added. If the user enables biometrics in this flow, `biometricUnlockEnabled = true` is set in UserDefaults — the lock screen will offer biometric unlock on the next lock event.

6. **I2b-2 prerequisite** — This package (I2b-1) is the local half. I2b-2 (auth flows, token persistence, Keychain redesign, registration) requires the CONFORMANT contract. The old SessionManager ping and session-duration code is untouched and will be cleaned up in I1 per decisions.

---

## Section 9 of PROGRAM.md (one line)

I2b-1 (inactivity lock, local half): `InactivityLockController` with monotonic clock tracking, `LockView` in a UIWindow at `.alert+0.5`, biometric gate via `LocalAuthenticationService`, preference in UserDefaults, touch recognizer per scene; 203 tests (79 new); no networking; simulator/device verification pending.
