# Handoff: iOS to Brian, package I4a (recording a purchase, with the budget confirmation flow)

Date: 2026-11-12. Branch: feat/i4a-record-purchase (from master). Not pushed. Contract state: CONFORMANT, decisions revision 32 (spec sha256 prefix 7c5880219bd5). The commit messages say "revision 31" for the regeneration because the spec change landed at 31; revision 32 (S13) changed the decisions and docs with no spec change.

## Contract issues found
- None filed in Docs/contract-issues.md (the file is unchanged by this package). No disagreement between the spec, the guide and the client was found: the guide (7.6) documents that an expired, tampered or mismatched confirmation token gets a fresh 200 `confirmation_required` and no 4xx, and error-codes.md has no code for it, so the client has no token-error branch.
- Questions for the API team that are NOT contract rows (detail in Docs/reports/I4a-4-record-purchase-screen.md, "Open items"):
  1. 409: `createPurchase` documents 200, 201, 400, 401, 403, 404, 429 and 500 only. Please confirm the server never answers this operation with 409 (a stale token is a fresh 200, never a 4xx). No test pins a 409 mapping.
  2. The exact token boundary: is the 5-minute limit "less than" or "at most" 300 seconds, measured from the warning? The client expires a pending confirmation at 270 seconds so it never depends on this; it only affects the mock's fidelity (its tests use 299 and 301 seconds).
  3. 422: not documented for this operation; the client maps an undocumented 422 to `invalidResponse`.
- Decision L16 (purchases are accepted on an ARCHIVED list) is applied by flags only; real-mode step 13 verifies it against the server (carried from I3c, where L16 was not in the synced docs).

## What changed
- Story P0: regenerated the package spec from the synced contract (Item gains optional `quantityPurchased` and `quantityRemaining`; the null-schema guard held at 5); `readConfiguration` takes the API-mode override as a required parameter, so the configuration tests are hermetic (reports I4a-1).
- Story A: the purchase domain (`RecordedPurchase`, `PurchaseDraft`, `BudgetWarning`, `PurchaseOutcome`, `RecordPurchaseError`, all Decimal money), the pure `RecordPurchaseFlow` budget-confirmation state machine with an injected clock and one expiry constant (270 s, the server limit is 5 minutes), the form rules and parser, the warning panel state, the mapping functions, and `ListItem.quantityPurchased` / `quantityRemaining` (the item detail's remaining text now comes only from the server's `quantityRemaining`, never computed) (report I4a-2).
- Story B: `GeneratedClientPurchaseRepository` (create only, every generated Output case explicit), `MockPurchaseRecorder` (reproduces S12), a session-safe `PurchaseService` (typed errors, nothing published, the token kept nowhere), composition for real, mock and inert modes, 8 clearables (report I4a-3). Decisions accepted by you: `RecordPurchaseError` is final; the parser accepts ".50" and "12."; every type holding a token prints `<redacted token>`; a 200 `created` body without `warnings` is `invalidResponse`; `recordPurchase` returns `PurchaseOutcome`; the mock does not change mock items.
- Story C: the rebuilt Record Purchase screen (`RecordPurchaseView`, `RecordPurchaseModel`, an inline `BudgetWarningPanel`, expiry notice, previews), the soft over-purchase prompt, the refresh plan after a purchase, and the item detail integration; "View Purchase History", its sheet case and the `ListItem.legacyPurchaseItem` bridge are gone (report I4a-4).
- Behavior changes you will notice: Record Purchase now actually records (before, it only reloaded the items); a purchase that would exceed a budget shows an INLINE warning panel with Cancel, Record Anyway and Edit Details instead of an alert; a repeat overage purchase asks again; the over-purchase prompt ("Record anyway?") is a soft confirmation attached to the Record button and only appears when the server told the app how many remain; the "already purchased" line and the client-computed remaining count are gone; "View Purchase History" is gone from the item detail (the purchase status card already lists the purchases the caller may see).

## Commits (git log --oneline master..HEAD)
```
d8854ec I4a: rebuild Record Purchase with the inline budget confirmation and the flag-gated item detail entry
ef50812 I4a: record purchases through the generated client with a session-safe service
05be1e0 I4a: add the purchase domain, the budget confirmation state machine, and the form rules
9f88f78 I4a: regenerate from contract revision 31 and make the configuration tests hermetic
aabd269 I4a: add epic brief and inventory
5b98544 chore: sync the contract at 8e9985c
```
(The sync commit 5b98544 is yours; the Story D docs commit follows these, see `git log --oneline master..HEAD`. The Story C commit was amended once, see report I4a-4, item 9b.) Test totals: app suite 2523 passed (2089 after P0, 2209 after A, 2402 after B, 2523 after C), TrackerAPI package 212, release-script 92, destination-script 17. Package-end diff (`git diff master...HEAD --shortstat`, taken before this handoff commit): 100 files changed, 10941 insertions(+), 483 deletions(-); it includes your contract sync (contract/ and the regenerated package openapi.json).

