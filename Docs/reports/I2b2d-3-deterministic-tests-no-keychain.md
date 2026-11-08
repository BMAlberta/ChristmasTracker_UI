# I2b-2d E3: make logout tests deterministic and keep unit tests off the real Keychain
Date: 2026-11-07. Branch: feat/i2b2d-carry-forward. Base: 427bf51 (E2).
Pipeline: full (session, Keychain). Gate 1 spec: Docs/epics/I2b2d-carry-forward.md, "E3" and decision D2.

## What changed
- **Deterministic logout test.**
  - `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` (`:489`) keeps its name and display string. Its `for _ in 0..<10 { await Task.yield() }` is gone.
  - The file's `SuspendingLogoutRepository` (`:203-261`) now signals when `logout()` is entered, then suspends until released. It provides `waitUntilLogoutEntered()` (`:248`) and `resumeLogout()`.
  - The test logs in, starts logout, awaits entry, expects `isAuthenticated == false`, releases, and awaits the task. It carries `.timeLimit(.minutes(1))`.
  - The handshake proves the contract. Production calls `repo.logout()` only from the best-effort Task that runs after `sessionManager.teardown` and `clearAuthState()`.
  - It cannot pass vacuously. If `repo.logout()` were never called, the wait would hit the time limit. If logout were awaited before `clearAuthState`, the expectation would fail.
- **Keychain seam (D2).**
  - `LegacyTokenCleaning` gains `func clearStoredSessionTokens()`.
  - `LegacyTokenCleanup` implements it with the former `AuthenticationService.clearStoredTokens()` body, unchanged: the same keys in the same order (`"auth.tokens"`, then `"auth.refresh_token"`), the same `do`/`try` that stops at the first error, and the same `LogDebug` and `LogError` lines.
  - `AuthenticationService.clearStoredTokens()` now forwards to `legacyCleanup.clearStoredSessionTokens()`. It is still called from `performSessionEnd` and `clearForSession`.
  - The two key constants that are now unused were removed.
  - The production default `legacyCleanup: any LegacyTokenCleaning = LegacyTokenCleanup()` is unchanged, and `LegacyTokenCleanup` is still the only production conformer.
- **`deviceFingerprint` removed (D2(b)).** The stored property and its assignment in `init` were removed. The rest of `init` is unchanged (`refreshBiometricAvailability()`, then `cleanUpLegacyTokens()`). The evidence is in the next section.
- **Test wiring.**
  - Every unit-test construction of AuthenticationService now injects `legacyCleanup: FakeLegacyTokenCleanup()` or a counting fake.
  - Every construction that relied on the `KeychainBiometricCredentialStore()` default now gets an in-memory credential store.
  - `FakeLegacyTokenCleanup` counts `clearStoredSessionTokens()` calls.
  - The `biometricAuthenticator` defaults are untouched, as D2 requires.
- **Adapter-test exceptions (D2(c)).** These are comments only, with no logic change:
  - `ChristmasTrackerTests/Core/Security/KeychainServiceTests.swift:7-10` (header).
  - `ChristmasTrackerTests/Features/Authentication/BiometricFaceIDGapTests.swift:111-114` (above the "KeychainBiometricCredentialStore LAError mapping" suite).

## D2(b): evidence that deviceFingerprint had no reader
Source: grep plus reading code, by the Orchestrator, the implementer and the acceptance reviewer. Before the change, `deviceFingerprint` appeared only in these places:
- `AuthenticationService.swift:53` (the declaration) and `:87` (the assignment in `init`).
- `NetworkAPIClient.swift:21, 31, 123`: a separate property that `NetworkAPIClient` owns and sends as `X-Device-Fingerprint`. It was not touched.
- `DeviceFIngerprintService.swift:16`: the Keychain key string only.
- SentryBootstrap has no fingerprint reference. Nothing in logging, headers or Sentry scrubbing read the AuthenticationService property.
- `openapi.json:2058` and `client-guide.md:132` have a `deviceFingerprint` field. It is server data, and AuthenticationService never sent it.

Effect of the removal:
- In real mode, `NetworkAPIClient()` is built in `makeReal` (`ChristmasTrackerApp.swift:110`) before AuthenticationService (`:295`), so the fingerprint UUID is still created and persisted as before.
- In mock mode, the UUID is no longer persisted when AuthenticationService is built. Nothing in mock mode reads it.
- There is one fewer `LogDebug("Device fingerprint: …")` call per launch.

