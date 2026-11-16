# OL1: Record the purchase when adding an off-list item
Track: iOS. Depends on: CL1 (merged to master). Blocks: nothing.
Contract state: synced from backend commit b52957c, decisions revision 41, spec sha256 43800da4ba32. `contract/STATUS.md` says CONFORMANT. No contract change in this package. S17 is present in `Docs/DECISIONS.md` (revision 41, so 40 or later is met).

Why: a member who adds an off-list (surprise) item usually already bought the gift; the point of adding it is that other members see it and do not buy it too. Today the Add Item form creates the item only, and the member must then open the item and record the purchase. This package adds an "I already bought this" choice to the Add Item form, shown only when the item will be off-list, on by default, with a required price. When it is on, adding the item creates it and then opens the existing Record Purchase form for the new item, already filled in, so the member only reviews and taps Record. All budget-warning, confirmation, error and unconfirmed-purchase behavior stays exactly the existing Record Purchase flow; this package adds no purchase logic.

The full instruction is `prompts/mobile-ui/OL1-offlist-purchase-on-add.md` (outside this repo). The decisions below are copied from it; where this file and the synced contract differ, the contract wins.

## Server contract (S17, P21, P26)
- No atomic create-and-purchase in V1: two calls. `POST /lists/{listId}/items` creates the item (the server derives off-list from the caller's role; the request has no off-list field), then `POST /items/{itemId}/purchases` records the purchase.
- The creator of an off-list item may purchase it. A purchase needs `quantity` and `totalCost`. `totalCost` is a decimal in dollars with at most two decimals (S11), computed by the client as unit price times quantity in integer cents, then divided by 100.
- A purchase over a budget limit answers with a confirmation requirement and token; the existing flow handles it (S12: a repeat purchase gets a fresh warning).
- Checked against the synced `Docs/DECISIONS.md` (S17, S11, S12): same wording, no difference.

## Decisions (1 to 11)
1. Where the choice shows: Add Item form only, only when `permissions.showsOffListNotice` is true (the list's `canAddOffList` flag; never a role) and the list's `canPurchase` flag is true. Never on the Edit form, owners or co-owners, or when `canPurchase` is false (then no toggle and the form behaves exactly as today).
2. Control: a toggle "I already bought this", ON by default each time the form opens (not remembered). Footer when on: "You'll review the purchase next. It needs a price." Off: the form is exactly today's form.
3. Price required while the toggle is on: the existing price field must hold a valid amount greater than zero (same parsing, at most two decimals) or Add stays disabled. Toggle off: price stays optional. The existing invalid-price line style is reused; no other new field.
4. Total: unit price cents times the form quantity in integer cents, shown with two decimals. Existing price parsing and Decimal helpers; no floating point. A total that overflows or is zero keeps Add disabled (defensive; tested).
5. Order: Add runs the existing create. A failed create does nothing else (existing banner, form stays open and editable). A successful create with the toggle on opens Record Purchase for the NEW item (the `ListItem` returned by create) with quantity = form quantity, total = computed total as two-decimal text, and store, notes, confirmation and tracking number empty. Nothing is recorded until the member taps Record.
6. The sheet is the existing `RecordPurchaseContent` and `RecordPurchaseModel`, unchanged except ONE optional initializer parameter on the model for the starting input. No parameter means exactly today's behavior; existing model tests pass unchanged. No purchase logic is copied or forked.
7. Presenting: a sheet from the Add Item view over the form. While the sheet is up and after the item exists, Add and the fields are disabled and a second create is impossible in code (a created-item marker). Any finish (`recorded`, `itemGone`, `cancelled`, `checkItem`) dismisses the Add form. The refreshes that ItemDetailView runs afterwards run here too, through a small shared function if the code is inline in the view; nothing else moves.
8. Cancelling the sheet leaves the item created and unpurchased; the form dismisses; no extra copy. The handoff states this as a known consequence.
9. Session end while the create is in flight or the sheet is open applies nothing and shows nothing beyond the existing flows (a test is added).
10. Privacy: price, total, item name and any token are never logged, reported, put in an error description or a Sentry span. A scan test is added in the pattern of the other purchase files.
11. Out of scope: an atomic create-and-purchase API, recording without the review sheet, remembering the toggle, the Edit form, purchase history, any contract change, theme changes, the App Store key path, `ChristmasTrackerApp.swift` (not touched).

## Gate 1 spec
Weight: full pipeline for both stories (isolated test-writer and implementer, convention-reviewer and acceptance-reviewer). Reason: the package touches the purchase and budget-confirmation flow and the capability-flag-driven form.

### O1: the pure rules (no UI)
- Contract slice: none (no new call). `createItem` and `recordPurchase` are used as they are.
- New interface: yes.
  - `OffListPurchaseOption` (pure, nonisolated, Sendable, no SwiftUI). Inputs: the list `ListCapabilities` (through `ItemPermissions`), a form mode (add or edit), the price text, the quantity, and the toggle. Answers: `isToggleShown`, `isAddAllowed(otherFieldsValid:)` or an equivalent that combines the toggle rule with the existing form validity, `totalCents: Int?`, `totalText: String?` (two decimals), and `startingInput: RecordPurchaseFormInput?`.
  - `OffListPurchaseStep` (the post-create state): `idle`, `creating`, `createdAwaitingPurchase(ListItem)`, `finished`, with transitions `beginCreate`, `createSucceeded(item, opensPurchase)`, `createFailed`, `purchaseFinished`. A second `beginCreate` after `createdAwaitingPurchase` or `finished` is rejected (returns false); a failed create returns to `idle`.
  - `RecordPurchaseModel.init`: one new optional parameter `startingInput: RecordPurchaseFormInput? = nil`. With nil, the stored input is exactly today's default.
- Total rules: cents = priceCents x quantity using integer arithmetic with overflow-reporting operations; a zero price, a zero total, an overflow, or a total above 99,999,999 cents (the Record Purchase form rejects a cost above 999999.99, so a larger total could never be recorded) means Add stays disabled.
- Acceptance:
  - Toggle visibility table: owner list, co-owner, member on an off-list-capable list, no purchase capability, Edit mode.
  - Add allowed table: toggle on with no price, zero price, invalid price, three decimals, valid price; toggle off with no price allowed.
  - Total arithmetic in cents: 1 x 12.50, 3 x 12.50 = 37.50, 3 x 0.10 = 0.30, 7 x 19.99 = 139.93, a large quantity near the limit, overflow rejected.
  - Starting input fields (quantity, total text, empty store, notes, confirmation and tracking number).
  - State machine: a second create is rejected after the first succeeded; a failed create returns to idle.
  - The model with a starting input behaves like the default model in every other way; the existing model tests run unchanged.
- Files: `Features/Items/ViewState/OffListPurchaseOption.swift`, `Features/Items/ViewState/OffListPurchaseStep.swift`, `Features/Purchases/ViewState/RecordPurchaseModel.swift` (one parameter). Tests under `ChristmasTrackerTests/Features/Items/` (one type per file) and the existing model test files unchanged.

### O2: the form
- Contract slice: none.
- New interface: no new protocol. A small extracted subview for the toggle and its footer; a shared function for the post-purchase refreshes (see inventory).
- Acceptance:
  - AddItemView shows the toggle per decision 1, default on, footer per decision 2, after the form fields where the existing comment says it belongs.
  - The price rule feeds the Add button's disabled state.
  - A successful create with the toggle on sets the created marker, then presents `RecordPurchaseContent` for the returned item with the starting input.
  - Every `RecordPurchaseFinish` dismisses the form and runs the refreshes (decision 7).
  - Add and the fields are disabled while the sheet is up; a second create is impossible in code.
  - Session end during create or while the sheet is open applies nothing and shows nothing new.
  - Accessibility: the toggle has the label and the hint "Opens the purchase form after you add the item"; the price requirement is in the footer text.
  - Scan tests: the toggle is built in one place and only in AddItemView (never EditItemView); no purchase logic copied (the new files do not call the purchase repository or service directly); the new files contain no log, report or error text with a price, total or name.
  - Previews: member with the toggle on and off, owner (no toggle), the sheet prefilled with the mock services.
- Files: `Features/Items/Views/AddItemView.swift`, a new toggle subview in `Features/Items/Components/`, `Features/Items/Views/ItemDetailView.swift` (only if the refresh call moves into the shared function), and the shared function's home (see inventory). Keep every file under the length limits.

## Inventory
"A/" = ChristmasTracker/ChristmasTracker/. "T/" = ChristmasTracker/ChristmasTrackerTests/.

Baseline (Step 0, 2026-11-15): `scripts/verify.sh` ends with `tests: 5334 passed, 0 failed, 0 skipped` and `** BUILD SUCCEEDED **`; `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.

### The Add form
- A/Features/Items/Views/AddItemView.swift (143 lines): holds the field `@State` (`name`, `description`, `url`, `imageUrl`, `priceText`, `quantityRequested`, `priority`, `imageFill`, `isCreating`, `creationError`). `input` is `ItemFormValidation.makeCreateInput(...)`; the Add button is `.disabled(input == nil || isCreating)`. The comment at lines 60 and 61 ("An off-list item bought on creation needs an API decision first; if it is ever built, its control goes here, after the form fields") marks where the control goes and is replaced by this package. `createItem()` calls `try await itemService.createItem(listId:, input)` and then `dismiss()`; `CancellationError` is silent; any other error is mapped to `ItemError` and shown in the banner, unless `ItemErrorPresentation.leavesScreen` (then dismiss). `.onDisappear` cancels the image fill and clears the error. Previews: "Owner" and "Member (surprise item)".
- A/Features/Items/Components/ItemFormFields.swift (73 lines): shared by Add and Edit. Pricing section: `$` plus a `Price (optional)` field, the invalid-price line (`ItemError.invalidPrice.userMessage`, `appCaption1`, destructive color) when the text is non-empty and `parsePrice` fails, and the quantity stepper (1 to 999). `showsOffListNotice` shows the "hidden from the recipient" label in the last section. Header comment says "There is no offList control anywhere"; the toggle is not an offList field (the request still has none), and the comment is updated if needed.
- A/Features/Items/Views/EditItemView.swift: does not get the toggle (checked by a scan test).
- A/Features/Items/ViewState/ItemFormValidation.swift (187 lines): `parsePrice` is strict (ASCII digits, optional dot and one or two digits, 0 to 999999.99, returns `Decimal?`); zero is accepted today, so the new rule adds "greater than zero". `makeCreateInput` returns nil when invalid, with `expectedUnitPrice: parsePrice(priceText)`.
- A/Features/Items/ViewState/ItemPermissions.swift: `showsOffListNotice` is `canAddOffList`; `canPurchase` is exposed. No role is read.

### How the create returns the item today
- A/Features/Items/Services/ItemService.swift: `@discardableResult func createItem(listId:, _ input:) async throws -> ListItem` already returns the created `ListItem` (the repository's `createItem` result, after the cache write and the append to `items`). No signature change is needed; AddItemView currently discards the result. Session safety: the call captures `generation`, runs in `perform` (cancel handle in `inFlight`), calls `ensureCurrent` after each await, and a session end turns into `CancellationError` (`failure(...)`). It uses a manual `SentrySDK` span with an explaining comment, logs only fixed strings ("Created item", "create item failed"), and never logs ids, names or prices. AddItemView already treats `CancellationError` as "nothing to show".

### The Record Purchase sheet
- A/Features/Purchases/Views/RecordPurchaseView.swift (158 lines): `RecordPurchaseView` reads `purchaseService` from the environment and wraps `RecordPurchaseContent(item:context:service:onFinish:)`. `RecordPurchaseContent` owns `@State model` and calls `onFinish` once through `.onChange(of: model.finish)`; it has two initializers (item/context/service, or a ready-made model). It has its own `NavigationStack` and Cancel button, and sets `interactiveDismissDisabled(model.isSubmitting)`.
- A/Features/Purchases/ViewState/RecordPurchaseModel.swift (278 lines): `@MainActor @Observable`. `init(item:context:service:now:currencyCode:locale:)` sets `storedInput` to quantity `RecordPurchaseFormState.defaultQuantity(quantityRemaining:)` (known only when `canSeeGiftActivity`) and empty text. This is where the optional `startingInput` parameter goes. `RecordPurchaseFinish` is `recorded(RecordedPurchase)`, `itemGone`, `cancelled`, `checkItem`. `perform` maps `CancellationError` to `.sessionEnded` in the flow, so a session end during the sheet does not record or show a new error.
- A/Features/Purchases/ViewState/RecordPurchaseFormState.swift (138 lines): `RecordPurchaseFormInput` (quantity, totalCostText, storeName, notes, confirmationNumber, trackingNumber). `parseTotalCost` accepts at most two fraction digits, above 0 and at most 999999.99, and uses the locale's decimal separator (the model's default locale is `.current`); the starting total text is built with the same separator rules so that it parses in the form (O1 decides how: a `Locale` parameter with the same default as the model, tested with a comma-separator locale).
- A/Features/Purchases/Domain/PurchaseDraft.swift: `PurchaseDraft` (quantity, `totalCost: Decimal`, optional strings). Nothing here changes.
- Money helpers to reuse: `ItemFormValidation.parsePrice` (price text to `Decimal`), `RecordPurchaseFormState.parseTotalCost` (total text to `Decimal`), and the Decimal helpers in `LocalPackages/TrackerAPI` ("Money helpers" suite). O1 confirms the exact helper for cents conversion; none is added if one exists. No `Double` anywhere.

### How ItemDetailView handles the Record Purchase finish
- A/Features/Items/Views/ItemDetailView.swift (411 lines): `sheet = .recordPurchase` presents `RecordPurchaseView(item:context:onFinish:)`; `handleRecordPurchaseFinish(finish, item:)` sets `sheet = nil` first, then:
  - `.recorded` and `.checkItem`: `Task { await refreshAfterPurchase(item) }`;
  - `.itemGone`: `dismiss()` (the item service already dropped the item and set `goneItemId`);
  - `.cancelled`: nothing.
- `refreshAfterPurchase(item)` builds `PurchaseRefreshPlan.steps(itemId:, listId:, currentItemsListId: itemService.currentListId)` and runs `refreshRunner.run(steps)`. `refreshRunner` is `PurchaseRefreshRunner(itemService:, listService:, spendingCaches: spendingCacheInvalidator)`. The plan has four steps: item detail, items (refresh or load), list detail, spending invalidation (the stats caches). A failed step never throws and never stops the next one.
- A/Features/Purchases/ViewState/PurchaseRefreshPlan.swift and PurchaseRefreshRunner.swift hold the pure plan and the runner. The only inline code is the five-line `refreshAfterPurchase` and the `refreshRunner` property in the view; the shared function is a method on `PurchaseRefreshRunner` (for example `runAfterPurchase(itemId:listId:)`, which reads the item service's current list id and runs the plan), and ItemDetailView calls it. Nothing else moves. Decision 7 says the item detail, the items and the list detail are force-refreshed on `checkItem` and the stats caches on `recorded`; the existing plan already runs all four steps for both, so Add reuses it as it is and the report notes the difference in wording.
- AddItemView needs `listService` and `spendingCacheInvalidator` from the environment for the runner (the same environment keys ItemDetailView reads).

### Session end
- ItemService and PurchaseService are `SessionClearable` and drop results after the generation changes. AddItemView treats `CancellationError` as silent; the Record sheet's model maps it to `.sessionEnded`. The session-end test for O2 is done at the pure state level (`OffListPurchaseStep`) and with the mock services; the app already replaces the signed-in tree on session end.

### Files this package may touch
- New: A/Features/Items/ViewState/OffListPurchaseOption.swift, OffListPurchaseStep.swift; a toggle subview in A/Features/Items/Components/; tests under T/Features/Items/ and T/Features/Purchases/.
- Edited: A/Features/Items/Views/AddItemView.swift, A/Features/Purchases/ViewState/RecordPurchaseModel.swift (one parameter), A/Features/Purchases/ViewState/PurchaseRefreshRunner.swift (one method), A/Features/Items/Views/ItemDetailView.swift (call the shared method).
- Not touched: contract/, LocalPackages/, .claude/, any .pbxproj, the synced Docs files, `ChristmasTrackerApp.swift`.

## Stories and commits
1. Step 1: this brief. Commit `OL1: add epic brief and inventory`.
2. O1: the rules. Commit `OL1: add the already-bought rules`. Report `Docs/reports/OL1-1-rules.md`.
3. O2: the form. Commit `OL1: offer to record the purchase when adding an off-list item`. Report `Docs/reports/OL1-2-form.md`.
4. Handoff. Commit `OL1: add the package handoff note`. Report `Docs/reports/OL1-3-handoff.md`.