## What the API team must do
- Nothing required. Please answer the three questions above when convenient (409, the 300 second boundary, 422).
- Before I4b: the spec has NO delete-purchase operation (see Open risks). The legacy iOS `deletePurchase` has no contract backing.

## Log hygiene carried to I4b (not changed here)
Raw error values are still interpolated into log strings in the legacy purchase stack, which this package did not touch on purpose: Features/Purchases/Views/PurchaseHistoryView.swift:175 (`Mock error: \(error)`), the legacy `NetworkPurchaseRepository.swift` and `MockPurchaseRepository.swift` log calls, and Core/Networking/NetworkAPIClient.swift:71, :103, :167 and MockAPIClient.swift:57. They go when I4b deletes the legacy stack. The new purchase code logs only the constant string `record purchase failed` (PurchaseService) and nothing else.

## Legacy that remains (listed on purpose)
- Legacy and untouched until I4b: `Core/Models/Purchase.swift`, `GiftItem` (the bridge to it is gone), `MockItemData`, `PurchaseHistoryView`, `PurchaseDetailView`, `PurchaseEditView`, `PurchaseRow`, the legacy `PurchaseRepository`, `NetworkPurchaseRepository`, `MockPurchaseRepository` (it also declares the legacy top-level `PurchaseError`). None of them is reachable from the item detail any more. They still use the old client and Double money.

## Open risks
- The spec has no delete-purchase operation (inventory in the epic: createPurchase, listPurchases, getPurchase, updatePurchase, updatePurchaseShipping). I4b must raise this with the API team (or drop delete) before building it. updatePurchase and updatePurchaseShipping exist, so edit and shipping status are possible.
- The new screens were never rendered by me: no simulator screenshot of the Record Purchase form or the panel was taken (the previews exist). Your real-mode check is the first visual verification, including light and dark mode and large Dynamic Type.
- Mock mode does not move item counts or statuses after a mock purchase (documented limitation), so the refreshed quantities can only be seen against the real server.
- A purchase on a WRAPPED or GIFTED item is recorded and counted but never changes the item's status (S13); the client never infers a status and shows whatever the refetched item says.
- Raw SF Symbol names in the new views because there is still no AppIcons file; the validation range text in `RecordPurchaseFormFields.swift` is hard-coded rather than taken from the form constants (convention-reviewer warnings, not changed).
- The scheme-level `-apiModeOverride` was never exercised by the configuration tests (they set and clear the process key instead).
- The `RecordPurchaseView` form shows "You can't record purchases on this list." if it is ever reached without `canPurchase` (only a programming error can do that; the entry is hidden by the flag).
- Process notes: in Story A the test-writer used `sed -i` and a one-off python heredoc on test files; in Story C the implementer used a `python3` script for in-place edits. Both are recorded in the reports; no stray files remain. The first after-commit verify of Story C failed at the prohibited-frameworks check because two scan-test sample strings spelled the prohibited words (that check diffs `master...HEAD`, so a working-tree verify cannot see it); fixed by concatenation and an amend (report I4a-4, item 9b).

## One line for PROGRAM.md section 9
I4a (iOS): recording a purchase on the generated client with the two-step budget confirmation (inline panel, replaced on a changed spend, never reused or cached token, 4:30 client expiry, redacted token types), a session-safe PurchaseService, flag-driven Record Purchase entry and soft over-purchase prompt, server-supplied quantityRemaining, refreshes after a purchase, "View Purchase History" and the legacy bridge removed; no delete-purchase operation in the spec (I4b risk); real-mode check pending.

## Brian's real-mode check
These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (all seeded users share the password printed there; never write passwords, ids, tokens or the registration code into this repo).

NOTE: the epic asked for "the fifteen steps exactly as specified" in the package prompt. That prompt was not on disk in this run (the session was cleared before Story C), so the list below is a DRAFT written by the iOS run from the brief and the seeded users used in the I3c check. Replace it with your own list if it differs, and tell me which steps to rename.

