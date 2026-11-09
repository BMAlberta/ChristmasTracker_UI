# I3a-5: The list screens on capability flags and the permissions function

Branch feat/i3a-lists (base commit 77056a0). Gate 1: Docs/epics/I3a-lists.md (L3 and its addendum). Path: full pipeline (capability-flag-driven UI).

## What changed
- `Features/Lists/ViewState/ListViewState.swift` (new, Foundation only, every type `nonisolated` and Sendable): `ListRowState(list:)`, `ListDetailState(detail:)` (both with title, badge title and tone, counts text and progress only through `ListPermissions.showsCounts/showsProgress`, Edit/Delete from `canEditList/canDeleteList`, Members section from `canSeeMembers` and members present, always-present member count text, add-item flag from `canCreateItem`), `ListFormValidation` (create validity: name 1 to 200 after trim, theme at most 500, year 2000 to 2100; edit validity; `makeCreateInput`; `makeUpdateInput` sending only changed fields and returning nil when nothing changed; `selectableVisibilities` = four values), `CreateFormValidity`, `EditFormValidity`, `ListErrorPresentation` (message == `ListError.userMessage`, `isRetryable`, `shouldLeaveScreen`), `ListDeleteConfirmation`, `ListErrorDismissal` and `ListItemsScope` (added in the fix round, below), and `ListVisibility.title`/`.icon`.
- Views rebuilt to bind only to those states and `ListService`: ListDetailView, CreateListView, EditListView, DashboardView, ListPreviewCard, plus shared token-only pieces in `Features/Lists/Views/ListComponents.swift` (`listCard()`, `ListBadge`, `ListCountsView`, `ListErrorBanner`, `ListVisibility.summary`). The dashboard list is now a SwiftUI `List` (swipe actions did not work in the old ScrollView/LazyVStack); rows are Buttons.
- Privacy: when counts are hidden the state fields are nil/false and nothing hints at hidden items (the old "Item details are hidden to keep gifts a surprise" note is gone). The views contain no `ListPermissions`, `.capabilities`, `myRole`, `ListRole` or `ListRoleBadge(`; the role is shown only as a badge coloured from `badgeTone`. Edit and Delete follow the state on the detail screen; Delete follows `showsDeleteAction` on the dashboard swipe action; no Edit exists on the dashboard. No Members placeholder is added (the existing members card shows only when `canSeeMembers` and members are present). Create is for yourself only (recipient is `authenticationService.currentUser?.id`; a plain message when absent).
- Delete: confirmation dialog from `ListDeleteConfirmation` ("The list will be removed from your lists.") on the dashboard and the detail screen; the detail screen dismisses after a successful delete.
- Detail items: items render only through `ListItemsScope.itemsToShow(..., currentListId: itemService.currentListId, listId: listId)`, and `currentDetail` renders only when `currentListDetail.id == listId`, so another list's or a previous session's data cannot flash under this list. For viewers without visible counts the items section appears only if the server returned items; "No items yet" and the item count are reachable only when counts are visible (Docs/privacy-matrix.md allows showing the returned item list: `GET /lists/{id}/items` is 200 (BLIND) for blind owners).

## Dead code removed (named)
`ListStatsHiddenNote` and its text; `ListPreviewCard`'s private `RoleBadge`, `ListStatsSection`, `ListStatsRow`, `ListStatItem`, `ListPreviewCardHeader`; the `ListVisibility.displayName` extension in ListDetailView (replaced by `title`); the unused `showAddItemSheet` state and the "Add First Item" button that only set it; `statItem`, `actionsSection`, old `statsCard`; the hand-written chevron year buttons capped at 2020 to 2030 in CreateListView; the old three-value visibility list that omitted Friends Only; the confirmation dialog with a Cancel button inside the message and the `.constant(listToDelete != nil)` dialog binding; the `.system(size:)` icon font on the empty-items view; every `.cornerRadius`, `Color.red`, `.foregroundColor(.white)`, `.black.opacity` shadow and numeric padding in these screens. (Reported by the implementer; the convention reviewer's greps found none of the removed symbols remaining.)

## Files
Added: Features/Lists/ViewState/ListViewState.swift; Features/Lists/Views/ListComponents.swift; tests Features/Lists/{ListRowStateTests,ListDetailStateTests,ListFormValidationTests,ListErrorPresentationTests,ListDeleteConfirmationTests,ListViewScanTests,ListViewGuardsTests}.swift.
Changed: ListDetailView.swift, CreateListView.swift, EditListView.swift, DashboardView.swift, ListPreviewCard.swift; Docs/epics/I3a-lists.md (L3 addendum).
Deleted: none.

## Test arithmetic
App: 858 (after L2) + 88 = 946 (verify: `--- tests: 946 passed, 0 failed, 0 skipped ---`). By `@Test` declarations, a parameterized test counting once: ListRowStateTests 15, ListDetailStateTests 19, ListFormValidationTests 25, ListErrorPresentationTests 6, ListDeleteConfirmationTests 4, ListViewScanTests 5, ListViewGuardsTests 14 = 88. Rewritten or deleted existing tests: none in this story. Package: 212 -> 212.

