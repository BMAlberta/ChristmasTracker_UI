# I2b-2d E1: a stale 403 or 404 cannot sign out the next user
Date: 2026-11-07. Branch: feat/i2b2d-carry-forward. Base: c72fc2b ("I2b-2d: add brief and inventory").
Pipeline: full (session and generated-client layer). Gate 1 spec: Docs/epics/I2b2d-carry-forward.md, "E1" and decision D1.

## What changed
- Package seam:
  - `SessionEnding.sessionEnded(reason:requestToken:)` replaces `sessionEnded(reason:)`, with no overload and no default.
  - `SessionEndingMiddleware` passes the bearer token of the request it received and forwards to `next`. That is the text after the exact prefix `"Bearer "`; it is nil when the header is absent, has a different prefix, or is empty after the prefix.
  - Everything else in the middleware is unchanged: non-public operations only, the same two status/code pairs, a byte-identical body, and at most one handler call per response.
- Package middleware order (D1, **a package change outside the original E1 file list, approved by Brian on 2026-11-07**):
  - The new order is Headers, RefreshOn401, RateLimit, VersionOutdated, BearerAuth, SessionEnding. Before, SessionEnding sat outside BearerAuth.
  - The order now lives in a new internal `TrackerClientFactory.makeMiddlewares(...)`, which `make(...)` uses. `make`'s public signature is unchanged.
  - The factory comment says why SessionEnding sits inside BearerAuth: it must see the Authorization header BearerAuth sets.
  - Nothing else in the factory changed.
- App adapter:
  - `SessionEndingSeam` forwards `(reason, requestToken)`.
  - The closure in `makeClientSeams()` keeps its guards: the single-flight flag, the box value, and `isAuthenticated`.
  - It then ends the session only when `requestToken` is non-nil and equals `service.currentAccessToken`. Otherwise it logs the fixed text "Session end ignored: ignored a stale session-end", with no token values, and returns.
  - The trade-off comment is at `ClientSeams.swift:72-76`: a request whose token a refresh has since rotated is ignored, because the next request carries the new token and gets its own 403/404.

