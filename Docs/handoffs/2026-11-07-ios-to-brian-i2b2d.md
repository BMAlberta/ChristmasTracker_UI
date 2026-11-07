# iOS Handoff: Package I2b-2d (carry-forward fixes from I2b-2c)
**Date:** 2026-11-07
**From:** iOS agent (Orchestrator)
**To:** Brian (PROGRAM.md) and the API team
**Branch:** feat/i2b2d-carry-forward, from master 699659d. PRs target master. Not pushed.
**Contract:** unchanged from I2b-2c. STATUS.md CONFORMANT, backend commit 5c86cc3, spec sha256 55f570342c69, decisions revision 24.

## Commits
`git log --oneline master..HEAD`, taken before the E4 commit:
```
50c9c19 I2b-2d: make logout tests deterministic and keep unit tests off the real Keychain
427bf51 I2b-2d: end sessions through one guarded entry point
0065700 I2b-2d: ignore a session-end from a stale request so it cannot sign out the next user
c72fc2b I2b-2d: add brief and inventory
```
The E4 commit ("I2b-2d: fix the version-check retry-after and add the package handoff note") adds one more line. It contains this handoff.

## Contract issues found
None. No row was added to Docs/contract-issues.md.

## What changed
- **E1: a stale 403/404 can no longer sign out the next user.**
  - The package `SessionEnding` seam is now `sessionEnded(reason:requestToken:)`. `SessionEndingMiddleware` passes the bearer token of the request it forwarded.
  - The app ends the session only when that token is non-nil and equals the current in-memory access token. A stale token, a nil token, or nobody signed in is ignored, and the log line carries no token value.
  - The documented trade-off: a 403 for a request whose token a refresh has since rotated is ignored, because the next request carries the new token and gets its own 403.
  - **Package change outside the original E1 file list, approved by Brian (D1, 2026-11-07):**
    - The middleware order is now Headers, RefreshOn401, RateLimit, VersionOutdated, BearerAuth, SessionEnding. Before, SessionEnding sat outside BearerAuth and could never see the Authorization header.
    - The order now lives in an internal `TrackerClientFactory.makeMiddlewares(...)`, which a test pins.
    - `make(...)`'s public signature is unchanged.
- **E2: one session-end entry point.**
  - `AuthenticationService.endSession(reason:deletingEnrollmentForCurrentUser:)` is the single guarded entry. The guard is a stored `Task<Void, Never>?`.
  - Every path uses it: the server end (through `handleServerSessionEnd`; the box only forwards), both refresh credential-failure paths, user logout, and the lock fallback.
  - Overlapping ends tear down once, and callers that arrive mid-end wait for it.
  - After an end, further ends are no-ops until a new sign-in resets the guard.
  - The enrollment is deleted only when a refresh credential failure is the call that started the end. A server end or a logout never deletes it.
  - The two old `isEndingSession` flags are gone.
