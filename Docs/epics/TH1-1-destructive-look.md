# TH1.1: The destructive look

Package TH1.1 (branch `feat/th1-1-destructive-look`, from master at the TH1 merge 62d8110). Two stories: A1 Logout, A2 audit and fix.

## Why

Brian, 2026-11-14, after a visual look at the merged TH1: Logout on Profile is a big filled Evergreen capsule (`PrimaryButtonStyle`), the loudest control on the screen, and the confirmation dialog's "Logout" button shows in the green app tint. Brian wants the red look for destructive actions and counts signing out as one. It should look like the Leave list button (Cranberry text on a dim Cranberry fill in dark mode, bordered), and the dialog's confirm button uses the destructive role so iOS shows it red.

## UX1b reversal

UX1b decision 3 said "Sign out is NOT destructive and stays neutral" (Docs/epics/UX1b-dialogs-colors-and-polish.md, rule 3 and Story B2 scan (c)). Brian decided on 2026-11-14, after seeing the filled green button, that this is reversed: sign out is destructive for the look. The two scans that enforced the old rule (`DestructiveRealFilesTests.signOutIsNeutral` and `logoutButtonViewIsNeutral`) are replaced in Story A1. The `ProfileView.swift` entry in `ButtonChromeScanTests.primaryButtonFiles` is removed in Story A1, because Logout was the only `PrimaryButtonStyle` use in that file.

## Decisions

1. A destructive control is `.buttonStyle(.bordered)` with `destructiveTint()` and `role: .destructive` (the existing `AppButtonKind.destructive` spec), a swipe action or menu item with the destructive role, and a dialog button with `role: .destructive`. Signing out counts as destructive for this purpose.
2. No new color tokens, no palette change, no change to token values.
3. No behavior change: the same confirmation, the same service calls.

## Gate 1 spec

- Contract slice: none. No networking, no API model, no repository change.
- New interface: none. Views and test target only, so the solo path applies for the code stories (one implementer: failing tests, then the change, then build and test). Gate 2 still runs the convention-reviewer and the acceptance-reviewer, as the brief asks for both.
- Acceptance criteria:
  - A1.1 `LogoutButtonView` in ProfileView.swift is `.buttonStyle(.bordered)` with `.destructiveTint()` and `role: .destructive`, with the same icon, full width and 44pt minimum height as before. It is not `PrimaryButtonStyle`.
  - A1.2 The dialog's "Logout" button has `role: .destructive`. The dialog stays attached to the button and its state stays above the rows. The accessibility label and identifier are unchanged.
  - A1.3 `AppButtonKind.destructive.spec` is still bordered, accent tint, destructive role.
  - A2.1 Every destructive control in the inventory that does not comply is fixed. Controls that comply are not restyled.
  - A2.2 A source-scan test fails when a `confirmationDialog` or `alert` action button titled Delete, Remove, Archive, Leave, Logout or Sign Out lacks `role: .destructive`.
- Scoped files:
  - `ChristmasTracker/ChristmasTracker/Features/Profile/Views/ProfileView.swift`
  - Tests under `ChristmasTracker/ChristmasTrackerTests/`: `Features/Shared/DestructiveRealFilesTests.swift`, `DesignSystem/ButtonChromeScanTests.swift`, a new scan test file, and a new `AppButtonKind` spec test if none exists.
  - Docs: this brief, reports and the handoff.

## Inventory (search results, not assumed)

Searches run over `ChristmasTracker/ChristmasTracker/**/*.swift`: `confirmationDialog`, `swipeActions`, `role: .destructive`, `destructiveTint`, `.alert(`, and button titles matching Delete, Remove, Archive, Leave, Clear, Logout, Log Out, Sign Out, Discard, Unarchive. Lines are as of the TH1 merge.

