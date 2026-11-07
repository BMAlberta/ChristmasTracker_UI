# I2b-2d: Carry-forward fixes from I2b-2c
Track: iOS. Depends on: I2b-2c (merged, PR #22, master 699659d). Blocks: I3 (its screens make the first authenticated generated calls).
Branch: feat/i2b2d-carry-forward (from master 699659d). PRs target master.
Contract state: unchanged from I2b-2c. STATUS.md CONFORMANT, backend commit 5c86cc3, spec sha256 55f570342c69, decisions revision 24. No contract change is expected in this package.

Source: the "found, not fixed" table in Docs/handoffs/2026-11-06-ios-to-brian-i2b2c.md.

## Why
- E1. SessionEndingMiddleware (I2b-2c U2) ends the session on a 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND from an authenticated call, but the app adapter only checks that someone is signed in. A slow response to user A's request that arrives after user B has signed in would sign B out. U2 itself introduced this defect.
- E2. Two guards against ending a session twice cannot see each other: `AuthServiceBox.isEndingSession` for the server-initiated end, and `AuthenticationService.isEndingSession` for refresh failures. Overlapping ends can still tear down twice.
- E3. `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` fails every time when run alone and passes in a full run. The likely cause is that 10 `Task.yield()` calls do not cover the `sessionManager.teardown` actor hop. Tests must pass in isolation. Separately, logout reaches `KeychainService.delete` through `clearStoredTokens` in unit tests, which is a real Keychain call from a unit test.
- E4. `GeneratedClientAppVersionRepository` maps a 429 using the numeric error code (8001) as the retry-after seconds.

## Decisions taken in this package (Brian, 2026-11-07)
- D1. Middleware order (E1). At the start of this package, SessionEnding sits outside BearerAuth (`TrackerClientFactory.swift:51-60`). `BearerAuthMiddleware.swift:28` is the only code that sets `Authorization`, so the request SessionEnding forwards never carries the header. Brian chose to move SessionEnding just inside BearerAuth. The new order, outermost first, is Headers, RefreshOn401, RateLimit, VersionOutdated, BearerAuth, SessionEnding. Conditions:
  1. `TrackerClientFactory.swift` may change for the order, its comment, and one internal hook for tests (for example, an internal function that returns the middleware array so a test can assert the order). Nothing else in that file changes.
  2. A package test pins the exact middleware order. Another test shows that a 403 ACCOUNT_DISABLED on an authenticated operation passes the bearer token that BearerAuth set into the SessionEnding seam (the token is read from the request SessionEnding received).
  3. The existing 426, 429, 401-replay and SessionEnding tests are re-run unchanged in meaning. Any that needed an expectation change is reported with the reason.
  4. The factory comment says why SessionEnding sits inside BearerAuth: it must see the Authorization header that BearerAuth sets.
  5. The E1 report and the handoff record the order change as a package change outside the original E1 file list, approved by Brian.
- D2. Keychain scope (E3). Option "logout + init". Conditions:
  - (a) The production behaviour of logout, init and the Keychain adapters is unchanged. Only seams and test wiring change.
  - (b) The dead `deviceFingerprint` stored property in AuthenticationService is removed, but only after every reference has been read to confirm nothing uses it (including Sentry scrubbing, headers and logs). The report says so. If anything reads it, stop and ask.
  - (c) `KeychainServiceTests` and the real-store suite in `BiometricFaceIDGapTests` stay. Each gets a comment naming it an adapter-test exception, and the report lists them.
  - (d) A test asserts that logout calls the cleaning seam. A guard test fails if AuthenticationService is built with the real `LegacyTokenCleanup` default in a unit-test context, or the report documents why that is not possible.
  - (e) The E3 inventory lists every remaining real-Keychain or LocalAuthentication path, with file and line, as "found, not fixed" where it is not changed.
- D3. Version-check 429 tests (E4). Option "fake sleeper". Conditions:
  - (a) The repository unwraps `ClientError` and rethrows `TrackerAPIError.rateLimited(retryAfter:)`, so `VersionService.check()` maps a 429 to `.backOff`. The mapping for every other status stays unchanged, and no catch-all hides cases.
  - (b) The typed `.tooManyRequests` arm reads `error.details.retryAfter`, or falls back to the package default. The 8001 mapping is removed.
  - (c) Tests build the generated `Client` with the package's real `RateLimitMiddleware(sleeper: fake)`, plus any other real middleware needed (without SessionEnding):
    - A `Retry-After: 7` header gives 7.
    - `details.retryAfter` 12 gives 10. The test documents that the middleware caps a single wait at 10 seconds.
    - Neither gives the package default.
    - One factory-built test uses `Retry-After: 0`, so it needs no sleeping.
    - A VersionService test shows `.backOff`.
  - (d) No change to LocalPackages/TrackerAPI for E4.
  - (e) The handoff records that, because of the 10-second cap, a server Retry-After above 10 is reported as 10.

## Scope
- E1. A stale 403 or 404 cannot sign out the next user. Changes:
  - The package seam carries the request's bearer token, using the D1 order.
  - The app adapter ends the session only when that token equals the current in-memory access token.
- E2. One single-flight session-end guard and entry point, owned by AuthenticationService. It is used by:
  - the server-initiated end (through the box);
  - the refresh credential-failure paths;
  - explicit logout, which stays local-first.

  The guard resets after a new sign-in.
- E3. Two parts:
  - The logout ordering test uses a deterministic handshake. Every other `Task.yield()` or sleep used as synchronization in a test is run alone and fixed if it fails alone.
  - Logout's Keychain deletions go through the LegacyTokenCleaning seam, with the D2 scope.
- E4. Two parts:
  - The version-check 429 retry-after, with the D3 tests.
  - The package handoff.

Allowed package changes: E1 only. That covers the SessionEnding seam signature, `SessionEndingMiddleware`, their tests, and, under D1, the factory order, its comment, one internal test hook, and the order test. Anything else in the package: stop and report.

Non-goals:
- lists, items, purchases and stats;
- the privacy cover, the lock, and FirstLaunchWipe;
- Core/Networking;
- logout without a bearer token;
- the awaited session end;
- the remaining untested 429 branches on the POST auth operations;
- the minor I2b-2c warnings.

All of these are carried forward in the handoff.

---

## Inventory (taken 2026-11-07 on feat/i2b2d-carry-forward at 699659d, before any change)

### 1. The SessionEnding seam: call sites
Package sources:
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Seams.swift:60-72`: `SessionEndReason` and `protocol SessionEnding { func sessionEnded(reason: SessionEndReason) async }`.
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/SessionEndingMiddleware.swift:50`: `await handler.sessionEnded(reason: reason)`, the only production call of the seam.
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerClientFactory.swift:17` (parameter), `:46-49` (order comment), `:57-60` (SessionEnding appended before BearerAuth).
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/BearerAuthMiddleware.swift:28`: the only place `Authorization` is set (see D1).

App sources:
- `ChristmasTracker/ChristmasTracker/Core/API/SessionEndingSeam.swift:7-17`: `SessionEndingSeam.sessionEnded(reason:)` awaits the injected closure.
- `ChristmasTracker/ChristmasTracker/Core/API/ClientSeams.swift:71-77`: the production closure. It checks the box flag, then `box.value`, then `isAuthenticated`, then calls `logout(reason: .sessionExpired)`.
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift:154` (the `buildGeneratedClient` parameter), `:165` (passed to the factory), `:239` (`makeClientSeams()`), `:250` (`sessionEndingHandler: seams.sessionEnding`), `:300` (`seams.box.value = auth`).

Package tests:
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SessionEndingMiddlewareTests.swift:32` (the recording handler's `sessionEnded`), `:70` (`SessionEndingMiddleware(handler:)`), `:422-433` (`makeFactoryClient`), `:442`, `:461`, `:479`, `:507` (factory-built clients).

App tests:
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SessionEndingSeamTests.swift:30, 40, 50, 58-61`.
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SeamTests.swift:306-307` (`NoopSessionEnding`), `:320`, `:335`.
- `ChristmasTracker/ChristmasTrackerTests/Core/API/ClientSeamsTests.swift:112, 145, 163, 180-181, 202, 238, 276-277, 290`.

### 2. The two isEndingSession flags
- `ChristmasTracker/ChristmasTracker/Core/API/ClientSeams.swift:31`: declared as `nonisolated(unsafe) var isEndingSession = false` on `AuthServiceBox`. It is read and set at `:72-74` inside the `@MainActor` session-ending closure, and its doc comment is at `:17-20` and `:27-30`.
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift:63`: declared as `private var isEndingSession: Bool = false`. It is read and set at `:393-395` in `endSessionAfterRefreshCredentialFailure()`, which is called from `refreshTokenIfNeeded` (`:337`) and `forceRefresh` (`:369`).
- `AuthenticationService.logout(reason:)` (`:284-305`) has no guard. `isAuthenticated` becomes false only after `await sessionManager.teardown(reason:)` (`:290`), in `clearAuthState()` (`:293`).

### 3. Logout and the real Keychain
Production path:
- `AuthenticationService.logout` calls `clearStoredTokens()` (`AuthenticationService.swift:294`), which calls `KeychainService.delete("auth.tokens")` and `KeychainService.delete("auth.refresh_token")` (`:508-516`).
- `clearForSession()` (`:563-571`) also calls `clearStoredTokens()`.
- The Face ID store uses its own key, `biometric.credential.v1` (`BiometricCredentialStoring.swift:44`). Neither path touches it.

Other real-Keychain paths reached by unit tests (D2):
- `AuthenticationService.init` calls `legacyCleanup.cleanUpLegacyTokens()` (`:87`), and the default `LegacyTokenCleanup()` (`:72`; `LegacyTokenCleaning.swift:10-17`) calls `KeychainService.delete` four times.
- `AuthenticationService.init` calls `DeviceFingerprintService.getFingerprint()` (`:84`; KeychainService get/set). The stored `deviceFingerprint` (`:52`) has no reader in AuthenticationService (grep; to be re-confirmed in E3 per D2(b)).
- The default `KeychainBiometricCredentialStore()` (`:73`) is real Keychain and LocalAuthentication.
- The default `LocalAuthenticationService()` (`:70`) is real LocalAuthentication.

Test constructions of AuthenticationService: 37, in 15 files.
- ClientSeamsTests 1, AutoAttemptF3Tests 1, LoginBiometricModelTests 1, InactivityLockControllerTests 1, EnrollMarkerRegistrationTests 1, AuthServiceRegisterSignatureTests 1, BiometricOfferIntegrationTests 1, ProfileToggleEnrollmentTests 1, EnrollCurrentSessionTests 1, BiometricFaceIDGapTests 2, AuthenticationServiceTests 11, ObservableSnapshotTests 1, LogoutPathTests 3, SignInWithBiometricTests 10, SessionTeardownTests 3.
- Only 2 of them inject `FakeLegacyTokenCleanup`: `ClientSeamsTests.swift:97` and `AuthenticationServiceTests.swift:236-244`. The other 35 run the real legacy cleanup in `init`.
- 27 inject a `biometricAuthenticator`.
- The full per-construction table is in the E3 Gate 1 spec.

Unit tests that log out a real-cleanup AuthenticationService, and so call `KeychainService.delete` through `clearStoredTokens`:
- `AutoAttemptF3Tests.swift:119`.
- `LoginBiometricModelTests.swift:160, 264, 307`.
- `BiometricFaceIDGapTests.swift:246, 284`.
- `AuthenticationServiceTests.swift:120, 302, 312, 322, 332`.
- `SignInWithBiometricTests.swift:482, 741, 832`. Its refresh calls (`:536, 561, 584, 607, 631, 663, 683, 704, 729, 745, 758, 777-780`) reach logout only on a credential failure. The E3 Gate 1 table says which ones do.
- `LogoutPathTests.swift:126, 169, 250`.
- `clearForSession()` is not called on an AuthenticationService by any test (grep). SessionTeardownTests (`:167, 232, 263`) builds AuthenticationService with the real cleanup default, so it reaches the Keychain in `init`.
- `ClientSeamsTests` session-ending tests also log out, but they inject `FakeLegacyTokenCleanup`. They still reach `clearStoredTokens`, because that path does not use the seam today.

Direct adapter tests (kept under D2(c)):
- `ChristmasTracker/ChristmasTrackerTests/Core/Security/KeychainServiceTests.swift:13-44` (3 tests).
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricFaceIDGapTests.swift:110-114` (the suite "KeychainBiometricCredentialStore LAError mapping", which builds the real store).

### 4. Task.yield() and sleeps used as synchronization in test code
App tests:
- `Features/Authentication/SignInWithBiometricTests.swift:486`: `for _ in 0..<10 { await Task.yield() }`, in the E3 target `logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes`.
- `Features/Authentication/SignInWithBiometricTests.swift:791`: `for _ in 0..<20 { await Task.yield() }`, in `concurrentRefreshesSharingAccountDisabledTearDownOnce`.
- `Features/Authentication/SignInWithBiometricTests.swift:178`: a polling loop in `waitUntilRefreshCalled()`, on the blocking refresh repository.
- `Features/Authentication/SignInWithBiometricTests.swift:1028`: a polling loop in `waitUntilRefreshCalled()`, on the signed-in fixture's repository.
- `Features/Authentication/InactivityLockControllerTests.swift`: 23 sites, at `:166, 181, 196, 213, 230, 251, 255, 268, 274, 291, 295, 300, 309, 322, 343, 367, 383, 410, 432, 449, 456, 471, 487` (the file header at `:35` says the sleeper path uses `Task.yield()`).
- `Features/Authentication/InactivityLockPresenterTests.swift:64, 87, 113, 137, 162`.
- `Features/Authentication/InactivityLockIntegrationTests.swift:188`.
- `Features/Lists/ListServiceTests.swift:34`: `try? await Task.sleep(for: .milliseconds(100))`, a real sleep. Lists are out of scope; this is inventory only.

Package tests (inventory only; package tests may change only for E1):
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift:88-89`: two `Task.yield()` calls after `waitUntilRefreshCalled()`.

`scripts/test.sh` accepts `-only-testing` identifiers (`scripts/test.sh:12-14`), so each suite can be run alone without another command.

### 5. Version-check 429 mapping
- `ChristmasTracker/ChristmasTracker/Features/Version/GeneratedClientAppVersionRepository.swift:57-60`: `.tooManyRequests` maps to `TrackerAPIError.rateLimited(retryAfter: TimeInterval(err.error.code))`, so the error code (8001) is used as the seconds.
- The repository does not catch `ClientError`. Through the factory, checkAppVersion is a GET:
  - `RateLimitMiddleware.swift:56-77` retries twice with the real `DefaultSleeper` (`:85-89`, `Task.sleep`). Each wait is capped at 10 s (`:10, :70`), with a total of 20 s (`:11`).
  - It then throws `TrackerAPIError.rateLimited(retryAfter:)`, which reaches the repository wrapped in `ClientError`. The typed arm is unreachable through the factory.
- `ChristmasTracker/ChristmasTracker/Core/API/VersionService.swift:30-41` catches `TrackerAPIError` only. A `ClientError` falls to `catch { lastErrorCategory = .showMessage }`, so a 429 is shown as a message instead of backing off (D3(a)).
- Existing test: `ChristmasTracker/ChristmasTrackerTests/Features/Version/VersionCheckRepositoryTests.swift:210-240` sends three 429s with `Retry-After: 0` and asserts `ClientError.underlyingError` is `.rateLimited`.
- The generated 429 payload is `Components.Schemas.Error`. `error.details` is a free-form object (`additionalProperties: true`), and no Retry-After header is documented for checkAppVersion (spec 429 is `$ref: #/components/responses/RateLimitError`).

### 6. Baseline (P2, master 699659d, before branching)
- `scripts/verify.sh`: `** BUILD SUCCEEDED **` / `--- tests: 633 passed, 0 failed, 0 skipped ---` / `Test run with 179 tests in 13 suites passed` / `=== test-release.sh: 62 passed, 0 failed ===` / `=== verify: OK ===`.
- `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 179 tests in 13 suites passed after 0.012 seconds.`

---

## Gate 1 specs
(Added before each story.)
