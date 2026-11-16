# Handoff: iOS to Brian, package OL1 (record the purchase when adding an off-list item)

Date: 2026-11-15. Branch: feat/ol1-offlist-purchase (from master at the CL1 merge, e0a0afd). Nothing was pushed.

## Contract issues found
None. No API model, contract file or network behavior was touched. `contract/STATUS.md` said CONFORMANT (decisions revision 41); S17, S11 and S12 in `Docs/DECISIONS.md` match the brief. `ItemService.createItem` already returned the created `ListItem`, so no service signature changed.

## What changed (per story, with commit)
- **Brief** (9019ab4). Docs/epics/OL1-offlist-purchase.md: decisions, Gate 1 spec, inventory.
- **O1, the pure rules** (ec2a717). `OffListPurchaseOption` (toggle visibility from the `canAddOffList` and `canPurchase` flags in Add mode only; Add allowed; total in integer cents with a cap of 99,999,999 cents because the Record Purchase form rejects a cost above 999999.99; two-decimal total text in the passed locale; the starting `RecordPurchaseFormInput`). `OffListPurchaseStep` (`idle`, `creating`, `createdAwaitingPurchase(item)`, `finished`; a second create is rejected). `RecordPurchaseModel.init` gained ONE optional trailing parameter `startingInput` (diff +3/-2). Report: Docs/reports/OL1-1-rules.md.
- **O2, the form** (19a1cff). `AddItemView` shows the "I already bought this" toggle (on by default each open, new `OffListPurchaseToggleSection`); price is required while it is on; on a successful create it presents the existing `RecordPurchaseContent` for the new item, prefilled (quantity and the computed total, everything else empty); every finish dismisses the form; `.recorded` and `.checkItem` run the refreshes through the new shared `PurchaseRefreshRunner.runAfterPurchase(itemId:listId:)`, which `ItemDetailView` now calls too. Report: Docs/reports/OL1-2-form.md.

## Test counts
- Baseline (Step 0): app 5334 passed, 0 failed, 0 skipped; TrackerAPI package 212 tests in 16 suites.
- After O1: 5383 (+49). After O2: 5410 (+27). Package suite 212 throughout. Total new: 76.
- Final `scripts/verify.sh` (after commit 19a1cff): `--- tests: 5410 passed, 0 failed, 0 skipped ---`, package `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`.

## EDITED tests (marker `EDITED (OL1-<story>)`)
- None. No existing test was edited, removed or weakened; the existing `RecordPurchaseModel` tests ran unchanged. Two formatting wraps (lines over 120) were made in test files that this package itself added.

## Stories stopped or partly done
- None stopped. One review rejection in O2 (the prefill was read after the create from editable fields, and decision 9 had no test); fixed in the same commit and re-approved by the same reviewer.

## What the API team must do
Nothing.

## Open risks
- **Cancelling the Record Purchase sheet leaves an unpurchased off-list item** (decision 8): the item exists, it is hidden from the recipient and other members see it, and the member must record the purchase later from the item. The form dismisses and no copy explains it.
- **The two calls are not atomic by design (S17).** The create can succeed and the purchase can then fail, be cancelled, or end with `checkItem`; the item stays. An atomic option is revisited after V1.
- **Swipe-dismiss of the sheet is untested on a device.** `.interactiveDismissDisabled()` is set outside `RecordPurchaseContent`, which sets its own `interactiveDismissDisabled(model.isSubmitting)`; it is not known which one SwiftUI honors. The code is safe either way: a swipe finishes the step and dismisses the form, so a second create is impossible, but no refresh runs on that path (nothing was recorded). The sheet closing and the form dismissing happen in the same transaction; check that transition on a device.
- **Total cap.** An item whose unit price times quantity is above 999999.99 cannot be added with the toggle on (Add stays disabled), because the Record Purchase form could not record it. The footer does not explain this; turning the toggle off adds the item as before.
- **Refresh scope.** The brief says `checkItem` refreshes the item, items and list detail and `recorded` the stats caches; the existing plan runs all four steps for both, and Add reuses it unchanged.
- **Scope deviation.** Two files outside the brief's list: `RecordPurchaseServiceReader.swift` (type `RecordPurchaseEnvironmentReader`, a small view that reads `\.purchaseService` so AddItemView can build the model without naming the purchase service, which the scan test forbids; file and type names differ, cosmetic) and `RecordPurchasePrefilledPreview.swift`. The reviewer's simpler alternative (optional `locale` and `startingInput` on `RecordPurchaseView`) was not taken.
- No "toggle off" AddItemView preview (the state is private); the toggle section's On and Off previews cover it.
- Nothing ran on a simulator or the network; the agents never saw either. The acceptance reviewers' screenshot check was not performed.

