# I3c-6: Separate item load errors per screen; a detail screen that cannot spin forever (Story F1)

Branch: feat/i3c-items. Path: full pipeline (session safety, privacy-sensitive UI). Gate 1: Docs/epics/I3c-items.md "Fix pass Gate 1" > "F1" (commit 8217eec).

## Why (source: Brian's real-mode check, step 11; cause confirmed by reading the code)
`ItemService` had one `loadError`. Pushing the item screen fired `ListDetailView.onDisappear`, which called `clearLoadError()` and wiped the error the item screen's failed load had just set. `ItemDetailView.content` then fell through to `LoadingView` with nothing loading.

## What changed
- `ItemService`: `loadError` and `clearLoadError()` removed. `listLoadError` (set only by `loadItems`/`refreshItems`, cleared at their start, by `clearListLoadError()`, and in `clearForSession`) and `detailLoadError` (set only by `loadItemDetail`, cleared at its start, by `clearDetailLoadError()`, and in `clearForSession`). New `detailLoadToken`: only the newest `loadItemDetail` may set `detailLoadError`, clear `isLoadingDetail`, or publish `currentItem` (the last is a small addition to the spec, required by test `supersededDetailSuccessWritesNothing`). Mutation errors reach neither property. Logging is unchanged (operation names only).
- `ItemDetailScreenState` (new, nonisolated, Equatable, Sendable): `loaded(ListItem)`, `loading`, `error(InlineErrorBannerState)`, `notLoaded`, `resolve(item:isLoading:hasStartedLoading:error:)`, `notLoadedMessage = "This item could not be loaded."`. Order: item -> loaded; loading or not started -> loading (the only spinner); error with a banner -> error; else notLoaded (a `.sessionEnded` error has no banner, so it also gives notLoaded).
- `ItemDetailView`: local `hasStartedLoading` set at the start of `.task`; content switches over `resolve`; Try Again reloads the item; Dismiss clears only the detail error; `.notLoaded` shows the message and a Try Again button (44 pt minimum). `onDisappear` clears the delete error, the item detail and the detail error only.
- `ListDetailView`: only the item-error lines changed (`listLoadError`, `clearListLoadError()` in the banner source, the dismiss handler, `onDisappear`, and one comment).

## Files
Added (production): Features/Items/ViewState/ItemDetailScreenState.swift.
Changed (production): Features/Items/Services/ItemService.swift, Features/Items/Views/ItemDetailView.swift, Features/Lists/Views/ListDetailView.swift.
Added (tests, ChristmasTrackerTests/Features/Items): ItemServiceSeparateErrorsTests (24), ItemDetailScreenStateTests (10), ItemErrorScopeScanTests (7).
Changed (tests): Features/Authentication/SessionTeardownTests (asserts both errors cleared), Features/Items/{ItemServiceLoadTests, ItemServiceMutationTests, ItemServiceListSwitchTests, ItemServiceSessionSafetyTests, ItemUIRulesScanTests}. Deleted: none.

## Existing tests changed (reason for all: F1 removes `loadError`/`clearLoadError()`)
- ItemServiceLoadTests: tests of `loadItems`/`refreshItems` now use `listLoadError`; tests of `loadItemDetail` now use `detailLoadError`; renamed `newLoadClearsListLoadError`, `detailClearsDetailLoadError`, `clearDetailLoadError`. Setup changed in two tests: `refreshFlagAndErrorClear` seeded its error with a failed detail load, which no longer sets the list error, so it now seeds `listLoadError` with a failed `refreshItems` and still asserts it is cleared at the start of the refresh; `listChangeEmptiesItemsAndListLoadError` also seeds a failed refresh and asserts `listLoadError` is cleared.
- ItemServiceMutationTests: each "`loadError == nil`" now asserts both properties nil (stricter); `mutationErrorLeavesLoadErrorAlone` and `mutationSuccessLeavesLoadErrorAlone` renamed to `...DetailLoadErrorAlone` (their precondition is a detail failure); `goneItemIdLifecycle` clears both.
- ItemServiceListSwitchTests: `loadError` -> `listLoadError` (all use `loadItems`).
- ItemServiceSessionSafetyTests: every "`loadError == nil`" has a `detailLoadError == nil` twin; the `.network` precondition in `clearForSessionEmptiesEverything` is `detailLoadError`.
- SessionTeardownTests: asserts both errors nil after teardown.
- ItemUIRulesScanTests: the rule "a file that reads loadError also calls clearLoadError()" is split into the list pair and the detail pair with synthetic positive/negative strings for each, a new `wrongPairDoesNotSatisfy`, and real-source tests `realListLoadError` and `realDetailLoadError`.
No assertion was weakened (acceptance reviewer compared the diffs).

