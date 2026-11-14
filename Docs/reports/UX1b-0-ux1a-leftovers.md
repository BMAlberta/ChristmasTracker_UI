# UX1b Story B0: UX1a leftovers

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer, in that order, sequentially).

## What changed
- **Gap 1 (recorded, not thrown).** `ListService.refetchDetailAfterMemberChange` (addMember, removeMember) and `reloadAfterArchive` (deleteList) now store a failed refetch or reload instead of only logging it. A failed detail refetch is stored under the list id; a failed lists reload sets `listsLoadFailure` (the list is still removed from `lists` and the cache). A successful detail refetch removes the list's keyed entry. The mutations return and throw exactly as before; a superseded reload (`reloadToken`) still records nothing. A gone list (`goneListId == listId`) records nothing. `refetchAfterArchivedReadOnly` is unchanged (its mutation failed).
- **Gap 3 (keyed by list id).** `detailLoadFailure` is now `detailLoadFailures: [String: ListError]` with `detailLoadFailure(forListId:)`, `clearDetailLoadFailure(forListId:)` and `clearDetailLoadFailure()` (clears all). `loadListDetail` clears and stores only its own id (including the `reportGuarded` not-found); `resetSession` clears all. ListDetailView reads and clears with its own `listId`.
- **Gap 2 (items unavailable).** New pure `ItemsSectionAvailability` (Features/Items/ViewState): rows are `.content`; else loading is `.loading`; else a failure is `.unavailable`; else `.empty`. `ItemsSectionView` renders `.unavailable` as muted caption text "Items unavailable. Pull to refresh or tap Try Again." (tokens only); the empty copy shows only for `.empty`. No ItemService change.
- **F5: banked, nothing changed.** `StatsScreenModel.failureCount` increments on every failed load outcome, and the banner hides while `dismissedFailureCount == failureCount`. Telling a repeat of the same failure from a new identical one needs failure identity the model does not have. The existing test `StatsScreenModelStaleBannerTests.newFailureShowsAgain` pins that a second failed refresh after a dismissal shows the banner again, so a fix would contradict it or change the policy mapping, which B0 forbids.

## Files
Added: `Features/Items/ViewState/ItemsSectionAvailability.swift`; tests `Features/Lists/ListServiceReloadFailureRecordingTests.swift`, `Features/Lists/ListServiceKeyedDetailFailureTests.swift`, `Features/Items/ItemsSectionAvailabilityTests.swift`.
Changed (production): `Features/Lists/Services/ListService.swift`, `Features/Lists/Views/ListDetailView.swift`, `Features/Items/Components/ItemsSectionView.swift`.
Changed (tests, mechanical migration to the keyed accessor, assertions kept as strong): ListServiceLoadFailureTests, ListServiceDeletedListGuardTests, ListServiceArchivedListsTests, ListServiceRevalidationTests, ListServiceRefreshDetailTests, ListServiceTests, ListServiceSessionSafetyTests (`expectCleared` asserts `detailLoadFailures.isEmpty`), ListServiceMemberSessionSafetyTests, ListServiceArchivedReadOnlyTests, ListServiceRemoveCoOwnerTests, ListServiceMutationPublishesNothingTests, ScopedMutationErrorStateTests, ListArchiveCompletionTests (`loadStates`), ListServiceArchiveSessionSafetyTests, BudgetEditorModelListsLoadTests, ChildDeletionFlowHarness (`noLoadFailure`), ListServiceLoadFailureSupport (`anyLoadFailure` = `listsLoadFailure ?? detailLoadFailures.values.first`), ListServiceMemberTests (`addMemberFailure`, `leaveListLaterDetailLoadShowsDetail`).
Deleted: none. Docs: Docs/epics/UX1b-dialogs-colors-and-polish.md (Gate 1 signatures), this report.

## Rewritten tests (the old assertion contradicted the new, intended behavior; each marked "REWRITTEN (UX1b B0)")
- `ListServiceMemberTests.addMemberRefetchFailure`, `removeMemberRefetchFailure`: now expect the keyed failure (still: the call returns normally, detail unchanged, `isMutating == false`).
- `ListServiceArchiveTests.reloadFailureAfterArchive`: now expects `listsLoadFailure == .network`; `reloadFailureIsNotPublished` renamed `reloadFailureIsRecordedAsListsFailure`.
- `ListArchiveCompletionTests.reloadFailureIsNotShown` renamed `reloadFailureIsRecordedForTheDashboardOnly`; `normalReturnShowsNothing` and the success-path archive tests now script a good detail refetch (an unscripted refetch fails with `.server` and is now recorded). Equivalent "not on the detail screen" coverage stays in the renamed test.

## Test arithmetic (app suite)
Baseline 4230 + 20 new (6 ListServiceReloadFailureRecordingTests, 9 ListServiceKeyedDetailFailureTests, 5 ItemsSectionAvailabilityTests; parameterized tests count once) - 0 deleted (renames and rewrites are net zero) = 4250. Measured by scripts/verify.sh: 4250. Package suite: 212 (unchanged). Release scripts 92, destination scripts 17.
New tests (first comment line of each names the old behavior): archiveDetailRefetchFailureIsRecorded, addMemberRefetchFailureIsRecorded, removeMemberRefetchFailureIsRecorded, archiveListsReloadFailureIsRecorded, successfulMemberRefetchClearsKeyedFailure, successfulArchiveRefetchClearsKeyedFailure; failureForAIsNotReturnedForB, loadingBDoesNotClearA, eachListKeepsItsOwnFailure, successfulLoadClearsOnlyOwnEntry, keyedClearRemovesOneEntry, keyedClearWithoutEntryIsHarmless, unkeyedClearRemovesAll, teardownClearsAllKeyedFailures (4 reasons), clearCacheClearsAllKeyedFailures; rowsAreContent, loadingWithoutRows, failedWithNoRowsIsUnavailable, loadedAndEmpty, unavailableTextIsNeutral.

## Raw output (from running commands)
Before commit (scripts/verify.sh, with the work in the tree):
```
--- tests: 4250 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.026 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.022 seconds.`
After commit: recorded in the next section once run.

## Gate 2
- convention-reviewer: APPROVE. Warnings: one new doc-comment line over 120 characters in ListService.swift (soft limit); ListService.swift is 1130 lines (hard limit 600, pre-existing, banked as a follow-up split); ListDetailView.swift 440 lines (soft limit).
- acceptance-reviewer: APPROVE (read the production code, answers with file:line). Notes: a keyed entry for a list the user left stays until that list loads again or the session resets (never shown on another list); `goneListId` is sticky for the session, so a later non-notFound refetch failure for a list already marked gone is also skipped (practically unreachable).
- Rejections: none. Stuck-detector log (implementer): attempt 1 compile error (own replace_all stripped spaces), attempt 2 two real failures in ListArchiveCompletionTests (fixture needed a good refetch), attempt 3 green; signatures differed, no stop.

## Verification sources
Counts and "OK" lines came from running commands. The Gate 2 file:line claims came from the reviewers reading code. No simulator run.

## Deviations
None from the brief. The test-writer first reported 8 functions for the keyed file; the file has 9 (grep count 6 + 9 + 5 = 20).

## Not done or partial
- F5 (dismissed-count resurfacing) is banked, with the reason above.
- No simulator run was possible; the "Items unavailable" rendering and the banners are not visually verified. Brian's real-mode check is the only proof of on-screen behavior, and these three gaps cannot be reproduced by hand (covered by unit tests).
- Banked follow-ups: split ListService.swift (over the file-length limit); stale keyed entry for a left list.
