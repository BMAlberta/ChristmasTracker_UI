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

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LockPolicy.swift` — `LockTimeoutProviding` protocol and `LockPolicy` struct; reads `INACTIVITY_LOCK_MINUTES` from Info.plist (xcconfig-sourced) with a `UserDefaults` override key `inactivityLockMinutesOverride`; clamped to 1–30; `parse(_:)` trims whitespace before `Int()`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityTracker.swift` — Pure value type; monotonic `ContinuousClock.Instant` only; `recordActivity`, `becameActive` (pure read, no side effects), `deadline`, `isTimedOut`. Background entry tracking removed (R1 rework).
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift` — `@MainActor @Observable` controller; `SessionClearable` conformance; foreground idle timer via injected `sleepUntil` closure (default: `Task.sleep(until:clock:)`); `clockNow` injection seam; `private(set) var isRunning`; `var lockPresenter: (any InactivityLockPresenting)?`; `@discardableResult usePasswordTeardown() -> Task<Void, Never>`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift` — `BiometricResult` enum (7 cases) + `BiometricAuthenticating` protocol (includes `biometryTypeName: String`) + `LocalAuthenticationService` (LAContext-backed, `@Instrumented`).
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift` — Protocol fake in production module (per testing-conventions); `biometryTypeName` returns `"Face ID"`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricUnlockPreference.swift` — `BiometricUnlockPreferring` protocol and `BiometricUnlockPreference` struct; two `UserDefaults`-backed flags.
- `ChristmasTracker/ChristmasTracker/App/AppWindowLevels.swift` — `UIWindow.Level` extensions: `.inactivityLockLevel = .alert + 0.5`, `.privacyCoverLevel = .alert + 1`.
- `ChristmasTracker/ChristmasTracker/App/InactivityTouchRecognizer.swift` — Passive `UIGestureRecognizer`; wired to `lockController.recordActivity()` on each scene's main window.
- `ChristmasTracker/ChristmasTracker/App/LockWindowAdapter.swift` — UIKit adapter for the lock window; `showLock`/`hideLock`; window at `.inactivityLockLevel`.
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — SwiftUI lock screen; DesignSystem tokens only; biometric button (gated on availability + preference); `BiometricOutcome` enum; `biometricOutcome(for:biometryTypeName:)` and `showBiometricButton(isAvailable:preferenceEnabled:isPasswordOnly:)` pure functions; `.failed` keeps biometric button visible with "try again" hint (R2 rework); `@State var biometricHint`.
- `ChristmasTracker/ChristmasTracker/App/InactivityLockPresenting.swift` — `internal protocol InactivityLockPresenting: AnyObject` with `presentLock()` / `dismissLock()` (R2 rework).

**New test files** (104 new tests; 124 baseline → 228 total):

- `LockPolicyTests.swift` (13), `InactivityTrackerTests.swift` (6), `InactivityLockControllerTests.swift` (21) — Stories 1 + R1 rework
- `BiometricAuthenticatingTests.swift` (18), `InactivityLockIntegrationTests.swift` (10), `SessionTeardownTests.swift` (+1 delta) — Story 2
- `BiometricUnlockPreferenceTests.swift` (12), `LockControllerPreferenceTests.swift` (5) — Story 3
- `InactivityLockPresenterTests.swift` (5), `BiometricOutcomeTests.swift` (12) — R2 rework
- `FakeClock.swift`, `FakeSleeper.swift` — R1 test infrastructure (not @Test files)

**Modified production files:**

