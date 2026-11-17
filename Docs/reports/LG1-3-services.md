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
