# I3c-7: Pull to refresh always refreshes and reports a failure (Story F2)

Branch: feat/i3c-items. Path: full pipeline. Gate 1: Docs/epics/I3c-items.md "Fix pass Gate 1" > "F2" (commit 8217eec). Applied deviation D6 below.

## Why (source: Brian's real-mode check, step 11; cause confirmed by reading the code)
`ListDetailView.refreshable` called `load()` = `loadListDetail` + `loadItems`. `loadItems` serves a fresh non-empty cache without a fetch, and a `loadListDetail` failure with a cached detail lands in `ListService.error`, which the screen shows only when no detail is loaded. A failed pull was never reported.

## `.refreshable` audit (source: grep of the whole app, and reading each caller)
| File:line | Calls | Forces the network | Surfaces a failure | Action |
|---|---|---|---|---|
| Features/Lists/Views/ListDetailView.swift:111 | now `refresh()` (was `load()`) | now yes (detail and items) | now yes (two banners) | fixed here |
| Features/Dashboard/Views/DashboardView.swift:55 | `listService.refreshLists()` | yes (always fetches) | yes (`ListService.error` in the list banner or empty-state banner) | none needed |
| Features/Children/Views/ChildrenView.swift:86 | `childService.loadChildren()` | yes (no cache) | yes (error row) | none needed, outside scope |
Banked observation (existing, not changed): `refreshLists` returns silently if a refresh is already running (`isRefreshing`).

## What changed
- `ListService.refreshListDetail(id:) async -> ListError?` (`@discardableResult`, manual Sentry span with the explaining comment): always fetches; success writes the cache and the open detail and returns nil; a failure other than gone keeps the cached detail, logs only the operation name, and returns the typed error (it does not set `ListService.error` or `isLoadingDetail`); gone (404, or 403 on the open detail) is handled as in `loadListDetail` and returns nil; guarded by generation, the list's archive epoch, `reportGuarded` and a new `detailRefreshToken` (only the newest refresh applies; reset in `resetSession`); cancellation and an ended session return nil and write nothing.
- `ListDetailRefresh` (new, nonisolated): `banner(for:)` (nil for nil and `.sessionEnded`; message "The list could not be refreshed. " + `userMessage`; Try Again only for retryable errors; always dismissible) and `itemsStep(currentItemsListId:listId:)` (`.refresh` when the items service already holds the list, else `.load`).
- `ListDetailView`: `@State refreshError`; `refresh()` clears it, awaits `refreshListDetail`, then `refreshItems()` (or `loadItems` per `itemsStep`); `.refreshable { await refresh() }`; `.task { await load() }` unchanged (cache-first); an `InlineErrorBanner` at the top of the detail content (Try Again repeats `refresh()`, Dismiss clears it); `onDisappear` clears `refreshError` and the item list error. A failed items refresh shows in the items-section banner (`listLoadError`). Both failing shows both banners once.
- D6 (deviation from the prompt wording "records a refresh failure"): the failure is returned and held in the screen's `@State`, not stored in the service, so it cannot appear on another screen by construction. Accepted by the acceptance reviewer.

## Files
Added (production): Features/Lists/ViewState/ListDetailRefresh.swift.
Changed (production): Features/Lists/Services/ListService.swift (882 lines, was 829; carried size debt), Features/Lists/Views/ListDetailView.swift (410 lines, was 391).
Added (tests): Features/Lists/{ListServiceRefreshDetailTests (22), ListDetailRefreshTests (11), ListDetailRefreshScanTests (8)}.swift; Features/Items/ItemServiceForcedRefreshTests (7).swift. Changed tests: none. Deleted: none.

## Test arithmetic (source: command output and grep of `@Test`)
2031 (end of F1) + 48 new (22 + 11 + 8 + 7) + 0 rewritten - 0 deleted = 2079, matches the run. Package 212, release 92, destination 17.

## Verification (source: commands I ran)
Before the commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 2079 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.020 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
F1 after-commit (6fa89c4, clean tree, run by me):
```
--- xcodebuild exit status: 0 ---
--- tests: 2031 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.022 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.022 seconds.
```
Gate 1 docs commit (8217eec) after-commit: 1985 passed, 0 failed; package 212; release 92; destination 17; `=== verify: OK ===`.
After this commit (F2): see the closing block in Docs/reports/I3c-8-handoff-update.md and the final message (commits are never amended).

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warnings: ListService.swift 882 lines (carried debt, +53); ListDetailView.swift 410 lines (over the 400 warning); `refreshListDetail` about 47 lines with a repeated three-part guard (optional helper); ListServiceRefreshDetailTests 425 lines; possible long test lines. Banked.
- Acceptance-reviewer: APPROVE, no blocking findings; ran verify itself (OK). Focus answers:
  (3) Detail: `refreshListDetail` always calls `fetchListDetail` (ListService.swift:284). Items: `refreshItems` calls `fetchAndStore` unconditionally (ItemService.swift:105-124) when `itemsStep` says `.refresh`. Detail only fails: banner at the top (ListDetailView.swift:222-228), cached detail stays. Items only fail: items-section banner (ItemsSectionView.swift:24-25), cached items stay. Both: both banners once. 404/403 on the open detail: screen leaves through `goneListId` (ListDetailView.swift:105-110). Initial `.task` still `load()` (ListDetailView.swift:114-116), pinned by a scan test.
  (4) `@State refreshError` (ListDetailView.swift:26); cleared on dismiss (:226), at the start of each refresh and on success (:150-151), and on disappear (:118); Try Again calls `refresh()` (:225); the service stores nothing (ListService.swift:269, :309).
  (5) Audit as the table above; exactly three `.refreshable` in the app; only Features/Lists files (and tests) changed.
  (6) Guards at ListService.swift:276-289, :296-297, `resetSession` :630-648; a cancelled pull returns nil and is never a failure (repository maps `URLError.cancelled` to `CancellationError`, GeneratedClientListRepository.swift:294-304; `perform` cancels with the caller). The 403 drop is narrower than `loadListDetail` (only when the open detail is this list), equivalent for any screen that can pull.
  (7) No existing test changed; no vacuous assertion found. Weak spots: `olderFailureAfterNewerSuccess` does not assert the older call's return value; the view's `@State` clearing and the Try Again wiring are not unit-tested.
  (8) Logging: fixed strings "Refreshed list detail" and "refresh list details failed" only.
- Findings accepted, not fixed: (1) MINOR a pull that lands before the initial load has set the items service's list takes the cache-first `loadItems` branch (spec choice; narrow window; hardening: call `loadItems` then `refreshItems`); (2) MINOR a superseded older refresh returning nil could clear a newer refresh's banner (no realistic path, the banner is cleared at the start of each refresh); (3) NIT doc comment says nil "when the session ended" though a repository-reported `.sessionEnded` is returned as a value (the banner maps it to nil); (4) NIT `refresh()` still refreshes items after a 404 (one extra request while the screen leaves).
- No rejection, no rework loop, stuck detector not triggered (one implementer attempt).

## Deviations, bugs, scope
- D6 as above. No contract disagreement found; nothing added to Docs/contract-issues.md. No real bug found beyond the one this story fixes.
- Environment: the local scheme edit stays stashed for this pass (see I3c-6).
- Nothing outside Features/Items and Features/Lists (and tests, docs) changed.

## Not done or partial
- Real-mode check (step 11 against the real server) NOT PERFORMED; it needs Brian. No simulator or screenshot check of the refresh banners.
- Not tested: the view's `@State` clearing on disappear and the Try Again wiring (covered by the scan and review only).
- Banked: the findings and warnings above; `ListService.swift` split (882 lines).