## Files
Changed (production):
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LegacyTokenCleaning.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`

Changed (tests: construction wiring, plus the rewritten test and fake):
- `AuthenticationServiceTests.swift` (the fake, plus constructions at `:58, 78, 97, 118, 145, 162, 179, 196, 214, 261, 380`)
- `AuthServiceRegisterSignatureTests.swift:28`
- `InactivityLockControllerTests.swift:123`
- `LogoutPathTests.swift:112, 156, 246`
- `SessionTeardownTests.swift:167, 234, 267`
- `AutoAttemptF3Tests.swift:26`
- `LoginBiometricModelTests.swift:24`
- `EnrollMarkerRegistrationTests.swift:79`
- `EnrollCurrentSessionTests.swift:47`
- `ProfileToggleEnrollmentTests.swift:49`
- `ObservableSnapshotTests.swift:102`
- `BiometricOfferIntegrationTests.swift:54`
- `BiometricFaceIDGapTests.swift:32, 49` (plus the comment)
- `SignInWithBiometricTests.swift` (the rewritten test and repository, plus constructions at `:272, 492, 534, 552, 579, 603, 627, 652, 752, 1101`)
- `KeychainServiceTests.swift` (comment only)

Unchanged because they already injected both fakes: `ClientSeamsTests.swift:96`, `StaleSessionEndTests.swift:172`, `SessionEndGuardTests.swift:272`.

Added:
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LegacyTokenSeamTests.swift`
- This report.

Changed (docs): `Docs/epics/I2b2d-carry-forward.md` (the E3 Gate 1 spec, with the isolated-run table taken before E3).

Deleted: none.

## Test arithmetic
App: 664 + 3 new - 0 deleted = **667**. Package: 191 + 0 = **191**.

- **New tests** (suite `LegacyTokenSeamTests`): `logoutCallsClearStoredSessionTokensOnce`, `clearForSessionCallsClearStoredSessionTokens`, `everyTestConstructionInjectsLegacyCleanup` (the guard). None is parameterized.
- **Rewritten:** `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes`. It keeps its name, so it is not counted as new.
- **Unchanged in meaning:** the 37 construction sites changed wiring only. No expectation changed. The full suite passes, so every existing test still passes.
- **Reconciliation:** the runner reports 667. The acceptance reviewer ran `LegacyTokenSeamTests` alone and got 3 passed.

## Isolation runs (from running commands)
Before E3, at 427bf51, with `scripts/test.sh` (also recorded in the E3 Gate 1 spec):

| Run alone | Result |
|---|---|
| target test | `--- tests: 0 passed, 1 failed, 0 skipped ---` FAIL "isAuthenticated must be false while repo.logout is still suspended" |
| `SignInWithBiometricTests` | 29 passed, 1 failed (the target) |
| `concurrentRefreshesSharingAccountDisabledTearDownOnce()` | 1 passed |
| `InactivityLockControllerTests` | 21 passed |
| `InactivityLockPresenterTests` | 5 passed |
| `InactivityLockIntegrationTests` | 10 passed |
| `ListServiceTests` | 13 passed |
| package, `swift test --filter "RefreshOn401MiddlewareTests"` | 11 passed |

After E3, the target test run alone five times in a row by the Orchestrator, each with `scripts/test.sh "ChristmasTrackerTests/SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes()"`:
```
run 1: --- xcodebuild exit status: 0 --- / --- tests: 1 passed, 0 failed, 0 skipped --- / /tmp/ct-results-1794071895.xcresult
run 2: --- xcodebuild exit status: 0 --- / --- tests: 1 passed, 0 failed, 0 skipped --- / /tmp/ct-results-1794071904.xcresult
run 3: --- xcodebuild exit status: 0 --- / --- tests: 1 passed, 0 failed, 0 skipped --- / /tmp/ct-results-1794071912.xcresult
run 4: --- xcodebuild exit status: 0 --- / --- tests: 1 passed, 0 failed, 0 skipped --- / /tmp/ct-results-1794071920.xcresult
run 5: --- xcodebuild exit status: 0 --- / --- tests: 1 passed, 0 failed, 0 skipped --- / /tmp/ct-results-1794071928.xcresult
```
Also:
- The test-writer ran it alone once, and the acceptance reviewer ran it alone twice: 1 passed each time.
- `SignInWithBiometricTests` alone: 30 passed, 0 failed.
- In the full suite it passes (667 passed, below).

The other yield- or sleep-synchronized tests all passed alone before E3, so none needed a fix. They are reported here as passing alone.

