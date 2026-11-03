# I2a Story R1 — Real Teardown Reasons, No Notification Observers

Branch: `feat/i2a-session-hygiene`

## What changed

### Files modified

- `Features/Authentication/Services/AuthenticationService.swift`
  - Removed: `nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol] = []`
  - Removed: `deinit` block that removed notification observers
  - Removed: `setupNotificationObservers()` method and its call from `init()`
  - Changed: `func logout() async` → `func logout(reason: TeardownReason = .userLogout) async`
  - Changed: `await sessionManager.teardown(reason: .userLogout)` → `await sessionManager.teardown(reason: reason)`
  - Changed: `refreshTokenIfNeeded()` catch block — `await logout()` → `await logout(reason: .sessionExpired)`

- `Features/Authentication/Services/SessionManager.swift`
  - Added: `private(set) var lastTeardownReason: TeardownReason?` (actor-isolated)
  - Updated: `teardown(reason:)` — `self.lastTeardownReason = reason` is now the first line

- `ChristmasTrackerTests/Features/Authentication/LogoutPathTests.swift`
  - All 5 tests replaced (same file, all new bodies and names — see below)
  - `ThrowingLogoutRepository` gained `var loginExpiresIn: Int = 900` + `setLoginExpiresIn(_:)` to support the refresh-failure test
  - Notification posting (`NotificationCenter.default.post(...)`) removed
  - `Task.sleep` calls removed

### Files not modified

`SessionClearable.swift` (protocol and enum unchanged), `ChristmasTrackerApp.swift`, `ProfileView.swift`, all `Core/Networking` files, all repository protocols, all Core/Models files.

## verify.sh (verbatim)

```
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestBundleInject.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestSwiftSupport.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/PlugIns'

** BUILD SUCCEEDED **

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 64 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793723230.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 64 tests.
Tests removed: 2 (notification observer tests: `unauthorizedRequestNotificationTriggersLogout`, `versionUpdateNotificationTriggersLogout`).
Tests added: 2 (entry-point tests: `sessionExpiredTeardownClearsRegisteredClearable`, `forcedUpdateTeardownClearsRegisteredClearable`).
Tests rewritten: 3 (same names below, new bodies).
Net change: 0.
New total: **64 tests**.

Full test names in the replaced `LogoutPathTests.swift`:
1. `profileLogoutPathSendsTeardownWithUserLogoutReason` (rewritten)
2. `refreshFailureCallsLogoutWithSessionExpiredReason` (rewritten)
3. `sessionExpiredTeardownClearsRegisteredClearable` (new — replaces notification test 3)
4. `forcedUpdateTeardownClearsRegisteredClearable` (new — replaces notification test 4)
5. `networkLogoutFailureDoesNotPreventSignOut` (kept, renamed from `networkLogoutFailureDoesNotPreventSignOut`)

Removed test names:
- `unauthorizedRequestNotificationTriggersLogout`
- `versionUpdateNotificationTriggersLogout`

Verification source: running `scripts/verify.sh` (command output above).

## Gate 2 results

**Convention reviewer:** APPROVED WITH WARNING — 0 blockers, 1 warning.
- Warning: `protocol SessionClearable` does not use the `-ing` suffix. This name was introduced in Story 1 and noted there as a known deviation. Not introduced in R1; not fixed in R1.

**Acceptance reviewer:** APPROVED — all 15 acceptance criteria met.

## Stuck-detector log

No stuck-detector trigger. One pass through test-writer, implementer, both reviewers.

## Wired in I1

- **401 path**: client-guide §3.6 requires refresh once, replay the original request, then if refresh fails redirect to login with `.sessionExpired`. The `.unauthorizedRequest` notification still exists in `NetworkAPIClient` (unchanged). I1 must wire the full refresh-replay loop; this R1 removes the premature observer.
- **426 path**: client-guide §3.6 requires blocking the app and prompting for an update — do not retry. Whether the 426 response should also clear the session is an **OPEN QUESTION for I1**; `.forcedUpdate` is available as an entry point but the UX decision has not been made here.

## Deviations from prompt

1. `@Instrumented` absent on modified `async` functions — approved project-wide deviation (I6a; macro not in codebase).
2. `SessionClearable` naming warning — pre-existing from Story 1; tracked, not fixed.

## Not done or partial

None.
