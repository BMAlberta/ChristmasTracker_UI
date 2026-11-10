# I3b-4: The screens (story M3)
Date: 2026-11-09. Branch feat/i3b-members-children. Path: full pipeline (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer). The swiftui-expert-skill was loaded by the Orchestrator and its rules were passed to the implementer (the implementer subagent cannot invoke skills); the convention reviewer checked the result against the skill's checklist.

## Previous commit (M2, 47bd3e6), after (source: command run, grep-filtered summary lines of the full stream)
```
** BUILD SUCCEEDED **
--- tests: 1352 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```

## What changed
- **Pure helpers** (tested): `CreateListRecipientOptions.resolvedSelection(current:)`, `AddMemberFormValidation.canSubmit`, `ChildFormValidation.canSubmit`, `CoOwnerFormValidation.canSubmit`, `MembersSectionState.removeConfirmation(for:)` and `.leaveConfirmation`.
- **ListDetailView** (+ new `MembersSectionView`, `AddMemberView`): Members section from `MembersSectionState(detail:)`: roster card only when `showsRoster`; per-row Remove only when `row.canRemove` (confirmation dialog); "Add member" sheet (email, role Picker default member, Add gated by `canSubmit`, sheet stays open with the plain message on error, dismisses on success); "Leave list" outside the roster card when `showsLeave` (so a viewer who cannot see the roster can still leave), with confirmation; the member count line is always shown and nothing hints at a hidden roster. All of Add, Remove, Leave and Delete list are disabled while `listService.isMutating`. Leave takes the user id from the in-memory session user (`.sessionEnded` message if missing). The detail pops on `goneListId` (from K0). The error banner's Try Again repeats whichever action failed (`FailedAction`).
- **EditListView**: a "Co-owner" section: the current co-owner's display name, a change-email field only when `showsChange`, a Remove toggle only when `showsRemove` (never today: `clearingSupported = false`, contract-issues row 2). Save sends ONE `updateList` with `makeUpdateInput(... coOwner:)`: `.set` only when the field is non-empty and valid, otherwise `.unchanged`; a non-empty invalid email disables Save; the sheet dismisses on a gone list.
- **ProfileView**: a new "Family" section between Settings and About with a "Children" row (`navigationDestination`) to the new **ChildrenView** (`Features/Children/Views`: loading, error with retry, empty states, `.task` + `.refreshable` load, toolbar add, `AddChildView` sheet (first name, last name, optional display name, relationship Picker, Save gated by `canSubmit`), delete by swipe, context menu or VoiceOver action with a confirmation from `ChildrenState.deleteConfirmation`, the `childHasLists` message shown in an alert). Biometric toggle and logout untouched.
- **CreateListView**: "Who is it for?" recipient Picker from `CreateListRecipientOptions` ("For me" default; children loaded on `.task`; loading, empty hint and error with retry; a failed or empty load leaves "For me" usable; selection normalized with `resolvedSelection` when the options change; the request carries the resolved `recipientId`). No blindness wording.

### Dead code removed (named)
In `ListDetailView.swift`: `membersCard(members:)` (the old members block that read `member.role.displayName` and showed `member.email`), its avatar `Circle` and email line, the `state.showsMembersSection, let members = detail.members` branch in `detailContent`, and the `"\(members.count)"` count text. The temporary `roleReadAllowlist` entry in `MembersSourceScanTests` is deleted (the list is now empty and a test asserts it). Left over, noted by the reviewer: `ListDetailState.showsMembersSection` (ListViewState.swift) is now unused by any view (removing it would touch I3a tests); the `removesCoOwner` toggle and `.clear` branch in `EditListView` are dormant behind `clearingSupported`.

## Files
Added (production, under ChristmasTracker/ChristmasTracker): `Features/Lists/Views/{MembersSectionView,AddMemberView}.swift`, `Features/Children/Views/{ChildrenView,AddChildView}.swift`.
Changed (production): `Features/Lists/ViewState/{MembersViewState,CoOwnerViewState}.swift`, `Features/Children/ViewState/ChildrenViewState.swift`, `Features/Lists/Views/{ListDetailView,EditListView,CreateListView}.swift`, `Features/Profile/Views/ProfileView.swift`.
Added (tests, under ChristmasTrackerTests/Features): `Children/{RecipientSelectionResolutionTests,ChildSubmitGateTests,MembersChildrenViewScanTests}.swift`, `Lists/{AddMemberSubmitGateTests,CoOwnerSubmitGateTests,MembersConfirmationStateTests,ListErrorPresentationCompletenessTests}.swift`.
Changed (tests): `Lists/MembersSourceScanTests.swift` (the one sanctioned edit: allowlist emptied, `allowlistEntriesStillNeeded` replaced by `allowlistIsEmpty`; counted as rewritten). Changed (docs): `Docs/epics/I3b-members-children.md` (M3 Gate 1 addendum). Deleted files: none.

