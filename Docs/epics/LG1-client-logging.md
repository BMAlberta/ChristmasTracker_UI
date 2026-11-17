# LG1: Client logging coverage
Track: iOS. Depends on: OL1 (merged to main). Blocks: the lists pull-to-refresh package (this package only makes that problem visible).
Contract state: no contract change; nothing under `contract/` or the synced Docs is touched.

Why: during real-mode testing the app's own log was not trustworthy as evidence. Login and list loading log; Profile logs button taps; Statistics, Budgets and tab switches log nothing although they call the API. Pull to refresh on the lists screen sends nothing and logs nothing, and nobody could tell from the app side. There is no request-level logging and service-level logging is patchy (ListService logs successes; StatsService logs only a failure). This package makes the client log what it does, so a tester can follow one action from the tap to the API call to the result in the Xcode console (Debug) and the device log (Release).

## Brian's rules
1. Log whatever makes sense. Anything that calls the API is logged. Button taps and tab switches are NOT logged unless they call the API (Profile already logs taps; leave it).
2. Log steps, not only outcomes: request made, response received (status, duration), response processed, or the failure and where it failed. Debug logging must be robust.
3. Wrap functions that perform work with performance tracking (existing mechanism, below).
4. Release logs much less: failures plus the server request id. No per-step chatter in Release.
5. The logging lives in the app target for now, not in `LocalPackages/TrackerAPI`.

## Never in a log line (any level, any build)
Item, list, child, member or store names; descriptions; notes; emails; display names; prices, totals, budgets, amounts; URLs the member typed or pasted; confirmation or tracking numbers; tokens, the Authorization header, any other header value except the request id; request or response bodies; query values; path parameter values (ids); server error text; confirmation tokens.
Allowed: operation name (OpenAPI operationId), HTTP method, status code, duration, byte counts, attempt number, the request id, counts ("12 lists"), a stable error category or error code number. `PIIFilter.redact` already runs in Logger but is NOT the control: a variable goes into a message only if it is one of the allowed things.

## Decisions (D1 to D8, from the instruction)
- D1: A `LoggingClientTransport` (app target) implements `ClientTransport`, wraps `URLSessionTransport` built with `TrackerURLSessionConfiguration.make()`, and logs every attempt. It sits below all middlewares, so it sees each real attempt (replay after a 401 refresh, retry after a 429) and receives the operationID. No middleware is added to `TrackerClientFactory`.
- D2: Category `.network`. Debug: "request made" (operation, method, attempt), "response received" (operation, status, duration ms, request id), "request failed" (operation, error category, duration). `.debug` for made/received on success, `.warning` for 4xx/5xx, `.error` for transport failures. Release: failures only (5xx, transport errors, and 4xx other than the expected 401/404/409/426 flow statuses) with operation, status, request id. Uses `#if DEBUG`, the check Logger already uses; no new flag.
- D3: Services log "<operation> processed" (`.debug`, Debug builds) after the repository returned and the result was applied, with a count when natural. Existing `.info` success lines stay. Every failure path logs once (`.error`), none silent, none doubled.
- D4: Every service method that calls a repository or the API gets: performance wrapper, a "started" `.debug`, a "processed" `.debug` on success, one `.error` on failure. Cancellation logs "<operation> cancelled" at `.debug`, never an error. The audit table goes in the report.
- D5: Refresh entry points (dashboard lists, items, statistics, budgets, purchase history) log "started" with a reason (pull, appear, tab) from a small enum when known and "skipped (already refreshing)" when the `isRefreshing` guard returns early. Refresh behavior is NOT changed.
- D6: Release services log failures only, as today, plus the transport failure lines. No new `.info` lines in services.
- D7: Categories: `.network` transport, `.business` services, `.performance` the helper.
- D8: One line per operation; nothing per item or per row.

## Gate 1 spec
Weight: L2 (transport, the generated-client layer) takes the FULL pipeline: isolated test-writer and implementer, convention-reviewer and acceptance-reviewer. L1, L3 and L4 are solo (one implementer writes failing tests, implements, loops build and test) with the convention-reviewer, and the acceptance-reviewer reviews the whole package on its focus list at the end.

Shared new interface (introduced in L1, used by L2 to L4): `OperationLogging`, a small `Sendable` protocol with `log(_ level: LogLevel, _ message: String, category: LogCategory)`; the production type `AppOperationLog` forwards to the global `LogDebug`/`LogInfo`/`LogWarning`/`LogError`; tests inject a capturing sink. A second small type carries the "is verbose" decision (true under `#if DEBUG`), injectable so Release behavior is testable in a Debug test run.

