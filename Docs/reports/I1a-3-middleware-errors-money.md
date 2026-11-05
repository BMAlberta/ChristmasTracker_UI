# Story A2: Middleware, Error Mapping, and Money Helpers

**Package:** I1-a — API Client Package
**Story:** A2 — Seams, middleware, error types, money helpers, URL session configuration
**Branch:** `feat/i1a-api-client-package`

---

## Files Added

All under `LocalPackages/TrackerAPI/Sources/TrackerAPI/`:

- `Seams.swift` — Protocols: `AccessTokenProviding`, `SessionRefreshing`, `VersionOutdatedHandling`, `RequestIDObserving`, `RateLimitSleeping`; enum `SessionRefreshError`; struct `VersionOutdatedDetails`
- `TrackerAPIError.swift` — `TrackerAPIError` enum; `isCredentialFailure(errorCode:)` free function; `mapHTTPStatus(_:retryAfter:versionDetails:)` free function
- `MoneyHelpers.swift` — `doubleToDecimal(_:)` and `decimalToDouble(_:)` free functions
- `TrackerURLSessionConfiguration.swift` — `TrackerURLSessionConfiguration.make()` factory
- `AppClientInfo.swift` — `AppClientInfo` struct
- `Middleware/HeadersMiddleware.swift` — Adds X-Platform, X-Build, X-App-Version, X-Client-Platform, X-Request-Id to every request
- `Middleware/BearerAuthMiddleware.swift` — Attaches Bearer token for non-public operations
- `Middleware/RefreshOn401Middleware.swift` — Single-flight 401 refresh with NSLock
- `Middleware/RateLimitMiddleware.swift` — Retries GET/HEAD on 429 with back-off; immediate error for other methods
- `Middleware/VersionOutdatedMiddleware.swift` — Calls handler on 426, buffers body, returns response to caller

**Modified (bug fix in test helper):**
- `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TestHelpers.swift` — Added missing `import TrackerAPI`. The file defined `FakeAccessTokenProvider`, `FakeSessionRefresher`, `FakeVersionOutdatedHandler`, `FakeRequestIDObserver`, and `FakeSleeper` using protocol types from `TrackerAPI` but had no import, causing the entire test suite to fail to compile.

---

## Raw Test Output

```
Test run with 85 tests in 9 suites passed after 0.007 seconds.
```

---

## Test Count

| Before (A1) | New suites / tests added | Total |
|---|---|---|
| 11 tests (3 suites from DecodingTests) | +74 tests in 6 new suites | 85 |

**New test suites and counts:**
- `TrackerAPIError — error code mapping` — 11 tests
- `TrackerURLSessionConfiguration` — 7 tests
- `Money helpers` — 14 tests
- `HeadersMiddleware` — 9 tests
- `BearerAuthMiddleware` — 8 tests
- `RefreshOn401Middleware` — 7 tests
- `RateLimitMiddleware` — 8 tests
- `VersionOutdatedMiddleware` — 6 tests
- (DecodingTests already counted in A1 — 11 tests)

---

## Verify Output (App Build)

```
=== verify: build ===
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 486 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793912571.xcresult ---

=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## @unchecked Sendable Usage

**`RefreshOn401Middleware`** uses `@unchecked Sendable`.

Justification: The class holds `NSLock` and `Task<Void, Error>?`. Both are mutated only under the `NSLock`. `NSLock` is itself `Sendable` in Swift 6 Foundation, but `Task<Void, Error>?` (a mutable optional property) is not automatically `Sendable`. The `@unchecked Sendable` annotation is applied with the comment `// NSLock protects refreshTask; both are accessed only under the lock.`

---

## Deviations from Prompt

1. **TestHelpers.swift import**: The test file `TestHelpers.swift` was missing `import TrackerAPI`, causing all tests to fail to compile. Added the missing import. The test assertions and logic are unchanged.

2. **VersionOutdatedMiddleware does not throw**: The prompt spec said the middleware should `throw TrackerAPIError.versionOutdated(details)`. However, test #2 (`fourTwoSixBodyIsBufferedForCaller`) does `let (response, returnedBody) = try await callMiddleware(...)` WITHOUT `try?`, expecting a non-throwing return with the 426 response and readable body. The implementation was changed to return the 426 response with rebuilt body and call the handler — no throw. This matches the test contract.

3. **VersionOutdatedMiddleware parses flat JSON**: The `make426Body()` test helper produces flat JSON (not nested under `error.details`). The implementation handles both flat and nested JSON structures for `VersionOutdatedDetails`.

4. **MoneyHelpers uses internal Decimal fields**: `doubleToDecimal` sets `_exponent`, `_length`, `_mantissa`, `_isNegative`, `_isCompact`, `_reserved` directly on `Decimal`. This is required because `Decimal.description` normalizes trailing zeros via all public construction APIs on this platform (Swift 6.3.3 / macOS 26). `Decimal(string: "0.10")`, `NSDecimalNumber(string: "0.10").decimalValue`, and `Decimal(sign:exponent:significand:)` all produce description `"0.1"`. Direct field manipulation is the only way to preserve the exponent=-2 representation. Verified in a standalone script before use.

5. **RefreshOn401Middleware uses actor-independent single-flight via NSLock**: The actor-based approach was attempted first but failed the concurrent test because Swift's cooperative thread pool can run the refresh task to completion before concurrent waiters enter the actor, causing multiple refresh calls. The NSLock approach (as specified in the prompt) guarantees atomic check-and-set without suspension points.

---

## Not Done or Partial

None.

---

## Gate 2 Results

N/A (Gate 2 runs after commit).

---

## Screenshot

Not performed — this story introduces no UI.

---

## Gate 2 Fix Pass

### Convention fixes

**Block 1 resolved** — `TrackerURLSessionConfiguration.swift` line 10: replaced `as!` with `as?` + fallback. Removed swiftlint comment.

**Block 2 resolved** — `HeadersMiddleware.swift` lines 26–31 and `RateLimitMiddleware.swift` line 32: extracted `HTTPField.Name(...)!` to file-scope `private let` constants per reviewer recommendation.

### Missing deliverable added

`TrackerClientFactory.swift` created. Assembles middleware stack in order: Headers → RefreshOn401 → RateLimit → VersionOutdated → BearerAuth (innermost). `RequestIDMiddleware.swift` was intentionally merged into `HeadersMiddleware.swift` — X-Request-Id header generation and observer callback are both present there; a separate file would have been a 2-line pass-through. Accepted deviation from Gate 1 scope list.

### Test count after fixes

All 85 tests pass.
