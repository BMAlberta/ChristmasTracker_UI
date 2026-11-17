# LG1-L3: service audit and step logs

Branch feat/lg1-client-logging. Solo mode. Batch A: StatsService, BudgetService, PurchaseHistoryService.
Later batches append their own sections below.

## What changed (batch A)

- New `Core/Logging/ServiceLog.swift`: `ServiceLog` (started, processed, skipped, cancelled, failed) and
  `RefreshReason` (pull, appear, tab, session, unspecified). Step lines are `.debug`, category `.business`,
  verbose (Debug) only; `failed` is written in every build at `.error`; `cancelled` is never an error.
- Each service takes `log: ServiceLog = ServiceLog()` as a defaulted init parameter.
- The hand-written `SentrySDK.startTransaction`/`finish()` was replaced by `InstrumentedOperation.run` with the
  same span names in every repository-calling method.
- Existing failure wording kept (one `.error` per failure, now routed through `ServiceLog.failed`, so it is
  testable): "load stats failed" (load and refresh), "load budgets failed", "budget mutation failed",
  "load purchase history failed".
- Refresh reasons: defaulted `reason: RefreshReason = .unspecified` on `StatsService.load/refresh`,
  `BudgetService.loadBudgets`, `PurchaseHistoryService.loadPage`. UI call sites updated (no change to when or
  whether anything runs): `StatsScreenModel` (onAppear = appear, refresh = pull, others unspecified),
  `PurchaseHistoryModel` (`onAppear(reason:)` default appear, `refresh(reason:)` default unspecified, plumbed to
  `loadPage`), `PurchaseHistoryView` (`.refreshable` = pull, session-generation change = session).
- No message interpolates an error, id, year, name or amount. Counts use literal nouns ("budgets", "rows").

## Audit table (batch A)

| service | method | had logging before | has now | performance wrapper |
|---|---|---|---|---|
| StatsService | load(year:reason:) / refresh(year:reason:) (shared `fetch`) | one `.error` ("load stats failed") | started (reason), processed, cancelled, one failed | helper (`service.stats.load` / `service.stats.refresh`) |
| StatsService | load(year:) fresh-cache early return | none | none (no call is made; not an "already refreshing" guard) | n/a |
| StatsService | clearForSession | none | none (no repository call) | hand span kept: no repository call, teardown only, left as is |
| StatsService | stats(for:), failure(forYear:), dropBudget, markSpendingStale, clearLoadFailure | none | none (sync state, no API) | n/a |
| BudgetService | loadBudgets(force:reason:) | one `.error` ("load budgets failed") | started (reason), processed (N budgets), cancelled, one failed | helper (`service.budgets.load`) |
| BudgetService | loadBudgets fresh-cache early return | none | none (no call; not an "already refreshing" guard) | n/a |
| BudgetService | create / update / duplicate (shared `store`) | one `.error` ("budget mutation failed") | started, processed, cancelled, one failed | helper (`service.budgets.create/update/duplicate`) |
| BudgetService | delete(year:) | one `.error` (also fired for an already-gone delete) | started, processed (also for already gone), cancelled, one failed | helper (`service.budgets.delete`) |
| BudgetService | clearForSession | none | none (no repository call) | hand span kept: no repository call |
| PurchaseHistoryService | loadPage(filter:cursor:reason:) | one `.error` ("load purchase history failed") | started (reason), processed (N rows), cancelled, one failed | helper (`service.purchaseHistory.loadPage`) |
| PurchaseHistoryService | clearForSession | none | none (no repository call) | hand span kept: no repository call |

No `isRefreshing` style guard exists in these three services, so `skipped` is not emitted by them (the only
early returns are fresh-cache hits, which make no call). `ServiceLog.skipped` exists and is unit tested for the
later batches.

## Deviations and notes

- `BudgetService.delete`: previously a notFound (already deleted) logged "budget mutation failed" and then
  succeeded. Now the gone case logs `processed` and no error (a success must not log an error). State behavior
  is identical.
