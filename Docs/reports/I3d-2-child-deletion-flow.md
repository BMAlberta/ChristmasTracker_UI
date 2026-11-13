# I3d-2: The deletion plan, the batch archive, and the flow

Branch: feat/i3d-child-delete-members. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, strictly one after the other).
SwiftUI guidance: no views in this story.

## What changed
- `ChildDeletionPlan` (pure, nonisolated): `plan(childId:lists:)`. A list belongs to the child when `recipient.id == childId`; only ACTIVE and DRAFT count (`ListSegment.active`); none gives `deleteNow`; all `canDeleteList` gives `archiveThenDelete(listIds)` in input order; any `canDeleteList == false` gives `blocked`.
- `ListService.freshLists()`: always fetches (never the cache), session-safe, writes `lists` and the cache like `refreshLists`, publishes no shared `error`, returns the fetched lists, throws the typed `ListError` or `CancellationError`.
- `ListService.archiveLists(ids:) -> ArchiveBatchResult` (archivedCount, totalCount, failedId kept in memory only, failure): sequential, stops at the first failure, a 404 counts as archived, exactly one reload at the end (also after a failure and after zero progress; none for empty ids or an ended session), no shared `error`, `isMutating` paired through the generation-guarded mutation counters, archive epochs bumped like `deleteList`.
- `ChildDeletionFlow` (@MainActor) with `plan(childId:)`, `execute(childId:plan:)`, `run(childId:)` and the typed `ChildDeletionResult` (deleted, archivedThenDeleted(count:), partialFailure(archivedCount:totalCount:error:), blocked, failed(error:)). Cancellation and both services' session generations are checked between every step; `nil` means stopped: show nothing, and the child is never deleted after a stop or a failed archive. Nothing is published in a shared property. List errors map to the same-named `ChildError` cases (others to `server`).
- `ChildError.childHasLists` text is now "This child still has active lists. Archive them first." (decision L17).
- `MockListRepository.removeChild` now blocks only on ACTIVE or DRAFT lists of the child (its `deleteList` archives, so the alignment applied).

## Scope additions (all in the D2 Gate 1 of the epic brief)
1. `ListService.freshLists()` and `ArchiveBatchResult`: `refreshLists()` returns nothing and publishes failures, so the flow could not tell a failed reload from an empty one.
2. Read-only `sessionGeneration` on `ChildService` (found by the test-writer: after a `ChildService` user switch mid-archive, `deleteChild` would have captured the NEW generation and deleted through the repository). Implemented as a computed `var sessionGeneration: Int { generation }`, not a stored `private(set)`; same effect.
3. Read-only `sessionGeneration` on `ListService` (NOT in the Gate 1; added by the implementer because the batch result alone cannot show that the list session ended during the final reload, after which the flow would have gone on to delete the child). Accepted by the Orchestrator as the same minimal accessor.
4. Doc comment of `ChildRepository.deleteChild` updated.

## Files
- Added (production): `Features/Children/ChildDeletionPlan.swift`, `Features/Children/Services/ChildDeletionFlow.swift`
- Changed (production): `Features/Lists/Services/ListService.swift`, `Features/Children/Services/ChildService.swift`, `Features/Children/ChildError.swift`, `Features/Children/Repositories/ChildRepository.swift`, `Features/Lists/Repositories/MockListRepository.swift`
- Added (tests): `ChildDeletionPlanTests.swift`, `ChildDeletionFlowHarness.swift`, `ChildDeletionFlowTests.swift`, `ChildDeletionFlowSessionTests.swift` (Features/Children), `ListServiceArchiveBatchTests.swift` (Features/Lists)
- Changed (tests): `ListFixtures.swift`, `ChildErrorTests.swift`, `MockChildRepositoryTests.swift`
- Changed (docs): `Docs/epics/I3d-child-delete-members.md` (D2 Gate 1 additions), `Docs/reports/I3d-1-members-owner-rows.md` (after-commit section and one rewording)
- Deleted: none

## Existing tests changed (reason: this story)
- `ChildErrorTests.childHasListsText`: expects the new text (decision L17).
- `MockChildRepositoryTests`: `deleteChildWithListFails` and `childWithNewListCannotBeDeleted` renamed to say "active list" with a comment; behavior unchanged because the seed child's list and a new list are active.
- `ListFixtures.giftList(...)`: new optional trailing `recipient:` parameter with a default (existing call sites unaffected).
Nothing deleted, skipped or weakened.