## Files
Changed (production):
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Seams.swift`
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/SessionEndingMiddleware.swift`
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerClientFactory.swift` (D1: the order, the comment and the one internal hook only)
- `ChristmasTracker/ChristmasTracker/Core/API/SessionEndingSeam.swift`
- `ChristmasTracker/ChristmasTracker/Core/API/ClientSeams.swift`

Changed (tests):
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SessionEndingMiddlewareTests.swift`
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift` (the order tests and their no-op handler only)
- `ChristmasTracker/ChristmasTrackerTests/Core/API/ClientSeamsTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SessionEndingSeamTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SeamTests.swift` (the `NoopSessionEnding` signature only)

Added:
- `ChristmasTracker/ChristmasTrackerTests/Core/API/StaleSessionEndTests.swift`
- This report.

Changed (docs): `Docs/epics/I2b2d-carry-forward.md` (the E1 Gate 1 spec).

Deleted: none.

## Test arithmetic
App: 633 + 12 new - 0 deleted = **645**. Package: 179 + 12 new - 0 deleted = **191**. A parameterized test counts as one entry, as the runner reports it. No test was deleted or rewritten. The existing tests whose calls changed are listed after the new ones.

New app tests (12):
- `ClientSeamsTests` (6):
  - "A stale token is ignored…" (parameterized over both reasons; the first `@Test(` in the diff)
  - "A nil token while signed in is ignored…" (parameterized; the second `@Test(`)
  - "Signed out, a nil request token is a no-op: no teardown, enrollment intact"
  - "A stale token does not block a later matching token: the matching call ends the session once"
  - "The token from a previous sign-in of the same user is ignored after signing in again"
  - "Documented trade-off: a token a refresh has since rotated is ignored; the rotated token still ends the session"
- `SessionEndingSeamTests` (3):
  - "sessionEnded forwards the request token to the closure unchanged"
  - "sessionEnded forwards a nil request token to the closure as nil"
  - "Through any SessionEnding, each call forwards its own reason and token, in order"
- `StaleSessionEndTests` (3):
  - `staleAccountDisabledDoesNotSignOutNextUser` (the two-user test)
  - `accountDisabledForCurrentTokenEndsSessionOnce` (composition)
  - `userNotFoundForCurrentTokenEndsSessionOnce` (composition)

New package tests (12):
- `SessionEndingMiddlewareTests`, middleware alone (6):
  - "403 ACCOUNT_DISABLED with Authorization: Bearer T1 passes requestToken T1 once, with .accountDisabled"
  - "404 USER_NOT_FOUND with Authorization: Bearer T1 passes requestToken T1 once, with .userNotFound"
  - "The bearer token is read from the request the middleware received and forwarded to next"
  - The missing-Authorization test (parameterized 403/404)
  - The non-Bearer test (parameterized over "Basic abc", "Bearer ", "Bearer", "bearer T1", "BearerT1", "Token T1")
  - "A bearer token is not passed for codes that do not end the session (handler not called)"
- `SessionEndingMiddlewareTests`, factory-built (4):
  - "Factory client: getCurrentUser 403 ACCOUNT_DISABLED passes the token provider's token (set by BearerAuth) to the handler"
  - "… 404 USER_NOT_FOUND passes the token provider's token to the handler"
  - "… with no token from the provider, a 403 ACCOUNT_DISABLED passes a nil requestToken"
  - "Factory client: 401, refresh, replay 403 ACCOUNT_DISABLED passes the rotated token T2, once"
- `TrackerClientFactoryTests` (2):
  - "makeMiddlewares with a handler returns exactly Headers, RefreshOn401, RateLimit, VersionOutdated, BearerAuth, SessionEnding"
  - "makeMiddlewares without a handler returns exactly Headers, RefreshOn401, RateLimit, VersionOutdated, BearerAuth"

Existing tests changed in signature or call site only, with no expectation changed:
- **Package recorder:** the `RecordingSessionEndingHandler` test double records `(reason, requestToken)`, and `reasons` and `callCount` are derived from that.
- **Package helper:** `callMiddleware` gained an optional `authorization:` parameter (default nil).
- **`SessionEndingSeamTests`:** the existing three tests pass a token.
- **`SeamTests`:** `NoopSessionEnding` takes the new signature.
- **`ClientSeamsTests`:** the tests that end a session pass `service.currentAccessToken`, or `rotatedToken` where a refresh happens first. Without that, the new comparison would turn them into no-ops; the new signature requires the token. The signed-out and released-service tests pass "T1" or nil and remain no-ops.

Reconciliation:
- The runner reports 645 app and 191 package tests (commands below).
- `git diff -U0` lists 12 added `@Test` declarations in the package test files and 9 in the changed app test files, plus 3 in the new app file. No `@Test` was removed.

## D1 conditions
1. **Scope of the factory change:** the order, the comment and the one internal hook only.
   - `TrackerClientFactory.swift:40-53`: `make` delegates.
   - `:56-92`: `makeMiddlewares`.
   - `:66-80`: the comment.
   - `:81-90`: the order.
   - Source: reading code; the convention reviewer agreed.
2. **Tests:**
   - Order: `makeMiddlewaresWithHandlerHasExactOrder` and `makeMiddlewaresWithoutHandlerHasExactOrder`.
   - BearerAuth's token reaches the seam: `factoryGetCurrentUser403PassesProviderToken`, which asserts the sent header is `Bearer T1` and the handler received `[.accountDisabled, "T1"]`.
   - Source: running the tests (191 passing).
3. **Existing tests:** the 426 (VersionOutdatedMiddlewareTests), 429 (RateLimitMiddlewareTests), 401-replay (RefreshOn401MiddlewareTests, and `SessionEndingMiddlewareTests` :602-635) and SessionEnding tests are unchanged in meaning. Their files are untouched, except the SessionEnding recorder signature. No expectation changed. Source: reading the diff (both reviewers) and running the tests.
4. **The factory comment** is at `TrackerClientFactory.swift:74-76`. Source: reading code.
5. **Recorded here** and, at package end, in the handoff.

## Verification
All of the following came from running commands. The raw summary lines are copied verbatim.

Before the E1 commit, `scripts/verify.sh` (filtered to its summary lines):
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
--- tests: 645 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1794069527.xcresult ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.014 seconds.
=== verify: TrackerAPI import audit ===
check-package-imports: OK
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

Before the E1 commit, `swift test --package-path "LocalPackages/TrackerAPI"`:
```
Build complete! (5.02s)
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
􁁛  Test run with 191 tests in 13 suites passed after 0.015 seconds.
```

Before the E1 code (after the Step 1 commit c72fc2b): `--- tests: 633 passed, 0 failed, 0 skipped ---`, `Test run with 179 tests in 13 suites passed`, and `=== verify: OK ===`. The package run gave `Test run with 179 tests in 13 suites passed after 0.014 seconds.`

After the E1 commit: both runs are recorded at the top of the E2 report (Docs/reports/I2b2d-2-single-end-session.md, "Before E2"). They are the same tree state, and a report cannot contain the output of a commit made after it is written.

Isolated runs, made by the acceptance reviewer:
- `scripts/test.sh "ChristmasTrackerTests/StaleSessionEndTests"`: 3 passed, 0 failed.
- `scripts/test.sh "ChristmasTrackerTests/ClientSeamsTests"`: 13 passed, 0 failed.

## Gate 2
These verdicts were written after both reviews, which ran one after the other.

**Convention reviewer: APPROVE.** It found no hard blocks and eight size warnings, all in test files:
- **Line length:** lines over 120 characters (all under 160) at:
  - `ClientSeamsTests.swift:411`
  - `SessionEndingMiddlewareTests.swift:498, 660, 719`
  - `TrackerClientFactoryTests.swift:444, 454, 457`
- **File length:**
  - `SessionEndingMiddlewareTests.swift` is 733 lines, over the 600 error limit; this story raised it from 550.
  - `ClientSeamsTests.swift` is 436 lines, over the 400 warning limit; it was 292.
  - `TrackerClientFactoryTests.swift` is 469 lines; it was 418, already over.
- **Type body:**
  - `SessionEndingMiddlewareTests` is about 654 lines; it was about 470, already over.
  - `ClientSeamsTests` is about 361 lines; it was about 217.
  - `TrackerClientFactoryTests` is about 443 lines; it was about 392, already over.
- **Disposition:** not fixed in E1. Splitting these files means widening the Gate 1 file list. They are carried in the handoff as a test-file split for a later pass.

The reviewer confirmed:
- no Combine, no DispatchQueue, and no force unwraps, `as!` or `try!` on added lines;
- no sleeps, yields or XCTestExpectation;
- no token values logged;
- no new `@unchecked Sendable` or `nonisolated(unsafe)`;
- `@Instrumented` is not applicable;
- the scope is as specified.

**Acceptance reviewer: APPROVE.** Its focus-list answers, with evidence:
- (1) The seam carries the request's bearer token. The adapter ends the session only on a match, and a two-user test shows A's late 403 does not sign out B. Source: reading code and running the tests.
  - Token passed from the request: `SessionEndingMiddleware.swift:52` passes `bearerToken(in: request)`. The helper is at `:62-69`, and the request is the one forwarded at `:39`.
  - The adapter:
    - `ClientSeams.swift:78` keeps the existing guards.
    - `:79` requires a non-nil token equal to `currentAccessToken`, which is the in-memory `tokens?.accessToken` (`AuthenticationService.swift:349`).
    - The flag is set only after the match (`:84`), so a stale call cannot block a later matching one; `staleThenMatchingTokenEndsSessionOnce` covers this.
  - The two-user test is `StaleSessionEndTests.swift:211-249`. `HoldingTransport` (`:38-79`) holds the request with continuations: it signals arrival, then waits for a release, with no sleeps or yields.
  - **Recorded weakness:** the two-user test alone would not fail if SessionEnding moved back outside BearerAuth. The token would arrive as nil and be ignored, so B would still stay signed in. That regression is caught by:
    - the composition test `accountDisabledForCurrentTokenEndsSessionOnce` (`:257-276`), which fails when the session does not end;
    - the order test;
    - the factory token tests.

    The test would fail if the adapter skipped the comparison (B signed out, two teardowns).
- (6) No token is logged.
  - `ClientSeams.swift:81` logs a fixed string.
  - `:86` interpolates only the `SessionEndReason` enum.
  - The middleware does not log, and no Sentry call was added.
  - Source: reading code.
- (7) The counts reconcile: app 633 → 645 and package 179 → 191, +12 each, matching the lists above. Source: running the tests.
- (8) Nothing changed under contract/ or .claude/, in any .pbxproj, or in the synced Docs files. The package changed only in the E1 and D1 files. Source: `git status` and the diff stat.
- Edge cases, from reading code and tests:
  - Refresh rotation: the replay carries T2, once.
  - A nil token and non-Bearer headers.
  - Signed out.
  - Concurrency: the flag guard comes first, unchanged, and the concurrent test still expects one teardown.
  - The enrollment is untouched in every new app test (`deleteCallCount == 0`).
  - The trade-off comment is accurate (`ClientSeams.swift:72-76`), and `refreshRotatedTokenIsIgnored` pins it.

**Rejections and re-reviews:** none.

**Stuck-detector log:**
- Implementer attempt 1 was green on the first try: package 191 passed, build succeeded, app 645 passed. No further attempts.
- No suspected-flaky tests.

## Deviations, real bugs, out of scope
- **Deviation (approved):** the D1 order change in `TrackerClientFactory.swift`. It is a package change outside the original E1 file list, approved by Brian.
- **Real bug fixed:** the I2b-2c U2 defect. A stale 403/404 from a previous session could sign out the next user.
- **Found, for E2:** a user logout racing a matching 403. `logout` suspends in `sessionManager.teardown` before tokens are cleared (`AuthenticationService.swift:290-294`). During that window, a 403 carrying the still-current token passes `isAuthenticated`, the token check and the box flag, and can run a second teardown. This is the two-guards problem E2 fixes. E1 neither causes nor fixes it.
- **Found, for E3:**
  - The new and changed app tests that log out still reach `KeychainService.delete` through `clearStoredTokens`. Every service they build injects `FakeLegacyTokenCleanup`, but logout does not use that seam yet.
  - `StaleSessionEndTests.swift` defines its own private `InMemoryEmailStore` and `NoopVersionOutdatedHandler`, because the existing ones are private to other files.
- **Minor:** if the two-user test fails before `release`, the held continuation is never resumed. The `.timeLimit(.minutes(1))` trait bounds this.
- **Contract issues:** none. No row was added to Docs/contract-issues.md.

## Not done or partial
- The post-commit verify and package runs for E1 are recorded in the E2 report, not here (see Verification).
- The test-file size warnings above were not fixed.
- No manual or real-backend check: the stale-session path cannot be exercised manually until I3 makes an authenticated generated call.
