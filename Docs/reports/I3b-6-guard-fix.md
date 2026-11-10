# I3b-6: guard fix (a removal blocks only loads that started before it completed)

Branch feat/i3b-members-children. Path: full pipeline (session and privacy-sensitive layer). Product decision (Brian): a member who left a list and is re-added must see it after their next load.

## Commits
- `5085d7b` I3b-fix: add fix pass Gate 1 spec (Docs/epics/I3b-members-children.md, "Fix pass Gate 1")
- `6059163` I3b-fix: filter only loads that started before a removal completed (code, tests, handoff)
- this report is a third, docs-only commit: "I3b-fix: add the guard fix report"

## Files
Added: `ChristmasTrackerTests/Features/Lists/ListServiceRevalidationTests.swift`; this report.
Changed: `ChristmasTracker/Features/Lists/Services/ListService.swift`; `ListServiceDeletedListGuardTests.swift`; `ListServiceMemberTests.swift`; `Docs/epics/I3b-members-children.md`; `Docs/handoffs/2026-11-09-ios-to-brian-i3b.md`.
Deleted: none.

## What changed (ListService)
- `deletedListIds: Set<String>` replaced by `operationSequence: Int` and `removalSequence: [String: Int]` (private, session-local).
- `loadLists`, `refreshLists`, `loadListDetail`, `updateList` and `refetchDetailAfterMemberChange` capture `start = operationSequence` before their first await. A result is dropped when `removalSequence[id] > start` (`isRemoved(_:since:)`); `visibleLists(_:since:)` also keeps the archived filter.
- `recordRemoval(_:)` increments the counter and stores it. Called by `deleteList` (after `ensureCurrent`) and by `dropList` (leave, notFound, archivedReadOnly, membershipNotFound on leave, forbidden with a cached detail).
- `resetSession()` zeroes both with the generation bump; it still calls `dataStore.clear()` and clears the open detail.
- `loadListDetail`: the start-of-call guard was removed (a load that starts after a removal is never filtered); `reportGuarded(_:since:generation:)` is now async and, when it drops a result, clears the open detail, sets `goneListId`, records notFound and removes the cached entry. New `shownCached` flag: a `forbidden` revalidation after a cached detail was shown calls `dropList`; forbidden with no cached detail is unchanged.
- No new `@unchecked Sendable`, `nonisolated(unsafe)`, force unwrap, GCD or Combine. Manual Sentry spans unchanged; no new log lines.

## Existing tests changed (all named; none deleted or weakened otherwise)
Reason for the first five and the sixth: "the product decision changes the guard from session-long to in-flight only" (each carries an "I3b-6 replaces ..." comment).
| Old | New |
|---|---|
| `leaveListGuardsLaterRefresh` | `leaveListLaterRefreshShowsListAgain` |
| `leaveListGuardsDetailLoad` | `leaveListLaterDetailLoadShowsDetail` |
| `goneListIsNotResurrected` (3 args) | `goneListIsShownAgainByLaterLoad` (3 args) |
| `detailOfGuardedIdIsNotFound` | `laterDetailLoadAfterDeleteShowsDetail` |
| `cachedDetailOfGuardedIdIsNotFound` | `cachedDetailAfterDeleteIsShownAndRevalidated` |
| `detailGoneDropsList`, `updateGoneDropsList` (2 args each) | same names; the trailing "later refresh" assertion now expects the list back (`["list-a","list-b"]`, lists and cache) |

Other changed expectations, with their own reason: the `.forbidden` case was removed from `detailOtherErrorDropsNothing` (new `detailOtherErrors` list) and `otherErrorsLeaveGoneListIdNil` skips its detail-load step for forbidden, because "forbidden on a revalidation of a cached detail now drops the list (product rule in Gate 1)". `updateList` variants still run forbidden. In-flight tests are untouched (git diff shows no hunk): `inFlightLoadListsDoesNotResurrect`, `inFlightRefreshDoesNotResurrect`, `inFlightDetailDoesNotResurrect`, `freshDetailResultForNewlyGuardedIdIsNotFound`, `inFlightUpdateDoesNotResurrect`, `leaveListGuardsInFlightLoad`.

