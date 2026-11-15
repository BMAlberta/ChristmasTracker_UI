# UX1b Story B1: Anchored dialogs and stable presentation state

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, sequential). Colors and roles are deliberately NOT changed here (Story B2). The SwiftUI guidance skill is not available to subagents; its rules (modern APIs, private @State, stable ids, no AnyView) were put in the implementer's brief by the Orchestrator.

## What changed
- New pure `ConfirmationPresentation<Target>` (Features/Shared/Presentation): idle / confirming(target); `requesting` (only from idle), `cancelled`, `confirmed(target)` (returns the target to run only from confirming that target), `targetsChanged(existing:)` (idle only when the target is gone), `reset`.
- `MembersDialogTarget {leave, removeMember(userId)}` and `EditListDialogTarget {removeCoOwner}` (Features/Lists/ViewState/MembersDialogTarget.swift).
- ListDetailView + MembersSectionView: the leave dialog is attached to the Leave list button and the remove-member dialog to each roster Remove button (were on the screen's root chain). State is `membersDialog` on the screen; Add member, Leave and every Remove are disabled while a dialog is open; reset on roster change (targetsChanged), session generation change, list gone and disappear. The archive dialog is unchanged (plain Bool on its own button).
- DashboardView: `listToArchive` and `archiveDialogBinding` replaced by `ConfirmationPresentation<String>`; the dialog stays on the row; Cancel no longer clears optional state by hand; targetsChanged on the visible ids; reset on session change and disappear.
- EditListView: the dialog moved from the Form to the Remove co-owner button; state is `ConfirmationPresentation<EditListDialogTarget>`; Save, Cancel and Remove disabled while it is open; reset on disappear and when the Remove control disappears.
- ProfileView: the dialog moved from the ScrollView to the Log out button inside LogoutButtonView (plain tap in a non-list container, Bool kept).
- Dialog texts, buttons, roles and outcomes are unchanged. No delay, sleep or Task.yield was added.
- Scan tests (test target): `DialogScanner` (container-anchored dialogs; set-then-clear), tested with bad and good fixtures, and run over every file under Features/ and App/ with an allowlist (LoginView.swift, RegistrationView.swift: the auth screens keep their own alert patterns, brief non-goal). The set-then-clear scan has no allowlist.

## Files
Added (production): Features/Shared/Presentation/ConfirmationPresentation.swift; Features/Lists/ViewState/MembersDialogTarget.swift.
Added (tests): Features/Shared/ConfirmationPresentationTests.swift (18), Features/Lists/MembersDialogTargetTests.swift (4), Features/Lists/EditListDialogTargetTests.swift (3), Features/Shared/DialogScannerTests.swift (26), Features/Shared/DialogScanRealFilesTests.swift (4), helper Features/Shared/DialogScanner.swift.
Changed: Features/Lists/Views/ListDetailView.swift, MembersSectionView.swift, EditListView.swift; Features/Dashboard/Views/DashboardView.swift; Features/Profile/Views/ProfileView.swift; test Features/Children/MembersChildrenViewScanTests.swift; Docs/epics/UX1b-dialogs-colors-and-polish.md (Gate 1); Docs/reports/UX1b-0-ux1a-leftovers.md (the after-commit verify line).
Deleted: none.

## Existing test changed
`MembersChildrenViewScanTests.listsViewBindings`: it required `removeConfirmation(for` and `leaveConfirmation` in ListDetailView.swift; those dialogs now live in MembersSectionView.swift, so the same two `requireText` checks point there. No assertion removed or weakened.

## Test arithmetic (app suite)
4250 + 55 new (18 + 4 + 3 + 26 + 4, grep -c @Test; parameterized counts once) - 0 deleted/rewritten = 4305. Measured by scripts/verify.sh: 4305. Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Before commit:
```
--- tests: 4305 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.021 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit 78aa67c (separate run): `--- tests: 4305 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `test-release.sh: 92 passed, 0 failed`, `test-destination.sh: 17 passed, 0 failed`, `=== verify: OK ===` (this line ships with the next commit).

## Gate 2
- convention-reviewer: APPROVE. Soft-limit warnings: ListDetailView.swift 445 lines (soft 400, hard 600), DialogScannerTests.swift 354 lines, two test lines over 120 characters in DialogScanRealFilesTests.swift.
- acceptance-reviewer: APPROVE (read the views, with file:line). Findings carried into this report:
  - Anchoring: every remaining dialog is on its trigger; the only allowlisted ones are LoginView and RegistrationView.
  - Scanner gaps, accepted risk: a dialog on a non-root `VStack`/`ZStack`/`NavigationSplitView`/`LazyVStack`, an indirect head such as `content.alert(...)`, a string literal with an unbalanced bracket before the dialog, a non-`body` helper root, and a body-root `HStack` (exempted as a row trigger).
  - Dashboard: targetsChanged runs when the id list changes, not when a filter hides the row; the dialog is modal so the row cannot be filtered while open.
  - EditListView has no session-generation reset (reset on disappear and on `showsRemove` false only).
  - **Open device check (ordering).** The confirm button calls `confirmed(target)` in its action while the dialog's `isPresented` setter calls `cancelled()`. If SwiftUI ran the setter before the action, a confirm would silently do nothing (fail-safe: no destructive action without consent, but the confirmation is lost). The Children delete (I3d-6 Risk B) and the Dashboard archive already depended on action-first ordering; B1 spreads the dependency to Leave, member Remove and co-owner Remove, which were order-independent before. Not proven without a device. Brian's real-mode check must confirm that CONFIRMING (not only cancelling) Leave, Remove member, Archive and Remove co-owner works. A hardening (make the confirm button independent of the state still being "confirming") was considered and not done; if a confirm is dropped on device, route as "code wrong" to the Implementer.
- Rejections: none. Stuck-detector (implementer): build green first try; first verify had one failure (`listsViewBindings`), fixed in the second run; no repeated signature.

## Verification sources
Test totals and OK lines from running commands; anchoring, state-location and reset claims from the reviewers reading code. No simulator run.

## Deviations
The scanner's `triggerHeads` set (Button, Menu, Label, LabeledContent, Toggle, Text, Image, Link, HStack) is a decision of the test-writer, accepted by the Orchestrator: a body-root row (ChildRow's HStack) is a trigger, not a container.

## Not done or partial
- No simulator run was possible. Dialog anchoring on screen, the swipe behavior, and the confirm ordering above are proven only by Brian's real-mode check.
- Scanner gaps listed above are accepted risk.
- Banked: split ListDetailView.swift (445 lines).
