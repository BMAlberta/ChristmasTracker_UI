# iOS to Brian: LG1 client logging coverage
Date: 2026-11-17. Branch: `feat/lg1-client-logging` (from main). Not pushed.

## Contract issues found
None. No contract, decision or synced doc was read differently from what the server does; nothing was added to `Docs/contract-issues.md`.

## What changed (commits)
| Commit | Story |
|---|---|
| `daeafb7` | Epic brief and inventory |
| `d69fcea` | L1: `InstrumentedOperation` helper and `OperationLogging` sink (app target, `Core/Logging/`) |
| `3e231b1` | L2: `LoggingClientTransport`, wired at the one client creation point |
| `b99dab9` | L3 batch A: `ServiceLog`/`RefreshReason`, Stats, Budget, PurchaseHistory |
| `719a4e1` | L3 batch B: Item, Purchase, Child |
| `41f5404` | L3 batch C: List, LinkPreview, Version |
| `7ad8a2b` | L3 batch D: Authentication |
| `f7712f1` | L4: three scan tests (R1 logs when calling, R2 no data in a log call, R3 instrumented) |

In short: every real network attempt is now logged at the transport (operation, method, attempt, status, duration in ms, request id; made and received lines in Debug only; failures only in Release). Every service method that calls a repository logs "started", "processed", "cancelled" (never an error) or exactly one "failed" line. Refresh entry points log a reason (pull, appear, tab, session) and "skipped (already refreshing)" when the guard returns. Only operation names, reasons, counts with a literal noun, status, durations and the request id ever reach a line.

## Test counts
- Baseline (before): app 5410 passed, 0 failed, 0 skipped; TrackerAPI package 212 tests in 16 suites passed.
- Final (after `f7712f1`, `scripts/verify.sh`): build succeeded; app 5598 passed, 0 failed, 0 skipped; package 212 passed. (Per commit: 5418, 5461, 5487, 5519, 5567, 5584, 5598.)

## Edited existing tests
- EDITED (LG1-3): `ChristmasTrackerTests/Features/Budgets/BudgetSourceScanTests.swift`: the expected `loadBudgets` signature string now includes the new defaulted `reason` parameter. Nothing relaxed.
- EDITED (LG1-3): `ChristmasTrackerTests/Features/Purchases/PurchaseLogHygieneScanTests.swift` (`serviceStaticLinesExist`): PurchaseService's two failure lines moved into `ServiceLog.failed`, so it now asserts zero direct `Log*(` calls and exactly two `log.failed(` sites. The privacy intent is kept by the new `ServiceLogCallScanTests` (log-call argument shapes) and by scan R2.
- `ServiceLogCallScanTests.swift` was created in this package (batch B) and had paths added to its file list in batches C and D; it is not a pre-existing test.

## Performance mechanism: which functions got what
- `@Instrumented` (macro, unchanged): already on every `GeneratedClient*Repository` method and a few non-MainActor helpers. Nothing was retrofitted (CLAUDE.md). The macro does a Sentry transaction named `#function` plus an os_signpost in DEBUG/QA; it captures no error and logs nothing.
- `InstrumentedOperation.run` (new app-side helper, same span names as the old hand spans): the repository-calling methods of StatsService (fetch), BudgetService (load and the four mutations), PurchaseHistoryService (loadPage), ItemService, PurchaseService, ChildService, ListService (all repository-calling methods), LinkPreviewService (two operations), VersionService (check), AuthenticationService (login, register, biometric sign-in, refresh, force refresh). The helper starts the Sentry span, emits the signpost and a duration line (Debug only), maps cancellation to `.cancelled` and rethrows the identical error.
- Hand spans kept (no repository call, or not behavior-neutral to move): `clearForSession` in every service, ListService `clearCache`, AuthenticationService `enrollCurrentSession`, `logout`, `endSession`, `handleServerSessionEnd`. Reasons are in `Docs/reports/LG1-3-services.md`.
- Side effect: the login span's Sentry operation changed from `"auth"` to `"AuthenticationService.login"` (the helper uses the span name for both). Check that no Sentry filter keys on op `auth`.