- Stats: a result superseded by a newer landed fetch (the `sequence < landed` drop) logs `cancelled`; a real
  failure whose result is superseded still logs its single `failed` line, as before.
- A mutation that ended with a stale-mutation discard in `loadBudgets` (a mutation landed while the load was in
  flight) logs `cancelled`.
- Stats and budget load methods swallow errors by design, so the span status is `.ok` for them (same as the old
  hand span, which had no status).
- `PurchaseHistoryModel.returnedFromPurchase` and Try Again stay `.unspecified` (not clearly pull/appear/tab).
- `InstrumentedOperation` writes its own `.performance` duration line through the default sink; it is not
  captured by the per-service test sinks (tests assert the service lines only).

## Edited existing tests

- EDITED (LG1-3): ChristmasTrackerTests/Features/Budgets/BudgetSourceScanTests.swift: the signature scan string for
  `loadBudgets` now includes the new defaulted `reason: RefreshReason = .unspecified` parameter; the check is
  otherwise unchanged.

## New tests

- ChristmasTrackerTests/Core/Logging/ServiceLogTests.swift
- ChristmasTrackerTests/Features/Statistics/StatsServiceLogTests.swift
- ChristmasTrackerTests/Features/Budgets/BudgetServiceLogTests.swift
- ChristmasTrackerTests/Features/PurchaseHistory/PurchaseHistoryServiceLogTests.swift

## Commands and raw summary lines

- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- `scripts/test.sh` (first run after the implementation): `--- tests: 5486 passed, 1 failed, 0 skipped ---`
  (FAIL BudgetSourceScanTests/budgetServiceSignatures: the signature string, fixed as listed above)
- `scripts/test.sh` (final): `--- xcodebuild exit status: 0 ---`, `--- tests: 5487 passed, 0 failed, 0 skipped ---`
  (baseline 5410; scripts/verify.sh not run, per instruction)
- Attempts: 1 implementation loop plus one single-line test fix; no repeated error signature; no flaky test.

## Not done or partial

- Batch B and later services (List, Item, Purchase, Child, LinkPreview, Version, Authentication) are not touched.
- `skipped` is not emitted by any batch A service (no already-refreshing guard exists in them).
- `clearForSession` in the three services keeps its hand span (no repository call, teardown only).
- Screenshot / visual check: not performed (no UI layout change).
- PurchaseHistory Try Again and returnedFromPurchase reasons left as `.unspecified`.

# Batch B: ItemService, PurchaseService, ChildService

## What changed (batch B)

- Each service takes `log: ServiceLog = ServiceLog()` as a defaulted init parameter (PurchaseService: on both inits).
- Every method that calls a repository now runs inside `InstrumentedOperation.run` with the same span name as
  the old hand span, and writes started, processed, cancelled and exactly one failed line through `ServiceLog`.
- Old `LogError` lines folded into `ServiceLog.failed` with the wording kept ("load items failed",
  "refresh items failed", "load item detail failed", "create/update/delete item failed", "record purchase failed",
  "purchase management failed"). The ItemService `LogError("\(operation) failed")` interpolation was only ever fed
  the literals "load items" and "refresh items" (confirmed at both call sites); it is now `log.failed(op)` with
  the same literals.