## Raw outputs (commands run by the Orchestrator after the last change)
```
Test run with 212 tests in 16 suites passed after 0.017 seconds.
=== verify: unit tests ===
--- tests: 946 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(verify lines are grep-filtered.) Before (state after L2, command run): 858 app, 212 package.

## Gate 2
- Process note: the implementer subagent had no Skill tool, so the swiftui-expert-skill (required by CLAUDE.md) was not applied when the views were written. The Orchestrator loaded the skill and supplied its checklist to the convention reviewer (which, per its report, applied the checklist from the brief and did not open the skill's reference files), and the fix rounds were instructed with the skill's rules. The SwiftUI rules were therefore checked at review time, not at authoring time.
- Convention-reviewer: first APPROVED with warnings: the dashboard error path bypassed ListErrorPresentation (always "Try Again", localizedDescription, raw red/white); `.sheet(isPresented:)` with a model that could be nil; a ForEach with a conditional Divider per element; ListDetailState built twice per body; stale detail flash. Fixed in a round (scroll-indicator hiding skipped: no earlier screen hid them, so adding would change behaviour). Re-check: APPROVED. Warnings carried to the handoff (deferred): raw `44` minimum-target literals with no token (many call sites), radii borrowed from `AppSpacing` because no radius token exists, `opacity(0.2)`, a fixed 44x44 circle in ListDetailView, `Color.accentColor` used as the destructive color, scroll indicators not hidden, fixed-size `AppTypography` fonts so Dynamic Type does not scale, `.offset(y: -AppSpacing.md / 2)` divider coupling.
- Acceptance-reviewer: first REJECTED: (1) the dashboard error banner stayed silent after a repeated identical failure (dismissal was never reset by confirmDelete); its Retry after a failed delete ran a refresh; (2) the detail screen rendered `itemService.items` without checking they belong to this list (could show another list's or a previous session's items; for blind or viewer users the items section would appear purely because items were non-empty). Fixed with the pure helpers `ListErrorDismissal` (reset at every new operation; Retry only after load/refresh) and `ListItemsScope`, with tests (ListViewGuardsTests). Re-review: APPROVED.
- Stuck detector: two rejection rounds, each fixed on the next attempt.
- Visual check: NOT performed. The implementer booted the simulator but could only capture the login screen in mock mode (simctl cannot tap or type and there are no mock credentials); neither reviewer ran the simulator. The screens were judged by reading the code and SwiftUI previews exist (blind owner and owner detail, dashboard with and without lists, create, edit). This is Brian's check in L4.

## Focus-list answers
7. Blind owner, blind co-owner, viewer-role member and public non-member get nil counts/progress in the states and nothing in the views draws a count, ring, zero or placeholder (reviewer grep for "surprise", "hidden", "0 items" found nothing in Lists/Views, Dashboard and ViewState; the accessibility label/hint carry no counts, tested in ListRowStateTests). Reached from the states in ListViewState.swift and the views ListPreviewCard.swift and ListDetailView.swift (reviewer lines ListViewState.swift:33 to 47 and :90 to 112).
6. No view reads myRole/isOwner/canEdit/capabilities/ListRole (grep by the reviewer; enforced by ListViewScanTests, which passes).

## Deferred (recorded, not fixed here)
- `ItemService.swift:99` logs "Loaded N items for list <id>" (contains a list id): items epic I3c.
- `ItemRow` still uses raw `.orange`, `.white`, `.system(size:)` and a "Surprise" badge for off-list items: items epic.
- A pull-to-refresh on the detail sets `currentListDetail = nil` first (ListService.swift:150), so it shows Loading and a failed refresh replaces the detail with the error screen; `loadListDetail` serves the cache and has no forced refresh.
- When the edit sheet closes on a notFound or archived error, the detail screen behind it stays up showing the old list.
- DesignSystem `ErrorStateView` and `EmptyStateView` keep raw `.red`/`.white`/`.cornerRadius(12)` (shared with StatsView and PurchaseHistoryView; `EmptyStateView` is still used by the dashboard); needs a radius token.
- The 429-test and earlier L2 advisories are in the I3a-4 report.

## Deviations, bugs, scope
- Real bugs found by review: the dashboard silent-repeat error banner; items not tied to the current list (both fixed).
- Extra state fields beyond the addendum: `subtitle` on both states, `visibilityIcon` on ListDetailState, `ListVisibility.summary` (view-support strings).
- Create flow now offers all four visibilities (the Friends Only gap noted in I3a-3 is closed).
- `ListDetailState.showsAddItemAction` is defined and tested but no view uses it: L3 adds no Add Item control (the old button only set an unpresented sheet and was removed).

## Not done or partial
- Visual check not performed (see Gate 2); no screenshots of the list screens exist.
- Dynamic Type scaling cannot hold while `AppTypography` uses fixed sizes (a DesignSystem follow-up).
- The deferred items above.