## Test arithmetic
App suite: 2950 + 47 new - 0 deleted = 2997. The 47 new entries: `ChildDeletionPlanTests` 1 (parameterized truth table, 15 rows), `ListServiceArchiveBatchTests` 13 (5 parameterized), `ChildDeletionFlowTests` 21, `ChildDeletionFlowSessionTests` 9, `MockChildRepositoryTests` 3 new (archived-only child deletable; one archived plus one active still blocked; the archived list is kept). 1 + 13 + 21 + 9 + 3 = 47. The total 2997 was confirmed by running `scripts/verify.sh`; the per-file entry counts come from the test-writer's report (not re-listed by an independent test listing). Package suite: 212 (unchanged).

## Raw output (commands run by the Orchestrator, before the commit)
```
--- xcodebuild exit status: 0 ---
--- tests: 2997 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
Test run with 212 tests in 16 suites passed after 0.022 seconds.   (swift test, TrackerAPI package)
```
After-commit run: see "After-commit run" below (added after the commit; committed with Story D3).

## Gate 2
- convention-reviewer: APPROVED, no findings. Manual-span rule satisfied on all five new @MainActor async functions (ListService.freshLists, archiveLists; ChildDeletionFlow.plan, run, execute; the private helpers are covered by their public callers' spans); no Combine or GCD; no force unwraps, no `@unchecked Sendable` or `nonisolated(unsafe)`; logs are constants and counts only (ListService.swift freshLists/archiveLists, `LogInfo("Archived \(archivedCount) of \(ids.count) lists")` counts only); `failedId` never logged; fakes are MainActor structs/classes; no sleeps or yield loops. It noted that the banned GCD type name appeared once in the D1 report text; that line was reworded in this commit. It could not query `.claude/` directly (hook), but `git status` showed no entry there.
- acceptance-reviewer: APPROVED, no rejection. Focus list: (1) the only route to `deleteChild` after an archive is ChildDeletionFlow.swift:132-143 and needs the isCurrent guard (:133), no `batch.failure` (:134) and `archivedCount == totalCount` (:142); a clear during the final reload is caught at :133; retry goes through `plan` -> `freshLists`, archived lists excluded at ChildDeletionPlan.swift:20; covered by the test at ChildDeletionFlowTests.swift:225. (2) `freshLists` always calls `repository.fetchLists` (ListService.swift ~500-527); plan filters at ChildDeletionPlan.swift:20-22. (3) `archiveLists` ListService.swift:546-607: break at first failure, one reload, 404 as archived, no `error`, epochs bumped like `deleteList`; `deleteList` untouched. (5) generations and `Task.isCancelled` through `isCurrent` (:167-171). (7) no identifying data in logs, spans or Sentry. (8) test changes as listed above. (10) nothing forbidden changed. The reviewer ran no tests and took no screenshot (no UI in this story).
- Reviewer notes recorded, not defects: a cancel landing right after the last archive still starts the final reload attempt, which is discarded without writing (ListService.swift:578-581), and the flow returns nil; if an archive finishes while `freshLists` is in flight, its result is returned but not cached (:512), harmless because the next plan refetches; `ChildService.deleteChild` (existing code) still sets its own shared `error` and `isMutating`, so D3 must not read `childService.error` for the flow result.
- Stuck detector: not triggered (implementer green on the first attempt).

## Verification source
Counts and verify: from running commands. Flow, batch and session-safety behavior: from reading code plus the passing tests; no simulator run.

## Deviations and findings
- `sessionGeneration` is computed rather than `private(set)` stored; one extra accessor on `ListService` beyond the Gate 1 (accepted, see above).
- `GeneratedClientChildRepository.swift:124` still carries the stale comment "the child still has lists" (comment only, outside the D2 file list; left alone).
- When a batch is stopped by a cleared session or a cancelled caller it returns the counts so far with `failure` and `failedId` nil and does not reload; the flow treats "fewer archived than total with no failure" as a stop (nil).
- No real bug found in existing code.

## Not done or partial
- The blocked message constant and the confirmation texts belong to D3 and are not implemented here.
- No real-mode check (Story D4, Brian's steps 2 to 5).
- The after-commit verify run is recorded below, after the commit.