- **E3: deterministic logout test, and no real Keychain through AuthenticationService in unit tests.**
  - `logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` uses a handshake (the repository's logout signals entry), not 10 `Task.yield()`s. It failed every time when run alone before. It passed 5 of 5 isolated runs after, and passes in the full suite.
  - Logout's Keychain deletes go through `LegacyTokenCleaning.clearStoredSessionTokens()`. The production body is unchanged: same keys, same order, same logs.
  - The unused `AuthenticationService.deviceFingerprint` was removed. It had no reader, and production still creates the fingerprint through `NetworkAPIClient`.
  - Every unit-test construction injects fakes for cleanup and the credential store. A source-scanning guard test fails on any construction without `legacyCleanup:`.
  - `KeychainServiceTests` and the real-store `BiometricFaceIDGapTests` suite are kept and labelled as adapter-test exceptions.
- **E4: version-check retry-after.**
  - `GeneratedClientAppVersionRepository` unwraps the middleware's `TrackerAPIError.rateLimited(retryAfter:)` from `ClientError`, so `VersionService` now backs off on a 429 (`.backOff`). It used to show `.showMessage`. Every other error is unchanged.
  - The typed 429 arm reads `error.details.retryAfter`, falling back to the package default of 1. The code-as-seconds mapping (8001) is removed.
  - **Because RateLimitMiddleware caps a single wait at 10 seconds, a server Retry-After above 10 is reported as 10 (D3(e)).** The contract's own example is 900.
- **Real bugs fixed:**
  1. A stale 403/404 from user A could sign out user B. This was introduced by I2b-2c U2.
  2. Overlapping session ends could tear down twice: the two flags, and a user logout racing a matching 403.
  3. The logout ordering test was order-dependent.
  4. The version-check 429 used the error code as seconds, and never reached `.backOff`.
- **Tests:**
  - App: 633 → 645 (E1) → 664 (E2) → 667 (E3) → 677 (E4).
  - Package: 179 → 191 (E1) → 191 (E2, E3, E4).
  - `scripts/verify.sh` is OK before and after every commit. Details are in Docs/reports/I2b2d-*.md.

## What the API team must do
Nothing.

## Manual checks
The manual versions of these checks come with **I3**, because no screen makes a generated authenticated call yet:
- the stale-session check: a slow 403/404 must not sign out the next user;
- the refresh-once-and-replay check.

Set `JWT_EXPIRY=60s` on the backend and restart it after editing .env. The I2b-2c real-mode steps 1–14 in Docs/handoffs/2026-11-06-ios-to-brian-i2b2c.md are still pending, and this package does not change their expected results.

## Open risks and items found, not fixed

| Item | Detail | Source |
|---|---|---|
| Logout without a bearer token | Carried from I2b-2c. `performSessionEnd` clears tokens before the best-effort server logout, so the generated-client logout goes out with no bearer and gets a 401. RefreshOn401 then calls `forceRefresh`, which throws without ending anything (no tokens). Harmless today (A15). | I2b-2c handoff |
| Awaited session end | Carried from I2b-2c. The session-ending handler is still awaited inside the request, so the caller's typed `.forbidden`/`.notFound` arrives after the teardown. I3 screens must not write error state back after a sign-out. E2 adds that a caller arriving mid-end now waits for the end to finish. | I2b-2c handoff, E2 |
| Untested 429 branches | Carried from I2b-2c. getCurrentUser 429 has no test, and the typed `.tooManyRequests` arms on the POST auth operations can't be reached through the factory. The version-check path is now covered (E4). | I2b-2c handoff |
| Retry-After cap | A server Retry-After above 10 s is reported as 10 on the middleware path (D3(e)). | E4 |
| Negative or NaN Retry-After can crash | RateLimitMiddleware (`RateLimitMiddleware.swift:39, 70`) does not clamp negative or NaN values. `DefaultSleeper` (`:88`) then runs `UInt64(seconds * 1e9)`, which traps, so a GET receiving `Retry-After: -1` or `details.retryAfter: -1` could crash the app. This is a package fix, barred in this package (D3(d)). | E4 acceptance review |
| Sign-in during an in-flight end | If a sign-in completes while an end is still running, `handleAuthSuccess` resets the guard and the running end's `clearAuthState()`/`clearStoredTokens()` would wipe the new session. The old logout had the same order, and it is unlikely in practice. Possible fix: skip the clear when the guard was reset meanwhile. | E2 acceptance review |
| Remaining real LocalAuthentication / Keychain in the test process | 12 test constructions use the real `LocalAuthenticationService()` default (listed in the E3 report). The test host runs `ChristmasTrackerApp.init` with real adapters (`ChristmasTrackerApp.swift:205, 223, 295-299`). Some tests use the UserDefaults email store default. | E3 report, D2(e) |
| Yield-synchronized tests | `SignInWithBiometricTests.swift:823` (20 yields; latent race) and the polling loops at `:178` and `:1060` remain. InactivityLock suites use `Task.yield()`. `InactivityLockControllerTests/foregroundIdleFiresTimerAtDeadline()` failed once in a full run during E4's red phase, passed alone, and passed in every later full run, so it is a suspected flaky test. The lock is out of scope here. `ListServiceTests.swift:34` has a real 100 ms sleep. The package's `RefreshOn401MiddlewareTests.swift:88-89` uses 2 yields. | E3 inventory, E4 |
| Guard-test limits | The source-scanning guard checks the `legacyCleanup:` label only. A typealias, an implicit `.init`, an explicit real `LegacyTokenCleanup()`, or app-target code (`EnvironmentValues+Auth.swift:14-17`) would not be caught. There is no guard for `credentialStore`. | E3 report |
| Login 403 and stored tokens | Carried from I2b-2c (D-c). iOS keeps the Face ID token on login 403 and deletes it on the next Face ID attempt. | I2b-2c handoff |
| Size and style warnings | Over the error limit: `AuthenticationService.swift` (638 lines, type body about 572), `SessionEndingMiddlewareTests.swift` (733), `SessionEndGuardTests.swift` (775), `SignInWithBiometricTests.swift` (1152). Struct bodies over 300 lines: ClientSeamsTests, TrackerClientFactoryTests, AuthenticationServiceTests. There are also some lines of 121 to 153 characters, unsorted test imports, and a stale "expected red" header in `LegacyTokenSeamTests.swift:9-11`. These need a test-file split pass. | Gate 2 warnings |
| Minor, carried | From I2b-2c: the repository `?? "…"` fallbacks, and the `nonisolated(unsafe)` on `AuthServiceBox.value`. New: the `SessionClearable.swift:22` comment still says the service self-clears in `logout()`, but it now does so in `performSessionEnd`. `TeardownReason.forcedUpdate` has no production caller. | Gate 2 warnings, E2 review |
| Device fingerprint in the client guide | `client-guide.md:132` shows a `deviceFingerprint` in the refresh body. The iOS generated refresh does not send one (it did not before this package either). | E3 Gate 1 |

## PROGRAM.md section 9 (one line)
I2b-2d: carry-forward fixes from I2b-2c. A stale 403/404 can no longer sign out the next user: the session-end seam carries the request token, and SessionEnding moved inside BearerAuth, a package change Brian approved. All session ends go through one guarded entry point. The logout ordering test is deterministic, and logout's Keychain deletes go through a seam faked in all unit tests. The version-check 429 backs off with the real retry-after. App tests 633 → 677, package 179 → 191. No contract issues. Manual stale-session and refresh-replay checks come with I3.
