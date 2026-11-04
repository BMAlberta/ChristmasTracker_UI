# I2b-1 R5 Report: Enable Biometrics Without a Stored Token and Keep Availability Live

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R5 — Biometric enablement model and live availability refresh
**Branch:** feat/i2b1-inactivity-lock
**Commit:** f08338a — I2b-1: enable biometrics without a stored token and keep availability live

---

## Defects Fixed

- **B1** — `BiometricSetupView.enableBiometric()` read Keychain silently; failed if no token stored. Fixed by introducing `BiometricEnablementModel` that calls `authenticator.authenticate(reason:)` directly and sets preference on success — no Keychain read.
- **B2** — `AuthenticationService.isBiometricAvailable` and `biometricType` were computed once at launch via `checkBiometricAvailability()`. Fixed by injecting `BiometricAuthenticating` and introducing `refreshBiometricAvailability()`, called from `init()` and from `handleAuthSuccess`.

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricEnablementModel.swift` — `@MainActor @Observable` class; `EnablementState` enum (idle/inProgress/succeeded/failed(String)); `enable() async` calls `authenticator.authenticate(reason:)` and updates `preference.biometricUnlockEnabled`; manual SentrySDK span (not `@Instrumented` — actor-isolated method); `reset()` returns state to `.idle`.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricEnablementModelTests.swift` — 10 tests covering all `EnablementState` transitions, preference write, and reset.

## Files Changed

- `AuthenticationService.swift` — Added `private let biometricAuthenticator: any BiometricAuthenticating`; 3-param init with default `LocalAuthenticationService()`; `refreshBiometricAvailability()` replaces `checkBiometricAvailability()` at init and `handleAuthSuccess`.
- `FakeBiometricAuthenticator.swift` — Added `var stubbedBiometryTypeName: String = "Face ID"`; `biometryTypeName` now returns `stubbedBiometryTypeName`.
- `BiometricSetupView.swift` — Accepts `var model: BiometricEnablementModel`; `enableBiometric()` calls `await model.enable()`; `onComplete(true)` only on `.succeeded`.
- `ChristmasTrackerApp.swift` — Shared `LocalAuthenticationService` instance passed to both `LockCoordinator` and `AuthenticationService`; `BiometricSetupView` sheet passes `BiometricEnablementModel`.
- `AuthenticationServiceTests.swift` — 4 new tests (R5 group).
- `BiometricAuthenticatingTests.swift` — 1 new test for `stubbedBiometryTypeName`.

---

## verify.sh Output (post-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 243 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Results

**Convention reviewer:** PASS (all 13 hard blocks)
- Warning raised: `@Instrumented` macro cannot be applied to `@MainActor`-isolated `enable()`. Fixed before review by using manual `SentrySDK.startTransaction` with explaining comment per coding-standards.md precedent.

**Acceptance reviewer:** PASS

---

## Deviations

- `@Instrumented` not applied to `BiometricEnablementModel.enable()` because it is `@MainActor`-isolated. Manual SentrySDK span used per coding-standards.md convention for actor-isolated methods.

---

## Not Done or Partial

None. All R5 acceptance criteria met.
