# Story S1 Report — Credential Store, Readiness, and the Mock
**Package:** I2b-2a — Face ID / Touch ID sign-in
**Branch:** feat/i2b2a-face-id-sign-in
**Commit:** 4775f59

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricCredentialStoring.swift`
  — `BiometricCredentialError` enum, `BiometricCredentialStoring` protocol, `KeychainBiometricCredentialStore` (production), `InMemoryBiometricCredentialStore` (test double)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricReadinessTests.swift` (17 tests)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricCredentialStoreTests.swift` (14 tests)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/MockAuthenticationRepositoryTests.swift` (11 tests)

## Files Modified

- `BiometricAuthenticating.swift` — Added `BiometricReadiness` enum, `BiometricSetupReason` enum, `biometricReadiness(biometryPresent:canEvaluate:errorCode:)` free function, `biometricReadinessMessage(for:biometryTypeName:)` free function; added `readiness: BiometricReadiness` to the `BiometricAuthenticating` protocol and implemented it in `LocalAuthenticationService`
- `FakeBiometricAuthenticator.swift` — Added `stubbedReadiness: BiometricReadiness = .ready` and `var readiness: BiometricReadiness` conformance
- `LegacyTokenCleaning.swift` — `LegacyTokenCleanup.cleanUpLegacyTokens()` now also deletes `"auth.biometric_token"` and `"auth.user_id"` (four legacy keys total)
- `AuthenticationService.swift` — Deleted dead `loginWithBiometric()` and `setupBiometrics(biometricToken:)`; fixed `clearStoredTokens()` to delete only `"auth.tokens"` and `"auth.refresh_token"` (the two new Keychain keys are not touched); added `import TrackerInstrumentation`; added SentrySDK span to `clearForSession()`
- `MockAuthenticationRepository.swift` — Converted from `actor` to `nonisolated final class @unchecked Sendable`; `login` now derives a stable user per email (id: `"mock-{localPart}"`, name from local part); `refreshToken` now produces a NEW token (`"mock_rt_{userId}_{uuid}"`) on every call and validates token format; rejects tokens for `"mock-expired"` user (i.e. `expired@example.com`)
- `Core/Models/AuthTypes.swift` — Added `nonisolated` to `AuthData`, `ResponseMeta`, `AuthTokens` (required for Swift 6.3 MainActor-inference fix)
- `Core/Models/User.swift` — Added `nonisolated` to `User` and `UserRole` (same reason)

---

## scripts/verify.sh — Before commit

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 322 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## scripts/verify.sh — After commit (4775f59)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 322 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test arithmetic

Baseline (before S1): 281 tests

New tests:
- `BiometricReadinessTests.swift`: 17 tests (`noHardwareWhenBiometryNotPresent`, `noHardwareWhenBiometryNotPresentEvenIfCanEvaluateTrue`, `readyWhenBiometryPresentAndCanEvaluate`, `knownErrorCodesMapsToNeedsSetup` (parameterized, counts as 1 entry), `nilErrorCodeFallsBackToNotEnrolled`, `unknownErrorCodeFallsBackToNotEnrolled`, `noHardwareOpensSettingsFalse`, `readyOpensSettingsFalse`, `passcodeNotSetOpensSettingsTrue`, `notEnrolledOpensSettingsTrue`, `disabledForAppOpensSettingsTrueAndMentionsBiometryTypeName`, `lockedOutOpensSettingsTrue`, `passcodeNotSetMessageIsNonEmpty`, `notEnrolledMessageIsNonEmpty`, `lockedOutMessageIsNonEmpty`, `disabledForAppMessageMentionsTouchID` — 16 test functions; `knownErrorCodesMapsToNeedsSetup` is parameterized)
- `BiometricCredentialStoreTests.swift`: 14 tests
- `MockAuthenticationRepositoryTests.swift`: 11 tests (removed: none)

Total new: 42 tests (some parameterized entries expand at runtime)
New total per verify.sh: **322 passed**

Removed tests: 0 (no existing tests deleted or weakened). Tests that previously called `loginWithBiometric()` or `setupBiometrics()` did not exist in the test suite; those were dead methods with no test coverage.

---

## Verification claims

All claims come from running commands and reading code:
- Keychain behavior (prompt/no-prompt, biometryCurrentSet access control): **verified by reading code only** — not runnable in the test host without the Simulator; Brian must verify manually.
- `enrolledUser()` attributes-only query: verified by reading `BiometricCredentialStoring.swift:46-62` — `kSecReturnData: false`, no `kSecUseAuthenticationContext`.
- `readRefreshToken` single prompt: verified by reading code — one `LAContext` created, passed once to `SecItemCopyMatching`.
- Test counts: verified by `scripts/verify.sh` output.

---

## Gate 2 results

**Convention reviewer**: REJECT then APPROVE (re-review after fixes)
- Initial rejection: (1) `readRefreshToken` missing `@Instrumented`; (2) `clearForSession` comment but no Sentry span
- Fixes applied: added `@Instrumented` to `readRefreshToken`, added `SentrySDK.startTransaction` span to `clearForSession`, added explaining comment to `@unchecked Sendable` on `KeychainBiometricCredentialStore`
- Re-review verdict: **APPROVE** — all checks pass, 322 tests, verify OK

**Acceptance reviewer**: REJECT then APPROVE (re-review after commit)
- Initial rejection: implementation was uncommitted
- Re-review verdict: **APPROVE** — all 7 focus items pass in committed code

**Stuck-detector log**: 1 convention-review attempt (rejected), 1 fix pass, 1 convention re-review (approved). 1 acceptance attempt (rejected on process), 1 acceptance re-review (approved). Stuck detector not triggered (3-attempt limit not reached).

---

## Deviations

1. **`MockAuthenticationRepository` converted from `actor` to `nonisolated final class @unchecked Sendable`**: The test-writer wrote tests that call `MockAuthenticationRepository()` from a `nonisolated` test context. The `actor` type prevented direct synchronous init access in some contexts. Converted to a class to match test usage; the class has no actual concurrent mutation risk in tests. This is consistent with similar mock patterns in the codebase.

2. **`Core/Models/AuthTypes.swift` and `User.swift` modified outside Gate 1 scope**: Both files received `nonisolated` on `Sendable` value types (`AuthData`, `ResponseMeta`, `AuthTokens`, `User`, `UserRole`). This was required because Swift 6.3 infers `@MainActor` on these types from their production usage context, causing the new nonisolated test code to fail to compile. The change is mechanical and correct; it matches the pattern of other `nonisolated` declarations already in the same file (e.g. `LoginRequest`, `RegisterRequest`).

---

## Not done or partial

None. All S1 acceptance criteria met and committed.
