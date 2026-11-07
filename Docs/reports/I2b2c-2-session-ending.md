# I2b-2c U2: end the session when the account is disabled or no longer exists

Package: I2b-2c. Story: U2. Date: 2026-11-06.
Contract: contract content of C16 (backend f1d4f57), synced at backend commit 5c86cc3 (one docs-only commit later), spec sha256 55f570342c69. Client guide section 4 (C15 middleware table).
Pipeline: full. Test-writer, then implementer, then convention-reviewer, then acceptance-reviewer, then a fix round (test-writer, implementer), then re-review by the same acceptance-reviewer and then the same convention-reviewer. Every step ran one at a time.

## After the U1 commit (5d67f29), from running commands
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 618 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 156 tests in 12 suites passed after 0.016 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `􁁛  Test run with 156 tests in 12 suites passed after 0.010 seconds.`
These also serve as the "before" outputs for U2.

## Files
Added
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/SessionEndingMiddleware.swift`
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SessionEndingMiddlewareTests.swift`
- `ChristmasTracker/ChristmasTracker/Core/API/SessionEndingSeam.swift`
- `ChristmasTracker/ChristmasTracker/Core/API/ClientSeams.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SessionEndingSeamTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/API/ClientSeamsTests.swift`

Changed
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/Seams.swift`: adds `SessionEndReason` and `SessionEnding`.
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerClientFactory.swift`: adds the defaulted `sessionEndingHandler` parameter and the order comment.
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`:
  - The private `AuthServiceBox` and the `[weak authBox]` seam closures are removed.
  - `init` uses `makeClientSeams()` and sets `seams.box.value = auth`.
  - `buildGeneratedClient` gains `sessionEndingHandler`.
- `ChristmasTracker/ChristmasTrackerTests/Core/API/SeamTests.swift`: 2 tests added.
- `Docs/epics/I2b2c-adopt-c15-c16.md`: the U2 Gate 1 "Exact signatures" block was added before coding. A stale closure signature was fixed later, after the convention reviewer's warning 4.

Deleted: none.

Package changes, all of them allowed by the story: the seam, the middleware, the factory parameter with its order comment, and tests. Nothing else changed in the package.

## What changed
Package
- `SessionEndingMiddleware` (`Middleware/SessionEndingMiddleware.swift`):
  - Public operations pass straight through (lines 33-35).
  - It inspects a response only when the status is 403 or 404 and there is a body (line 39). It buffers that body (44-47) and decodes it leniently with the private `ErrorEnvelopePeek` (58, 75-81).
  - It calls the handler once, and only for (403, ACCOUNT_DISABLED) giving `.accountDisabled` or (404, USER_NOT_FOUND) giving `.userNotFound` (49-50, 62-69).
  - It returns `HTTPBody(bufferedData)`, the same bytes (54).
  - It has no Sentry, with the same comment RefreshOn401Middleware uses (23-25).
- `TrackerClientFactory.make` gains `sessionEndingHandler: (any SessionEnding)? = nil` after `requestIDObserver` and before `transport`.
  - The order is Headers, RefreshOn401, RateLimit, VersionOutdated, SessionEnding (only when a handler is given), BearerAuth, and a comment documents it.
  - Existing call sites compile unchanged.

App
- `SessionEndingSeam`: wraps an `@Sendable (SessionEndReason) async -> Void` closure, and `sessionEnded(reason:)` awaits it.
- `ClientSeams.swift`: `AuthServiceBox` with a weak `value`, `struct ClientSeams`, and `makeClientSeams()`.
  - All three closures are `@MainActor` and capture the box strongly. The ownership chain is client, then seams, then box, then a weak link to the service, so there is no retain cycle.
  - Token closure: returns `box.value?.currentAccessToken`.
  - Refresh closure: with no service it throws `AuthenticationError.invalidRefreshToken`, which SessionRefreshSeam maps to `SessionRefreshError.credentialFailure`. Otherwise it calls `forceRefresh()`.
  - Session-ending closure (lines 65-77): a single-flight guard on the main actor. The check is `!box.isEndingSession`, a service exists, and `isAuthenticated`. It then sets the flag, clears it with `defer`, logs the reason only, and awaits `logout(reason: .sessionExpired)`. It never touches the credential store, so the Face ID enrollment stays.
- `@unchecked Sendable` and `nonisolated(unsafe)` in production, each justified in a comment:
  - `AuthServiceBox: @unchecked Sendable` (`ClientSeams.swift:21`; comment at 15-20). Its state is written on the main actor during composition and used only by the `@MainActor` closures.
  - `nonisolated(unsafe) weak var value` (line 25). It is written during composition before any request, then read by the main-actor closures.
  - `nonisolated(unsafe) var isEndingSession` (line 31). It is read and written only inside the `@MainActor` session-ending closure, so every access is serialized.
  - The convention reviewer notes that both `nonisolated(unsafe)` markers are probably unnecessary, because the app module is main-actor by default. They were kept to match the spec and the existing box, and are recorded as a warning.
- Test-only `@unchecked Sendable`, both NSLock-protected and commented: `DeleteCountingCredentialStore` (`ClientSeamsTests.swift:30-31`) and `RotatingSession` (`SessionEndingMiddlewareTests.swift:41-42`).

## Real bugs found
1. **The composition root dropped the seam box, so the token and refresh seams were dead.** This is decision D-a.
   - `ChristmasTrackerApp.init` created `let authBox = AuthServiceBox()` as a local. The `AccessTokenSeam` and `SessionRefreshSeam` closures captured it only as `[weak authBox]`, so nothing retained it after `init` returned.
   - The result: the token seam always returned nil (no bearer token on any authenticated generated call), and the refresh seam always threw `invalidRefreshToken`.
   - It was introduced in I2b-2b C1 (a90965e), which replaced the earlier, working `[weak auth]` captures of the service; that service is held strongly by `@State authService`. It stayed latent since then because no screen makes an authenticated generated call yet.
   - Fixed by `makeClientSeams()`, in which the closures hold the box strongly and the box holds the service weakly. Two composition tests, required by Brian, prove the fix.
   - Source: git history (`git log -S "[weak authBox]"` and `git show a90965e`) and reading the code.
2. **Concurrent session ends tore the session down more than once.** Found by the acceptance reviewer, Finding 1, and fixed in U2.
   - `AuthenticationService.logout` suspends in `sessionManager.teardown` before `isAuthenticated` turns false, so several 403/404 responses that arrive close together each passed the `isAuthenticated` guard.
   - The new test showed the teardown running 3 times for 3 concurrent calls. It now runs once, through the single-flight flag.

## Tests
App suite: 618 previous + 12 new - 0 deleted = 630 (a parameterized test counts as one entry).
- SessionEndingSeamTests.swift (3): `forwardsAccountDisabled`, `forwardsUserNotFound`, `conformsToSessionEnding`.
- ClientSeamsTests.swift (7):
  - `sessionEndedSignsOutSignedInService` (parameterized over both reasons)
  - `sessionEndedIsNoOpWhenSignedOut`
  - `sessionEndedTwiceIsIdempotent`
  - `concurrentSessionEndedRunsTeardownOnce` (fix round)
  - `seamsReachServiceAfterCompositionReturns` (composition test 1)
  - `seamsFailSafelyAfterServiceReleased` (composition test 2)
  - `seamsFailSafelyWithNoServiceAttached`
- SeamTests.swift (2): `trackerClientIsNonNilInRealModeWithSessionEndingHandler`, `trackerClientIsNilInMockModeWithSessionEndingHandler`.

Package suite: 156 previous + 23 new - 0 deleted = 179 (12 suites became 13). All 23 are in SessionEndingMiddlewareTests.swift:
- `accountDisabledCallsHandlerOnce` (parameterized: getCurrentUser, logout, listLists)
- `accountDisabledBodyIsByteIdentical`
- `accountDisabledIsNotRetried`
- `minimalEnvelopeIsTolerated`
- `userNotFoundCallsHandlerOnce` (parameterized)
- `userNotFoundBodyIsByteIdentical`
- `forbiddenDoesNotCallHandler`
- `listNotFoundDoesNotCallHandler`
- `accountDisabledOn404DoesNotCallHandler`
- `userNotFoundOn403DoesNotCallHandler`
- `otherStatusesDoNotCallHandler` (parameterized: 400, 401, 409, 500)
- `publicOperation403DoesNotCallHandler` (parameterized over `publicOperationIDs`)
- `publicOperation404DoesNotCallHandler`
- `okDoesNotCallHandler`
- `nonJSONBodyDoesNotCallHandler`
- `emptyBodyDoesNotCallHandler`
- `nilBodyDoesNotCallHandler`
- `concurrentResponsesEachCallHandler`
- `factoryGetCurrentUser403CallsHandlerAndDecodes`
- `factoryGetCurrentUser404CallsHandlerAndDecodes`
- `factoryLogin403DoesNotCallHandler`
- `factoryRefreshThenAccountDisabledCallsHandlerOnce` (fix round)
- `factoryWithoutHandlerStillWorks`

Rewritten or deleted: none.

Reconciliation:
- The Orchestrator listed the `@Test` declarations in the three new files with grep: 23 in the package file, and 3 plus 7 in the app files. The 2 SeamTests additions were checked in the diff.
- The totals come from running verify.sh below. The acceptance reviewer independently counted the same numbers.

How the two tests Brian required prove the fix (from reading code; the acceptance reviewer confirmed it):
- Test 1 builds the seams through a helper that returns only the three seam objects, so the `ClientSeams` value and the box go out of scope. After it returns, the test checks three things:
  - the token provider returns the signed-in token
  - `refresh()` rotates the service's token
  - `sessionEnded` signs the service out
- Against the old `[weak box]` wiring, the first check (the token equals the signed-in token) would fail.
- Test 2 releases the service and checks:
  - a `weak` probe is nil, so there is no retain cycle
  - the token provider returns nil
  - `refresh()` throws `SessionRefreshError.credentialFailure`, a typed catch
  - `sessionEnded` returns safely

Notes on the tests:
- The app tests use `AuthenticationService` with `MockAuthenticationRepository`, a counting in-memory biometric store and fake authenticators.
- `logout` still reaches `KeychainService.delete` through `clearStoredTokens`, exactly as the existing AuthenticationService logout tests do. The new tests add no new kind of real-Keychain use. This is recorded for the handoff.

## Raw outputs before the U2 commit
`scripts/verify.sh` (Orchestrator run, grep-filtered summary lines):
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 630 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 179 tests in 13 suites passed after 0.016 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"` (implementer's fix-round run): `􁁛  Test run with 179 tests in 13 suites passed after 0.022 seconds.`
Fix-round red evidence (test-writer's run of `scripts/test.sh ChristmasTrackerTests/ClientSeamsTests`, before the fix):
```
--- xcodebuild exit status: 65 ---
--- tests: 6 passed, 1 failed, 0 skipped ---
FAIL ClientSeamsTests/concurrentSessionEndedRunsTeardownOnce(): Expectation failed: (dependencies.clearable.clearCallCount → 3) == 1
```
After the U2 commit: recorded at the top of the U3 report.

## Gate 2
Convention reviewer, first review: **APPROVED**.
- Hard blocks: all pass.
  - `SessionEnding` uses the -ing suffix.
  - `@Instrumented` is not required: the package has no Sentry, and the seams are non-throwing adapters, as AccessTokenSeam and SessionRefreshSeam already are.
  - No GCD, Combine, force unwraps, `try!` or `as!`.
  - The log line carries the reason only (`ClientSeams.swift:75`).
  - Reserved test emails; no sleeps; no real network.
  - The only hand parsing is the package peek.
  - Scope: nothing under `.claude/`, any `.pbxproj` (synchronized folders), `contract/` or the synced Docs.
- Warnings:
  1. Branch name: per Brian, the package stays on the chore branch.
  2. `nonisolated(unsafe)` is probably unnecessary (kept; see above).
  3. Uncommented `@unchecked Sendable` on a test double: fixed in the fix round.
  4. Stale brief line: fixed.
  5. Lines over 120 characters (`ClientSeamsTests.swift:123, 127`; `SessionEndingMiddlewareTests.swift:162, 495, 511`, all under 160) and no explicit access modifiers on the new top-level app declarations, matching the existing seams. Recorded.
  6. Unbounded buffering of error bodies. Recorded; 403/404 bodies only.

Acceptance reviewer, first review: **APPROVED**. Focus answers:
- (4) The middleware fires only for non-public operations and only for the two status/code pairs, at most once per response, with byte-identical readable bodies, and never for FORBIDDEN, LIST_NOT_FOUND, other codes or public operations.
  - Evidence is the middleware line numbers above, plus tests at `SessionEndingMiddlewareTests.swift` 128-470.
  - The factory order is correct and documented. Existing `make()` callers compile unchanged.
- (5) The adapter signs out without deleting the enrollment: `logout` (`AuthenticationService.swift:281-302`) never calls the credential store, and the tests check `deleteCallCount == 0`.
  - It is a no-op when signed out and there is no retain cycle.
  - The composition-root fix is in place (`ChristmasTrackerApp.swift:239, 246-250, 300`), and test 1 would fail against the old wiring.
- (11) No change under `contract/`, `.claude/`, any `.pbxproj` or the synced Docs. The package changed only as allowed.
- Findings:
  - 1: concurrent double teardown. Fixed in the fix round.
  - 2: the handler is awaited inside the request (an I3 concern).
  - 3: a stale 403/404 can sign out a newly signed-in user.
  - 4: no end-to-end order test. Added in the fix round.
  - 5: the guide's "discard stored tokens" wording (D-c).
- It confirmed the logout-ordering interaction the Orchestrator raised (see Out of scope).

Fix round:
- The test-writer added `concurrentSessionEndedRunsTeardownOnce` (red: 3 teardowns instead of 1), the order test (green on arrival), and the test-double comment.
- The implementer added the single-flight flag in `ClientSeams.swift` only. That was fix attempt 1 and it went green.

Acceptance reviewer, re-review: **APPROVED**.
- The check and the set happen with no suspension between them on the main actor (lines 72-73). The `defer` clears the flag on every path (74).
- A later, separate session end still works, and there is no deadlock.
- The concurrency test is a real race, because SessionManager is an actor, and it would fail without the fix. The sequential and composition tests are still meaningful.
- The order test pins the replay path: one refresh, one handler call, `.forbidden`, and Bearer T2 on the replay. It would not detect SessionEnding moving to another position in the stack, but for 403/404 the position has no observable effect.

Convention reviewer, re-review: **APPROVED**. The delta passes every check, and warning 3 is resolved. Warnings 1, 2, 4 and 5 remain as recorded.

Stuck-detector log:
- Test-writer: attempt 1, then the fix round as attempt 1.
- Implementer: attempt 1 green (629/178), then fix attempt 1 green (630/179).
- No repeated error signatures.

## Deviations
- U2 gained a fix round after both initial approvals. It closed acceptance Findings 1 and 4 and convention warning 3 before the commit, and both reviewers re-reviewed it.
- The brief was edited inside this story: the exact signatures were added at Gate 1, and one stale line was corrected.
- The order test pins behaviour on the replay path, not the middleware's position in the array (see the acceptance re-review).

## Out of scope (found, not fixed; for the handoff, per D-a)
- **Logout ordering, pre-existing since a90965e.** `AuthenticationService.logout` clears tokens before its best-effort server call. The generated-client logout therefore always goes out with no bearer token, gets a 401, has RefreshOn401 call `forceRefresh`, which throws, and the error is logged as a best-effort failure. This is not a U2 regression: the dead box gave the same result. The Orchestrator noticed it and the acceptance reviewer confirmed it from the code. U3 must make sure forceRefresh does not end a session that is already gone.
- The session-end action is awaited inside the request, so the caller's typed `.forbidden` or `.notFound` arrives after the teardown. A caller that loses the race returns mid-teardown. This matters once I3 adds authenticated screens.
- A slow 403/404 from user A that arrives after user B has signed in would sign B out.
- The guide says to "discard stored tokens" for ACCOUNT_DISABLED (`client-guide.md:119, 174`). The adapter keeps the Face ID enrollment, as D-c intends.
- `logout` uses the real `KeychainService.delete` in unit tests through `clearStoredTokens`. This pattern predates this package.

## Not done or partial
- Real-mode check: not performed. The session end on an authenticated call cannot be exercised manually until I3, because no screen makes an authenticated generated call; see U4.
- The convention warnings 1, 2 and 5 are recorded and not fixed.
- getCurrentUser 429 is still not covered (carried over from U1).