| # | Control | File:line | Current look (style, tint, role) | Complies |
|---|---|---|---|---|
| 1 | Logout trigger | Features/Profile/Views/ProfileView.swift:266-276 | `PrimaryButtonStyle` (filled capsule), app tint, no role | **No** |
| 2 | Logout dialog button | Features/Profile/Views/ProfileView.swift:283 | plain `Button("Logout")`, no role, shows in the app tint | **No** |
| 3 | Archive List trigger | Features/Lists/Views/ListDetailView.swift:371-382 | `.bordered`, `destructiveTint()`, `role: .destructive` | Yes |
| 4 | Archive dialog button | Features/Lists/Views/ListDetailView.swift:388-391 | `role: .destructive`, `destructiveTint()` | Yes |
| 5 | Leave list trigger (the model) | Features/Lists/Views/MembersSectionView.swift:81-92 | `.bordered`, `destructiveTint()`, `role: .destructive` | Yes |
| 6 | Leave dialog button | Features/Lists/Views/MembersSectionView.swift:102-105 | `role: .destructive`, `destructiveTint()` | Yes |
| 7 | Member Remove icon button | Features/Lists/Views/MembersSectionView.swift:139-146 | `.plain` icon-only, `Color.destructiveColor` foreground, `role: .destructive` | Yes |
| 8 | Member Remove dialog button | Features/Lists/Views/MembersSectionView.swift:160-161 | `role: .destructive`, `destructiveTint()` | Yes |
| 9 | Remove co-owner (Form row button) | Features/Lists/Views/EditListView.swift:212-219 | text row, `destructiveTint()`, `role: .destructive` | Yes |
| 10 | Remove co-owner dialog button | Features/Lists/Views/EditListView.swift:232-235 | `role: .destructive`, `destructiveTint()` | Yes |
| 11 | Dashboard Archive swipe action | Features/Dashboard/Views/DashboardView.swift:290-298 | swipe, `destructiveTint()`, `role: .destructive` | Yes |
| 12 | Dashboard Archive dialog button | Features/Dashboard/Views/DashboardView.swift:309-312 | `role: .destructive`, `destructiveTint()` | Yes |
| 13 | Children Delete swipe action | Features/Children/Views/ChildrenView.swift:363-369 | swipe, `.tint(Color.destructiveColor)`, `role: .destructive` | Yes |
| 14 | Children Delete context menu item | Features/Children/Views/ChildrenView.swift:370-376 | `.tint(Color.destructiveColor)`, `role: .destructive` | Yes |
| 15 | Children Delete dialog button | Features/Children/Views/ChildrenView.swift:386-389 | `role: .destructive`, `destructiveTint()` | Yes |
| 16 | Delete Item trigger | Features/Items/Views/ItemDetailView.swift:286-295 | `.bordered`, `.tint(Color.destructiveColor)`, `role: .destructive` | Yes |
| 17 | Delete Item dialog button | Features/Items/Views/ItemDetailView.swift:301-304 | `role: .destructive`, `.tint(Color.destructiveColor)` | Yes |
| 18 | Delete purchase trigger | Features/Purchases/Views/ManagePurchaseView.swift:307-321 | `.bordered`, `.tint(Color.destructiveColor)`, `role: .destructive` | Yes |
| 19 | Delete purchase dialog button | Features/Purchases/Views/ManagePurchaseView.swift:328-331 | `role: .destructive`, `.tint(Color.destructiveColor)` | Yes |
| 20 | Budget card Delete menu item | Features/Statistics/Views/BudgetCardMenu.swift:29-34 | menu item, `role: .destructive`, destructive label color | Yes |
| 21 | Budget Delete dialog button | Features/Statistics/Views/BudgetCardMenu.swift:50-53 | `role: .destructive`, `.tint(Color.destructiveColor)` | Yes |
| 22 | Budget editor remove-row icon | Features/Budgets/Views/BudgetEditorView.swift:255-264 | `.borderless` icon-only, destructive foreground, `role: .destructive` | Yes |

Not destructive, listed so the search is auditable:

| Control | File:line | Why it is not in scope |
|---|---|---|
| "Continue Anyway" over-purchase dialog button | Features/Purchases/Views/RecordPurchaseRecordSection.swift:35 | the budget confirmation flow; it records a purchase, it deletes nothing |
| "Cancel" dialog buttons (`role: .cancel`) | every dialog above | cancel is not a destructive action |
| "Error" and explanation alerts | Features/Authentication/Views/LoginView.swift:83,88,106; RegistrationView.swift:30 | OK or retry alerts; no delete, remove, archive, leave or sign out |

Result: only rows 1 and 2 (the Logout pair) need a code change. Rows 3 to 22 comply and are not restyled.

## Stories

- A1 Logout: ProfileView.swift `LogoutButtonView`, plus the test changes named above. Report `Docs/reports/TH1-1-1-logout.md`.
- A2 Audit and fix: nothing beyond Logout to fix per this inventory, so the commit is the new dialog-button scan test alone, unless the test finds more. Report `Docs/reports/TH1-1-2-audit.md`.
- Handoff: `Docs/handoffs/<run date>-ios-to-brian-th1-1.md` and `Docs/reports/TH1-1-3-handoff.md`.
