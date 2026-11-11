# I3c-4: Item screens on capability flags, the destructive token, and InlineErrorBanner (Story D)

Branch: feat/i3c-items. Path: full pipeline (capability-flag-driven UI). Gate 1: Docs/epics/I3c-items.md "Story D" and "Story D Gate 1 addendum". Applied: D1, D5 (the compile-only adaptations from Story C are replaced here).

## What changed
- `Color.destructiveColor` (`Color(uiColor: .systemRed)`) in DesignSystem/Colors/AppColors.swift.
- `InlineErrorBannerState` / `InlineErrorBannerAction` (pure; actions `[tryAgain]`, `[dismiss]`, `[tryAgain, dismiss]`, `[]`; blank message falls back to "Something went wrong. Please try again."; label "Error. " + message; minimum button height 44) and the `InlineErrorBanner` view (icon + wrapping message as one accessibility element, buttons below left-aligned in fixed order, 44 pt, AppSpacing tokens, destructiveColor at low opacity, `ViewThatFits` and vertical stacking at accessibility sizes, announcement on appear, light/dark/large-type previews).
- `ItemErrorPresentation` (isRetryable, banner(for:hasRetryAction:) nil only for `.sessionEnded`, leavesScreen true only for `.notFound`).
- Item screens rebuilt on `ItemListState`, `ItemDetailState`, `ItemRowState`, `ItemPermissions` (new `ItemListContext` carries the flags so views never read `.capabilities`; the existing `ListViewScanTests` forced this): `ItemsSectionView` (new), `ItemFormFields` (new), `ItemStatusStyle` (new, status colour tokens replace raw `.gray`/`.orange`), `ItemRow`, `ItemDetailView`, `AddItemView`, `EditItemView`, and the item section of `ListDetailView`.
- Mutation errors are local `@State` of the initiating view (Add `creationError`, Edit `saveError`, Detail `deleteError`), shown with `InlineErrorBanner`, cleared on dismiss, retry, cancel and disappear. The list shows `loadError` with a banner (Try Again = `refreshItems`) and calls `clearLoadError()` on disappear (ListDetailView.swift:116-118; ItemDetailView.swift:76). No `.alert(` remains in Items. Delete is `Button(role: .destructive)` with `.tint(Color.destructiveColor)` and the `confirmationDialog` on that button (ItemDetailView.swift:237-261).
- `ItemService`: `listLoadToken` guard so only the newest list load may set `loadError` or clear `isLoadingItems` (carried Story C finding 1). The detail Delete error is surfaced (carried finding 2). `ItemDetailState.remainingQuantity` clamped with `max(0, ...)`.
- `GiftItem.swift` trimmed: deleted `isAvailable`, `isPurchased`, `canEdit`, `totalPrice`, `totalSpent`, `remainingQuantity`, `isPartiallyPurchased`, `isFullyPurchased`, `purchaseProgress` and a commented-out block; no production code or test read the last six, and the Purchases screens read only `id`, `name`, `quantityRequested`, `totalQuantityPurchased`, `expectedUnitPrice`, `listId`. Stored properties and the bridge are unchanged.
- Dead code removed: commented-out undo/purchase calls, the "Mark as purchased" dialog, alert plumbing, consumers of removed service members.

## Files
Added (production): DesignSystem/Components/{InlineErrorBannerState,InlineErrorBanner}.swift; Features/Items/ViewState/ItemErrorPresentation.swift; Features/Items/Components/{ItemsSectionView,ItemFormFields,ItemStatusStyle}.swift.
Changed (production): DesignSystem/Colors/AppColors.swift; Features/Items/Services/ItemService.swift; Features/Items/ViewState/ItemViewState.swift (clamp, `ItemListContext`, `linkURL`, context convenience inits; existing inits unchanged); Features/Items/Components/ItemRow.swift; Features/Items/Views/{ItemDetailView,AddItemView,EditItemView}.swift; Features/Lists/Views/ListDetailView.swift (item section, Add Item sheet, onDisappear); Core/Models/GiftItem.swift.
Deleted: none (members only).
Added (tests, ChristmasTrackerTests): DesignSystem/{InlineErrorBannerStateTests (12), DestructiveColorTests (2)}.swift (new folder); Features/Items/{ItemErrorPresentationTests (6), ItemServiceListSwitchTests (7), ItemDetailStateRemainingTests (4), ItemUIRulesScanTests (17), GiftItemTrimScanTests (2)}.swift.
Changed (tests): Features/Items/LegacyGiftItemScanTests.swift (5 -> 7 tests: TRANSITIONAL allowlist entries removed, `allowlistIsFinal` and `rewrittenScreensAreClean` added, three Story D files added to the clean list). Deleted: none.
Docs: Docs/epics/I3c-items.md (Story D addendum), this report.