- Existing `LogInfo` success lines in ItemService ("Created item", "Updated item", "Deleted item", "Loaded N
  items") kept unchanged (D6); no new `.info` lines.
- `ItemService.loadItems` and `refreshItems` take `reason: RefreshReason = .unspecified`. UI call sites:
  `ListDetailView.load()` passes `.appear` (the `.task`), `ListDetailView.refresh()` passes `.pull`
  (`.refreshable`). The Try Again path and `PurchaseRefreshRunner` stay `.unspecified`.
- Stale "manual SentrySDK span" comments fixed in the touched methods.
- ChildService header comment said "Nothing is logged here"; updated to describe the ServiceLog lines.

## Audit table (batch B)

| service | method | had logging before | has now | performance wrapper |
|---|---|---|---|---|
| ItemService | loadItems(listId:reason:) | one `.error` ("load items failed", silent on cancel/stale) | started (reason), processed (N items), cancelled (cancel, session end, superseded), one failed | helper (`service.items.loadItems`) |
| ItemService | refreshItems(reason:) | one `.error` ("refresh items failed") | started (reason), processed (N items), cancelled, one failed | helper (`service.items.refreshItems`) |
| ItemService | refreshItems no-list guard | none | none (no list loaded, nothing to refresh; not an "already refreshing" guard) | n/a |
| ItemService | loadItemDetail(id:) | one `.error` ("load item detail failed") | started, processed, cancelled (also when superseded), one failed | helper (`service.items.loadItemDetail`) |
| ItemService | createItem / updateItem / deleteItem | one `.error` each + `LogInfo` success | started, processed, cancelled, one failed; `LogInfo` unchanged | helper (`service.items.createItem/updateItem/deleteItem`) |
| ItemService | clearForSession | none | none (no repository call) | hand span kept: no repository call, teardown only |
| ItemService | clear*/ sync state methods | none | none (no API) | n/a |
| PurchaseService | recordPurchase | one `.error` ("record purchase failed") | started, processed, cancelled, one failed | helper (`service.purchases.recordPurchase`) |
| PurchaseService | fetchPurchase / updateNotes / updateShipping / deletePurchase (shared `runManagement`) | one `.error` ("purchase management failed") | started ("fetch purchase", "update purchase notes", "update purchase shipping", "delete purchase"), processed, cancelled, one failed ("purchase management failed") | helper (`service.purchases.fetchPurchase/updateNotes/updateShipping/deletePurchase`) |
| PurchaseService | clearForSession | none | none (no repository call) | hand span kept: no repository call |
| ChildService | loadChildren | none (silent) | started, processed (N children), cancelled, one failed | helper (`service.children.loadChildren`) |
| ChildService | addChild / deleteChild | none (silent) | started, processed, cancelled, one failed ("add child failed", "delete child failed") | helper (`service.children.addChild/deleteChild`) |
| ChildService | clearForSession | none | none (no repository call) | hand span kept: no repository call |
| ChildService | clearLoadFailure | none | none (sync state) | n/a |

ChildDeletionFlow.swift was not touched.

## Deviations and notes (batch B)

- `ItemService` list and detail load failures that were silently dropped (cancellation, session ended, superseded
  by a newer load) now log `cancelled`. A real failure of a superseded load is no longer an error line (it logs
  `cancelled`, because its result is discarded); state behavior is identical.
- `ItemService.loadItems` now logs one `processed` line at the end of both the cache-hit and the fetch paths
  (count is `items.count` after the result is applied).
- `ChildService.deleteChild` of an already-gone child (`childNotFound`) is still thrown as before, so it logs one
  `failed` line, same as any thrown failure (the existing behavior treats it as a thrown error).
- `skipped` is not emitted by any batch B service: none has an "already refreshing" guard.
- Releases: only the failed line is written in Release; all step lines are Debug (verbose) only.

## Edited existing tests (batch B)

- EDITED (LG1-3): ChristmasTrackerTests/Features/Purchases/PurchaseLogHygieneScanTests.swift: `serviceStaticLinesExist`
  asserted PurchaseService contains exactly two direct `Log*(` calls; those two `LogError` lines moved into
  `ServiceLog.failed`. It now asserts zero direct `Log*(` calls, exactly two `log.failed(` call sites, and still
  no violations (non-vacuity kept). The `Log*(` scan only matches that spelling, so it no longer sees the
  lowercase `log.<step>(` calls; the new ServiceLogCallScanTests (below) enforces the same "fixed literal, no
  interpolation" rule for them (Gate 2 finding).

## New tests (batch B)

- ChristmasTrackerTests/Features/Items/ItemServiceLogTests.swift
- ChristmasTrackerTests/Features/Purchases/PurchaseServiceLogTests.swift
- ChristmasTrackerTests/Features/Children/ChildServiceLogTests.swift
- ChristmasTrackerTests/Features/Purchases/ServiceLogCallScanTests.swift: a source scan over PurchaseService,
  ItemService and ChildService (add a path to `ServiceLogCallScan.files` for later services). Every
  `log.<started|processed|cancelled|failed|skipped>(` argument list must be the operation identifier or a
  literal without `\(`, `op, count: <identifier path>, noun: "<literal>"`, or `op, reason: <identifier>`, and every
  `let op`/`let opName` must be a plain literal. It has self-proofs (fires on `log.started("x \(price)")`,
  `log.processed(notes)`, a non-literal noun, a non-literal `let op`; allows the fixed shapes) and a non-vacuity
  check per file.

Each of the three service log test files covers: started and processed on success, exactly one `.error` on failure, `cancelled` and no `.error` on
session end mid-call, Release-style (`LogVerbosity(isVerbose: false)`) logs only the failure line, and secret
fixtures ("ZZ-secret-name", 987654.32, "zz-secret@example.com", note text) never appear in a captured line.
No `skipped` test (no guard exists).

## Commands and raw summary lines (batch B)

- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- `scripts/test.sh` (first run): `--- tests: 5514 passed, 1 failed, 0 skipped ---`
  (FAIL PurchaseLogHygieneScanTests/serviceStaticLinesExist: expected two `LogError` calls, found 0; test updated
  as listed above)
- `scripts/test.sh` (after the first fix): `--- tests: 5515 passed, 0 failed, 0 skipped ---`
- `scripts/test.sh` (final, after Gate 2 fixes: ServiceLogCallScanTests added, one long line wrapped):
  `--- xcodebuild exit status: 0 ---`, `--- tests: 5519 passed, 0 failed, 0 skipped ---`
  (scripts/verify.sh not run, per instruction)
- Attempts: 1 implementation loop plus one test update; no repeated error signature; no flaky test.

## Not done or partial (batch B)

- Later services (List, LinkPreview, Version, Authentication) are not touched.
- `PurchaseRefreshRunner` and the Try Again paths still call the item loads with `.unspecified` (not clearly
  pull/appear/tab).
- Screenshot / visual check: not performed (no UI layout change; only two reason arguments added).
- ItemService.swift is 414 lines (it was 403 before), over the 400-line guideline; not split (scope).

# Batch C: ListService, LinkPreviewService, VersionService

## What changed (batch C)

- Each service takes `log: ServiceLog = ServiceLog()` as a defaulted init parameter (last parameter).
- Every repository-calling method runs inside `InstrumentedOperation.run` with the same span name as the old hand
  span and writes started (after guards), processed (after the result is applied), cancelled and exactly one failed
  line through `ServiceLog`. Failure wording kept: "load lists failed", "refresh lists failed", "load list details
  failed", "refresh list details failed", "create list failed", "update list failed", "remove co-owner failed",
  "archive list failed", "fresh lists failed", "archive list in batch failed", "reload lists after archive batch
  failed", "add member failed", "remove member failed", "leave list failed", and the sub-operation lines
  ("refresh list after member change failed", "reload lists after archive failed", "refresh list after archive failed").
  `record(...)` / `failure(...)` (private helpers, label `operation:` renamed `op:` so the scan accepts them) now write
  through `ServiceLog.failed`; a nil result (cancellation, ended session) now logs `cancelled`.
- The pull-to-refresh diagnostic: `refreshLists(reportingFailure:reason:)` logs "refresh lists started (pull)",
  "refresh lists skipped (already refreshing)" at the `isRefreshing` guard (no call made), "refresh lists cancelled" on
  CancellationError (SwiftUI cancelling the refreshable task), "refresh lists processed (N lists)" or one "refresh
  lists failed". The same lines are written when `loadLists` runs the background refresh of a stale cache (it passes
  its reason on). The refresh itself (guards, state, when it runs) is unchanged.
