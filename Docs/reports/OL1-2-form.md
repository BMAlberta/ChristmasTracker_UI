# OL1-2: the Add Item form (story O2)

Branch: feat/ol1-offlist-purchase. Pipeline: full (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
- `Features/Items/Views/AddItemView.swift` (about 235 lines, `body` split into `creationBanner` and `toolbarContent`): the "I already bought this" toggle (default on each open, `@State`, not remembered) shown only when `OffListPurchaseOption.isToggleShown` (the `canAddOffList` and `canPurchase` flags). Add is disabled by `!option.allowsAdd(formIsValid: input != nil) || isLocked`. `createItem()` calls `step.beginCreate()` (a second create is impossible in code), snapshots the option as `sentOption` BEFORE the await, and after a successful create presents `RecordPurchaseContent` for the returned item with `startingInput` from the snapshot. Any `RecordPurchaseFinish` dismisses the form; `.recorded` and `.checkItem` run `runAfterPurchase` (runner built before the dismiss). `.itemGone` and `.cancelled` only dismiss. A swipe-dismiss of the sheet finishes the step and dismisses the form (`sheetDismissed`). The whole form and Cancel are locked while a create is in flight or the item exists. The option and the Record model use the same `formLocale`.
- `Features/Items/Components/OffListPurchaseToggleSection.swift` (new): the toggle, footer "You'll review the purchase next. It needs a price." (shown when on), accessibility hint "Opens the purchase form after you add the item"; tokens only; On and Off previews.
- `Features/Purchases/ViewState/PurchaseRefreshRunner.swift`: new `runAfterPurchase(itemId:listId:)` (the same four-step plan ItemDetailView ran inline). `ItemDetailView.refreshAfterPurchase` now calls it; nothing else moved.
- `Features/Purchases/Views/RecordPurchaseServiceReader.swift` (new, not in the brief's file list): type `RecordPurchaseEnvironmentReader`, a small generic view that reads `\.purchaseService` and hands it to a content closure, so AddItemView can build the model with `startingInput:` and `locale:` without naming the purchase service (the scan test forbids that). `Features/Purchases/Views/RecordPurchasePrefilledPreview.swift` (new): the prefilled sheet preview with the mock services.
- Tests (new files only; no existing test edited apart from two formatting wraps in this story's own new tests): `PurchaseRefreshRunnerAfterPurchaseTests`, `OffListPurchaseFormScanTests` (toggle in one place and only in AddItemView, no purchase logic copied, no logging or price/total/name interpolation, size and token rules, ChristmasTrackerApp.swift untouched), and the decision 9 session-end tests `OffListPurchaseCreateSessionEndTests`, `OffListPurchaseSheetSessionEndTests`, `RecordPurchaseModelSessionEndStartingInputTests`.

## Commands and raw output
Red phase (test-writer): `scripts/test.sh` exit 65; six compile errors, all `Value of type 'PurchaseRefreshRunner' has no member 'runAfterPurchase'`.

After (before commit), `scripts/verify.sh`:
```
** BUILD SUCCEEDED **
--- tests: 5410 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: OK ===
```
Baseline 5334; O1 added 49 (5383); O2 added 27 (5410).

## Reviews
- Convention reviewer: PASS with warnings. Fixed: `body` length, two test lines over 120 characters. Not fixed: the type `RecordPurchaseEnvironmentReader` sits in `RecordPurchaseServiceReader.swift` (a rename of the type fails the existing scan `noPurchaseLogic`, which forbids the text `PurchaseService` in the feature files; a file rename needs a move command; cosmetic). The reviewer also noted a cleaner alternative: optional `locale` and `startingInput` parameters on the existing `RecordPurchaseView` wrapper, which would remove the reader. Not done, to keep the change to the brief's one allowed model parameter and avoid touching more of the purchase views.
- Acceptance reviewer: first REJECT, then APPROVE after the fix.
  - Defect 1 (code): the prefill was read after the create's await from fields that were still editable, so editing the price or quantity while the create ran could change or skip the sheet. Fixed with the `sentOption` snapshot and the full form lock. Re-review confirmed at AddItemView.swift lines 144-154.
  - Defect 2 (tests): no session-end test (decision 9). Added; they passed against the current code.

## Deviations
- Two new files outside the brief's file list (the reader and the prefilled preview), both in Features/Purchases/Views/, both explained above.
- No "toggle off" AddItemView preview: the toggle state is private view state. The toggle section's On and Off previews cover it; the AddItemView Owner and Member previews are unchanged.
- The decision 7 wording asks for a force-refresh of the item, the items and the list detail on `checkItem` and the stats caches on `recorded`; the existing plan runs all four steps for both, and Add reuses it as is.

## Not done or partial
- Not run in the simulator; the agents never saw the simulator or the network. The acceptance reviewer's screenshot check was not performed.
- Open question for Brian's device check: both `.interactiveDismissDisabled()` (outside the sheet content) and `RecordPurchaseContent`'s own `interactiveDismissDisabled(model.isSubmitting)` are set, and it is not known which one SwiftUI honors, so a swipe on the sheet may or may not be blocked. The code is safe either way (a swipe finishes the step and dismisses the form, so a second create is impossible). The sheet closing and the form dismissing happen in the same transaction; check that transition on a device.
- The footer text "You'll review the purchase next. It needs a price." was used as given; no change proposed.