## D2(d): the guard test
`everyTestConstructionInjectsLegacyCleanup` (`LegacyTokenSeamTests.swift:80-232`) works like this:
- It walks up from `#filePath` to `ChristmasTrackerTests` and lists every `.swift` file except its own.
- It blanks out comments and string contents, keeping line numbers.
- It finds every `AuthenticationService(` and `AuthenticationService.init(` call site and requires `legacyCleanup:` inside the call's balanced parentheses. It reports file:line for each offender.
- It also fails if it finds no files or no call sites, so an unreadable source tree cannot make it pass by default.

Verification:
- The test-writer confirmed that the simulator test process can read the host source tree.
- The test-writer also showed the guard fails on a real offender: with `legacyCleanup:` removed from `AuthServiceRegisterSignatureTests.swift:28` for one run, the guard reported exactly that line. The line was then restored.

Known limits (false negatives; none occur in the tree today):
- It checks the label only, so an explicit `legacyCleanup: LegacyTokenCleanup()` would pass.
- It skips its own file.
- It does not catch a construction through a typealias or an implicit `.init(...)`.
- It does not scan app-target code that a test could reach, for example the environment default in `EnvironmentValues+Auth.swift:14-17`. No test reads `\.authenticationService` (grep).
- There is no matching guard for `credentialStore`; Gate 1 asked only for the `legacyCleanup` guard.

## D2(e): real-Keychain and LocalAuthentication paths still reached by the test process (found, not fixed)
These were found by grep and reading code, by the Orchestrator and the acceptance reviewer.

1. **Named adapter-test exceptions** (kept on purpose):
   - `KeychainServiceTests.swift:22-47`: 3 tests that call `KeychainService` directly.
   - `BiometricFaceIDGapTests.swift:120`: `KeychainBiometricCredentialStore()` in the LAError-mapping suite.
2. **LocalAuthentication defaults left under D2.** These 12 constructions omit `biometricAuthenticator`, so they get the real `LocalAuthenticationService()` (`AuthenticationService.swift:70`). It creates an `LAContext` and checks availability, with no prompt, through `refreshBiometricState` in `init`. The sites:
   - `AuthServiceRegisterSignatureTests.swift:28`
   - `AuthenticationServiceTests.swift:58, 78, 97, 118`
   - `InactivityLockControllerTests.swift:123`
   - `LogoutPathTests.swift:112, 156, 246`
   - `SessionTeardownTests.swift:167, 234, 267`
3. **Test-host launch path.** It is not a unit test, but it runs in the same process. The test target uses the app as its host (`TEST_HOST`), so `ChristmasTrackerApp.init` runs at launch with the real adapters:
   - `FirstLaunchWipe().performIfNeeded()` (`ChristmasTrackerApp.swift:205`), using the live Keychain wiper.
   - `LocalAuthenticationService()` (`:223`).
   - `AuthenticationService(...)` (`:295-299`), with the default `LegacyTokenCleanup` and `KeychainBiometricCredentialStore`.

   Gate 1 rules out production test-detection, so this is left for a later decision.
4. **Not Keychain:** constructions without `emailStore` use `RememberedEmailStore` (shared UserDefaults).

After E3, no unit test reaches `KeychainService` through AuthenticationService's `init`, logout or `clearForSession`. Source: grep finds no `LegacyTokenCleanup()`, `DeviceFingerprintService`, `NetworkAPIClient(` or `LocalAuthenticationService(` in tests, and every construction injects the fake; the guard test enforces the cleanup part.

## Verification
All of the following came from running commands. The output is copied verbatim.

**Before E3 (after the E2 commit 427bf51).** `scripts/verify.sh`:
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
--- tests: 664 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1794071020.xcresult ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.016 seconds.
=== verify: TrackerAPI import audit ===
check-package-imports: OK
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`:
```
Build complete! (4.65s)
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
􁁛  Test run with 191 tests in 13 suites passed after 0.012 seconds.
```

**Before the E3 commit.** `scripts/verify.sh`:
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
--- result bundle: /tmp/ct-results-1794072397.xcresult ---
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
Build complete! (4.60s)
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
􁁛  Test run with 191 tests in 13 suites passed after 0.013 seconds.
```

**After the E3 commit:** recorded at the top of the E4 report. It is the same tree state.

## Gate 2
Verdicts were written after the reviews. The two reviews ran one after the other.