## Banked items (not done, for later)
- Atomic create-and-purchase API (S17, after V1).
- Replace the reader with optional parameters on `RecordPurchaseView`, and rename file or type to match.
- Say why Add is disabled when the total is over the cap (a footer line), if it ever matters.
- Remember the toggle, or add a note after a cancelled sheet, only if you want either.

## PROGRAM.md section 9 line
OL1 (record the purchase when adding an off-list item) on feat/ol1-offlist-purchase: Add Item has an "I already bought this" toggle (on by default, price required, member lists only) that opens the existing Record Purchase form prefilled for the new item; two calls by design (S17), cancelling the form leaves the item unpurchased; 5410 app and 212 package tests green; real-mode check pending; nothing pushed.

## Package-end diff
`git diff --stat master...HEAD` (before this handoff commit; 24 files, 1961 insertions, 43 deletions) lists only app and test sources under ChristmasTracker/, Docs/epics/OL1-offlist-purchase.md and Docs/reports/OL1-*.md: nothing under contract/, LocalPackages/, any `.pbxproj`, the synced Docs files, the dot-folders, or ChristmasTrackerApp.swift. Re-run after the final commit; the result is in the final message.

## Brian's real-mode check
Needs the local API running (seeded). Use a seeded MEMBER (not owner, co-owner or recipient) on a list where a member can add; Mike's budget is already over its limit, so a purchase by Mike also tests the budget confirmation.
1. **Real mode on.**
   - Debug build with `-apiModeOverride real`, sign in as a seeded member, open a list where you can add items.
   - Expect: the list opens.
2. **The toggle.**
   - Tap Add Item.
   - Expect: an "I already bought this" toggle, ON, and a note that the item is hidden from the recipient (as today).
   - Expect: the Add button is disabled until you give a name and a price.
3. **Price required.**
   - Type a name only. Expect: Add disabled. Add a price of 12.50 and quantity 2. Expect: Add enabled.
   - Turn the toggle off. Expect: Add stays enabled without a price.
4. **Add and record.**
   - Toggle on, name "Test gift", price 12.50, quantity 2, tap Add.
   - Expect: the item is created and the Record Purchase form opens already filled with quantity 2 and a total of 25.00.
   - Tap Record. Expect: the form closes, the item shows as purchased, and your Statistics reflect the 25.00.
5. **Budget confirmation.**
   - As Mike (budget already over), repeat step 4 with a price that goes over.
   - Expect: the existing budget warning panel; confirm it. Expect: the purchase is recorded.
6. **Cancel the review.**
   - Add another item with the toggle on and tap Cancel on the Record Purchase form.
   - Expect: the form closes, the item exists and is not purchased, and you can record it later from the item.
7. **Toggle off.**
   - Add an item with the toggle off.
   - Expect: no Record Purchase form; the item is created as before.
8. **No toggle for an owner.**
   - Open a list you own and tap Add Item.
   - Expect: no "I already bought this" toggle.
9. **No toggle on Edit.**
   - Edit an item.
   - Expect: no toggle.
10. **Offline create.**
    - Turn the network off, fill the form with the toggle on, tap Add.
    - Expect: the existing error banner, the form stays open, no Record Purchase form, no item created.
11. **Sign out in the middle.**
    - With the Record Purchase form open, sign out (if reachable) or background the app until the session ends.
    - Expect: the login screen, no crash, no stale form after signing in again.
12. **Swipe the sheet (extra, from the open risks).**
    - With the Record Purchase form open and not submitting, swipe it down.
    - Expect: either nothing happens, or the sheet and the Add form both close and the item exists unpurchased; never a second Add form with the same item.

Which checks Brian ran: NOT PERFORMED yet (to be filled in by Brian). The agents never saw the simulator or the network.

## Commits (git log --oneline master..HEAD, before this handoff commit)
```
19a1cff OL1: offer to record the purchase when adding an off-list item
ec2a717 OL1: add the already-bought rules
9019ab4 OL1: add epic brief and inventory
```
