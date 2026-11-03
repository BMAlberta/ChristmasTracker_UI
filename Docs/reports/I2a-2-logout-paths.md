Superseded in part by I2a-4 and I2a-5.

# I2a Story 2 — Route All Session-Ending Paths Through Teardown

Branch: `feat/i2a-session-hygiene`

## What changed

### Files modified
- `Features/Authentication/Services/AuthenticationService.swift`
  - `logout()` rewritten: network call stays first; then `await sessionManager.teardown(reason: .userLogout)`; then `clearAuthState()` + `clearStoredTokens()` (explicit self-clear for paths where `authService` is not yet a registered clearable).
  - Added `nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol] = []` + `deinit` to remove observers.
  - Added `setupNotificationObservers()` called from `init()`: registers observers for `.unauthorizedRequest` and `.versionUpdateRequired`, each dispatching `Task { @MainActor [weak self] in await self?.logout() }`.
- `Features/Profile/Views/ProfileView.swift`
  - Removed `@Environment(\.listService)` property and the `await listService.clearCache()` call from the logout confirmation button. Teardown handles all store clearing now.
- `ChristmasTrackerApp.swift`
  - Promoted `sessionManager` from local variable to stored property `private let`.
  - Added `Task` in `init()` to register `listDataStore`, `itemDataStore`, `listService`, `itemService`, `authService`, and `NetworkCache.shared` with `sessionManager`.

### New test file
- `ChristmasTrackerTests/Features/Authentication/LogoutPathTests.swift` — 5 tests.

## Paths before → after

| Path | File : line before | File : line after | Reason |
|------|-------------------|-------------------|--------|
| Profile logout button | `ProfileView.swift:70–71` (clearCache + logout) | `ProfileView.swift:69` (logout only) | `userLogout` |
| Token refresh failure | `AuthenticationService.swift:178` (calls `logout()`) | Unchanged — chains to updated `logout()` | `userLogout` (via `logout()`) |
| `.unauthorizedRequest` notification | No observer | `AuthenticationService.setupNotificationObservers()` → `logout()` | `userLogout` — **wired in I2a**; full end-to-end wiring completes in I1 |
| `.versionUpdateRequired` notification | No observer | Same method → `logout()` | `userLogout` — **wired in I2a**; full end-to-end wiring completes in I1 |

## verify.sh (verbatim)

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 55 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793720162.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 50 tests (after Story 1).
New tests added: 5 (`LogoutPathTests.swift` is a new file; all 5 tests count as new).
New total: **55 tests**.

Test names:
1. `logoutViaAuthServiceClearsRegisteredDataStore`
2. `refreshTokenFailureClearsRegisteredDataStore`
3. `unauthorizedRequestNotificationTriggersLogout`
4. `versionUpdateNotificationTriggersLogout`
5. `networkLogoutFailureDoesNotPreventSignOut`

Verification source: running `scripts/verify.sh`.

## Gate 2 results

**Convention reviewer:** APPROVED — 0 blockers, 3 warnings (all pre-existing or approved deviations).
- Warning: `SessionClearable` name lacks `-ing` suffix (Gate 1 approved deviation).
- Warning: actor-layer `clearForSession()` methods lack I6a explaining comment (approved deviation; `AuthenticationService` sets the correct pattern).
- Warning: `AuthenticationService.swift` is 405 lines (pre-existing, not introduced by Story 2).

**Acceptance reviewer:** APPROVED — all 5 ACs met by passing tests.

## Stuck-detector log

No stuck-detector trigger. Implementer completed in one pass.

## Deviations from Gate 1 spec

1. **Notification observers wired in `AuthenticationService.init()` instead of `ContentView`** — The Gate 1 spec suggested wiring in `ContentView`, but the test-writer's tests (3 and 4) create a standalone `authService` with no view. Observer in `AuthenticationService` is the only approach that makes the tests pass without a view hosting context. This is architecturally correct (the observer removes itself in `deinit`; no view lifecycle gap), and accepted. `ContentView` does not need modification for this story.
2. `nonisolated(unsafe)` on `notificationObservers` — Swift 6 requires this for `deinit` access on a `@MainActor` type. Written once in `init`, read once in `deinit`; fully documented with an inline comment.
3. `@Instrumented` absent — approved deviation (I6a; macro not in codebase).

## Wired in I1

- `.unauthorizedRequest` → `logout()` path: observer fires; full round-trip (network 401 → token refresh attempt → final logout) requires `NetworkAPIClient` to also observe the notification (currently it posts it). Completing this loop is I1 work.
- `.versionUpdateRequired` → `logout()` path: same pattern. I1 should also present a force-update UI before calling logout.

## Not done or partial

None.