### L1: instrumentation helper
- Contract slice: none. New interface: yes (`InstrumentedOperation`, `OperationLogging`).
- Acceptance: `InstrumentedOperation.run(_ name: String, ... operation:)` for `@MainActor` code; starts a Sentry transaction named by the operation name (same shape the services start by hand), emits the Logger signpost begin and end (`.performance`), records the duration, finishes the span `.ok`, or with an error status on a thrown error other than cancellation, and a cancelled status (not failure) on cancellation; rethrows the identical error; only the operation name ever reaches a span or a log line.
- Files: `Core/Logging/InstrumentedOperation.swift`, `Core/Logging/OperationLogging.swift`; tests under `ChristmasTrackerTests/Core/Logging/`.

### L2: logging transport
- Contract slice: every operation (transport level). New interface: yes (`LoggingClientTransport`).
- Acceptance: D1 and D2 behavior; wired at the one client creation point; tests with a fake inner transport and a capturing sink: made and received with operation, status, duration, request id; a 500 warns; a thrown transport error logs an error with a stable category and rethrows the same error; a 401 and its replay log two attempts (the transport counts sends per request id; if the id is missing each send is its own attempt 1); secret strings in path, query, header and body never appear in a captured line; Release-style behavior logs nothing for a success.
- Files: `Core/API/LoggingClientTransport.swift` (and helpers in `Core/API/`), `ChristmasTrackerApp.swift` (the single `TrackerClientFactory.make` call only: add the `transport:` argument).

### L3: service audit and step logs
- Contract slice: none. New interface: a small `ServiceLog` helper (started, processed, skipped, cancelled, failed) and a `RefreshReason` enum.
- Acceptance: D3 to D8 for every service; per-service tests with a captured sink (success logs started and processed; failure logs exactly one error; cancellation logs cancelled and no error; skipped line while refreshing; secret fixtures never appear).
- Files: the `*Service.swift` files (list, stats, budget, item, purchase, purchase history, child, link preview, version, authentication) and their tests.

### L4: scan tests
- Acceptance: file-based scans fail when a `*Service.swift` calls a repository without a log call in the file; a log call interpolates a variable outside the allowed kinds; a new file under `Features/*/Services` calls a repository with neither `@Instrumented` nor `InstrumentedOperation`. Each rule is documented in the test comment.

## Inventory (taken 2026-11-17 at baseline)
- Baseline: `scripts/verify.sh` build succeeded; 5410 app tests passed, 0 failed; `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.
- Client creation point: `buildGeneratedClient(...)` in `ChristmasTrackerApp.swift:205` calls `TrackerClientFactory.make` at line 217; it is the only production call (the others are in tests). Result: the sole-creation-point exception applies; `TrackerClientFactory.make` already takes an optional `transport:`.
- Request id: `HeadersMiddleware` generates a UUID per request and sends it as the request header `X-Request-Id`; the server exposes the same header name on responses (client guide, CORS section). The transport reads the response header first and falls back to the request header.
- Performance mechanism: `@Instrumented` (TrackerInstrumentation): a body macro that, in DEBUG or QA, begins an `os_signpost` named `#function` and ends it in a `defer`, and starts `SentrySDK.startTransaction(name: #function, operation: #function)` finished in the `defer`. It records no error status, captures no error and logs nothing itself. It is already applied in every `GeneratedClient*Repository` and a few non-MainActor files. It cannot be applied to `@MainActor` methods, so every service starts spans by hand with `SentrySDK.startTransaction`.
- Logger: global `LogDebug/Info/Warning/Error` call `Logger.shared`; the OS destination logs every level in every build, so Release gating must be done in code (`#if DEBUG`). Signposts: `Logger.shared.signpostBegin/End`.
- Services audited (existing logging before this package): ListService (about 14 `LogInfo`, 4 `LogError`, hand spans), ItemService (3 `LogInfo`, 1 loaded-count `LogInfo`, 3 `LogError`), BudgetService (2 `LogError`), PurchaseService (2 `LogError`), PurchaseHistoryService (1 `LogError`), StatsService (1 `LogError`), ChildService (hand spans, no logs), LinkPreviewService (hand spans, no logs), VersionService (hand span, check where it logs), AuthenticationService (about 40 log calls, existing).