- Reasons (defaulted `reason: RefreshReason = .unspecified`): `loadLists`, `refreshLists`, `loadListDetail`,
  `refreshListDetail`. UI call sites: `DashboardView` `.refreshable` = pull, `.task` = appear; `ListDetailView.load()`
  = appear, `ListDetailView.refresh()` = pull. Try Again (dashboard `retryLoad`, detail `refetchDetail`),
  `BudgetEditorModel` and `PurchaseRefreshRunner` stay `.unspecified`. `freshLists` and `archiveLists` take no reason
  (called by the child deletion flow, not a user refresh).
- D8: `archiveLists` no longer logs per list. One started, one processed ("N lists", N = archived), and one failed line
  if an archive failed (the old "archive list in batch failed" wording, now after the loop). A failed reload after the
  loop keeps its own "reload lists after archive batch failed" line; a cancelled reload is no longer an error line.
  Batch behavior (order, stop at first failure, one reload, result) is identical.
- LinkPreviewService.imageUrl: two operations, "link preview lookup" (API repository) and "device link preview" (the
  provider fallback), each started/processed/cancelled/failed. An invalid page URL makes no call and logs nothing. No
  URL, host or image value ever reaches a line or the span.
- VersionService.check: "check version" started/processed/cancelled/failed; `checkIfDue` early returns (in flight,
  inside the success interval, inside the failure interval) make no call and log nothing. State handling is unchanged
  (a cancellation still records a failure and `.showMessage`, only the log differs).
