# UX1b Story B2: Destructive colors

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer; one Gate 2 rejection, fixed and re-reviewed by the same reviewers). Only colors, roles and tints changed: no text, state, anchoring or logic.

## What changed
- DesignSystem/Components/DestructiveAction.swift (new): `DestructiveActionKind` (archive, delete, remove, leave, clear; each `color` is `Color.destructiveColor`) and `View.destructiveTint()` (`.tint(Color.destructiveColor)`).
- ListDetailView: archive button filled with the destructive token (was accent); its dialog button tinted.
- MembersSectionView: Leave list button tinted destructive (was accent); the member Remove icon button gained `role: .destructive` and the token (it had neither); leave and remove dialog buttons tinted.
- DashboardView: the Archive swipe action has an explicit destructive tint (the tab view's green tint could leak into it); dialog button tinted.
- EditListView: Remove co-owner button and its dialog button tinted.
- ChildrenView: the dialog's confirm button tinted (the test-writer found it was missing; colour-only change, nothing else touched there).
- ProfileView (sign out is NOT destructive): the dialog's Logout button lost `role: .destructive`. Gate 2 found the Logout trigger itself was still raw red (`.background(.red, ...)`, line 279); fixed to `Color.surfaceColor` text on a `Color.primaryColor` background. Text, frame, accessibility and action unchanged.

## Gate 2 rejection and fix
The acceptance-reviewer rejected the first diff: the Profile Logout button was still red, and my scan only searched for `role: .destructive`, so it passed. Routing: code wrong to the Implementer, coverage gap to the Test-writer. The Test-writer added `logoutButtonViewIsNeutral` (scoped to `struct LogoutButtonView`, fails if the type is not found), `noRawRedInViews` (no raw `.red`/`Color.red` under Features/ and App/), and scanner fixtures; both new real-file tests failed on exactly ProfileView.swift:279 before the fix. The Implementer fixed the view. The same reviewers re-reviewed and approved.

## Files
Added (production): DesignSystem/Components/DestructiveAction.swift.
Added (tests): Features/Shared/DestructiveScanner.swift (helper), DestructiveScannerTests.swift (24), DestructiveRealFilesTests.swift (7), DesignSystem/DestructiveActionKindTests.swift (4).
Changed: Features/Lists/Views/ListDetailView.swift, MembersSectionView.swift, EditListView.swift; Features/Dashboard/Views/DashboardView.swift; Features/Profile/Views/ProfileView.swift; Features/Children/Views/ChildrenView.swift; Docs/epics/UX1b-dialogs-colors-and-polish.md (Gate 1); Docs/reports/UX1b-1-dialogs.md (after-commit verify line).
Deleted: none. Existing tests changed: none.

## Destructive controls (acceptance-reviewer enumeration, file:line before the fix; all have the role and the token)
ListDetailView 371/389; MembersSectionView 82/103/140/161; DashboardView 292 (swipe, tinted)/309; EditListView 212/232; ChildrenView 352 (swipe, tinted), 359 (context menu), 374; ItemDetailView 289/304; ManagePurchaseView 309/330; BudgetCardMenu 29/50; BudgetEditorView 255. Sign out: neutral (ProfileView dialog button has no role; trigger has no red). No other logout entry point.

## Test arithmetic (app suite)
4305 + 35 new (24 + 7 + 4, grep -c @Test; parameterized counts once) - 0 deleted = 4340. Measured by scripts/verify.sh: 4340. Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Before commit:
```
--- tests: 4340 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit 6f599d5 (separate run): `--- tests: 4340 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `test-release.sh: 92 passed, 0 failed`, `test-destination.sh: 17 passed, 0 failed`, `=== verify: OK ===` (this line ships with the next commit).

## Gate 2
- convention-reviewer: APPROVE (twice: first diff and the revised diff). Warnings: test lines over 120 characters in DestructiveRealFilesTests.swift (53, 72, 81, 104) and DestructiveScannerTests.swift (354); DestructiveScannerTests.swift 386 lines (soft limit 400); ProfileView logout background keeps a raw corner radius `12` carried over from the old line (not changed; a radius, not spacing); ListDetailView.swift 446 lines (soft limit; banked split).
- acceptance-reviewer: REJECT (Logout still red), then APPROVE after the fix, with file:line evidence for every destructive control.
- Stuck detector: none (implementer green first try; one fix round).

## Verification sources
Totals and OK lines from running commands; the control enumeration and neutrality claims from reviewers reading code. No simulator run.

## Deviations
ChildrenView got a one-line tint on the dialog confirm button although the brief said the Children delete "conforms": the scan found it untinted. Colour-only.

## Not done or partial
- No simulator run: the red colors, the swipe tint, and the neutral Sign out look are proven only by Brian's real-mode check.
- Scanner limits (accepted): it cannot see a destructive-looking control with no `role:` (the member Remove button was one; covered by a dedicated test), and it misses a conditional role such as `role: cond ? .destructive : nil`.
- Banked: `DesignSystem/Components/ErrorStateView.swift:20` uses a raw `.foregroundColor(.red)`; it is an error view, not a destructive control, and outside the scanned Features/App scope.