## Test arithmetic (source: command output and grep of `@Test`)
1985 (end of I3c) + 41 new in three new files (24 + 10 + 7) + 5 net new in ItemUIRulesScanTests (git diff: 34 `@Test` lines added, 29 removed or rewritten = renamed declarations in the modified files) - 0 deleted = 2031, matches the run. Package 212, release 92, destination 17.

## Verification (source: commands I ran)
Before the commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 2031 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.020 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
After the commit: see the closing block in Docs/reports/I3c-7-forced-refresh.md (commits are never amended; the after-commit run for this commit is recorded there and in the final message).

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warnings: ItemService.swift is now 403 lines (over the 400 warning, under 600); ItemServiceSeparateErrorsTests 441 lines; lines over 120 characters in new tests; two @Test titles over 160 characters in ItemServiceSessionSafetyTests (lines 148 and 379; line 148 is old, line 379 had its title extended). Banked, not fixed.
- Acceptance-reviewer: APPROVE, no blocking findings; ran verify itself (OK). Focus answers:
  (1) Callers of `clearListLoadError`: ListDetailView.swift:117 (onDisappear) and :357 (dismiss). Callers of `clearDetailLoadError`: ItemDetailView.swift:78 (onDisappear) and :104 (banner Dismiss). Definitions ItemService.swift:158 and :162. No other caller; `ItemErrorScopeScanTests` enforces that each view mentions only its own pair.
  (2) Spinner rule at ItemDetailScreenState.swift:26-31; `hasStartedLoading` and `isLoadingDetail` are both set before the first suspension so no flash of the placeholder. Brian's sequence on paper: push (loading) -> list `onDisappear` clears only the list error -> fetch fails -> error banner stays -> Dismiss gives the quiet placeholder -> Try Again gives loading then the banner again; no endless spinner.
  (3) Generation guards at ItemService.swift:139, :148, :150, :281-295, :386; the added token guard does not suppress a retry of the same item (the newest load wins), nor a mutation update (`updateItem` writes `currentItem` directly).
  (4) Mutations use `failure(...)` and store nothing. (5) Only fixed operation names are logged. (6) Existing tests: renames only, no weakening. (7) Nothing outside scope changed.
- Observations (non-blocking): a detail fetch that ignores cancellation and finishes after the view disappeared could write `currentItem` (pre-existing; the view filters on `itemId`); no test for retrying the same item id while the previous load is in flight (the token logic is covered with different ids).
- No rejection, no rework loop, stuck detector not triggered. Implementer run 1 had one failing test (`supersededDetailSuccessWritesNothing`), fixed in run 2 (changed error signature).

## Deviations, bugs, scope
- Process: the test-writer used `perl -pi -e` one-liners for mechanical renames (the prompt's rule bans `sed -i` and scratch scripts); the result was reviewed and no file outside the test scope changed.
- Environment: the working tree holds an uncommitted local edit to the shared scheme (the `-apiModeOverride real` launch argument for the real-mode check). It makes `ReadConfigurationTests/apiModeFromDictMock` fail, so with Brian's agreement it was stashed for this fix pass and is restored at the end. It is never staged.
- No contract disagreement found; nothing added to Docs/contract-issues.md. No real bug found beyond the one this story fixes.

## Not done or partial
- Real-mode check (Brian's step 11 in the simulator against the real server) NOT PERFORMED; it needs Brian. No simulator or screenshot check of the detail placeholder was made.
- Not added: a same-id retry-in-flight test; no unit tests for the SwiftUI view glue (covered by the truth table of `resolve`, scans and review).
- Banked: file and line length warnings above.