## Test arithmetic (from running the suite; per-file counts)
1352 + 47 new - 0 deleted = 1399 (runner reports 1399). New 47: RecipientSelectionResolution 13 (nilResolvesToDefault, unknownResolvesToDefault, listedChildKept, selfKept, selfKeptInEveryPhase, childResetsWhenNotOffered, vanishedChildResets, emptyLoadedOnlySelf, resolvedIsAnOption, childRecipientInRequest, forMeRecipientInRequest, vanishedSelectionInRequest, otherFieldsUnchanged), AddMemberSubmitGate 4, ChildSubmitGate 6, CoOwnerSubmitGate 2, MembersConfirmationState 4, ListErrorPresentationCompleteness 4, MembersChildrenViewScan 14. Rewritten: 1 (`allowlistEntriesStillNeeded` to `allowlistIsEmpty`). Deleted: 0. Parameterized tests count once. Package suite 212 + 0 = 212. The error-presentation coverage for every ListError and ChildError case, and the "roster hidden for viewers and public non-members even with a members array" test, already existed from M1; the test-writer added only the exhaustiveness guard.

## Gate 2
- Convention-reviewer: APPROVED. Observations, non-blocking: no `AppIcons` or minimum-target token exists (new code uses `minHeight: 44` and literal SF Symbol names like the existing views; a DesignSystem follow-up); the two confirmation-dialog blocks in ListDetailView and ChildrenView are duplicated style.
- Acceptance-reviewer: APPROVED. Minor notes recorded below. No simulator screenshot was taken (the visual check was NOT performed).
- Stuck detector: no rejection; the implementer's first build failed once (a blocked edit and a missing `listRepository:` argument in a preview), then green.

### Focus-list answers (M3-relevant)
5. Flags only: `MembersSectionView.swift:20-25` (roster on `showsRoster`, Leave on `showsLeave`), `MembersViewState.swift:59-76` (roster = canSeeMembers and members present; Add = canManageMembers; Leave = canLeaveList; per-row Remove = canManageMembers and kind member or viewer), `CoOwnerViewState.swift:17,27`; no `.myRole` and no `ListMember.role` read in any view (scan tests `noRoleOrOwnerReads`, `noMembershipRoleReads`); roster hidden for viewers and public non-members; only the member count line remains.
6. Refetch after add and remove (service) and the view renders `currentListDetail`; after leave the service drops the list and the detail pops on `goneListId` (`ListDetailView.swift:108-113`).
7. Co-owner: see above; clearing blocked and hidden; contract-issues row 2 exists.
10. Accessibility identifiers are static strings (scan `identifiersAreConstant`); labels use display names only; no Log or print in the Children views (`childrenViewsDoNotLog`).
11. Recipient picker sends `recipientId` (`CreateListView.swift:246`), fails softly, resets a vanished selection.
13. No change under `contract/`, `.claude/`, any `.pbxproj`, synced Docs, or `LocalPackages/TrackerAPI` (`git diff --stat`).

### Minor notes carried to the handoff
1. If Add or Remove succeeds but only the refetch fails, `service.error` is set but the detail screen shows it only when no detail is loaded; the sheet dismisses and pull to refresh catches up.
2. Re-typing the current co-owner's email re-sends it as a `.set` (the client holds only the co-owner's display name); harmless.
3. Child delete has no visible button (swipe, context menu, VoiceOver action only): a discoverability cost.
4. `goneListId` notifies only on a value change (K0 limitation G1).

## Verification before the M3 commit (source: command run, grep-filtered summary lines)
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 1399 passed, 0 failed, 0 skipped ---
check-package-imports: OK
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package: `Test run with 212 tests in 16 suites passed after 0.018 seconds.` After the commit: recorded at the top of Docs/reports/I3b-5-handoff.md.

## Deviations, bugs, scope
- Deviation 1: Leave is shown on `showsLeave` alone, outside the roster card. The Decisions say Leave shows when `canLeaveList` is true; a VIEWER-role member cannot see the roster but must be able to leave; the acceptance reviewer judged this correct. The M3 addendum phrase "when the roster is not shown nothing else is" is read as "no roster-dependent controls".
- Deviation 2: the `#Preview("Blind owner")` in ListDetailView was renamed `#Preview("Owner of a self list")` because the new blindness-wording scan checks string literals.
- Deviation 3: Delete list is now also disabled while `isMutating` (double-submit protection).
- Command-habit slip: the implementer used a short Python heredoc to apply multi-line edits (against the command habits); no stray file remained (checked with `git status`).
- Real bugs found: none.

## Not done or partial
- No simulator run and no screenshot of any new screen (no agent could log in); the screens are verified only by view-state tests, text-scanning tests and reviewers reading the code. Brian's real-mode check (M4 handoff) is the first run.
- Dynamic Type behavior and VoiceOver actions were reviewed by reading, not exercised.