## Client creation point
`ChristmasTrackerApp.swift` was touched, because `buildGeneratedClient` (line 205) holds the only production `TrackerClientFactory.make` call. The exact change: in the call at line 217 `sessionEndingHandler: sessionEndingHandler` gained a trailing comma and one argument line was added:
```
            sessionEndingHandler: sessionEndingHandler,
            transport: LoggingClientTransport.production()
```
(+2/-1 lines, no other change in the file.) `LoggingClientTransport.production()` wraps `URLSessionTransport` built from `TrackerURLSessionConfiguration.make()`, the same configuration the factory used by default, so cookie handling stays off. No middleware was added and nothing under `LocalPackages/` changed.

## Open risks
1. `URLError.cancelled`: the transport logs it as cancelled (debug), but a service whose repository does not map it to `CancellationError` still logs "failed" and stores a load failure (as before). If a cancelled lists pull to refresh shows "refresh lists failed", this is probably why. Not changed (no behavior change in this package).
2. Pull to refresh itself is NOT fixed. Several callers still pass `.unspecified` (Try Again paths, `PurchaseRefreshRunner`, `BudgetEditorModel`).
3. Files over the length limit: `ListService.swift` 1169 lines (was 1130), `AuthenticationService.swift` about 704 (was 652), `ItemService.swift` 414 (was 403). All were already over; they need a split story.
4. A superseded or dropped load that used to be silent now logs "cancelled" (including a real failure of a superseded load); `BudgetService.delete` of an already-gone budget now logs "processed" and no error; a dismissed Face ID prompt logs "cancelled"; other biometric credential errors still log one error each (can be noisy).
5. Not covered by any line: `ItemThumbnail.swift:27` (`AsyncImage` through `URLSession.shared`) and `LinkPresentationProductImageProvider.swift:78` (`LPMetadataProvider`) bypass the logging transport. The device link preview fallback is logged by LinkPreviewService.
6. Out of scope, noticed: `LegacyTokenCleaning` and `SessionManager` log lines interpolate `error` / `error.localizedDescription` (pre-existing, not LG1). Worth a follow-up.
7. Scan tests are regex and line based: a repository reached through a variable not named `*Repository` and not `client.` would be missed.
8. New files rely on the project's folder-based membership; no `.pbxproj` change was needed and the build and tests pass.

## Package-end diff
See `Docs/reports/LG1-5-handoff.md` (`git diff --stat main...HEAD`, taken after the final docs commit).

## Line for section 9 of PROGRAM.md
LG1 (client logging coverage): the app now logs every API attempt at the transport (Debug: made, received, failed with operation, status, duration, request id; Release: failures only) and every service step (started, processed, cancelled, failed) with no data in any line, guarded by three scan tests; pull to refresh on the lists screen is made visible but not fixed (next package decides from Brian's check 4).

## Brian's real-mode check
The agents never saw the simulator or the network; none of these steps were PERFORMED by an agent. Needs the local API running (seeded), a Debug build, launch argument `-apiModeOverride real`, and the Xcode console open with the filter `network` and then `business`.

1. **One request, all steps.** Sign in, open the Statistics tab.
   - Look at the `network` and then the `business` filter.
   - Expect: lines for "request made", "response received" (status 200, a duration in ms, a request id) and "processed" for the stats load. The request id matches the line in the API terminal.
2. **Tab switch.** Switch between tabs.
   - Expect: a request line only when the tab calls the API; no line for a tab that does not.
3. **Budgets.** Open Budgets and pull to refresh.
   - Expect: started (pull), made, received, processed.
4. **Lists pull to refresh.** On the lists screen, pull to refresh.
   - Expect (this is the diagnostic): either started, made, received, processed; or started followed by cancelled; or "skipped (already refreshing)"; or no line at all; or started followed by "failed" (see risk 1).
   - WRITE DOWN which one you see and send it to the iOS chat; this decides the next package.
5. **Failure.** Stop the API and pull to refresh on Statistics.
   - Expect: a transport error line (category offline or timeout) and one service error line, no crash.
6. **Release floor.** Run a Release-configuration build on the simulator and repeat steps 1 and 5.
   - Expect: no per-request lines for the success; a failure line with the operation and no request id when the API was unreachable.
7. **Nothing sensitive.** Add an item named "ZZ-secret-name" with a price and a note, record a purchase, then search the console output for ZZ-secret-name, the price, the note text and the email you signed in with.
   - Expect: none of them appears.