- Existing `LogInfo` success lines in ListService kept (D6). Stale "manual SentrySDK span" comments fixed in touched
  methods.

## Audit table (batch C)

| service | method | had logging before | has now | performance wrapper |
|---|---|---|---|---|
| ListService | loadLists(reportingFailure:reason:) | one `.error` ("load lists failed") + `LogInfo` | started (reason), processed (N lists), cancelled, one failed; waiter path logs nothing | helper (`service.lists.loadLists`) |
| ListService | refreshLists(reportingFailure:reason:) (and the background refresh inside loadLists) | one `.error` ("refresh lists failed") + `LogInfo` | started (reason), skipped (already refreshing), processed (N lists), cancelled, one failed | helper (`service.lists.refreshLists`) |
| ListService | loadListDetail(id:reason:) | one `.error` ("load list details failed") + `LogInfo` | started (reason), processed, cancelled, one failed | helper (`service.lists.loadListDetail`) |
| ListService | refreshListDetail(id:reason:) | one `.error` ("refresh list details failed") + `LogInfo` | started (reason), processed, cancelled, one failed | helper (`service.lists.refreshListDetail`) |
| ListService | createList / updateList / removeCoOwner | one `.error` each + `LogInfo` | started, processed, cancelled, one failed | helper (`service.lists.createList/updateList/removeCoOwner`) |
| ListService | deleteList (op "archive list") | one `.error` + `LogInfo` | started, processed, cancelled, one failed | helper (`service.lists.deleteList`) |
| ListService | freshLists | one `.error` ("fresh lists failed") | started, processed (N lists), cancelled, one failed | helper (`service.lists.freshLists`) |
| ListService | archiveLists(ids:) (op "archive list in batch") | `.error` per failure inside the loop, one reload `.error`, `LogInfo` | started, processed (N lists), cancelled, one failed after the loop; separate reload failed line | helper (`service.lists.archiveLists`) |
| ListService | archiveLists empty ids | none | none (no call) | n/a |
| ListService | addMember / removeMember / leaveList | one `.error` each + `LogInfo` | started, processed, cancelled, one failed | helper (`service.lists.addMember/removeMember/leaveList`) |
| ListService | setCoOwner | none of its own | delegates to updateList ("update list" lines) | via updateList |
| ListService | clearCache / clearForSession | none | none (no repository call) | hand span kept: no repository call, teardown only |
| ListService | clear*Failure, clearCurrentDetail, filters (sync state) | none | none | n/a |
| LinkPreviewService | imageUrl(for:) API step | none (silent) | started, processed, cancelled, one failed ("link preview lookup") | helper (`service.linkPreview.imageUrl`) |
| LinkPreviewService | imageUrl(for:) device fallback step | none (silent) | started, processed, cancelled, one failed ("device link preview") | same helper span |
| LinkPreviewService | imageUrl invalid URL | none | none (no call) | n/a (returns before the span, as before) |
| LinkPreviewService | clearForSession | none | none (no repository call) | hand span kept: no repository call |
| VersionService | check() | none (silent) | started, processed, cancelled, one failed ("check version") | helper (`service.version.check`) |
| VersionService | checkIfDue() early returns | none | none (no call; not logged by instruction) | n/a (span comes from check) |

