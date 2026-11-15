# TH1.1 Story A2: audit and fix

Branch `feat/th1-1-destructive-look`. Path: solo implementer, then convention-reviewer (approve) and acceptance-reviewer (first review rejected, fixed, re-reviewed by the same reviewer, approve).

## Result

The audit found nothing to fix beyond the Logout pair, which Story A1 already fixed. No production code changed in this story. The commit is the new scan test alone.

## Audit table

Searches (listed in Docs/epics/TH1-1-destructive-look.md): `confirmationDialog`, `swipeActions`, `role: .destructive`, `destructiveTint`, `.alert(`, and button titles matching Delete, Remove, Archive, Leave, Clear, Logout, Log Out, Sign Out, Discard, Unarchive. The acceptance-reviewer re-ran the search independently and found nothing missed: dialogs and alerts exist only in 12 files under Features/.

| Control | File | Before | After |
|---|---|---|---|
| Logout trigger | Features/Profile/Views/ProfileView.swift | `PrimaryButtonStyle`, no role | `.bordered`, `destructiveTint()`, `role: .destructive` (fixed in A1, commit 8bfadfd) |
| Logout dialog button | Features/Profile/Views/ProfileView.swift | no role, app tint | `role: .destructive`, `destructiveTint()` (fixed in A1) |
| Archive List trigger and dialog button | Features/Lists/Views/ListDetailView.swift | already compliant | unchanged |
| Leave list trigger and dialog button | Features/Lists/Views/MembersSectionView.swift | already compliant | unchanged |
| Member Remove icon button and dialog button | Features/Lists/Views/MembersSectionView.swift | already compliant | unchanged |
| Remove co-owner button and dialog button | Features/Lists/Views/EditListView.swift | already compliant | unchanged |
| Dashboard Archive swipe action and dialog button | Features/Dashboard/Views/DashboardView.swift | already compliant | unchanged |
| Children Delete swipe, context menu and dialog button | Features/Children/Views/ChildrenView.swift | already compliant | unchanged |
| Delete Item trigger and dialog button | Features/Items/Views/ItemDetailView.swift | already compliant | unchanged |
| Delete purchase trigger and dialog button | Features/Purchases/Views/ManagePurchaseView.swift | already compliant | unchanged |
| Budget card Delete menu item and dialog button | Features/Statistics/Views/BudgetCardMenu.swift | already compliant | unchanged |
| Budget editor remove-row icon | Features/Budgets/Views/BudgetEditorView.swift | already compliant | unchanged |

The full row-by-row table with file and line is in the epic brief (rows 1 to 22).

## Left alone

- "Continue Anyway" in the over-purchase dialog (Features/Purchases/Views/RecordPurchaseRecordSection.swift:35): the budget confirmation flow. It records a purchase and deletes nothing.
- Every `role: .cancel` "Cancel" button: cancel is not a destructive action.
- The Login and Registration alerts ("Error", explanation, "OK", "Open Settings"): no delete, remove, archive, leave or sign out button.
- Remove co-owner (EditListView.swift:212): a Form row with a text button, red through `destructiveTint()` and the destructive role. It is not `.bordered`, but it does not use the green tint or the primary style, so it complies and was not restyled.
- The two icon-only remove buttons (member Remove, budget editor row): destructive role and destructive foreground, and not restyled.

## The new scan test

All files are in `ChristmasTrackerTests/Features/Shared/`, test target only, with no pbxproj edit (the project uses synchronized folders).

- `DialogActionScanner.swift`: a pure helper. It finds the trailing action closure of `.confirmationDialog(...)` and `.alert(...)`, ignores the `message:` closure and comments, takes each Button's first argument (a literal or an identifier path), lowercases it, strips whitespace, and matches delete, remove, archive, leave, logout or signout. A matching non-cancel button must have `role: .destructive`. It exposes `examinedButtons(in:)`, and `missingDestructiveRole` is that list filtered to buttons without the role.
- `DialogActionScannerTests.swift`: 11 fixture tests.
  - Fires without a role: a Delete dialog button, an alert Remove, a literal Sign Out, the identifier titles (`ListArchiveConfirmation.confirmButtonTitle`, `StatsScreenModel.deleteButtonTitle`, `CoOwnerRemoveConfirmation.confirmButtonTitle`, `MembersSectionState.leaveConfirmation.confirmButtonTitle`), and a real-looking Logout dialog with the role removed.
  - Does not fire: with the role present, Cancel, "Continue Anyway", a keyword in a comment, and a Delete button outside a dialog.
  - Count: `examinedCount`.
- `DialogActionRealFilesTests.swift`: 4 real-file tests over Features/ and App/.
  - Every keyword dialog button has the role.
  - `scanExaminesRealDialogButtons` asserts at least 8 keyword buttons were examined. The acceptance-reviewer counted exactly 8 in the real sources (BudgetCardMenu:50, ManagePurchaseView:328, ListDetailView:388, EditListView:232, MembersSectionView:102, DashboardView:309, ProfileView:285, ItemDetailView:301).
  - `childrenConfirmIsDestructive` and `membersConfirmIsDestructive` are pins for the two buttons with a generic title (`confirmation.confirmButtonTitle` in ChildrenView.swift:386 and MembersSectionView.swift:160), which the keyword rule cannot see.

How it fails on a violation: if `role: .destructive` is removed from the Logout dialog button (ProfileView.swift:285), the real-files test reports `Features/Profile/Views/ProfileView.swift:285 "Logout"`. If it is removed from the Archive dialog button (ListDetailView.swift:388), it reports `ListDetailView.swift:388 ListArchiveConfirmation.confirmButtonTitle`. The same holds for the other six keyword buttons.

Allow-list: none.

Review history: the acceptance-reviewer first rejected on test coverage. The member Remove dialog button (generic title) was invisible to the scan and not pinned, and the real-file scan could pass vacuously. Both were fixed (the `membersConfirmIsDestructive` pin, the `examinedButtons` count with a threshold of 8) and the same reviewer approved the re-review. The convention-reviewer approved the first version and was not re-run on the small test-only fix.

## Test arithmetic

Baseline for this story (after A1): 4623 app tests. Added 15, so 4623 + 15 = 4638. The run shows 4638. Against the package baseline, 4622 + 1 (A1) + 15 (A2) = 4638. TrackerAPI: 212 before and after.

## Commands and raw output

Before the commit (`scripts/verify.sh`, filtered to the summary lines):

```
--- tests: 4638 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.023 seconds.
=== verify: OK ===
```

## Deviations

None.

## Not done or partial

- Visual check: not performed. The agents and I never ran the simulator.
- The scan matches only the button's own title. A future dialog button with a generic title and no keyword is caught only if someone adds a pin, as was done for the two existing ones.
- Known limits of the scanner, none present in the app today: a dialog written with an explicit `actions:` label is missed, and bracket matching ignores string literals, so a dialog title with an unbalanced `(` or `{` would break closure matching.
