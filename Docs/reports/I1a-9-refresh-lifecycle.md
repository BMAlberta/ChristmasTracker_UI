# I1a-9 — Refresh Lifecycle Fix (H1)

**Date:** 2026-11-05  
**Story:** H1 — Clear the in-flight refresh task on completion so every token expiry refreshes  
**Commit:** 57a3122

---

## Bug

`RefreshOn401Middleware` stores a completed `Task<Void, Error>` in `refreshTask` on success. A comment in the code documented this intentionally ("concurrent requests must reuse the same completed task"). The side effect: when the access token expires a *second* time in the same session, the middleware finds the still-populated `refreshTask`, `await task.value` returns immediately without calling the refresher, and the replay sends the same expired token. Refresh worked only once per client lifetime.

---

## Fix

Replaced `private var refreshTask: Task<Void, Error>?` with `private var refreshEntry: (id: UUID, task: Task<Void, Error>)?`.

Each new refresh task is created alongside a unique `UUID` nonce. The task body has a `defer` block that acquires the NSLock and sets `refreshEntry = nil` **only if** `refreshEntry?.id == id`. This ensures:

- The creating task self-clears on completion (success or failure).
- A concurrent caller that joined the in-flight task before it completed still sees the correct result (because `defer` runs before `task.value` becomes available, and all three had already suspended on `await task.value`).
- A second token expiry finds `refreshEntry == nil`, creates a fresh entry, and refreshes normally.

The two existing `lock.withLock { refreshTask = nil }` error-path clears were removed — `defer` handles both success and failure.

---

## Files Changed

| File | Change |
|------|--------|
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift` | `refreshTask` → `refreshEntry: (id: UUID, task: Task<Void, Error>)?`; task body gains `defer` for nonce-based self-clear; two error-path `refreshTask = nil` clears removed |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift` | Added 4 new tests; replaced `concurrent401sResultInSingleRefresh` with suspendable-refresher version |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TestHelpers.swift` | Added `FakeSuspendableRefresher`; added `@unchecked Sendable` comment to `FakeAccessTokenProvider`; replaced force-unwrap in `makeBaseURL()` with `guard let` + `preconditionFailure` |

---

## New Tests

| Test | What it proves | Status |
|------|---------------|--------|
| `secondExpiryTriggersFreshRefresh` | Same SUT, same stale token, two sequential 401s → `refreshCallCount == 2` | PASS |
| `concurrent401sResultInSingleRefresh` (revised) | 3 concurrent 401s with `FakeSuspendableRefresher` → exactly 1 refresh | PASS |
| `afterCredentialFailureNextExpiryTriggersNewRefresh` | After credential-failure refresh, next 401 creates a new task → `refreshCallCount == 2` | PASS |
| `afterNonCredentialFailureNextExpiryTriggersNewRefresh` | Same but with non-credential error | PASS |

All 8 prior tests continue to pass. Total: **144 tests, 0 failures**.

---

## Flakiness Check (5 runs)

| Run | Result |
|-----|--------|
| 1 | 144 tests passed, 0 failed |
| 2 | 144 tests passed, 0 failed |
| 3 | 144 tests passed, 0 failed |
| 4 | 144 tests passed, 0 failed |
| 5 | 144 tests passed, 0 failed |

No flakiness observed.

---

## verify.sh Output

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
--- tests: 486 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 144 tests in 11 suites passed after 0.011 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## @unchecked Sendable

`RefreshOn401Middleware` retains `@unchecked Sendable`. The nonce change replaces `Task<Void, Error>?` with `(id: UUID, task: Task<Void, Error>)?`. Both are still protected by the same `NSLock`. The existing comment was updated to reference `refreshEntry`.

---

## Gate 2 Results

**Convention reviewer:** Initial REJECT (two pre-existing items in the modified `TestHelpers.swift`): force-unwrap in `makeBaseURL()` and missing `@unchecked Sendable` comment on `FakeAccessTokenProvider`. Both fixed by Orchestrator (minor convention fixups on pre-existing code that was surfaced when the file was touched). Second-pass review: **PASS**.

**Acceptance reviewer:** **PASS** — All 5 ACs verified with passing tests. 144/144 passing. No new public API surface. `contract/` unmodified.

---

## Not Done or Partial

None.