## Test arithmetic (source: command output and the test-writer's grep counts)
1921 (end of Story C) + 50 new files' tests (12 + 2 + 6 + 7 + 4 + 17 + 2) + 2 added to LegacyGiftItemScanTests = 1973, matches the run. 0 rewritten, 0 deleted. Package 212, release 92, destination 17.

## Verification (source: commands I ran)
Before the commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 1973 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.017 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.019 seconds.
```
After the commit: filled in the Story E commit (commits are never amended). Story C after-commit: no separate verify run was made on the clean 5f05709 tree; the pre-commit run above in I3c-3 was on identical content, and the first run after it is the Story D run above (which is 5f05709 plus Story D).

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warnings: (1) Archive button in ListDetailView is `role: .destructive` without the destructiveColor tint and uses `Color.accentColor` (Story A code, outside rule 3's item scope; banked); (2) Leave List and Remove Member dialogs are attached at screen level (old screens, banked); (3) stepper bounds hard-coded (confirmed against the contract by the acceptance reviewer); (4) a banner constant is reused as the general tap-target height (a shared token would be cleaner; banked). Process notes: two `cd` uses and one empty heredoc command by the implementer (no effect, no file written). I also used one `cd` in a survey command during orchestration, which moved the session directory until I returned to the repo root; no effect on files.
- Acceptance-reviewer: APPROVE, no blocking items; ran verify itself (OK). Privacy traced end to end: no view reads `myRole` or raw status/offList/purchases (ItemViewState.swift:94-106, :201-229, :142-153); `ItemListContext` carries flags only; the always-visible items section leaks nothing. Purchase entry = `canPurchase` only (ItemViewState.swift:228; ItemDetailView.swift:207); history also needs a status marker (stricter, safe). UI rules verified (ItemDetailView.swift:238-256, ListDetailView.swift:324, InlineErrorBanner.swift:40-85). Token guard correct (ItemService.swift:49-116, :341-360). Stepper bounds match the contract (quantity 1-999, priority 1-10).
  Findings recorded: M1 `.notFound` closes the screen with no "gone" message (the addendum asked for a message in the list; accepted as a deliberate divergence because `goneItemId` is only cleared at teardown, so a list message would stick; needs a small service change if Brian wants it). M2 `loadError` is one shared property read by list and detail, cleared on disappear by both (matches the brief; note the coupling). M3 no unit tests for view glue. L1 stricter purchase-history gate. L2 a same-list stale refresh can overwrite newer items (pre-existing). L3 Leave dialog and Archive confirm tint (banked). L4 only price has inline field validation. L5 the Add sheet is swipe-dismissible while a create is in flight (service handles the late result).
- No rework loop was needed.

## Deviations, bugs, scope
- `.notFound` closes without a list message (M1). The items section always shows (the old "hide for viewers with no items" gate is gone because the empty copy never hints at hidden state). Add Item is presented for the first time (nothing opened AddItemView before). Forms gained an Image URL field and a quantity range 1-999; the Edit "surprise gift" notice that read raw `offList` was removed; the "Surprise Gift" toggle was already removed in Story C.
- No contract disagreement found; nothing added to Docs/contract-issues.md. No real bugs found in pre-existing code beyond those fixed above.
- Screenshot sanity check: NOT PERFORMED. The simulator was booted but the app sat on the login screen and a mock-mode launch was not attempted. Previews exist but were not rendered by me. Brian's real-mode check covers the screens.

## Not done or partial
- No visual or simulator verification of any item screen or the banner (see above).
- No unit tests for the SwiftUI views themselves (banner announcement, Dynamic Type, the `.notFound` close path, load banner wiring); covered only by scans and review.
- Banked, not fixed: M1 message, L2, L3, L4, L5, convention warnings 1, 2 and 4, and the ListService.swift size debt from Story A.
- L16 remains unconfirmed (D2).
