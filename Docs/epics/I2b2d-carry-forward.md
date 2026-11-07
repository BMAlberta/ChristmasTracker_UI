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

### E1: a stale 403 or 404 cannot sign out the next user
- Contract slice: client guide section 4. A 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND on a bearerAuth operation means "redirect to login". The contract does not change.
- New interface: yes. The signatures below are fixed at Gate 1.
  - Package `Seams.swift`: `public protocol SessionEnding: Sendable { func sessionEnded(reason: SessionEndReason, requestToken: String?) async }`. This REPLACES `sessionEnded(reason:)`; there is no overload and no default. `SessionEndReason` is unchanged.
  - Package `Middleware/SessionEndingMiddleware.swift`:
    - `init(handler:)` is unchanged.
    - When it calls the handler, it passes `requestToken`, read from the `Authorization` header of the `request` it received (the request it forwards to `next`). The value is the text after the exact prefix `"Bearer "`. It is nil when the header is absent, does not start with `"Bearer "`, or has nothing after the prefix.
    - Unchanged: non-public operations only; only the 403/ACCOUNT_DISABLED and 404/USER_NOT_FOUND pairs; the body is returned byte-identical; the handler is awaited at most once per response.
  - Package `TrackerClientFactory.swift` (D1): one new `internal static func makeMiddlewares(info: AppClientInfo, tokenProvider: any AccessTokenProviding, sessionRefresher: any SessionRefreshing, versionOutdatedHandler: any VersionOutdatedHandling, requestIDObserver: (any RequestIDObserving)?, sessionEndingHandler: (any SessionEnding)?) -> [any ClientMiddleware]`.
    - It returns, outermost first: HeadersMiddleware, RefreshOn401Middleware, RateLimitMiddleware, VersionOutdatedMiddleware, BearerAuthMiddleware, then SessionEndingMiddleware only when a handler is given.
    - `make(...)` keeps its public signature and uses this function.
    - The order comment says why SessionEnding is inside BearerAuth: it must see the Authorization header BearerAuth sets.
    - Nothing else in the file changes.
  - App `Core/API/SessionEndingSeam.swift`:
    - `init(onSessionEnded: @escaping @Sendable (SessionEndReason, String?) async -> Void)`.
    - `sessionEnded(reason:requestToken:)` awaits the closure with both values.
  - App `Core/API/ClientSeams.swift`: the session-ending closure keeps its existing guards (flag, box value, `isAuthenticated`).
    - It then ends the session ONLY when `requestToken` is non-nil and equals `service.currentAccessToken`.
    - On a mismatch, or a nil request token, while signed in, it does nothing except `LogInfo("Session end ignored: ignored a stale session-end", category: .auth)`, with no token values in the log.
    - A code comment documents the trade-off: a request that used a token a refresh has since rotated gets ignored, because the next request carries the new token and gets its own 403.
    - The E2 refactor of the guard comes later. E1 does not touch the guards.
- Acceptance (tests):
  - Package, with a fake transport and the middleware alone:
    - 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND with `Authorization: Bearer T1` give `requestToken == "T1"`.
    - No Authorization header gives nil.
    - A non-Bearer value gives nil.
  - Package, factory-built:
    - `makeMiddlewares` returns exactly the six types in order. Without a handler, it returns the first five in order.
    - A 403 ACCOUNT_DISABLED on getCurrentUser passes the provider's token (the one BearerAuth set) to the handler.
    - The 401, refresh, replay, 403 path passes the rotated token "T2", once.
  - Existing package tests: the 426, 429, 401-replay and SessionEnding tests stay unchanged in meaning. Only the handler's signature changes in the test doubles.
  - App adapter, with fakes and `makeClientSeams()`:
    - A matching token ends the session once.
    - A stale token is ignored: the user stays signed in, there is no teardown, and the enrollment stays intact.
    - A nil token while signed in is ignored.
    - Signed out is a no-op.
    - Two users: A signs in, then A's request is held in a fake transport until released (a deterministic handshake: the transport signals that the request arrived, then waits for a release, with no sleeps). A signs out, B signs in, and the transport then releases a 403 ACCOUNT_DISABLED for A's request. B is still signed in, there is no teardown, and the enrollment is untouched.
    - The Face ID enrollment is untouched in every case.
  - App composition: the client built from `makeClientSeams()` seams through `TrackerClientFactory.make`, with a fake transport, gets a 403 ACCOUNT_DISABLED on getCurrentUser for the signed-in user's token, and the session ends once.
  - The existing ClientSeamsTests, SessionEndingSeamTests and SeamTests stay unchanged in meaning (call sites gain the token).