## New tests (16 functions)
Guard file (6): `laterLoadListsReturningArchivedStaysHidden`, `laterRefreshReturningArchivedStaysHidden`, `laterLoadListsAfterDeleteShowsList`, `onlyTheLoadStartedBeforeTheRemovalIsFiltered`, `recordsClearedAtTeardownNewSessionStartsEmpty`, `newSessionInFlightGuardStillWorks`.
Member file (3): `leaveListLaterLoadListsShowsListAgain`, `leaveListOnlyEarlierLoadIsFiltered`, `leaveListRecordClearedAtTeardown`.
New file `ListServiceRevalidationTests` (7 functions, 9 cases): `revalidationFailureRemovesCachedDetail` (notFound, archivedReadOnly, forbidden), `revalidationFailureKeepsOtherCachedDetails`, `forbiddenWithoutCacheDropsNothing`, `cachedDetailRevalidationRacingDeleteReportsNotFound`, `teardownDropsCachedDetail`, `newSessionStartsWithoutPreviousUsersDetail`, `newSessionFailureShowsNoPreviousDetail`.

Test arithmetic (from the test-writer's read of the diff, not from a test listing): functions before/after: guard file 18 -> 24, member file 27 -> 30, revalidation 0 -> 7. 1399 + 6 + 3 + 7 = 1415, minus replaced-one-for-one (5 renamed tests, net 0) = **1415**, matching the runner. Per argument case it is +17 (+5 guard, +3 member, +9 revalidation); the runner total appears to count a parameterized test once, which is inferred from this arithmetic and not verified in a listing. Verified by running a command: the runner total 1415 (verify output below). Derived by reading the diff: the per-file counts.

## Raw outputs (all from running commands)
Baseline before the Gate 1 commit (first `scripts/verify.sh` tail, then a re-run filtered to summary lines):
```
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
--- tests: 1399 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.
```
After the Gate 1 commit (5085d7b): `--- tests: 1399 passed, 0 failed, 0 skipped ---`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.

Before the fix commit (tree = final code + handoff):
```
--- tests: 1415 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
Test run with 212 tests in 16 suites passed after 0.022 seconds.
```
After the fix commit (6059163): the same lines, `Test run with 212 tests in 16 suites passed after 0.020 seconds.`

Red phase: with the tests written and before the implementation, 12 test functions failed for the expected reason (the session-long guard still blocked later loads, or revalidation did not drop the cached detail). Implementation attempt 1: 1414 passed, 1 failed (a test-shape bug, see stuck-detector log). After the test fix: 1415 passed, 0 failed.

`git diff --stat HEAD~2..HEAD`, taken after the fix commit and before this report's commit:
```
 .../Features/Lists/Services/ListService.swift      | 106 +++++++----
 .../Lists/ListServiceDeletedListGuardTests.swift   | 193 ++++++++++++++++++---
 .../Features/Lists/ListServiceMemberTests.swift    |  88 ++++++++--
 .../Lists/ListServiceRevalidationTests.swift       | 188 ++++++++++++++++++++
 Docs/epics/I3b-members-children.md                 |  12 ++
 Docs/handoffs/2026-11-09-ios-to-brian-i3b.md       |  23 ++-
 6 files changed, 529 insertions(+), 81 deletions(-)
```

## Gate 2 (verdicts written after the reviews)
- convention-reviewer: **APPROVE**. One low finding (header comment still said "recorded in the set"), fixed by the test-writer afterwards; no re-review needed for a comment-only change (stated deviation from "re-reviewed by the same reviewer": the change touched no code).
- acceptance-reviewer: **APPROVE** (read ListService.swift in full). Focus-list answers (ListService.swift lines are as of the fix commit):
  1. Pre-removal load cannot resurrect: start captured at :100, :146, :175, :266, :546; `recordRemoval` :505-508 from `deleteList` :319 and `dropList` :532; `isRemoved` :499-502 (`recorded > start`) applied at every write point (lists :110/:121/:127/:153/:157, detail :191/:200/:204, update :278/:282, refetch :551/:554). The six in-flight tests are unmodified.
  2. A load that starts after a leave shows the list: yes; `leaveListLaterRefreshShowsListAgain`, `leaveListLaterLoadListsShowsListAgain`, `leaveListLaterDetailLoadShowsDetail` (lists, cache, detail). Equality edge: start == recorded is not filtered.
  3. Deleted list stays hidden on later list loads: `visibleLists` :494-496 always applies the archived filter; tests `laterLoadListsReturningArchivedStaysHidden`, `laterRefreshReturningArchivedStaysHidden`. Caveat (see below): the detail path has no archived filter.
  4. Records cleared per session: `resetSession` :477-478 with the generation bump (:469); every recorder is generation-gated (:318, :414, :418, :515, :211). Tests: `recordsClearedAtTeardownNewSessionStartsEmpty`, `newSessionInFlightGuardStillWorks`, `leaveListRecordClearedAtTeardown`.
  5. Revalidation failure removes the cached detail and leaves the screen: notFound/archivedReadOnly via `dropListIfGone` -> `dropList` (:531-539); forbidden with cache :209-211; error still recorded :215; guard drop via `reportGuarded` :577-586. Teardown clears detail and store (:475, :489). Tests in ListServiceRevalidationTests.
  6. Existing tests changed: the table above; the reviewer found no other changed, weakened or deleted test.
  7. Handoff matches the new behavior: updated (guard risk removed, step 9 expectation, revalidation behavior, totals, commits, row 2 note kept).
  8. Scope: only Features/Lists/Services/ListService.swift, the Lists tests, and Docs changed.

## Stuck-detector log
- Implementer attempt 1: build OK, 1414 passed / 1 failed (`laterLoadListsAfterDeleteShowsList`): the second `loadLists()` was served from the non-empty cache (shouldRefresh false for 15 minutes) so the queued fetch was never used. Implementer stopped after 1 attempt (test believed wrong), correctly.
- Routed to the test-writer (test bug, not implementation): single-initial-list fix; it applied the same fix to `laterLoadListsReturningArchivedStaysHidden`, which had the same flaw (its "stays hidden" assertions were passing vacuously) and added a `fetchListsCount == 2` check. After this: 1415 passed, 0 failed. No repeated error signature; 1 of 3 attempts used.

## Deviations, bugs found, out of scope
- **Test-writer command-habit violations:** the first test-writer run used `cd`, a here-doc and several `sed -i` edits (against CLAUDE.md's command habits and this prompt). All edits stayed in the Lists test folder, no production code, no stray files (checked with `git status`). It was told to stop; its later edits used the Edit tool only.
- The test-writer asked to flip `goneListIsNotResurrected`, which was not on the prompt's replace list; I authorized it because the prompt allows "any test with the same assertion" and it pins the same assertion.
- Report in its own commit (above) so it can hold the after-commit verify; the prompt's PACKAGE END range `HEAD~2..HEAD` was taken before this commit.
- `verify.sh` first baseline run: I tailed only 40 lines and missed the app test count; the re-run (above) shows 1399.
- Real bugs / notes: (a) `goneListId` is still cleared only at the session reset, so after leave, re-add and a second gone-report for the same id the automatic screen exit does not re-fire (pre-existing; in the handoff). (b) `loadListDetail` does not filter an ARCHIVED detail, so after a delete a later detail load shows the list if the server returns an archived detail instead of notFound or archivedReadOnly; needs a check on the real backend (in the handoff). (c) A load started before the removal stays filtered even if the user was re-added meanwhile (hidden until the next load); consistent with the rule.
- Outside scope: none changed.

## Not done or partial
- Brian's real-mode check was not run (needs the local backend and the simulator); step 9 now expects B to return for mike after the re-add on his next load.
- No simulator or UI run by any agent.
- The test-count reconciliation is against the diff and the runner total, not against a full test listing.
- The post-commit verify of this report's own docs-only commit is recorded in the session summary, not here.
