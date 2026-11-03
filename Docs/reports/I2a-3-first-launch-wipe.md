# I2a Story 3 — First-Launch Wipe of 4.4 Legacy Data

Branch: `feat/i2a-session-hygiene`

## What changed

### Files added
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FirstLaunchWipe.swift`
  — `KeychainWiping` protocol, `LiveKeychainWiper` struct, `FirstLaunchWipeError` enum,
    and `FirstLaunchWipe` struct with `performIfNeeded()`.
- `ChristmasTrackerTests/Features/Authentication/FirstLaunchWipeTests.swift` — 9 tests.

### Files modified
- `ChristmasTrackerApp.swift` — Added `FirstLaunchWipe().performIfNeeded()` as the first
  statement in `init()`, before `AppDependencies.make()`.

## verify.sh (verbatim)

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 64 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793721015.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 55 tests (Stories 1 + 2).
New tests: 9 (`FirstLaunchWipeTests.swift`).
New total: **64 tests**.

Test names:
1. `savedEmailRemovedAfterWipe`
2. `genericPasswordsDeletedAfterWipe`
3. `internetPasswordsDeletedAfterWipe`
4. `markerWrittenAfterSuccessfulWipe`
5. `secondLaunchIsNoOp`
6. `markerNotWrittenWhenKeychainWipeFails`
7. `retryAfterFailureCompletes`
8. `deviceLevelDefaultsSurviveWipe`
9. `freshInstallNoOpWithMarker`

## Gate 2 results

**Convention reviewer:** APPROVED — 0 blockers, 2 warnings.
- Warning 1: `deleteAllGenericPasswords()` and `deleteAllInternetPasswords()` lack
  `@Instrumented`; these are `throws`-only (not `async`) functions in the service layer.
  Approved deviation: macro not in codebase, deferred to I6a; documented in the Gate 1
  spec (`Docs/epics/I2a-session-and-cache-hygiene.md`, committed b77c4e6).
- Warning 2: `UserDefaults(suiteName:)!` force-unwrap in the test helper
  (`FirstLaunchWipeTests.swift:99`). Permitted in test files per coding standards.

**Acceptance reviewer:** APPROVED — all 6 ACs met.
- AC1: First-launch wipe removes `"savedEmail"`, calls both Keychain delete methods, writes marker. Tests 1–4, 9.
- AC2: Subsequent launch is no-op; no UserDefaults key touched. Test 5.
- AC3: Failure does not write marker; wipe retries next launch. Tests 6, 7 (precondition half).
- AC4: Non-wipe defaults untouched. Test 8.
- AC5: `FirstLaunchWipe().performIfNeeded()` is first statement in `ChristmasTrackerApp.init()` (line 52). Structural.
- AC6: 64 tests passed, 0 failed. Verified by `scripts/verify.sh`.

## Stuck-detector log

No stuck-detector trigger. Implementer completed in one pass.

## Deviations from Gate 1 spec

1. **Swift 6 concurrency adjustments** — The spec's code block used plain `let` for stored
   properties, but `UserDefaults` and `FileManager` are `@MainActor` in the iOS 26 SDK.
   Implementer correctly applied `nonisolated(unsafe)` on both stored properties (with an
   explaining comment) and declared `init()` and `performIfNeeded()` as `nonisolated` so
   tests (which run in a nonisolated Swift Testing context) can call them synchronously.
   `static let markerVersion` and `static let markerKey` are `static nonisolated let` for
   the same reason. These are correct Swift 6 additions, not behavioral changes.
2. `@Instrumented` absent — approved deviation (I6a; macro not in codebase).
3. `fileManager` parameter accepted in `init()` for future extensibility but unused in
   the current body — consistent with the epic brief noting no on-disk caches were found
   in the 4.4 audit.

## Not done or partial

None.

---

## Addendum: device fingerprint and education flags (added by R3)

### Device fingerprint (inventory item 9)

`FirstLaunchWipe` performs a class-wide `kSecClassGenericPassword` delete via `SecItemDelete`. This also deletes the device fingerprint UUID stored by `DeviceFingerprintService` at key `com.christmastracker.deviceFingerprintUUID` (inventory item 9, classified device-level). The device fingerprint is regenerated on next use — `DeviceFingerprintService.getFingerprint()` creates a new UUID and stores it if the key is absent.

No test covers this specific behavior. `FirstLaunchWipeTests` uses the injected `MockKeychainWiper` (a fake that conforms to `KeychainWiping` without touching the real Keychain), so the device fingerprint is not exercised by any unit test. A device-level integration test would require a real Keychain and a physical device or simulator; it is noted as pending until a distribution certificate exists.

### 4.4 education flags

The 4.4 education flags (`@AppStorage` keys with server-provided runtime names — `EducationViewModel.educationId` values) are intentionally left in place. The keys are not known at wipe time (they are runtime values), and the flags are low-risk stale data (the education feature does not exist in v2). They will be cleared if the user reinstalls the app (reinstall re-runs the wipe, which does a class-wide Keychain delete and removes `savedEmail`, but UserDefaults keys with unknown names are not removed). This is documented as an accepted tradeoff in the epic brief.
