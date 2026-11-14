# UX1a-3: The screens: every error through the inline banner with the stale-data policy

Commit subject: "UX1a: show every error through the inline banner with the stale-data policy".
Pipeline: full (isolated test-writer, implementer, convention-reviewer, then acceptance-reviewer, strictly one after the other). The swiftui-expert-skill was not invokable by subagents; its rules that matter here (private @State, services via @Environment, fetching in .task and never .onAppear, stable identity, accessibility, 44-point targets, previews) were written into the implementer's brief.

## Baseline for this story (after-commit run of the U2 commit 3903440)
```
--- tests: 4037 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(This is the after-commit output for the U2 commit, as promised in the U2 report.)

## Files
Added production (ChristmasTracker/ChristmasTracker/Features): Shared/ErrorPolicy/{LoadBannerPresentation, ScreenLoadPresentation, DismissedLoads, MutationBanner}.swift; Dashboard/ViewState/DashboardLoadState.swift (new folder); Lists/ViewState/ListDetailLoadState.swift; Children/ViewState/ChildrenLoadState.swift; Items/ViewState/ItemDetailLoadState.swift; Lists/Views/ListDetailBannersView.swift (with two previews).
Changed production: Dashboard/Views/DashboardView.swift; Lists/Views/{ListDetailView, CreateListView, EditListView, AddMemberView, ListComponents}.swift; Lists/ViewState/{ListViewState, ListDetailRefresh}.swift; Children/Views/{ChildrenView, AddChildView}.swift; Profile/Services/ProfileBiometricToggleModel.swift; Profile/Views/ProfileView.swift; Items/Views/ItemDetailView.swift; Items/Components/ItemsSectionView.swift; Statistics/ViewState/StatsScreenModel.swift; Statistics/Views/StatsView.swift; Budgets/ViewState/BudgetEditorModel.swift. InlineErrorBanner was checked and NOT changed (icon and message in a leading row, then left-aligned Try Again and Dismiss, at least 44 points via `minimumButtonHeight`, tokens only, VoiceOver announcement on appear).
Deleted files: none.
Added tests (ChristmasTrackerTests/Features): Shared/ErrorPolicy/{LoadBannerPresentationTests, ScreenLoadPresentationTests, DismissedLoadsTests, MutationBannerTests}, Shared/UX1aErrorScanTests, Lists/{DashboardLoadStateTests, ListDetailLoadStateTests, ScopedMutationErrorStateTests}, Children/ChildrenLoadStateTests, Items/ItemDetailLoadStateTests, Statistics/StatsScreenModelPolicyBannerTests, Budgets/BudgetEditorModelPickerPolicyTests, Authentication/ProfileBiometricToggleBannerTests.
Docs: the epic gained the U3 exact-interface amendment and the decisions on the test-writer's assumptions.

## What the screens do now
- Shared pure layer: `LoadBannerPresentation` (message to InlineErrorBannerState, blank falls back, Try Again on every load banner, Dismiss when dismissible), `ScreenLoadPresentation.make` (policy outcome to banners, full error, leave, sign-in), `DismissedLoads` (dismissal by SOURCE until reset, plus `reset(_ sources:)`), `MutationBanner` (ListError and ChildError; nil for session end; Dismiss always, Try Again when the existing presentations call the error retryable).
- Dashboard: lists load banner above the lists (stale text when lists are shown; full error otherwise); a failed archive is a local mutation banner with Try Again re-running the archive; Try Again for a load is a forced `refreshLists()`.
- List detail: ONE call to the policy with the detail failure, the pull-to-refresh failure and the items load error, `hasCachedData` = a detail is shown. Same category gives one banner whose retry targets are `.listDetail` and `.items`; different categories give two. The separate items-section banner and the separate refresh banner are gone. Mutation failures (archive, leave, remove member) are local mutation banners.
- Create list, edit list, add member, add child: mutation errors inside the sheet as InlineErrorBanner, held in local state, cleared on success, dismiss and close. The child-recipient load failure in Create list is an InlineErrorBanner.
- Children: load error row replaced by an InlineErrorBanner (full error when no children; stale text when a refresh fails with children shown); the delete banner is unchanged.
- Item detail: the Text-plus-Try-Again view is replaced by the banner (full error with no item, stale text with an item).
- Profile: the biometric failure is an InlineErrorBanner held by ProfileBiometricToggleModel (`banner`, `dismissBanner()`), Try Again re-runs the toggle; the alert is gone.
- Statistics and the budget editor: stale and failure banners (`staleBanners`, `staleBanner`, `failureBanner`) and the picker failure text now come from the policy.
Removals (each named): `ListErrorBanner` and all five use sites; `ListErrorDismissal`; `ListArchiveCompletion`; `ListDetailRefresh.banner(for:)` and `messagePrefix` (`itemsStep` kept); ChildrenView `errorRow`; AddChildView error Label; CreateListView child-load Text and Try Again row; ItemDetailView `notLoadedContent`; the Profile `.alert`; `ProfileBiometricToggleModel.errorMessage`; `StatsScreenModel.staleMessage`; the ItemsSectionView `errorBanner`, `onTryAgain`, `onDismissError` parameters and its "Load error, empty" preview (renamed "Empty, dark"); the dashboard's private `Operation` enum, `lastOperation`, `begin()` and `retryAction`.

## Test arithmetic (app suite)
Previous total 4037 + new 160 - removed or reduced 15 = 4182 (verify.sh: 4182 passed, 0 failed, 0 skipped). New by grep -c "@Test" (a parameterized test counts as one; ScreenLoadPresentationTests shows 20 hits but one is a comment line at its line 20, so 19 real): Profile banner 8, Picker policy 4, ChildrenLoadState 9, DashboardLoadState 12, ItemDetailLoadState 11, ListDetailLoadState 26, ScopedMutationErrorState 5, LoadBannerPresentation 10, DismissedLoads 14, MutationBanner 14, ScreenLoadPresentation 19, UX1aErrorScan 20, StatsScreenModelPolicyBanner 8 = 160. Removed or reduced (counts at HEAD versus now): ListViewGuardsTests 14 to 5 (-9: the ListErrorDismissal suite), ListDetailRefreshTests 11 to 4 (-7: the `banner(for:)` tests), ListArchiveCompletionTests 2 to 3 (+1) = -15. Rewritten in place without a count change: MembersChildrenViewScanTests (`retryIsNotHardWiredToSave`), EnrollMarkerRegistrationTests (E4b), StatsScreenModelStaleBannerTests (`staleBannerForNonRetryableFailure`), StatsScreenModelLoadTests (`failedNotRetryable`). Package suite 212, release script tests 92, destination script tests 17: unchanged. Clearable count 10 unchanged.

## Existing tests changed or removed, with reasons
- ListViewGuardsTests: the ListErrorDismissal suite (9 tests) removed; the type is gone. Equivalent: DismissedLoadsTests (dismissal is by source, not by error value). Two old cases have no equivalent (associated values in equality; a second dismiss replaces the first) because the new type hides by source.
- ListArchiveCompletionTests: rewritten (3 tests) to prove a normal return from `deleteList` leaves both load states empty, a failed follow-up reload is shown nowhere, and a thrown archive failure becomes a MutationBanner. The type it tested is gone; the service-level fact lives in ListServiceArchiveTests.
- ListDetailRefreshTests: the 7 `banner(for:)` tests removed (path removed); ListDetailLoadStateTests covers refresh alone, merged with a detail failure, session end, and the rate-limit hint. The 4 `itemsStep` tests stay.
- MembersChildrenViewScanTests `retryIsNotHardWiredToSave`: `onRetry:` is now `onTryAgain:` and the test now also requires `InlineErrorBanner(` and no `onRetry:` (stronger).
- EnrollMarkerRegistrationTests E4b: `errorMessage != nil` became `banner != nil` (property replaced).
- StatsScreenModelStaleBannerTests: a 403 with saved data now expects the plain permission message with Try Again and Dismiss, not the stale text (the policy forbids "Couldn't update" for a 403).
- StatsScreenModelLoadTests `failedNotRetryable`: the 403 full-error banner now has `[.tryAgain]` instead of none (LoadBannerPresentation has no per-error retryability): a declared small behavior change.
- Two new tests were first written with a wrong assumption (every error type puts the seconds in its rate-limit message); only ListError and ChildError do. They were corrected to compare with the typed error's own message (the repositories' messages are out of scope).

## Verification (commands run)
Before commit, run by the Orchestrator, `scripts/verify.sh`:
```
--- tests: 4182 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
The package suite ran inside verify.sh (`swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests passed). The after-commit output for this commit is recorded in the Story U4 report. Claims about screen structure, retry wiring and logging came from the reviewers reading the code; none of it was run on a device.

## Gate 2
Convention-reviewer: APPROVED, no hard blocks. Evidence: no raw color, spacing, font or SF Symbol string in the changed views (tokens only); no `DispatchQueue`, Combine, force unwraps, `try!` or `as!`; no logging, Sentry or accessibilityIdentifier additions; no `.onAppear` fetching (new `.onDisappear` blocks only clear state); @State private; no dead references left to the removed types. Warnings not reworked: ListDetailView.swift grew from 404 to 439 lines (under the 600 limit; the banner view was split out); `ForEach(Array(x.enumerated()), id: \.offset)` is used for banner lists of at most two entries in DashboardView, ChildrenView, ItemDetailView, StatsView and ListDetailBannersView (the standard asks for a stable id); `ChildrenState.errorMessage` and the recipient options' `errorMessage` are dead production code kept by the third amendment; AddMemberView and AddChildView have no previews (they had none before) and ChildrenView and ItemDetailView have no dedicated error-state preview; a few lines over 120 characters (ScreenLoadPresentation.swift:31, ItemDetailView.swift:144); StatsScreenModel.swift is 412 lines and MembersChildrenViewScanTests 542 lines; `DashboardLoadState.make` takes `archiveFailure` and discards it (the amended interface).
Acceptance-reviewer: APPROVED for the story and for the package (it did not run anything). Focus answers with evidence: (1) no ad-hoc error row, label, alert or ErrorStateView left in the Scope folders (the only icon use is DesignSystem/Components/InlineErrorBanner.swift:53); (2) no shared error is published or read (grep in the services finds only listsLoadFailure, detailLoadFailure, the two item errors and StatsService.loadFailure); a failed addMember is held at AddMemberView.swift:102-105 and cleared at :64, and ScopedMutationErrorStateTests.swift:56-116 proves both load states stay empty; (3) ListDetailLoadState.swift:21-28 feeds detail, refresh and items into one policy call; the retry closure runs `refreshListDetail` (or `loadListDetail` with no detail) for `.listDetail` and `refreshItems` (or `loadItems`) for `.items` (ListDetailBannersView.swift:25, ListDetailView.swift retry); (4) stale text, silence on a fresh cache, full error with no cache and no stale text for 403, 404 or session end are pinned in ListDetailLoadStateTests.swift:108-233; (6) LoadFailure.swift:28-103 exhaustive, no default; (8) no logging or identifier additions; (10) every Acceptance bullet is met at the state level; the Scope items (a) to (e) were done in U2 (findings A to E at service and model level) and U3 (the banners). UX1aErrorScanTests bites: every rule has synthetic fire and quiet proofs, a file-count guard and a named-screen reach test prevent a vacuous pass; it cannot catch an ad-hoc `Text(error...)` row that avoids the icon and "Try Again" (accepted at this scale).
Rejections: none. Stuck-detector log: none triggered (green on the first attempt, apart from the two wrong rate-limit assertions above, which were test errors and were fixed by the test-writer, not by bending the code). One cosmetic request after approval (a stale header comment in UX1aErrorScanTests and ListArchiveCompletionTests) was done with comments only.

## Deviations, behavior changes and notes (the acceptance reviewer judged each acceptable against the brief)
- An items 404 now leaves the LIST screen (it follows from the policy: any notFound gives leaveScreen). Before, it showed an items banner. Risk: an items-endpoint 404 on a list that still exists would eject the user. To be watched in the real-mode check.
- Mutation failures with `notFound` or `forbidden` no longer show a "Close" button (that was ListErrorBanner's `onLeave`); a notFound still leaves through `goneListId` or `ListScreenExit`; a forbidden mutation shows its message.
- `leaveList` and Create list with no signed-in user now return silently (MutationBanner is nil for session end).
- ChildrenView's full error is a banner row at the top of the list, not a centered container (the detail screens center theirs).
- 403 load banners now offer Try Again (declared).
- The dashboard clears its lists failure on every disappear, including when pushing into a list, so a dashboard banner is gone after going into a list and back.
- Two Statistics banners share one dismissal count, so Dismiss on one hides both.
- On the Dashboard, Children, Statistics and the budget editor a notFound or session-end outcome renders nothing (they cannot leave; session end hands over to the sign-in flow).
- With the items never loaded and the load failing, the list detail items section shows its empty copy under a banner reading "Couldn't update. Showing saved data." because the brief defines `hasCachedData` as "the detail is shown". Candidate for UX1b.
- `ChildService.phase` is still a load channel shared by ChildrenView and the Create list child picker; each clears it on disappear.
- Not covered by a unit test: the retry closures in the views (private view code). Only Brian's real-mode check covers them.

## Not done or partial
- No simulator run was possible: nothing was seen on screen. NOT verified visually: banner layout, centering of the full errors, reflow at accessibility text sizes, light and dark rendering, VoiceOver announcement and order, the two-banner case. Brian's real-mode check is the only proof of the on-screen behavior.
- No new error-state previews were added for Dashboard, ChildrenView, ItemDetailView, ProfileView or the stats screens (the mocks to make them fail were not checked).
- The `ForEach` identity warning, the dead `errorMessage` properties and the file-size warnings were not reworked.
