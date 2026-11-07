# I2b-2d E4: version-check retry-after, and the handoff
Date: 2026-11-07. Branch: feat/i2b2d-carry-forward. Base: 50c9c19 (E3).
Pipeline: full (generated-client repository layer). Gate 1 spec: Docs/epics/I2b2d-carry-forward.md, "E4" and decision D3.

## What changed
`GeneratedClientAppVersionRepository.checkVersion()` (`Features/Version/GeneratedClientAppVersionRepository.swift`):
- **(a) Unwrapping the rate-limit error** (`:33-44`).
  - The call is wrapped in `do`/`catch let clientError as ClientError`.
  - When `underlyingError` is a `TrackerAPIError` matching `.rateLimited`, that error is rethrown directly. This is the error RateLimitMiddleware throws once its retries are exhausted.
  - Every other `ClientError` is rethrown unchanged. Non-`ClientError` errors pass through untouched, and there is no catch-all.
  - Every other output arm is byte-identical.
  - As a result, `VersionService.check()` now maps a 429 to `.backOff` (`VersionService.swift:30-33`). Before, it fell through to `.showMessage`.
  - `import OpenAPIRuntime` was added for `ClientError`, the same way `GeneratedClientAuthenticationRepository.swift` does it.
- **(b) The typed `.tooManyRequests` arm** (`:70-74`).
  - It uses a new `private nonisolated func retryAfterSeconds(from:)` (`:93-109`). That function reads `retryAfter` from the generated free-form `error.details` (`OpenAPIObjectContainer.value`).
  - An `Int` or a `Double` is used as-is. A `Bool` is rejected explicitly, and anything else (no details, no key, a string) falls back to 1, the package default (`TrackerAPIError.swift:83`, `RateLimitMiddleware.swift:69`).
  - No cap is applied in this arm.
  - The `TimeInterval(err.error.code)` mapping is removed.
- `checkVersion` keeps `@Instrumented`. No new async or throws function was added.
- The handoff `Docs/handoffs/2026-11-07-ios-to-brian-i2b2d.md` was written per CLAUDE.md. It records the D3(e) cap, the D1 order change, the carried-forward items, and the PROGRAM.md line.

## Files
- **Changed (production):** `ChristmasTracker/ChristmasTracker/Features/Version/GeneratedClientAppVersionRepository.swift`
- **Added:**
  - `ChristmasTracker/ChristmasTrackerTests/Features/Version/VersionCheckRetryAfterTests.swift`
  - `Docs/handoffs/2026-11-07-ios-to-brian-i2b2d.md`
  - this report
- **Changed (docs):** `Docs/epics/I2b2d-carry-forward.md`, for the E4 Gate 1 spec
- **Unchanged:** `VersionCheckRepositoryTests.swift` and `VersionCheckTests.swift`. Their existing 429 test, `tooManyRequestsExhaustedThrowsRateLimited`, accepts either a wrapped or an unwrapped error, so it still passes.
- **Deleted:** none.

## Test arithmetic
- App: 667 + 10 new - 0 = **677**.
- Package: 191 + 0 = **191**.
- None of the new tests are parameterized.
- The new tests are in suite `VersionCheckRetryAfterTests` ("VersionCheck retry-after"):

| Item | Test | Expected | Waits checked |
|---|---|---|---|
| 1 | `retryAfterHeaderSevenThrowsRateLimitedSevenDirectly` | 7 | [7, 7] |
| 1 | `bodyRetryAfterTwelveIsCappedAtTen` | 10 (cap documented) | [10, 10] |
| 1 | `neitherHeaderNorDetailsGivesPackageDefault` | 1 | [1, 1] |
| 2 | `typedArmReadsDetailsRetryAfter` | 12, not 8001 | |
| 2 | `typedArmWithoutDetailsGivesPackageDefault` | 1 | |
| 2 | `typedArmContractExampleIsNotCapped` | 900 | |
| 2 | `typedArmAcceptsFloatingPointRetryAfter` | 2.5 | |
| 2 | `typedArmNonNumberRetryAfterGivesPackageDefault` | "12" gives 1 | |
| 3 | `factoryBuiltRetryAfterZeroThrowsRateLimitedDirectly` | 0 | |
| 4 | `versionServiceBacksOffOnRateLimit` | `.backOff`, `lastPolicy` nil | |

- How the tests are built:
  - Item 1 builds a generated `Client` with the real `RateLimitMiddleware(sleeper: RecordingSleeper)`. The fake sleeper records each wait and returns at once.
  - Item 2 uses a generated `Client` with no middleware.
  - Item 3 and item 4 use `TrackerClientFactory.make` with `Retry-After: 0`, so the real `DefaultSleeper` waits zero seconds.
  - There are no real sleeps or yields anywhere.
- Reconciliation:
  - The acceptance reviewer ran the suite alone and got 10 passed.
  - The full run reports 677.
  - The red state, before the implementation, was 0 of 10 passing when the suite ran alone. The failures were a wrapped `ClientError` (items 1 and 3), 8001 (item 2) and `.showMessage` (item 4).

## Verification
All of the following came from running commands; the raw output is quoted.

### Before E4 (= after the E3 commit 50c9c19)
`scripts/verify.sh`:
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 667 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1794072548.xcresult ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.012 seconds.
=== verify: TrackerAPI import audit ===
check-package-imports: OK
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`:
```
Build complete! (4.68s)
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
􁁛  Test run with 191 tests in 13 suites passed after 0.013 seconds.
```

### Before the E4 commit
`scripts/verify.sh`:
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1794073379.xcresult ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.014 seconds.
=== verify: TrackerAPI import audit ===
check-package-imports: OK
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`:
```
Build complete! (4.69s)
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
􁁛  Test run with 191 tests in 13 suites passed after 0.013 seconds.
```