1. Start the backend on http://localhost:3010, re-seed so the ids are fresh, confirm /livez, add the launch argument -apiModeOverride real to the scheme, run the Debug build on the simulator.
2. As jane.smith@example.com (a member of A, john's self list): open an item, tap Record Purchase; the form shows the item name, requested quantity and "N remaining" and NO "already purchased" line. Record quantity 1 with a total of 19.99 (within budget): the form closes and the item detail shows the purchase, the new status and the server's remaining count after the refresh; the list and the list detail counts match.
3. Money: try 19.999 (three decimals), 0, and 1000000.00 in the form: Record stays disabled with the message; 999999.99 is accepted by the form (do not submit it unless the budget allows).
4. Soft prompt: on an item with 2 remaining, enter quantity 3: tapping Record shows the "Record anyway?" confirmation dialog pointing at the Record button with the text "Only 2 remaining. You're recording 3."; Cancel records nothing; Continue Anyway records it (the server accepts it). On a fully purchased item the text is "This item has already been fully purchased, and others may have bought it too." and recording is still possible.
5. Budget panel: as the buyer, set up a budget small enough that a purchase exceeds the recipient budget only (use the backend's budget setup from its Docs/local-development.md; the iOS run did not verify how to set one). Record it: NO purchase is created (check the item), and an INLINE panel appears in the form (not an alert) with "Over the budget for <recipient name>", the limit, already spent, this purchase and over-by amounts, and Cancel, Record Anyway and Edit Details; the fields are read-only while it shows.
6. Both levels: make a purchase that exceeds the recipient budget and your total budget: two rows ("Over the budget for ..." and "Over your total budget"). Tap Record Anyway: it records once (one purchase, not two).
7. Edit Details: raise the warning again, tap Edit Details, change the amount, record: it must show a NEW warning (the old token is discarded), never record directly.
8. Cancel from the panel records nothing and closes the form.
9. S12 (changed spend): raise the warning and leave the panel up; from a second session (or the API) record another purchase for the same buyer; tap Record Anyway: the panel is replaced with the new amounts and the notice "The amounts changed since the last warning. Review them and confirm again."; nothing was recorded and nothing was resubmitted by itself; a second explicit Record Anyway records it.
10. Repeat purchase: after a recorded overage purchase, record the same item, quantity and amount again: it asks for confirmation again with a new warning (a token is never reused).
11. Expiry: raise the warning and wait 4 minutes 30 seconds: the panel becomes "This confirmation has expired. Review the details and record again." with one button back to the form; Record Anyway is no longer possible; recording again goes out without a token and asks again.
12. Blind and non-buyer callers: as john.doe@example.com on A (blind owner), carl.coowner@example.com on F (blind co-owner), vera.viewer@example.com on D (viewer) and nate.nonmember@example.com (public non-member where the list is visible): the item detail shows NO Record Purchase button, NO remaining quantity, NO status, NO purchase rows. As mike.johnson@example.com (member of B) and john on B (non-blind owner of a child's list) the button appears.
13. Archived list: archive a list you can buy on; open an item: Record Purchase still appears and the purchase is accepted (decision L16).
14. Errors: with the backend stopped, tap Record: a banner appears INSIDE the form (no alert) with Try Again and Dismiss; Try Again with the backend still stopped shows it again; restart the backend and Try Again records (it goes out without a token and asks for confirmation if over budget). Then, as another user delete the item (or use an item removed in the meantime) and record: the form closes and the item screen leaves (a 404 means gone).
15. Session paths: 401 refresh (set JWT_EXPIRY=60s, restart, log in, wait 70 seconds, record: no logout) and a disabled account (`npm run user:set-active -- --email jane.smith@example.com --active false` with a form open, then Record: the app returns to the login screen immediately; restore with `--active true`). Also check the accessibility and look of the panel in light and dark mode and at large Dynamic Type.

Scope reminder: editing, deleting or viewing a purchase, shipping status, the purchase history, stats and budgets screens are not part of this package (I4b and build 2).

### Which checks were run
- Checks 1 to 15: NOT PERFORMED by the iOS run (they need the local backend, the seeded users and a person at the simulator). Brian has not run them yet; mark each as run or not performed here when you do.
- What the iOS run did verify (by commands, not by the real server): scripts/verify.sh after each story commit and the TrackerAPI package tests (counts in the reports I4a-1 to I4a-4 and I4a-5), the guide-accurate fixtures through the real factory-built client with a fake transport (every documented createPurchase response), the mock's S12 table, the state-machine transition table with an injected clock, the visibility tests for every persona on active and archived lists, and the source scans (one confirmationDialog on the Record button, no alert, no token in a view). Behavior against the real server, the visual look of the form and the panel, and the L16 question are unverified until the steps above are run.