## Deviations and notes (batch C)

- `refreshListDetail`: a not-found or forbidden answer that drops the list (no error is returned, as before) logs
  `processed` (the call completed and the list was handled), not an error. A superseded or session-ended refresh logs
  `cancelled`.
- `updateList` / `removeCoOwner`: a list removed while the call was in flight (nothing written back, as before) logs
  `cancelled`.
- `loadLists`/`loadListDetail`/`refreshLists` results dropped because an archive finished meanwhile, or the session
  ended, log `cancelled` (previously silent).
- A real error thrown while the caller task is cancelled (for example a URLError.cancelled from the transport when
  SwiftUI cancels a pull to refresh) is NOT a CancellationError, so it still logs the one failed line and still stores
  the load failure, exactly as before. That is deliberate: it is what the new lines will reveal. Only a
  CancellationError logs `cancelled`.
- `deleteList`: a failed reload after a successful archive still writes its own sub-operation error line
  ("reload lists after archive failed") while the archive itself logs `processed` (one line per failure, as before).
- LinkPreview device fallback is a provider (LinkPresentation), not a repository; it is logged as its own operation
  because it is a call that can fail. Its failed line is an `.error` in Release; drop it if that is too noisy.
- ListService.swift is now 1169 lines (was 1130). Not split: the scope list does not allow other files and a split
  would touch the test source scans.
- `InstrumentedOperation` writes its own `.performance` duration lines through the default sink; they are not in the
  per-service test sinks.
- Failing tests first: the new test files call `ListService(..., log:)`, `loadLists(reason:)`, `refreshLists(reason:)`
  and the `log:` parameters that did not exist, so they did not compile before the implementation (red by compile
  failure; a separate red run was not made).

## Edited existing tests (batch C)

- EDITED (LG1-3): ChristmasTrackerTests/Features/Purchases/ServiceLogCallScanTests.swift: `ServiceLogCallScan.files`
  now also lists ListService.swift, LinkPreviewService.swift and VersionService.swift. Every rule and self-proof is
  unchanged (the three files also pass the non-vacuity check).

## New tests (batch C)

- ChristmasTrackerTests/Features/Lists/ListServiceLogTests.swift (success lines with reason, failure one error, cancelled
  load/refresh/detail/create/archive/member, skipped while refreshing with no second repository call, "started (pull)",
  D8 batch aggregation, Release-style, secrets "ZZ-secret-list", "987654.32", "zz-secret@example.com")
- ChristmasTrackerTests/LinkPreview/LinkPreviewServiceLogTests.swift (page "https://zz-secret.example/item")
- ChristmasTrackerTests/Features/Version/VersionServiceLogTests.swift

## Commands and raw summary lines (batch C)

- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- `scripts/test.sh`: `--- xcodebuild exit status: 0 ---`, `--- tests: 5567 passed, 0 failed, 0 skipped ---`
  (batch B final 5519; scripts/verify.sh not run, per instruction)
- Attempts: 1 implementation loop, green first time; no repeated error signature; no flaky test.

## Not done or partial (batch C)