- Files:
  - Package sources: `Seams.swift`, `Middleware/SessionEndingMiddleware.swift`, `TrackerClientFactory.swift` (D1 only).
  - Package tests: `SessionEndingMiddlewareTests.swift`, `TrackerClientFactoryTests.swift` (the order test only).
  - App sources: `Core/API/SessionEndingSeam.swift`, `Core/API/ClientSeams.swift`.
  - App tests: `Core/API/ClientSeamsTests.swift`, `Core/API/SessionEndingSeamTests.swift`, `Core/API/SeamTests.swift` (the `NoopSessionEnding` signature only).
  - A new app test file `Core/API/StaleSessionEndTests.swift` is allowed for the two-user and composition tests.

### E2: one session-end entry point
- Contract slice: none. This is app-internal. Client guide section 4 and the 401 "refresh once, then re-login" rule are unchanged.
- Callers today. Every teardown goes through `AuthenticationService.logout(reason:)`:
  - the server end (`ClientSeams.swift:87`, after the E1 token check);
  - the refresh credential failure (`AuthenticationService.swift:391-404`, through its own flag);
  - the user (`ProfileView.swift:86`);
  - the lock fallback (`InactivityLockController.swift:137`).

  The two flags are inventory 2.
- New interface: yes. These signatures are fixed at Gate 1, all on the `@MainActor` `AuthenticationService`.
  - `internal func endSession(reason: TeardownReason, deletingEnrollmentForCurrentUser: Bool = false) async`. This is THE single guarded entry point, and the only place a teardown happens. It does three things, in order:
    1. When `deletingEnrollmentForCurrentUser` is true and the enrolled user is the current user, it deletes the enrollment and refreshes the biometric state (today's U3 behaviour).
    2. It runs today's local-first logout body: `sessionManager.teardown(reason:)`, then `clearAuthState()`, then `clearStoredTokens()`, then `isLoading = false`.
    3. It sends the best-effort, non-awaited `repo.logout()`.
  - `func logout(reason: TeardownReason = .userLogout) async` keeps its signature. It now just calls `endSession(reason:)`, with the enrollment untouched as before.
  - `internal func handleServerSessionEnd(reason: SessionEndReason, requestToken: String?) async`. It moves the E1 adapter logic from the box closure into the service:
    - It is a no-op when not signed in.
    - When signed in, it ignores a nil or non-matching token with the fixed log "Session end ignored: ignored a stale session-end".
    - On a match, it logs "Session ended by the server: \(reason)" and calls `endSession(reason: .sessionExpired)`. The enrollment is never deleted.
  - The refresh credential-failure paths (`refreshTokenIfNeeded` and `forceRefresh`) call `endSession(reason: .sessionExpired, deletingEnrollmentForCurrentUser: true)` only when `isAuthenticated`. `forceRefresh` still rethrows.
  - `endSessionAfterRefreshCredentialFailure()` is removed, or reduced to that one call.
  - `ClientSeams.swift`: the session-ending closure only forwards: `await box.value?.handleServerSessionEnd(reason:requestToken:)` on the main actor.
  - `AuthServiceBox.isEndingSession` and its `nonisolated(unsafe)` are removed, and the box and closure comments are updated.
- Guard semantics (one guard, owned by the service):
  - The first `endSession` call tears down.
  - Any `endSession` call that arrives while one is in flight, from any path, waits for it to finish. It does not tear down again and does not delete the enrollment, so every awaiting caller returns after the teardown.
  - After an end completes, further `endSession` calls are no-ops until a new session starts.
  - The guard resets when a session starts. That is a successful login, register, or Face ID sign-in, which all go through `handleAuthSuccess`. A later end then works.
  - A fresh service that was never signed in can still end once (for example, the lock fallback or a user logout on a new service).
  - The mechanism is the implementer's choice, for example a stored `Task<Void, Never>?` that callers await. It must not use GCD, and it must not rely on sleeps or yields.
- Instrumentation: `endSession` and `handleServerSessionEnd` are main-actor-isolated, so they get manual SentrySDK spans with the explaining comment. The Sentry names are `service.authentication.endSession` and `service.authentication.handleServerSessionEnd`. Nothing that identifies the user goes into a span.
- Acceptance (tests: fakes, deterministic handshakes, no sleeps or yields):
  1. A server end and a refresh credential failure that overlap tear down once. The refresh failure deletes the enrollment only if it starts the end.
  2. A user logout and a server end that overlap tear down once. Logout is held inside the teardown by a clearable that signals when it is entered and waits for a release. A matching-token server end arrives during the hold. The result is one teardown, and both callers return after it.
  3. A user logout and a refresh credential failure that overlap tear down once, with the enrollment left intact because the logout started the end.
  4. After an end and a new sign-in, another end tears down again (the guard resets).
  5. A server-initiated end never deletes the Face ID enrollment.
  6. `handleServerSessionEnd` keeps the E1 behaviour: a stale token, a nil token, or being signed out is a no-op.
  7. The existing U2, U3 and E1 tests still pass unchanged in meaning: ClientSeamsTests, StaleSessionEndTests, SessionEndingSeamTests, the U3 tests in SignInWithBiometricTests, and the LogoutPath and SessionTeardown tests. Any existing test that calls logout twice on one service and expects two teardowns must be reported. It is not silently rewritten.
- Files:
  - App sources: `Features/Authentication/Services/AuthenticationService.swift`, `Core/API/ClientSeams.swift`.
  - App tests: a new `Features/Authentication/SessionEndGuardTests.swift`. `Core/API/ClientSeamsTests.swift` may change only if the box flag removal needs it (a signature or call site only).
  - No package change.

### E3: deterministic logout tests and no real Keychain in units
- Contract slice: none.
- Isolated runs, taken before E3 at 427bf51 with `scripts/test.sh`:

  | Run alone | Result |
  |---|---|
  | `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes()` | **0 passed, 1 failed** ("isAuthenticated must be false while repo.logout is still suspended") |
  | `SignInWithBiometricTests` | 29 passed, 1 failed (the same test) |
  | `SignInWithBiometricTests/concurrentRefreshesSharingAccountDisabledTearDownOnce()` | 1 passed |
  | `InactivityLockControllerTests` | 21 passed |
  | `InactivityLockPresenterTests` | 5 passed |
  | `InactivityLockIntegrationTests` | 10 passed |
  | `ListServiceTests` | 13 passed |
  | package, `swift test --filter "RefreshOn401MiddlewareTests"` | 11 passed |

  Only the target test fails when run alone, so it is the only one this story rewrites. The others are reported as passing alone. The package and Lists tests are out of scope and stay as they are.
- Why the target fails: logout now runs `endSession`, then a stored Task, then `performSessionEnd`, then the `sessionManager.teardown` actor hop, then `clearAuthState()`. Ten `Task.yield()` calls do not reliably cover that path. `repo.logout()` is called only after `clearAuthState()`, from the best-effort Task.
- D2(b) evidence: `AuthenticationService.deviceFingerprint` has no reader.
  - Its only references are its declaration (`AuthenticationService.swift:53`) and its assignment in `init` (`:87`).
  - SentryBootstrap has no fingerprint reference.
  - The other `deviceFingerprint` in the app is a separate stored property of `NetworkAPIClient`: `NetworkAPIClient.swift:21, 31` sets it, and `:123` sends it as `X-Device-Fingerprint`.
  - `NetworkAPIClient` is built in production at `ChristmasTrackerApp.swift:110, 129` and keeps calling `DeviceFingerprintService.getFingerprint()`, so production still creates and persists the fingerprint UUID.
  - The derived spec's `deviceFingerprint` (`openapi.json:2058`) and the client guide's refresh example (`client-guide.md:132`) are server-side data. AuthenticationService never sends either.
  - So the property is removed.
- New interface: yes. These signatures are fixed at Gate 1.
  - `LegacyTokenCleaning.swift`: the protocol gains `func clearStoredSessionTokens()`.
    - `LegacyTokenCleanup` implements it with exactly today's `AuthenticationService.clearStoredTokens()` body, which is a `do` block containing:
      - `try KeychainService.delete("auth.tokens")`
      - `try KeychainService.delete("auth.refresh_token")`
      - `LogDebug("Stored tokens cleared", category: .auth)`

      plus the `catch` that logs `LogError("Failed to clear tokens: \(error)", category: .auth)`.
    - That keeps the same keys, the same order, the same short-circuit on the first error, and the same log lines.
    - `cleanUpLegacyTokens()` is unchanged.
  - `AuthenticationService.clearStoredTokens()` becomes `legacyCleanup.clearStoredSessionTokens()`. It is still called from `performSessionEnd` and `clearForSession`.
    - The two now-unused key constants (`keychainAuthTokensKey`, `keychainAuthRefreshTokenKey`) are removed. The other constants are left alone.
    - The production default `legacyCleanup: any LegacyTokenCleaning = LegacyTokenCleanup()` is unchanged.
  - `AuthenticationService`: remove the `deviceFingerprint` stored property and its `init` assignment. `init`'s other behaviour (legacy cleanup, biometric availability) is unchanged.
- Test changes:
  1. The target test is rewritten with a deterministic handshake. The repository's `logout()` signals when it is entered (a continuation or AsyncStream), then suspends until it is released. The test:
     - logs in;
     - starts logout;
     - awaits "repo logout entered";
     - asserts `isAuthenticated == false` while the repository logout is still suspended;
     - releases;
     - awaits the logout task.

     It uses no yields and no sleeps, and carries `.timeLimit(.minutes(1))`. It keeps its name and its contract, so it counts as rewritten, not new.
  2. `FakeLegacyTokenCleanup` (in `AuthenticationServiceTests.swift:16`) implements `clearStoredSessionTokens()` and counts calls.
  3. New tests:
     - Logout calls the seam exactly once (`clearStoredSessionTokens` count 1, `cleanUpLegacyTokens` still 1 from `init`).
     - `clearForSession` calls the seam.
     - A guard test, as described below.
  4. Every unit-test construction of AuthenticationService injects:
     - `legacyCleanup: FakeLegacyTokenCleanup()`;
     - an in-memory credential store wherever it uses the `KeychainBiometricCredentialStore()` default today.

     This covers the 35 constructions in inventory 3. Their meaning is unchanged; only the wiring changes. `biometricAuthenticator` defaults are left alone, per D2: the LocalAuthentication paths are reported as found, not fixed.
  5. Adapter-test exceptions: a short comment is added at the top of `Core/Security/KeychainServiceTests.swift` and on the real-store suite in `BiometricFaceIDGapTests.swift`. It names each as an adapter-test exception (D2(c)). No test logic changes.
- The guard test (D2(d)): a test fails if any unit-test file builds `AuthenticationService(` without `legacyCleanup:`. The intended approach:
  - The test locates the test sources from its own `#filePath`.
  - It scans every `.swift` file under `ChristmasTrackerTests/` for `AuthenticationService(` call sites.
  - It requires `legacyCleanup:` within that call's argument list.
  - It ignores the scanner's own file and comments.

  If the simulator test process cannot read the host source tree, the test-writer stops and reports that. The report then documents why a guard is not possible, and production is not changed to detect tests.
- Acceptance:
  - The target test passes alone 5 times in a row (the Orchestrator records the 5 runs) and passes in the full suite.
  - After the change, no unit test reaches `KeychainService` through AuthenticationService (logout, init or `clearForSession`).
  - The only unit tests that still call the real Keychain are the two named adapter-test exceptions.
  - The E3 report lists every remaining real-Keychain or LocalAuthentication path, with file and line (D2(e)).
- Files:
  - Production: `Features/Authentication/Services/LegacyTokenCleaning.swift`, `Features/Authentication/Services/AuthenticationService.swift`.
  - Tests: every test file in inventory 3 that constructs AuthenticationService, which is these 15:
    - ClientSeamsTests
    - AutoAttemptF3Tests
    - LoginBiometricModelTests
    - InactivityLockControllerTests
    - EnrollMarkerRegistrationTests
    - AuthServiceRegisterSignatureTests
    - BiometricOfferIntegrationTests
    - ProfileToggleEnrollmentTests
    - EnrollCurrentSessionTests
    - BiometricFaceIDGapTests
    - AuthenticationServiceTests
    - ObservableSnapshotTests
    - LogoutPathTests
    - SignInWithBiometricTests
    - SessionTeardownTests

    Also allowed:
    - StaleSessionEndTests and SessionEndGuardTests, to check them only.
    - `Core/Security/KeychainServiceTests.swift`, for the comment only.
    - A new `Features/Authentication/LegacyTokenSeamTests.swift`, for the seam and guard tests.
  - No package change.
