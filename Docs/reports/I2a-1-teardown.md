# I2a Story 1 — Session Teardown and Clearable Stores

Branch: `feat/i2a-session-hygiene`

## What changed

### Files added
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift` — `SessionClearable` protocol and `TeardownReason` enum.
- `ChristmasTracker/ChristmasTracker/Core/Extensions/NetworkCache+SessionClearable.swift` — `NetworkCache: SessionClearable` conformance extension (outside `Core/Networking/` per brief).
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift` — 10 tests.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/MockSessionClearable.swift` — Spy clearable for testing.

### Files modified
- `Features/Authentication/Services/SessionManager.swift` — Added `clearables` array, `register(_:)`, and `teardown(reason:)` to the actor.
- `Features/Authentication/Services/AuthenticationService.swift` — Added `SessionClearable` conformance extension (same file for `private` method access); calls `clearAuthState()` and `clearStoredTokens()`.
- `Features/Lists/DataStores/ListDataStore.swift` — Added `SessionClearable` conformance; calls existing `clear()`.
- `Features/Items/DataStores/ItemDataStore.swift` — Added `SessionClearable` conformance; calls existing `clearAll()`.
- `Features/Lists/Services/ListService.swift` — Added `clearForSession()` in class body + empty conformance extension; changed stored property to `nonisolated let`.
- `Features/Items/Services/ItemService.swift` — Added `clearForSession()` in class body + empty conformance extension; changed stored property to `nonisolated let`.

### Files modified outside original Gate 1 scoped list (justified)
- `Features/Lists/Repositories/ListRespository.swift` — Added `nonisolated` to `protocol ListRepository`. Required because Swift 6.3.3 / iOS 26 SDK enables `InferIsolatedConformances`, which was inferring the protocol as `@MainActor` from its `ListService` usage. The test's actor-based mock conformance is otherwise impossible.
- `Features/Items/Repositories/ItemRepository.swift` — Same fix for `ItemRepository`.
- `Core/Models/GiftItem.swift` — Added `nonisolated` to `struct GiftItem` and `struct ItemPerson`; `@MainActor` on `ItemStatus.color`. `InferIsolatedConformances` was inferring `GiftItem` as `@MainActor`, making its properties inaccessible from non-isolated actor contexts.
- `Core/Models/GiftList.swift` — `@MainActor` on `ListRole.color` (same reason).
- `Core/Models/Purchase.swift` — `@MainActor` on `ShippingStatus.color` (same reason).

All out-of-scope changes are driven by the same toolchain inference issue; they are safe, backwards-compatible additions that add isolation clarity rather than change behaviour.

**Core/Networking files touched:** None. `NetworkCache` conformance lives in `Core/Extensions/NetworkCache+SessionClearable.swift`.

## verify.sh (verbatim)

```
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
note: Removed stale file ...
** BUILD SUCCEEDED **

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 50 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793719225.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 40 tests.  
New tests added: 10 (`SessionTeardownTests.swift`).  
New total: **50 tests**.  

Swift Testing tests ARE counted by `scripts/verify.sh` (verified by output: 50 passed). Total rose by exactly 10.

New test names:
1. `listDataStoreIsEmptyAfterTeardown`
2. `itemDataStoreIsEmptyAfterTeardown`
3. `listServiceIsEmptyAfterTeardown`
4. `itemServiceIsEmptyAfterTeardown`
5. `authServiceIsSignedOutAfterTeardown`
6. `networkCacheIsEmptyAfterTeardown`
7. `failingClearableDoesNotBlockOthers`
8. `teardownIsIdempotent`
9. `signedOutStateReachedEvenWhenClearableThrows`
10. `deviceLevelDefaultsSurviveTeardown`

Verification source: running `scripts/verify.sh` (command output).

## Gate 2 results

**Convention reviewer:** APPROVED — 0 blockers, 2 warnings.
- Warning 1: `SessionClearable` and `TeardownReason` lacked explicit `internal` access modifier. **Fixed** by Orchestrator before commit.
- Warning 2: `ListRepository` and `ItemRepository` protocol names (pre-existing, not introduced by this story). Not fixed; tracked for I2b or a naming cleanup story.

**Acceptance reviewer:** APPROVED — all 10 acceptance criteria met by passing tests and code inspection.

## Stuck-detector log

No stuck-detector trigger. Implementer completed in one pass.

## Suspected-flaky tests

None identified.

## Deviations from prompt

1. `@Instrumented` absent on new `async throws` functions — approved deviation (I6a; macro not in codebase).
2. Repository protocols and model structs modified outside Gate 1 scoped list — justified above (toolchain `InferIsolatedConformances` inference).

## Recommendations for I1

- **Late-response risk**: services (`ListService`, `ItemService`) have no in-flight task cancellation. A `loadLists()` or `loadItems()` task started before teardown can complete after stores are cleared and repopulate the `ListDataStore`/`ItemDataStore`. I1 should add task handles and cancel them at the start of `teardown(reason:)`.
- **Logout ordering risk**: `AuthenticationService.logout()` still calls the server before local teardown (addressed in Story 2). The server call can timeout/fail and the teardown still runs (deferred block ensures it); ordering is noted.

## Not done or partial

None.
