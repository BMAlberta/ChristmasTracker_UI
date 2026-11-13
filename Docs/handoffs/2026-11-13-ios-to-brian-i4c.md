# Handoff: iOS to Brian, package I4c (clear a tracking number; delete refresh survives leaving the screen)

Date: 2026-11-13. Branch: feat/i4c-clear-tracking (not pushed). Contract: CONFORMANT, decisions revision 34 (S15), spec checksum 494100e86e46.

## Contract issues found
None. The server behavior described by S15 (an empty string clears trackingNumber on updatePurchase and updatePurchaseShipping, and notes on updatePurchase; stored and returned as null; omitted is unchanged; null is a 400) was implemented as the contract states it. It has not been exercised against a real server yet (see the real-mode check below).

## What changed
- P0: regenerated the derived spec from contract revision 34 (descriptions only; the null-schema count stayed 5).
- A: a tri-state tracking change (`PurchaseTrackingChange`: unchanged, clear, set) derived by a pure function; the shipping update carries it; the shipping Save is enabled when the status or the tracking change differs; nil, "" and whitespace-only tracking and notes display as empty. A deliberate case order in that enum works around a compiler layout crash on the simulator toolchain (see Open risks).
- B: the shipping request sends `trackingNumber: ""` to clear, the value to set, and omits it when unchanged; `updatePurchase` still sends notes only; response mapping turns null, "" and whitespace into an empty tracking number and notes; the mock mirrors S15 and never stores "".
- C: the Shipping section clears a tracking number (announcement "Tracking number cleared.", the field shows empty and Save is disabled afterwards); the delete follow-up refresh (item detail, items, list detail) now runs from the model in the Delete button's task, so it still runs if the user swipes back mid-delete, guarded by a session generation (teardown or user switch mid-delete writes nothing); a 404 on the item refetch still drops the item; a failed refresh never turns the delete into an error. The swipe-back gesture is not disabled.
- D: stale comments from the I4b legacy-deletion report corrected (comments only), stale "Fails today" headers in the files this package touched reworded, this note.

Commits (`git log --oneline master..HEAD` at the time of writing; the Story D docs commit is added on top of these):
- 36a0408 chore: sync contract fe1a85f (Brian's contract sync)
- 105cf7f I4c: add epic brief and inventory
- dbcaf16 I4c: regenerate from contract revision 34
- 354f1e5 I4c: add the tracking number change type and clear rules
- 091ca8e I4c: send and read a cleared tracking number through the generated client
- 2539c2a I4c: clear the tracking number from the shipping section and refresh after a delete even if the user left
- (final) I4c: tidy stale comments and add the package handoff note

Reports: Docs/reports/I4c-1-regenerate.md to I4c-5-tidy-and-handoff.md. Epic brief: Docs/epics/I4c-clear-tracking.md.

## What the API team must do
Nothing. The app only relies on S15 as merged.

## Open risks
- Compiler workaround: `PurchaseTrackingChange` declares its cases as `unchanged`, `clear`, `set(String)` on purpose. With `.clear` declared after `.set(String)` the iOS 27.2 simulator toolchain emitted a bad retain (EXC_BAD_ACCESS) when a `.clear` update was copied inside `PurchaseService.updateShipping`. Why the new order avoids it was not confirmed. If it ever comes back, the fallbacks are `indirect case set` or a string plus a clear flag. A doc comment sits on the enum.
- `MockPurchaseRecorder` copies a draft's tracking number and notes as given, so a test that builds a draft with "" would store "" in the mock. Not reachable from the app (the form state maps empty to nil). Left alone because it is outside the package scope.
- ItemDetailView's handling of `.deleted` (only close) and `.gone` (close plus plan) is covered by a source scan and review, not by a behavioral view test.
- The refresh's continue-check runs between steps; a step already running is protected by ItemService's and ListService's own guards.
- About 50 older test files (51 files counted by grep across the test target) still carry a mechanical "Fails today" header (stale wording only); only the ones this package touched or that the I4b report listed were reworded.
- The tracking and delete behavior against a real server is NOT PERFORMED (needs Brian).

## Brian's real-mode check
(Needs the local backend and its seeded users from the backend repo's Docs/local-development.md; all seeded users share the password printed there. Never write passwords, ids, tokens, or the registration code into this repo.)

1. (1) start the backend on http://localhost:3010 (it must be on a commit that includes decision S15), re-seed so the ids are fresh and confirm /livez, use the "ChristmasTracker (Real)" scheme copy that carries the launch argument -apiModeOverride real (never edit the shared scheme), run the Debug build on the simulator;
2. (2) as mike.johnson@example.com (a member of list B) record a within-budget purchase (quantity 1, total 10.00) on an item in B, open its detail, choose Shipped, enter the tracking number TEST123 and Save: the detail shows Shipped and TEST123;
3. (3) clear the tracking field and Save: the field is empty, Save is disabled, and the status is still Shipped; leave the screen and reopen it: the tracking field is still empty and the status is still Shipped;
4. (4) in ONE save change the status to Delivered and enter the tracking number A1: both are saved; then clear only the tracking field and Save: the tracking number is gone and the status is still Delivered;
5. (5) Notes: type "gift wrap please" and Save, leave and reopen: it is there; clear the field and Save: after reopening there are no notes (unchanged behavior);
6. (6) delete while leaving: tap Delete, confirm, and swipe back IMMEDIATELY: when you are back on the item detail the purchase is gone without pulling to refresh, and the remaining quantity is back to what it was before the purchase;
7. (7) errors: with the backend stopped open a purchase detail you have already loaded, clear its tracking number and tap Save: an error banner appears INSIDE the Shipping section with Try Again and Dismiss and no error appears on any other screen; restart the backend and Try Again: the tracking number is cleared once;
8. (8) the I4b real-server steps that were pending (steps 2 to 10 and 12 to 15 of Docs/handoffs/2026-11-12-ios-to-brian-i4b.md) are run now if they have not been run yet;
9. (9) as nate.nonmember@example.com: an empty list of lists.

### What was not part of this package
The idempotency key (parked by the API team), clearing any other field, editing quantity, cost, store name or confirmation number, purchase history, refactoring older screens, the polish and theme passes.

### Checks performed and checks NOT PERFORMED
- Performed by the iOS side: build, the full unit suite, the package suite and the release and destination script tests (see the reports), all against fakes and a fake transport only.
- NOT PERFORMED: every step (1) to (9) above. No real backend, no real device and no real simulator run of the clear or the delete-while-leaving flow was done by the iOS side. Brian's results go here: ______.

## Section 9 of PROGRAM.md (one line)
I4c: iOS can clear a saved tracking number (S15) through the shipping section, and a purchase delete refreshes the item, items and list even if the user leaves the screen; verified with fakes only, real-server check pending with Brian.