- `SessionClearable.swift` — `TeardownReason.lockFallback` case; `makeProductionClearables` gains `lockController:` as 6th parameter.
- `ChristmasTrackerApp.swift` — `lockController`, `LockCoordinator` (per-scene lock windows + touch recognizers); `LockCoordinator` conforms to `InactivityLockPresenting`; `lockController.lockPresenter = lockCoordinator` wiring; `.onChange(of: lockController.lockState)` removed (R2 rework); `BiometricSetupView` first-login offer.
- `BiometricSetupView.swift` — `onComplete: ((Bool) -> Void)?` callback added.
- `ProfileView.swift` — `SettingsSectionView` gains `preference: Binding<BiometricUnlockPreference>`; Toggle replaces TODO biometric row.
- `Config.xcconfig`, `Config-Debug.xcconfig`, `Config-QA.xcconfig` — `INACTIVITY_LOCK_MINUTES = 10`.
- `Info.plist` — `INACTIVITY_LOCK_MINUTES` key.
- `scripts/check-config.sh` — adds `INACTIVITY_LOCK_MINUTES = 10` check.

---

## Commit Hashes (master..HEAD)

```
518809b I2b-1: remove vacuous tests and fix test hygiene
611ded0 I2b-1: present the lock synchronously and keep Try Again after a failed biometric attempt
a2c3eaf I2b-1: fix unlock relock loop, gate controller on running, measure inactivity from last activity
efdbe19 I2b-1: add rework Gate 1 spec
1c1d15e I2b-1: commit previously-untracked story 2-3 test files
1824b15 I2b-1: add package handoff note
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
40 files changed, 4582 insertions(+), 22 deletions(-)
```

---

## What the API Team Must Do

Nothing. This package has no API dependencies.

---

## Open Risks and Manual Verification Needed

1. **Lock screen appearance — simulator/device not verified** — Brian must run the app, trigger the lock (set `-inactivityLockMinutesOverride 1` as a launch argument), and verify: (a) lock screen appears over sheets, (b) privacy cover still appears over the lock screen in the app switcher, (c) biometric unlock works, (d) `.failed` biometric shows "try again" hint with button still visible, (e) "Use password" triggers login screen.

2. **Synchronous presentation gap — visual verification** — The R2 fix routes `presentLock()` synchronously through `InactivityLockPresenting` from within scene notification handlers. Visually verify there is no visible flash of app content between privacy cover drop and lock appearance on return from background.

3. **Face ID flash** — When the system Face ID prompt appears, the scene may briefly become inactive, triggering the privacy cover behind the Face ID dialog. If visually disruptive, add a suppression flag to `PrivacyCoverCoordinator` while `lockController.lockState == .locked`.

4. **Touch recognizer on additional windows** — `InactivityTouchRecognizer` is added only to the `.normal`-level window. Touches on sheets reset the timer correctly (sheets are in the main window hierarchy). Touches on the lock window do NOT reset the timer — intentional.

5. **BiometricUnlockPreference sync** — `ProfileView` holds its own `BiometricUnlockPreference()` instance (backed by `.standard` UserDefaults). Writes are reflected on the lock screen's next read; `controller.preference` is not `@Observable` so the biometric button won't reactively hide while the lock screen is on-screen.

6. **`FakeBiometricAuthenticator.biometryTypeName`** — Hardcoded to `"Face ID"` regardless of `stubbedBiometryType`. Previews using `.touchID` will show "Face ID" in the hint text. No production impact; consider adding `stubbedBiometryTypeName` in a future story.

7. **I2b-2 prerequisite** — This package (I2b-1) is the local half. I2b-2 (auth flows, token persistence, Keychain redesign, registration) requires the CONFORMANT contract. The old SessionManager ping and session-duration code is untouched and will be cleaned up in I1 per decisions.

---

## Section 9 of PROGRAM.md (one line)

I2b-1 (inactivity lock, local half): `InactivityLockController` with monotonic clock tracking, cumulative inactivity measurement, `InactivityLockPresenting` for synchronous lock presentation, `LockView` in a UIWindow at `.alert+0.5`, biometric gate via `LocalAuthenticationService` (`.failed` keeps button with retry hint), preference in UserDefaults, touch recognizer per scene; 228 tests (104 new); no networking; simulator/device verification pending.
