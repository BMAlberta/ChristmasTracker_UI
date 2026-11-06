# I1-a Second Fix Pass — Gate 1 Spec (H1 and H2)

**Date:** 2026-11-05  
**Branch:** feat/i1a-api-client-package  
**Pipeline:** Full (H1 and H2 both touch auth/session-related middleware; H2 is factory/transcoder)

---

## H1 — Refresh Lifecycle Fix

### Problem

`RefreshOn401Middleware` stores a completed `Task<Void, Error>` in `refreshTask` on success. A comment in the code documents this intentionally to let concurrent 401s reuse the same completed task. However, this means the NEXT time the access token expires (a new `intercept` call after the previous refresh completed), the middleware finds the stale completed task, `await task.value` returns immediately without calling the refresher, and the replay sends the same expired token. Refresh works only once per client lifetime.

### Fix Design

Replace `refreshTask: Task<Void, Error>?` with `refreshEntry: (id: UUID, task: Task<Void, Error>)?`.

When a new refresh task is created:
1. Generate a `UUID` as a nonce (`id`).
2. The task body has a `defer` block that acquires the NSLock and sets `refreshEntry = nil` **only if** `refreshEntry?.id == id`. This ensures the creating task clears itself, not a newer task created by a later expiry.
3. The task is stored as `(id: id, task: newTask)` in `refreshEntry`.
4. Remove the two existing `lock.withLock { refreshTask = nil }` error-path clears — `defer` handles both success and failure.

The `defer` runs before `task.value` becomes available to awaiters, so when any `intercept` caller resumes from `await task.value`, `refreshEntry` is already nil. A subsequent 401 in the same session finds nil, creates a fresh entry, and refreshes.

Stale-token detection (G3: compare `requestToken` vs `currentToken` before single-flight) is unchanged and correct.

### New Interface

No new public interface. `refreshEntry` is private; `(id: UUID, task: Task<Void, Error>)?` is a private tuple type.

`TestHelpers.swift` gains `FakeSuspendableRefresher` — an actor whose `refresh()` suspends until explicitly released. Required for the deterministic concurrent test.

### Acceptance Criteria

1. **Second expiry**: Two sequential calls on the same SUT instance, each receiving a 401 with the same token, each trigger a separate refresh. `refreshCallCount == 2` after both complete successfully.
2. **Concurrent single-flight**: Three concurrent 401s with the same token trigger exactly one refresh call. `refreshCallCount == 1` after all three complete. Uses `FakeSuspendableRefresher` to prevent Task(X) from completing before B and C join it.
3. **Stale-token unchanged**: Existing `staleTokenReplaySkipsRefresh` test continues to pass without modification.
4. **After credential failure, next 401 retries**: After a credential-failure refresh error (unauthorized thrown), a subsequent 401 on the same SUT creates a new refresh task and refreshes successfully. `refreshCallCount == 2`.
5. **After non-credential failure, next 401 retries**: Same as AC4 but with a non-credential `SessionRefreshError.other`.

ACs 1 and 5 together constitute the "mutation check": if `refreshEntry` is left non-nil after success, AC1 would see `refreshCallCount == 1`; if `refreshEntry` is left non-nil after failure, AC4/5 would see `refreshCallCount == 1`. Both must equal 2 to pass.

All existing 8 tests must continue to pass.

### Scoped Files

```
LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift  (modify)
LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift     (modify — add 4 new tests, update concurrent test)
LocalPackages/TrackerAPI/Tests/TrackerAPITests/TestHelpers.swift                     (modify — add FakeSuspendableRefresher)
Docs/reports/I1a-9-refresh-lifecycle.md                                              (create)
```

### `FakeSuspendableRefresher` interface (for TestHelpers.swift)

```swift
actor FakeSuspendableRefresher: SessionRefreshing {
    private(set) var refreshCallCount: Int
    // refresh() increments refreshCallCount, then suspends until releaseSuccess() is called
    func refresh() async throws
    // Waits (without sleeping) until refresh() has been called at least once
    func waitUntilRefreshCalled() async
    // Resumes the pending refresh() continuation with success
    func releaseSuccess()
}
```

### Revised concurrent test structure

```
1. Create FakeSuspendableRefresher, FakeTransport (3×401, 3×200), SUT
2. Launch three independent Task { callMiddleware } (not in task group, to allow coordination)
3. await refresher.waitUntilRefreshCalled()       // Task(X) is in-flight and suspended
4. await Task.yield(); await Task.yield()          // Give B and C time to reach await task.value
5. await refresher.releaseSuccess()               // Release Task(X); all three resume
6. await all three tasks
7. #expect(refreshCallCount == 1)
```

---

## H2 — Factory Fractional-Second Dates

### Problem

The only factory-level date test covers whole-second ISO 8601 timestamps (`2026-11-02T00:00:00Z`). Fractional-second timestamps (e.g., `2025-12-30T10:00:00.123Z`) are not covered through the full factory → `Configuration(dateTranscoder: TrackerDateTranscoder())` path.

### Fix Design

Add two new tests to `TrackerClientFactoryTests.swift`:

1. **`clientDecodesFractionalSecondISO8601Dates`** — same structure as `clientDecodesWholeSecondISO8601Dates` but the JSON fixture has `"createdAt": "2025-12-30T10:00:00.123Z"` and `"updatedAt": "2025-12-30T10:00:00.456Z"` and `"timestamp": "2025-12-30T10:00:00.789Z"`. Must decode without throwing.
2. **`clientDecodesZeroFractionalSecondISO8601Dates`** — JSON fixture has `"createdAt": "2025-12-30T10:00:00.000Z"` (zero milliseconds). Must decode without throwing.

No production code changes are expected; `TrackerDateTranscoder` already handles fractional seconds. These tests prove the transcoder is correctly wired through the factory into the generated client.

### New Interface

No new production interface. Tests only.

### Acceptance Criteria

1. `clientDecodesFractionalSecondISO8601Dates` calls `client.getCurrentUser()` with fractional-second dates in the JSON body, gets `.ok`, decodes `body.data.firstName == "Alice"` without throwing.
2. `clientDecodesZeroFractionalSecondISO8601Dates` same with `.000Z` fractional seconds.
3. All existing 10 factory tests continue to pass.

### Scoped Files

```
LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift  (modify — add 2 tests)
Docs/reports/I1a-10-factory-fractional-dates.md                                (create)
```

---

## Commit Message

```
I1-a: add second fix pass Gate 1 spec
```
