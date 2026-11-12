# I4a-4: The Record Purchase screen and the item detail integration

Branch: feat/i4a-record-purchase. Pipeline: full (isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer one after the other). Gate 1 spec: Docs/epics/I4a-record-purchase.md, section "Story C Gate 1 (detailed)". Contract: CONFORMANT, decisions revision 32; no contract slice is new.

## What changed
- `RecordPurchaseView` is rewritten. It takes a `ListItem`, the list's `ItemListContext` and an `onFinish` callback, and it no longer references the legacy `GiftItem` or the legacy purchase types. The form has the item summary, a quantity stepper (at least 1, no maximum), the total cost, store name, confirmation number, tracking number and notes (the four optional fields exist in the generated body), and the unit cost line only when valid.
- `RecordPurchaseModel` (`@MainActor @Observable`) drives the pure `RecordPurchaseFlow` and calls `PurchaseService`. It is a new interface beyond the brief (see Deviations 1).
- Pure pieces: `PurchaseRefreshPlan` (three steps, ids only), `RecordPurchaseErrorPresentation`, `RecordPurchaseItemSummary` (no "already purchased" member; remaining text only from the server's `quantityRemaining` and only with gift activity).
- Components: `BudgetWarningPanel` (inline: one row per warning, the notice, Cancel, a prominent Record Anyway, Edit Details), `RecordPurchaseFormFields`, `RecordPurchaseRecordSection`, `RecordPurchaseExpiredNotice`, `RecordPurchasePreviews` (editing, over-purchase, awaiting confirmation with a recipient and a total warning, expired, error).
- `ItemDetailView`: the Record Purchase button appears exactly when `state.showsPurchaseEntry`; "View Purchase History", `DetailSheet.purchaseHistory` and `legacyPurchaseItem` are gone. On `.recorded` the sheet closes and the screen runs `PurchaseRefreshPlan.steps(...)` in order (itemService.loadItemDetail; itemService.refreshItems or loadItems; listService.refreshListDetail). The follow-up results are discarded, so a failed refresh never becomes a purchase error; the screens' own banners apply. On `.itemGone` the sheet closes and the detail screen dismisses. On `.cancelled` the sheet closes.
- Bridge: `ListItem.legacyPurchaseItem` and the now unused `import TrackerAPI` are deleted from `Core/Models/GiftItem.swift`. Searched: a grep of ChristmasTracker/ and Docs/ for `legacyPurchaseItem` (after the change the only hits are the new scan rules and tests that assert it is gone, plus historical docs) and for `decimalToDouble` (still used by the item and purchase repositories, so the package helper stays). The only users were `ItemDetailView` (removed) and `GiftItemLegacyBridgeTests` (deleted). `GiftItem` itself and every other legacy purchase file are untouched.

## Privacy and dialogs (as Brian asked: file and line, read by the acceptance-reviewer)
- Exactly ONE `.confirmationDialog` in the new and rewritten files: `Features/Purchases/Views/RecordPurchaseRecordSection.swift:31`. It is chained on the Record Purchase `Button` (declared at lines 16-27, then `.buttonStyle`, `.tint`, `.disabled`, then the dialog), bound to `$model.isShowingOverPurchasePrompt`, with "Continue Anyway" and a Cancel with `role: .cancel` (line 39). It is not on a List, ScrollView, Form, NavigationStack, sheet or screen container.
- The other dialogs in the tree are not new code: `ItemDetailView.swift:265` (the existing Delete Item dialog, on the Delete Item button, unchanged) and `PurchaseDetailView.swift:53` (legacy, untouched). No `.alert(` exists in any new or rewritten file (the only one is in the untouched legacy `PurchaseEditView.swift:117`).
- The budget warning is the inline `BudgetWarningPanel`, not a dialog or alert.
- Gating: `RecordPurchaseModel.isAllowed` is `context.capabilities.canPurchase` and nothing else (RecordPurchaseModel.swift:87); `summary`, the prompt, panel, banner, Record button and expiry are nil or false when not allowed, and every action starts with `guard isAllowed`, so the service is never called. The item detail shows the Record Purchase button, remaining quantity, status and purchase rows only from `ItemDetailState`, which comes from the flags. A blind owner, blind co-owner, viewer-role member or PUBLIC non-member sees no purchase control, no purchase information and no quantities. `RecordPurchaseVisibilityTests` covers all seven personas on an active and on an archived list.
- Token: it exists only inside `PendingConfirmation.token` and the `send` effect (redacted in every description) and as a local passed to the one service call (RecordPurchaseModel.swift:172, 196, 222-231, 249-250). The model has no token property, and the view files contain no token identifier (scan test).

## Deviations and decisions
1. NEW INTERFACE: `RecordPurchaseModel` (and `RecordPurchaseFinish`) are beyond the brief, which adds only a pure refresh plan. Reason: the screen's behaviour (which effect leads to which service call, the identical draft, the gating, cancel, expiry, session end) must be unit tested and views are not. Recorded at Gate 1.
2. `RecordPurchaseModel.awaitingEpoch` (not in the Gate 1 listing) increments on every confirmation_required answer so the view's expiry timer restarts when a confirmation is replaced (S12).
3. Tapping Record in the failed state dismisses the error and submits from the current form without a token.
4. When the caller is not allowed, the form shows "You can't record purchases on this list." and no controls. It is reachable only by a programming error (the entry is hidden by `showsPurchaseEntry`); the line says nothing about hidden data.
5. `AppIcons` does not exist in the code base; raw SF Symbol strings are used, as `ItemDetailView` and `InlineErrorBanner` already do (new: `BudgetWarningPanel.swift:60`, `RecordPurchaseExpiredNotice.swift`). Not a Story C change; a later cleanup can add the constants.
6. `RecordPurchaseView` is split into an outer view (reads the environment service) and an inner `RecordPurchaseContent` that owns the `@State` model, because the environment is unavailable in `init`.
7. The scan counts "exactly one confirmationDialog" over the new purchase views (the existing Delete dialog in `ItemDetailView` stays).
8. PROCESS BREACH: the implementer used a short `python3` script (not `sed -i`) twice for in-place edits of ItemDetailView, RecordPurchasePreviews and RecordPurchaseView, against the command habits. The results were build- and test-verified, and the convention-reviewer found no stray files. No other agent used an interpreter. Stuck detector: no trigger (two build and test attempts; the first had one failing scan test, `noTokenInViews`).
9. Not performed: a simulator screenshot of the form (the acceptance-reviewer found a booted simulator but could not confirm the app was on the form, and took no screenshot). The previews exist; the real-mode check is Story D / Brian.
9b. AFTER-COMMIT FINDING: the first `scripts/verify.sh` on the committed tree failed only at "prohibited frameworks in changed lines". That check diffs `master...HEAD` (commits only), so it could not see the problem before the commit: two rule-proof sample strings in `RecordPurchaseViewScanTests.swift` contained the literal text of the prohibited import and dispatch API. Fixed by building those samples with string concatenation (identical strings, no rule or expectation changed) and amending the Story C commit. Lesson for later stories: the working-tree verify does not exercise this check; sample strings in scan tests must not spell the prohibited words on one added line.
10. Mock mode: no test assumes counts, statuses or quantities change after a mock purchase (the mock does not mutate items); `PurchaseRefreshPlan` lists refreshes only.

## Open items for the API team (Brian asked for these)
1. 409 MAPPING ASSUMPTION (from Story B). `createPurchase` documents 200, 201, 400, 401, 403, 404, 429 and 500. A 409 is not documented, and the middleware may throw `.conflict` before the generated Output is reached. Story B's report says the spec leaves a thrown `TrackerAPIError.conflict` unmapped for this operation, and no test pins a 409 (I did not re-read the repository mapping in Story C). If the server can answer a purchase with 409, the spec should document it and its body; otherwise the client treats it as an unexpected error. Please confirm the server never returns 409 for POST /tracker/v2/items/{itemId}/purchases (decision S12 says a stale token produces a fresh 200 confirmation_required, never a 4xx).
2. EXACT 300-SECOND TOKEN BOUNDARY (from Story B). The mock treats the token as valid up to and strictly less than 300 s (it expires strictly after `tokenLifetime`) and its tests use 299 and 301 seconds; the exact boundary is not pinned. The client expires a pending confirmation at 270 s (4:30) so it never relies on the boundary. Please confirm whether the server's limit is "less than 5 minutes" or "at most 5 minutes", and measured from the warning's creation (not from the request). It does not change the client, which expires earlier either way; it matters only for the mock's fidelity.
3. (Carried from Story B, unchanged) A 422 on this operation is not documented; the client maps it to `invalidResponse`.

## Tests
Previous total (after Story B): 2402 app tests, 212 package tests. New: 128 `@Test` declarations in 11 files (PurchaseRefreshPlanTests 7, RecordPurchaseErrorPresentationTests 5, RecordPurchaseItemSummaryTests 8, RecordPurchaseVisibilityTests 6 (7 personas x active and archived in each), RecordPurchaseModelBasicsTests 11, RecordPurchaseModelPromptTests 10, RecordPurchaseModelConfirmationTests 13, RecordPurchaseModelExpiryTests 11, RecordPurchaseModelErrorTests 17, RecordPurchaseModelTokenAndConcurrencyTests 8, RecordPurchaseViewScanTests 32) plus two support files (RecordPurchaseModelHarness, RecordPurchaseViewScanRules). Deleted: 7 (`GiftItemLegacyBridgeTests`, the bridge no longer exists). Changed: `LegacyGiftItemScanTests` (reason text of the `GiftItem.swift` allowlist entry only; entries unchanged). New total: 2402 + 128 - 7 = 2523 (matches the run). Package: 212.
Existing suites that changed deliberately, with this decision as the reason (Gate 1 item g): `GiftItemLegacyBridgeTests` deleted and `LegacyGiftItemScanTests` reason text updated, because `ListItem.legacyPurchaseItem` was deleted after nothing used it.

## Raw output (command run)
Before the commit (the Story C working tree, `scripts/verify.sh`, implementer and acceptance-reviewer each ran it with the same result):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2523 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
After-commit run for the Story B commit ef50812 (the promise in the Story B report; run by stashing the Story C work, verifying the clean tree, then restoring it):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2402 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
The after-commit run for the Story C commit is recorded in the Story D report (a report cannot contain the result of the commit that adds it).

## Gate 2
- convention-reviewer: APPROVE, no hard blocks. Checked: no Combine, GCD or force unwraps; no Double or Float money; no role reads; design tokens (raw SF Symbols noted, see Deviations 5); no logs or identifiers with a token; no `.alert`; the single confirmationDialog on the Record button; file and function sizes (largest new file 254 lines, ItemDetailView 357); no naming collisions; protected paths and legacy purchase files untouched; the bridge removal justified by grep. Warnings: the process breach (Deviations 8), `awaitingEpoch` (Deviations 2), the validation range text in `RecordPurchaseFormFields.swift` is hardcoded rather than taken from the form-state constants, and some copy bypasses `RecordPurchaseCopy` (consistent with existing style).
- acceptance-reviewer: APPROVE after running `scripts/verify.sh` itself (2523 passed, `verify: OK`). Read all views and the model in full and stated the placement of the dialog, the gating, the token location, the S12 replacement, edit details, cancel, expiry with the timer restart, the identical-draft resubmit, retry without a token, the error path, the refresh wiring and the removals, each with file and line. No vacuous test found. A simulator screenshot was not taken.
- Rejections: none. Stuck-detector log: no triggers.

## Not done or partial
- No simulator screenshot of the Record Purchase form; no real-network check (needs Brian, Story D lists the steps).
- The mock does not move item counts or status after a purchase (Story B deviation 4), so mock mode cannot show the refreshed quantities.
- The 409 mapping and the exact 300 s boundary are open items (above); neither is pinned by a test.
- The hardcoded validation range text and raw SF Symbols noted by the convention-reviewer were left as they are.
- The after-commit `scripts/verify.sh` for the Story C commit is not in this report (it is in the Story D report).
