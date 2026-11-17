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