- AuthenticationService and any later service are not touched.
- The pull-to-refresh problem itself is not investigated or fixed (diagnostic lines only).
- Try Again paths, `BudgetEditorModel` and `PurchaseRefreshRunner` call the list loads with `.unspecified`; `freshLists` and
  `archiveLists` have no reason parameter.
- `VersionService.checkIfDue` logs nothing for its early returns (no call), so there is no "already checking" line.
- Screenshot / visual check: not performed (no UI layout change; only reason arguments added at four call sites).
- ListService.swift is 1169 lines, over the guideline; not split (scope).

# Batch D: AuthenticationService

## What changed (batch D)

- `AuthenticationService.init` takes `log: ServiceLog = ServiceLog()` as the last parameter.
- login, register, signInWithBiometric, refreshTokenIfNeeded and forceRefresh run inside `InstrumentedOperation.run`
  (span names unchanged except login, see deviations) and write started, processed, cancelled and exactly one failed
  line through `ServiceLog`. Operation names: "auth login", "auth register", "auth biometric sign-in", "auth refresh",
  "auth force refresh", "auth logout".
- Privacy: every `LogError` that interpolated an error value is gone. "Login failed: \(authError)", "Login failed:
  \(error)", "Registration failed: ...", "Biometric sign-in: credential error / credential store error / auth error /
  network or unknown error: ...", "Token refresh failed (non-credential): ...", "Token refresh failed: \(error)",
  "Logout API failed (best-effort): \(error)" are now the literal "<op> failed" line. The "Token refresh credential
  failure - session ended" and "Forced refresh credential failure - session ended" `LogError`s became the single
  "auth refresh failed" / "auth force refresh failed" line (the session end follows as before). The
  "Session ended by the server: \(reason)" `LogInfo` is now the literal "Session ended by the server".
  Non-interpolated `LogInfo`/`LogDebug` lines stay (D6).
- Auth logic untouched: order and conditions of Keychain, biometrics, refresh single-flight, session end guard.
- No UI call site changed (no refresh reason for auth).

## Audit table (batch D)

| service | method | had logging before | has now | performance wrapper |
|---|---|---|---|---|
| AuthenticationService | login | `.error` with the error interpolated ("Login failed: ...") + `LogInfo` | started, processed, cancelled, one failed (literal) | helper (`AuthenticationService.login`) |
| AuthenticationService | register | `.error` with error interpolated + `LogInfo` | started, processed, cancelled, one failed | helper (`service.authentication.register`) |
| AuthenticationService | signInWithBiometric | `.error` x4 variants, error interpolated | started, processed, cancelled (also a dismissed Face ID prompt, `.userCancelled`), one failed (other credential errors or refresh failure) | helper (`service.authentication.signInWithBiometric`) |
| AuthenticationService | refreshTokenIfNeeded | `.error` x3 (two interpolated) | started (not logged when no refresh is due), processed, cancelled, one failed (credential or not) | helper (`service.authentication.refreshTokenIfNeeded`) |
| AuthenticationService | forceRefresh | `.error` for credential failure only | started (after the no-token guard), processed, cancelled, one failed (any error), error still rethrown | helper (`service.authentication.forceRefresh`) |
| AuthenticationService | best-effort logout API call in performSessionEnd | `.error` with error interpolated | started, processed, cancelled, one failed ("auth logout", written by the unawaited task when the call runs) | none new (see below) |
| AuthenticationService | logout / endSession / handleServerSessionEnd | none (one `LogInfo` interpolated the reason) | none of its own; `LogInfo` now literal | hand span kept: they make no repository call themselves; the API call is an unawaited task, and wrapping it would add a new span name |
| AuthenticationService | enrollCurrentSession, clearForSession | none | none (no repository call: Keychain / local state) | hand span kept |
| AuthenticationService | revokeEnrollment, clear*, refreshBiometricState, recordActivity | none | none (sync or local) | n/a |