### After the E4 commit
This is the last commit of the package, so no later report exists to hold these runs. Both runs, and the final `git diff --stat master...HEAD`, are pasted in the Orchestrator's package-end summary to Brian.

### Suspected-flaky test, outside this story
- `InactivityLockControllerTests/foregroundIdleFiresTimerAtDeadline()` failed once in the test-writer's full run during the red phase: "Timer released at the deadline must lock the controller". The run that included the 10 expected failures had 11 failures in total.
- It passed when the Orchestrator ran it alone with `scripts/test.sh "ChristmasTrackerTests/InactivityLockControllerTests/foregroundIdleFiresTimerAtDeadline()"`, which gave `1 passed, 0 failed`.
- It has passed in every full run since: the implementer's run, the acceptance reviewer's run, and the verify above.
- The suite synchronizes with `Task.yield()` (inventory 4), and the lock is out of scope for this package, so it is carried in the handoff.

## Gate 2
These verdicts were written after the reviews, which ran one after the other.

**Convention reviewer: APPROVE.** No hard blocks.
- Confirmed:
  - `@Instrumented` is kept (`:23-24`), and the helper is synchronous.
  - No Combine, DispatchQueue, force unwraps, `as!` or `try!`.
  - No sleeps or yields.
  - Nothing is logged.
  - Rule 11: the helper reads the generated `DetailsPayload` container that the runtime decoder has already filled. There is no hand-written model, no `JSONDecoder` or `JSONSerialization`, and no raw bytes, so this is not hand parsing.
  - The scope is correct.
- Warnings, not fixed:
  - **W1:** the `checkVersion()` body is 50 lines of code. It was 41 at HEAD, already over the warning limit of 40, and is under the error limit of 60.
  - **W2:** nine test lines are 121 characters long.
  - **W3:** the test imports are not sorted. This matches the sibling file.

**Acceptance reviewer: APPROVE.** Focus item (5): the 429 mapping uses the Retry-After header or `error.details.retryAfter`, and never the error code.
- From reading the code:
  - On the middleware path, the value comes from RateLimitMiddleware: body details first, then the header, then 1.0 (`RateLimitMiddleware.swift:67-69`), with a cap of 10 (`:10, :70`). It is passed through unchanged at `GeneratedClientAppVersionRepository.swift:40-42`.
  - The typed arm uses `retryAfterSeconds(from: err.error.details)` (`:98-109`). `TimeInterval(err.error.code)` is gone.
  - When neither value is present, the package default of 1 is used.
- Every D3(c) value is tested exactly. Source: reading the tests at `VersionCheckRetryAfterTests.swift:65-200`, and running them (10 passed alone, 677 in the full run).
- D3(a), from reading code and checking against `VersionService.swift:26-41`:
  - Only the rate-limited `ClientError` is unwrapped. Every other `ClientError` is rethrown unchanged, and there is no catch-all.
  - The categories for transport failures, 426, 400, 500 and 418 are unchanged.
- Only generated types are used, and the contract matches: the checkAppVersion 429 is `$ref RateLimitError`, and `details` is `additionalProperties: true` (checked with jq).
- Edge cases:
  - Covered by tests: a string, a float, and 900 uncapped.
  - There is a Bool guard, but no test for it.
  - A negative or huge value is passed through uncapped in the typed arm, as Gate 1 asks. VersionService reads only the case, not the seconds.
  - Retry-then-200 is covered by the package test `RateLimitMiddlewareTests.swift:48`.
- (6) Nothing is logged.
- (7) Counts: app 667 → 677, package 191 → 191 (from running the tests).
- (8) Nothing changed under contract/, .claude/, any .pbxproj, the synced Docs, or LocalPackages/TrackerAPI.

**Rejections and re-reviews:** none.

**Stuck-detector log:**
- **Attempt 1:** the build failed. The errors were `cannot find type 'ClientError' in scope` and `property 'value' is not available due to missing import of defining module 'OpenAPIRuntime'`.
- **Attempt 2** (a different signature, adding `import OpenAPIRuntime`): `** BUILD SUCCEEDED **`, the suite passed 10 of 10, and verify was OK at 677.
- No suspected-flaky test arose in this story. The lock test is listed above.

## Deviations, real bugs, out of scope
- **Deviation from the prompt:** three things the brief asked for could not be done through the factory-built client, for the reasons below. Brian chose the "fake sleeper" option (D3):
  - "429 with Retry-After 7 gives 7" through the real factory would sleep 14 real seconds.
  - "details 12 gives 12" always comes out as 10, because of the middleware cap.
  - The typed arm can't be reached through the factory.
- **Real bugs fixed:**
  - The version-check 429 used the error code (8001) as the retry-after.
  - A 429 never reached `.backOff`, because the error was still wrapped in `ClientError`.
- **Found, not fixed (in the handoff):**
  - **Possible crash in the package.** RateLimitMiddleware does not clamp a negative or NaN `Retry-After` or `retryAfter` (`RateLimitMiddleware.swift:39, 70`). `DefaultSleeper` (`:88`) then does `UInt64(seconds * 1e9)`, which traps. A package fix is barred by D3(d).
  - The 10-second cap (D3(e)).
- **Contract issues:** none.

## Not done or partial
- The post-commit verify, the package run, and the final `git diff --stat master...HEAD` for E4 are not in this report. They are in the package-end summary to Brian (see Verification).
- There is no test for a Bool `retryAfter`, and no test in this story for a 429 followed by a successful retry. The package covers the second case.
- The size and style warnings W1–W3 are not fixed.
- No manual check was done. The version-check 429 can be exercised against the local backend's rate limiter. That step is not in the I2b-2c real-mode list and is left to Brian.
