# I3b-1: Carried-forward fixes (story K0)
Date: 2026-11-09. Branch feat/i3b-members-children. Path: full pipeline (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
1. **No silent mock fallback.** `resolveBootstrap(mode:clientAvailable:)` and `AppDependencies.resolve(mode:generatedClient:reporter:)` return `(state, dependencies)`. Real mode without a generated client gives `.failed` and an inert dependency set (`InertAuthenticationRepository`, `InertListRepository`, `InertItemRepository`, `InertAppVersionRepository`, `InertAPIClient`; every method throws `ConfigurationError.clientUnavailable`, nothing is returned). The app body shows only `ConfigurationErrorView` (one `Text`, no button, no sign-in, DesignSystem tokens). One Sentry event is captured through `SentryBootstrapFailureReporter` (message "Bootstrap failed", tag `error_category = client_unavailable`, no URL or values). The legacy `AppDependencies.make()` and the `init()` mock fallback are deleted. `AppDependencies` gained `appVersionRepository` so the mock version repository is built only in `makeMock` (review finding F1). Mock mode is unchanged.
2. **Deleted-ids guard.** `ListService.deletedListIds` (private, session-local) is applied to every apply path of loadLists, refreshLists, loadListDetail and updateList; filled after a successful delete and when a detail load or update fails with notFound or archivedReadOnly; cleared only in the session reset.
3. **Per-operation loading state.** `isLoading` is replaced by `isLoadingLists`, `isLoadingDetail`, `isMutating` (generation-guarded defers). `loadListDetail` clears `currentListDetail` only when the id differs; `refreshLists` no longer blanks the detail.
4. **Leave a gone list.** `ListService.goneListId` (observable, set by the gone-list handling, cleared only at session reset). `ListScreenExit.shouldDismissDetail(goneListId:openListId:)` and `shouldDismissEdit(goneListId:editedListId:)` (the older error-based functions are kept). `ListDetailView` and `EditListView` react to `onChange(of: goneListId)`; the edit sheet also dismisses from its own save error. The dashboard reads `service.filteredLists`, so the dropped list disappears.
5. **Log hygiene.** Log-line-only edits in `ItemService`, `NetworkItemRepository`, `MockItemRepository` and `MockAuthenticationRepository` (list ids, item names, emails removed; counts and constants only). New `LogHygieneScanTests` scans every `.swift` file under `Features/`.

### Log scanning pattern (documented in the test header)
A Log call (LogDebug, LogInfo, LogWarning, LogError, LogCritical; multi-line aware, string-aware paren matching, comment and `func` lines skipped) fails when an interpolation (a) has a dot-component equal to `listId`, `listID`, `email`, `name`, `displayName`, `firstName`, `lastName`, `memberId`, `childId`, `userId`, or a path ending in `list.id` or `list.name`; (b) has a component ending in or starting with `name` or `email` (non-person allowlist inside the scanner: `fileName`, `typeName`, `operationName`, `categoryName`, `className`); or (c) interpolates a whole object (`list`, `detail`, `member(s)`, `child`, `children`, `person`, `user`, `item(s)`, or an identifier ending in `Item`, `Detail`, `List`). `\(error)`, counts and `x.status` are allowed. The file-level allowlist is EMPTY (no line is allowlisted). Known limits: opaque item or purchase ids and raw `\(error)` values are not flagged; `print(` and non-Log wrappers are not scanned.

## Files
Added (production): `App/Bootstrap.swift`, `App/ConfigurationErrorView.swift`, `App/InertRepositories.swift`, `Core/Observability/SentryBootstrapFailureReporter.swift`.
Added (tests): `App/BootstrapResolutionTests.swift`, `App/AppDependenciesResolveTests.swift`, `App/BootstrapSourceScanTests.swift`, `Core/Logging/LogHygieneScanTests.swift`, `Features/Lists/ListServiceLoadingFlagsTests.swift`, `Features/Lists/ListServiceDeletedListGuardTests.swift`, `Features/Lists/ListScreenExitTests.swift`, `Features/Lists/ListScreenExitGoneListTests.swift`.
Changed (production): `ChristmasTrackerApp.swift`, `Features/Lists/Services/ListService.swift`, `Features/Lists/ViewState/ListViewState.swift`, `Features/Lists/Views/ListDetailView.swift`, `Features/Lists/Views/EditListView.swift`, `Features/Dashboard/Views/DashboardView.swift`, `Features/Items/Services/ItemService.swift`, `Features/Items/Repositories/NetworkItemRepository.swift`, `Features/Items/Repositories/MockItemRepository.swift`, `Features/Authentication/Repositories/MockAuthenticationRepository.swift` (log lines only in the last four).
Changed (tests): `Features/Lists/ListServiceTests.swift`, `Features/Lists/ListServiceSessionSafetyTests.swift`.
Deleted: `AppDependencies.make()` (dead legacy real branch, which built a mock auth repository and `MockListRepository(withMockData: false)`); no files.

## Test arithmetic (from running the suite; reconciled by per-file counts, not by a test listing)
946 + 64 new - 0 deleted = 1010 (the runner reports 1010). A parameterized test is one entry.
New (64): ListServiceLoadingFlagsTests 5; ListServiceDeletedListGuardTests 18 (guard cases a to d, failedDeleteDoesNotGuard, gone-list handling, plus review rework: detailOfGuardedIdIsNotFound, cachedDetailOfGuardedIdIsNotFound, freshDetailResultForNewlyGuardedIdIsNotFound, inFlightUpdateDoesNotResurrect, detailGoneSetsGoneListId, updateGoneSetsGoneListId, otherErrorsLeaveGoneListIdNil, goneErrorOfOtherListIsNotMistaken, teardownClearsGoneListId); ListScreenExitTests 5; ListScreenExitGoneListTests 2; LogHygieneScanTests 15; BootstrapResolutionTests 7; AppDependenciesResolveTests 7; BootstrapSourceScanTests 5.
Rewritten (assertions kept, flag renamed): in ListServiceTests testLoadLists, testLoadListsFailureResetsIsLoading (renamed ...ResetsIsLoadingLists), deleteRemovesLocallyWithoutRefetch, failedDeleteKeepsList, createUsesReturnedDetail, failedCreateKeepsLists, updateUsesReturnedDetail, loadListsTypedError, loadListDetailTypedError, writeTypedErrors, cancellationOnLoadSetsNoError, cancellationOnDetailSetsNoError, cancellationOnWritesSetsNoError; in ListServiceSessionSafetyTests inFlightSuccessAfterTeardownIsDiscarded and cancellationDuringTeardownSetsNoError.
Deleted: none. Package suite: 212 + 0 = 212.

## Gate 2
- Convention-reviewer: APPROVED (first pass), re-checked after the rework: APPROVED. Warnings, non-blocking: `InertAPIClient.request` has no `@Instrumented` (not a repository or service); unchanged item-repository log lines still interpolate opaque item ids and raw `\(error)`; `NetworkItemRepository` and `MockItemRepository` are actors without `@Instrumented` (existing, not retrofitted).
- Acceptance-reviewer: REJECTED first pass. Routing: F1 (blocker) `ChristmasTrackerApp.swift` built `MockAppVersionRepository` unconditionally, so a Mock repository existed in the failed state: implementer. F2 (no test covered what `init` constructs) and F7 (log scanner false negatives): test-writer. F3 (an in-flight update could re-cache a deleted list), F4 (a guarded id left the detail on an endless spinner), F5 (the detail screen was dismissed by any global gone error, not scoped to its list): implementer, with tests first from the test-writer. Rework done in one round; re-reviewed by the same reviewer: APPROVED.
- Stuck detector: one rejection round (attempt 2 of 3 overall); no repeated error signature. One test conflict (`failedUpdateKeepsState` injected `.archivedReadOnly`, which K0 defines as a gone-list error) was resolved by changing ONLY the injected error to `.forbidden` (see Deviations).

### Focus-list answers (evidence from the acceptance reviewer, confirmed by reading)
1. Real mode, no client: no Mock type is constructed outside `makeMock` and `#Preview` bodies (enforced by `BootstrapSourceScanTests.mocksOnlyInMakeMock`); the body is `if let state = ConfigurationErrorState.state(for:) { ConfigurationErrorView } else { appContent }` (`ChristmasTrackerApp.swift` body); the Sentry reporter is called once from `resolve()` in `init`. Mock mode unchanged.
2. A deleted list cannot come back from an in-flight load or update (guard checks after each await in `ListService`); flags are separate.
3. Detail and edit screens leave on `goneListId == their own id`; the dashboard drops the list.
4. No Log call in `Features/` interpolates a list id or name, email, member, or child value (scan test passes, empty allowlist).
10 and 13 for this story: no children code yet; no change under `contract/`, `.claude/`, any `.pbxproj`, synced Docs, or `LocalPackages/TrackerAPI` (`git diff --stat` shows only app and test files).

## Verification (source: commands run)
Baseline before any change (P3): verify `--- tests: 946 passed, 0 failed, 0 skipped ---`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`; package: `Test run with 212 tests in 16 suites passed`.
Before the K0 commit (verify output filtered with grep to the summary lines; the full stream was run):
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 1010 passed, 0 failed, 0 skipped ---
check-package-imports: OK
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package: `Test run with 212 tests in 16 suites passed after 0.019 seconds.`
After the commit: a commit cannot contain its own post-commit output and amending is forbidden, so the post-commit verify and package-test output for K0 is recorded at the top of the next report (Docs/reports/I3b-2-domain-and-rules.md, "Previous commit, after").

## Deviations, bugs, scope
- Deviation 1: `failedUpdateKeepsState` (an existing test) had its injected error changed from `.archivedReadOnly` to `.forbidden` (injected error, thrown error and final error expectation only; every other assertion identical). Reason: K0 defines `.archivedReadOnly` on update as a gone-list error that drops the list, which the new `updateGoneDropsList` covers. The intent (a failed update keeps state) is preserved with a non-gone error.
- Deviation 2: log-line edits in Items and Authentication files were required by the scan pattern (the brief names only ItemService); no other item behavior changed.
- Deviation 3: `loadListDetail` now always revalidates with the server after showing a cached detail (one extra GET per open) and drops a guarded id. This was needed by the guard tests; accepted by the acceptance reviewer.
- The implementer could not invoke the swiftui-expert-skill (no Skill tool in its agent).
- Accepted limitation G1: `goneListId` notifies only on a value change, so a second gone report for the same id in one session does not re-fire the auto-dismiss; the error banner with its Leave action still shows. F6: a spurious 404 hides a list for the rest of the session (by design).
- Real bugs found: F1 to F5 above (all fixed before commit).

## Not done or partial
- Nothing was run in the simulator or against a real backend (the real-mode check is Brian's, in the M4 handoff).
- The simultaneous edit-sheet dismissal and detail pop was reviewed by reading, not exercised in SwiftUI.
- Opaque item and purchase ids and raw `\(error)` values in unchanged Items and Purchases log lines are not covered by the scan (I3c scope).