## Audit: API-calling code outside *Service.swift (report only, no change)

Searched every non-`*Service.swift`, non-repository, non-Mock Swift file for repository, API client, loader,
provider, URLSession and image-fetch calls. Callers of the services (views and view-state models: CreateListView,
EditListView, ChildrenView, ItemsSectionView, ProfileView, ProfileBiometricToggleModel, StatsScreenModel,
PurchaseHistoryModel) only go through services; none calls a repository or the API directly (the only repository
references in those files are `Mock*Repository()` in `#Preview` blocks). Calls that reach the network and are NOT
covered by a service's step lines:

- `Features/Items/Components/ItemThumbnail.swift:27`: `AsyncImage(url:)` downloads the item image through
  URLSession.shared, not the generated client and not the logging transport. No service line, no transport line.
- `Features/LinkPreview/Providers/LinkPresentationProductImageProvider.swift:78`: `startFetchingMetadata(for:)`
  (LPMetadataProvider) fetches a product page. It is the "device link preview" operation of LinkPreviewService, so
  its outcome is covered by that service's started/processed/failed lines (batch C), but it bypasses the logging
  transport (not the generated client).
- `Core/API/ClientSeams.swift:55`: `service.forceRefresh()` goes to AuthenticationService (now covered).
- `ProfileView.swift:60` / `InactivityLockController.swift:137`: `authService.logout(...)` (now covered).
- `SessionManager` makes no API call (teardown clears URLCache and registered clearables only).

All generated-client requests (the repositories) are logged by the transport.

## Deviations and notes (batch D)

- `login` span: the hand span was `name: "AuthenticationService.login", operation: "auth"`. The helper uses the name
  as the operation too, so the Sentry op becomes "AuthenticationService.login". The name is unchanged.
- A cancelled login or register still sets `error = .networkError` (existing behavior kept); only the log differs
  (cancelled, no error line).
- The "auth logout" lines are written by the best-effort task, not by `logout()`, because the API call is unawaited
  and the tests require processed only when the call really succeeds. A superseded session end makes no call and
  logs nothing. `endSession` for an already-ended session logs nothing.
- Biometric credential failures (for example the user cancelling the Face ID prompt) log the one "auth biometric
  sign-in failed" error line, as the old code logged an error line for them. Cancel it to `cancelled` later if too noisy.
- `InstrumentedOperation` writes its own `.performance` line through the default sink; not captured by test sinks.
- Gate 2 fix: the biometric prompt cancel (`BiometricCredentialError.userCancelled`) now logs cancelled, not failed
  (this replaces the earlier note on it). A URLError.cancelled reaching a generic catch is still logged as failed
  (only CancellationError is cancelled) if the auth repository does not map it.

## Edited existing tests (batch D)

- EDITED (LG1-3): ChristmasTrackerTests/Features/Purchases/ServiceLogCallScanTests.swift: `ServiceLogCallScan.files`
  now also lists Features/Authentication/Services/AuthenticationService.swift. Only the list changed; rules and
  self-proofs unchanged, and the new file passes the non-vacuity check.

## New tests (batch D)

- ChristmasTrackerTests/Features/Authentication/AuthenticationServiceLogTests.swift (written by the isolated
  test-writer; not edited)

## Commands and raw summary lines (batch D)

- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- `scripts/test.sh`: `--- xcodebuild exit status: 0 ---`, `--- tests: 5578 passed, 0 failed, 0 skipped ---`
  (batch C 5567; scripts/verify.sh not run, per instruction)
- Attempts: 1 implementation loop, green first time; no repeated error signature; no flaky test.

## Not done or partial (batch D)

- No refresh reason for auth (none is needed).
- logout / endSession / handleServerSessionEnd / enrollCurrentSession / clearForSession keep their hand spans.
- The non-service gaps listed above (ItemThumbnail `AsyncImage`, the LPMetadataProvider fetch bypassing the transport)
  are reported, not changed.
- Screenshot / visual check: not performed (no UI change).
