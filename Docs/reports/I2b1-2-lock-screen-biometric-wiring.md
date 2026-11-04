# I2b-1 Story 2 Report: Lock Screen, Biometric Gate, and Wiring

> **SUPERSEDED (partly)** — `LockView.attemptBiometricUnlock()` and `ChristmasTrackerApp` lock wiring were reworked in Story R2 (commit 611ded0). See `I2b1-5-presentation-and-biometric-mapping.md` for the authoritative description of those changes. `LockWindowAdapter`, `AppWindowLevels`, `InactivityTouchRecognizer`, and `BiometricAuthenticating` are unchanged.

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** 2 — Lock screen, biometric gate, activity capture, app wiring
**Branch:** feat/i2b1-inactivity-lock
**Commits:** a11a210 — I2b-1: add lock screen, biometric gate, and wiring; 7c13445 — I2b-1: attach touch recognizer, fix token violations, add internal modifiers

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift` — `BiometricResult` enum (7 cases), `BiometricAuthenticating` protocol, `LocalAuthenticationService` (LAContext-backed, `@Instrumented` on `authenticate(reason:)`, maps all LAError cases to BiometricResult values, never logs tokens or passwords).
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift` — Stubbable fake; lives in production module per testing-conventions.
- `ChristmasTracker/ChristmasTracker/App/AppWindowLevels.swift` — `internal extension UIWindow.Level` with `.privacyCoverLevel = .alert + 1` and `.inactivityLockLevel = .alert + 0.5`.
- `ChristmasTracker/ChristmasTracker/App/InactivityTouchRecognizer.swift` — `internal final class InactivityTouchRecognizer`; `cancelsTouchesInView = false`; always fails; simultaneous delegate returns `true`; `activityHandler` closure.
- `ChristmasTracker/ChristmasTracker/App/LockWindowAdapter.swift` — `internal final class LockWindowAdapter`; creates `UIWindow` at `.inactivityLockLevel`; `showLock`/`hideLock` APIs; never calls `makeKey`.
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — SwiftUI lock screen; DesignSystem tokens only; biometric button (shown when available, hidden after `lockedOut`/`failed`/`userFallback`); "Use password" always shown; `UIAccessibility.post(.screenChanged)` on appear; 44pt tap targets; 3 `#Preview` macros.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricAuthenticatingTests.swift` — 18 tests (protocol/fake behavior, BiometricResult mapping with controller).
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift` — 10 tests (makeProductionClearables registry count=6, clearForSession integration).

## Files Changed

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift` — `makeProductionClearables` gains `lockController: InactivityLockController` as 6th parameter; returned array has 6 elements.
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — `lockController` created in `init()` with `LockPolicy`; `LockCoordinator` (private inner reference type) manages per-scene lock windows and touch recognizers; scene notifications wire `sceneWillResignActive`/`sceneDidBecomeActive`; `.onChange(of:)` on `authService.isAuthenticated` drives `lockController.start()`/`stop()`; `.onChange(of:)` on `lockController.lockState` shows/hides lock windows; `attachTouchRecognizer(to:)` called on `UIScene.didActivateNotification` — adds recognizer to `.normal`-level window with `activityHandler → lockController.recordActivity()`.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift` — `productionClearableSetContainsExpectedClearables` updated: count 5→6, adds `lockController:` parameter, checks `clearables[5] is InactivityLockController`.

---

## verify.sh Output

**Post-rework commit:**
```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 186 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

| Stage | Total |
|---|---|
| Story 1 final | 158 |
| + BiometricAuthenticatingTests (18 tests) | 176 |
| + InactivityLockIntegrationTests (10 tests) | 186 |
| + SessionTeardownTests delta (0 net new) | 186 |
| **Final** | **186** |

---

## Gate 2 Results

**Convention reviewer (second pass): PASS**
- `@Instrumented` on `LocalAuthenticationService.authenticate(reason:)`: present.
- `import TrackerInstrumentation` in `BiometricAuthenticating.swift`: present.
- Explicit `internal` on `InactivityTouchRecognizer`, `LockWindowAdapter`, and `extension UIWindow.Level`: present (fixed in rework).
- DesignSystem tokens only in `LockView.swift`: raw `.system(size: 56)` replaced with `.appLargeTitle`; raw `12` corner radius replaced with `AppSpacing.md` via named constant (fixed in rework).
- No Combine, no GCD, no force unwraps, no `.pbxproj` edits: confirmed.
- Test coverage via protocol/fake pattern: `BiometricAuthenticatingTests.swift` and `InactivityLockIntegrationTests.swift` present and correct.

**Acceptance reviewer (second pass): PASS**
- All 12 acceptance criteria satisfied.
- Touch recognizer blocker resolved: `LockCoordinator.attachTouchRecognizer(to:)` called on `UIScene.didActivateNotification`; recognizer added to `.normal`-level window; `activityHandler` wired to `lockController.recordActivity()`.
- LockView biometric/password flow, `usePasswordTeardown()`, and `showPasswordOnly` state all verified.

**Stuck-detector log:**
- Attempt 1: Acceptance fail (touch recognizer never attached). Convention fail (raw font, raw corner radius, missing `internal` modifiers). Both fixed in targeted rework commit 7c13445.
- Attempt 2: Both reviewers PASS. No attempt 3 needed.

---

## Deviations from Prompt

1. **Corner radius uses `AppSpacing.md` via named `let`** rather than a dedicated `AppSpacing.cornerRadius` token (none exists). The named constant `private let buttonCornerRadius: CGFloat = AppSpacing.md` satisfies the no-raw-literal rule.
2. **`LockCoordinator` introduced** as a private inner reference type in `ChristmasTrackerApp.swift` to manage per-scene state (lock window adapters, touch recognizers). Gate 1 did not name this type; it is an implementation detail that keeps the wiring organized.
3. **`preference.biometricUnlockEnabled` gate on LockView deferred to Story 3** — the Story 2 Gate 1 spec references this parameter, but `BiometricUnlockPreference` is Story 3 scope. LockView gates on `isAvailable` alone in this story; Story 3 will add the preference parameter.

---

## Not Done or Partial

None. All Story 2 acceptance criteria are met:
- `BiometricAuthenticating` protocol and `BiometricResult` enum defined and tested via protocol/fake pattern.
- Lock window shown at `.inactivityLockLevel` (below privacy cover) via `LockWindowAdapter`.
- Touch activity captured via `InactivityTouchRecognizer` on the `.normal`-level window, wired to `lockController.recordActivity()`.
- `makeProductionClearables` accepts and returns `InactivityLockController` as 6th element.
- App wired: lock controller starts/stops with auth state; lock state shows/hides lock window per scene.
- The biometric unlock preference toggle (Story 3) is not yet implemented.
