# I2a Story R2 — Deterministic Clearable Registration

Branch: `feat/i2a-session-hygiene`

## What changed

### Files modified

- `Features/Authentication/Services/SessionClearable.swift`
  - Added free function `makeProductionClearables(listDataStore:itemDataStore:listService:itemService:networkCache:) -> [any SessionClearable]` at `internal` visibility, callable from tests.
  - Returns exactly 5 clearables in order: `ListDataStore`, `ItemDataStore`, `ListService`, `ItemService`, `NetworkCache`.

- `Features/Authentication/Services/SessionManager.swift`
  - `init(authRepository:)` replaced with `init(authRepository:initialClearables:[any SessionClearable] = [])`, pre-populating `self.clearables` at construction time.
  - Added I6a comment above `teardown(reason:)`: `// Actor-isolated: manual instrumentation only — @Instrumented not yet available (I6a)`.

- `ChristmasTrackerApp.swift`
  - Replaced fire-and-forget `Task { await sm.register(...) }` with a synchronous call to `makeProductionClearables(...)` passed directly to `SessionManager.init(authRepository:initialClearables:)`.
  - Local aliases `lds`, `ids`, `ls`, `is_` removed; local variables used directly.
  - `auth` (AuthenticationService) intentionally excluded from the factory — see below.

### Files not modified

`AuthenticationService.swift`, `ProfileView.swift`, `LogoutPathTests.swift`, all `Core/Networking` files, all Core/Models files, all repository protocols.

## Why AuthenticationService is excluded from the factory

`AuthenticationService` requires a fully constructed `SessionManager` in its own `init`. Including it in `makeProductionClearables` would require constructing authService before SessionManager exists — a circular dependency that cannot be resolved without a two-phase init or a new intermediate type. Therefore authService is not registered as a clearable. It self-clears via the explicit `clearAuthState()` + `clearStoredTokens()` calls in `logout()`, which run immediately after `sessionManager.teardown(reason:)`. An inline comment in `logout()` documents this. The documentation comment on `makeProductionClearables` explains the circular-dependency reason.

If authService is later refactored to break the circular dependency (for example by using a separate `AuthSessionCoordinating` protocol), it could be added to the factory without changing any other clearable or the teardown logic.

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
--- tests: 65 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793724132.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 64 tests.
New tests added: 1 (`productionClearableSetContainsExpectedClearables` in `SessionTeardownTests.swift`).
New total: **65 tests**.

New test name:
- `productionClearableSetContainsExpectedClearables` — asserts `makeProductionClearables(...)` returns count == 5, with `ListDataStore` at [0], `ItemDataStore` at [1], `ListService` at [2], `ItemService` at [3], `NetworkCache` at [4]. Fails if any clearable is missing from the factory.

Verification source: running `scripts/verify.sh` (command output above).

## Gate 2 results

**Convention reviewer:** APPROVED — 0 hard blocks, 1 surfaced warning.
- Warning: `actor SessionManager` lacks explicit `internal` modifier on its top-level declaration. Pre-existing; not introduced by R2. Not fixed in R2.

**Acceptance reviewer:** APPROVED — all 8 acceptance criteria met.

## Stuck-detector log

Convention reviewer issued one soft-reject (I6a comment not found in committed diff — it was in the uncommitted working tree). Comment was verified present by direct file read; reviewer re-run with correct instructions. No stuck trigger (single error, single fix, single re-review).

## Deviations from prompt

1. `@Instrumented` absent on `async` functions — approved project-wide deviation (I6a).
2. `actor SessionManager` lacks explicit `internal` — pre-existing issue, not in R2 scope.
3. AuthenticationService excluded from factory due to circular dependency — documented in code and in this report.

## Not done or partial

None.