**Convention reviewer: APPROVE.** No hard blocks.
- **Confirmed:**
  - The production changes are synchronous; no new async or throws function was added, and the existing spans are intact.
  - No Combine, `DispatchQueue`, force unwraps, `as!` or `try!`.
  - The rewritten test uses a continuation handshake with no yields, sleeps or polling, and has a time limit (`SignInWithBiometricTests.swift:487-520`; the repository is at `:203-261`).
  - No token, password or email is logged.
  - No new `@unchecked Sendable` or `nonisolated(unsafe)`.
  - The moved body is identical (`LegacyTokenCleaning.swift:19-27`).
  - The scope is as specified, and the two exception files changed by comment only.
- **Warnings** (not fixed, carried forward):
  1. `LegacyTokenSeamTests.swift:105` is about 153 characters long (warning limit 120).
  2. `LegacyTokenSeamTests.swift:136-188`: the `codeOnly(_:)` body is about 51 lines (warning limit 40).
  3. The `LegacyTokenSeamTests` type body is about 207 lines (warning limit 200).
  4. `AuthenticationServiceTests.swift` grew from 381 to 405 lines. Its struct body was already over 300.

  Files already over a limit before E3 and still over it:
  - `AuthenticationService.swift`: 649 lines, now down to 638.
  - `SignInWithBiometricTests.swift`: 1119 lines, now 1152.
  - `InactivityLockControllerTests.swift`: 501 lines, now 503.
  - `EnrollMarkerRegistrationTests.swift`: 453 lines, now 454.
- **Note:** the header comment at `LegacyTokenSeamTests.swift:9-11` still says "Expected red until the implementer adds…", which is out of date. It was left as is and is recorded here.

**Acceptance reviewer: APPROVE.** Answers to the focus list:
- **(3) The logout test is deterministic and proves its contract.**
  - Reading the code: the handshake is at `SignInWithBiometricTests.swift:230-260` and `:487-520`. Production calls `repo.logout()` only after teardown and `clearAuthState()` (`AuthenticationService.swift:445-459`).
  - Running it: it passed alone twice in the review, `SignInWithBiometricTests` alone passed 30 of 30, and the full suite passed 667.
  - All other yield-synchronized tests are accounted for in the Gate 1 table.
- **(4) Every remaining path is classified** as listed under D2(e) above (from reading code and grep). The guard's scanner was read and its limits recorded. It passed alone, 3 passed in `LegacyTokenSeamTests`.
- **D2(a) and D2(b):** production behaviour is unchanged: the same keys, order, short-circuit and logs; the default is unchanged; and the order of calls in `init` is unchanged. Removing the fingerprint is safe. This comes from reading code and comparing against `git show HEAD`.
- **(6)** No token, password or email is logged (from reading code).
- **(7)** App 664 → 667, package 191 → 191 (from running the tests).
- **(8)** Nothing changed under contract/ or .claude/, in any .pbxproj, in the synced Docs, or in LocalPackages/TrackerAPI (from `git status`).

**Rejections and re-reviews:** none.

**Stuck-detector log:**
- Implementer attempt 1 was green: the build succeeded, `LegacyTokenSeamTests` alone passed 3, and `scripts/verify.sh` was OK with 667.
- No further attempts.
- No suspected-flaky tests.

## Deviations, real bugs, out of scope
- **Deviations:** none from the Gate 1 spec.
- **Real bug fixed:** the logout ordering test failed every time it was run alone, because it synchronized on `Task.yield()`.
- **Latent risk, carried forward:**
  - `SignInWithBiometricTests.swift:823` (`concurrentRefreshesSharingAccountDisabledTearDownOnce`) still uses `for _ in 0..<20 { await Task.yield() }` to let `forceRefresh` join the in-flight refresh. It passes alone and in the full suite, so the brief did not require a fix.
  - If the race is lost, the late caller sees `tokens == nil` and gets `invalidRefreshToken`, and the expectation at `:830` fails.
  - The polling loops at `:178` and `:1060` (`waitUntilRefreshCalled`) remain as well. They are bounded by the actor and pass alone.
- **Out of scope:**
  - The test-host launch path (D2(e) item 3).
  - The `emailStore` UserDefaults default.
  - `BiometricFaceIDGapTests.swift` holds more than one suite.
- **Contract issues:** none.

## Not done or partial
- The post-commit verify and package runs for E3 are recorded in the E4 report.
- The LocalAuthentication defaults (12 sites) and the test-host launch path are not fixed, as D2 decided.
- The `:823` yield loop is not converted to a handshake; it passes alone.
- The size warnings and the stale header comment in `LegacyTokenSeamTests.swift` are not fixed.
