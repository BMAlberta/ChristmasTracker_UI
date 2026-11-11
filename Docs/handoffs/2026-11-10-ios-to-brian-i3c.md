# Handoff: iOS to Brian, package I3c (archived-lists tab, then items on the generated client)

Date: 2026-11-10. Branch: feat/i3c-items (from master). Not pushed. Contract state at the start: CONFORMANT, decisions revision 28.

## Contract issues found
- None filed in Docs/contract-issues.md. No disagreement between the spec, the guide and the client was found.
- One open question, not a contract row: decision L16 ("archiving closes list management only; items, off-list items and purchases are still accepted") is cited by the brief but does not appear in the synced Docs (DECISIONS.md revision 28, client-guide, error-codes, privacy-matrix, openapi.json were searched). The client treats the brief as the decision and lets the flags drive every control; real-mode step 3 below verifies the server accepts item writes on an archived list. If the server refuses, that is a contract-issues row, not a client workaround. (Epic deviation D2.)

## What changed
- Story A: the lists screen has an Active | Archived segmented control with per-segment empty states; archived lists show an "Archived" badge and open normally (the flags decide what is shown); deleting a list is now "Archive List" with a confirmation attached to its button, followed by a fresh GET /lists; a 422 CANNOT_EDIT_ARCHIVED_LIST shows "This list is archived and can't be edited.", stays on the screen and refetches the detail.
- Story B: the `ListItem` domain model (Decimal money, optional updatedAt/purchases), `ItemPermissions` (every item right from the capability flags, the item's offList and creator, and the current user's id; no role read), pure view-state functions, strict form validation, `ItemError` with plain messages.
- Story C: `GeneratedClientItemRepository` (list, get, create, update, delete; no status operation because the old UI never offered it), a privacy-aware mock, a session-safe `ItemService` (mutations throw to the initiating view; `loadError` is separate), `NetworkItemRepository` and the hand-written item wire types deleted.
- Story D: `Color.destructiveColor`, `InlineErrorBanner` and `InlineErrorBannerState`, and the item list, row, detail, add, edit and delete screens rebuilt on flags and the four UI rules; `GiftItem` trimmed.
- Story E: the log scan extended to forbid interpolating raw error values in Features/Items and Features/Lists (no violations existed; it guards regressions), and this handoff.
- Fix pass (after your step 11 run): the item list and the item detail now keep separate load errors (`listLoadError`, `detailLoadError`), so opening an item no longer wipes its own error; the item detail shows the error banner until you act, then a quiet "This item could not be loaded." with Try Again, and shows a spinner only while a load runs (reports I3c-6); pull to refresh on a list now always fetches the list detail and the items and reports a failure for each (a banner at the top for the detail, the items-section banner for the items), and the initial open stays cache-first (report I3c-7).
- Behavior changes you will notice: the "Surprise Gift" toggle is gone from Add Item (the server derives offList; a member's items are surprise items, shown by a sentence in the form); the Add form has an Image URL field and requires a description (the server requires it); the items section on a list always shows (empty text is the same for everyone); Add Item is presented from the list for the first time (nothing opened the old Add screen before).

## Commits (git log --oneline master..HEAD, taken before the handoff-update commit)
```
88b3a7b I3c-fix: make pull to refresh hit the network and report a failure
6fa89c4 I3c-fix: keep item list and item detail load errors separate and never spin forever
8217eec I3c-fix: add fix pass Gate 1 spec
0944cf9 I3c: record the after-commit verification and package-end check
a921775 I3c: extend the log scan to items and add the package handoff note
2d22686 I3c: rebuild the item screens on capability flags and the item permissions function
5f05709 I3c: move the item operations onto the generated client and make the item service session-safe
1fa75c7 I3c: add flag-driven item models and the item permissions function
4f323b2 I3c: add the Active and Archived tabs and keep archived lists openable
8a1cdd9 I3c: add epic brief and inventory
```
The handoff-update commit (`I3c-fix: update the handoff for the corrected item error behavior`) follows these; its hash is in `git log --oneline master..HEAD`. Test totals at the end of the fix pass: app suite 2079 passed (1985 before the fix pass, +46 in F1, +48 in F2), TrackerAPI package 212, release-script 92, destination-script 17 (reports I3c-6 and I3c-7).

## What the API team must do
- Nothing required. Pending, not blocking: Brian's proposal to add per-item `canEdit` and `canDelete` flags to ItemResponse. Until then `ItemPermissions` derives the rights from the list flags and the creator id (see the comment in Features/Items/ViewState/ItemPermissions.swift). One consequence the matrix does not settle: a member whose role later changes can still see Edit/Delete on an off-list item they created while the server answers 403; per-item flags would remove this.
- If real-mode step 3 shows the server refusing item writes on an archived list, tell the API chat (decision L16 is not in the synced docs).

## Log hygiene carried to I4 (not changed here)
Raw error values interpolated into log strings outside Features/Items and Features/Lists (the new scan does not cover these folders):
- Features/Purchases/Views/PurchaseHistoryView.swift:175 (`Mock error: \(error)`).
- Core/Networking/NetworkAPIClient.swift:71 (`Network request failed: \(error)`), :103 (`Decode error: \(error)`), :167 (`Failed to parse 426 response: \(error)`); Core/Networking/MockAPIClient.swift:57 (`Mock decode error: \(error)`). The old client stays because purchases still use it.
Fix these when the purchase stack is replaced in I4. Features/Items and Features/Lists have no such interpolation (29 Log calls, only counts and operation names). Known limit of the new scanner: it inspects interpolations only, so a Log argument built without `\(...)` (for example `LogError(error.localizedDescription)`) is not caught; none exists today.

## Legacy bridge (listed on purpose)
- `ListItem.legacyPurchaseItem` in Core/Models/GiftItem.swift converts the new item into the old `GiftItem` (the only Double money path left, via `decimalToDouble`) so the untouched purchase screens can open. LEGACY, delete in I4 together with `GiftItem`, `MockItemData` and the old purchase stack. `GiftItem` is trimmed to the members the purchase screens read.

## Purchases in real mode (out of scope, unchanged)
- Purchases, shipping, budgets and stats are not part of this package. The item detail shows "Record Purchase" exactly when `canPurchase` is true and "View Purchase History" when `canPurchase` is true and the item has a status marker; both open the existing purchase screens. Those screens still run on the old hand-written stack (NetworkAPIClient and the old models), which disagrees with the server, so they will NOT work against the real server until package I4. No purchase file changed.

## Open risks
- Item screens were never rendered by me: no simulator or screenshot check was possible in this run, and the SwiftUI views have only scan tests plus review. Brian's real-mode check below is the first visual verification of the banner, the item list, detail, add and edit screens.
- Older screens (children, members, profile, other list screens, login) do not follow the new UI rules; this is the banked polish backlog in PROGRAM.md section 11. Specifically still open: the Leave List and Remove Member confirmation dialogs are attached at screen level; the Archive button and the destructive confirm buttons on the list screen have no `destructiveColor` tint.
- `.notFound` on an item closes the screen with no explanation (the addendum asked for a message in the list; the item just disappears). A list-side message needs a small service change because `goneItemId` is only cleared at teardown.
- `.refreshable` audit (fix pass): three in the app. `ListDetailView.swift:111` now forces both the detail (`ListService.refreshListDetail`) and the items (`refreshItems`) and shows each failure; `DashboardView.swift:55` calls `refreshLists`, which always fetches and shows its failure (no change); `ChildrenView.swift:86` calls `loadChildren`, which has no cache and shows its failure in the error row (outside this package, no change). Banked from the fix-pass reviews: a pull that lands before the initial load has set the items service's list takes the cache-first items branch; a 404 on the detail refresh still triggers one items request while the screen leaves; `refreshLists` returns silently while another refresh is running; `ListService.swift` is now about 880 lines; two test titles in `ItemServiceSessionSafetyTests` are over 160 characters.
- The Add sheet can be swiped away while a create is in flight (the service handles the late result safely).
- A same-list stale refresh finishing after a newer load can overwrite newer items (pre-existing behavior).
- Only the price field shows inline validation messages; name, description and URL only disable the button.
- `ListService.swift` is about 880 lines (over the 600 limit; carried from Story A, grown by the fix pass).
- `ItemRepository` is not an `-ing` protocol name (pre-existing name kept on purpose).
- Raw SF Symbol names are used because there is no AppIcons file.
- Process notes: one implementer run used a scratch script and a heredoc in Story A (recorded in Docs/reports/I3c-1-archived-lists.md); `cd` was used a few times against the no-`cd` rule, with no effect on files.

## One line for PROGRAM.md section 9
I3c (iOS): Active | Archived lists tab, archived lists open and accept item writes by flags (L16 unconfirmed in the synced docs), items moved onto the generated client with flag-driven ItemPermissions, session-safe ItemService with separate list and detail load errors, pull to refresh on a list always refetches and reports a failure, InlineErrorBanner and destructiveColor added; purchases still on the old stack until I4; real-mode check pending.

## Brian's real-mode check
These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (all seeded users share the password printed there; never write passwords, ids, or the registration code into this repo).

1. Start the backend on http://localhost:3010, re-seed so the ids are fresh and confirm /livez, add the launch argument -apiModeOverride real to the scheme, run the Debug build on the simulator.
2. Active | Archived: as john.doe@example.com create a list for yourself for a free year, confirm it appears under Active; archive it ("Archive List" with the confirmation, which must point at the Archive button), confirm it moves to Archived with the badge, has no Edit or Archive action, and opens.
3. On that archived list add an item (it must work: items are accepted on archived lists), edit it, then delete it (the delete confirmation must point at the Delete control and the destructive action must be RED).
4. As john on list A (his self list, he is the blind owner and recipient): add an item with a price of 19.99 and confirm it appears as a plain available entry with no status marker and no purchase information; edit its price to 20.00 and then try a price with three decimals and confirm the form refuses it.
5. As jane.smith@example.com (a member of A): the items show real status and purchase information; add an item: the form shows the sentence that it will be hidden from the recipient; it is created as a surprise item; edit and delete your own item; the item john added shows NO Edit and NO Delete for jane.
6. As john again on A: jane's surprise item does NOT appear (he is blind).
7. As mike.johnson@example.com (a member of B, a child's list) add an off-list item; as john (owner of B, not blind) confirm mike's off-list item appears for him with status information but with NO Edit and NO Delete, and that john can add and edit a regular item there.
8. As vera.viewer@example.com (viewer on D): items show as available with no status, no updatedAt, no off-list items, and no Add, Edit or Delete.
9. As carl.coowner@example.com (blind co-owner of F): add and edit and delete a regular item; no off-list items and no status information.
10. As dana.owner@example.com on D: add an item and confirm vera, as a viewer, sees it without any status.
11. (11) Item errors, with the backend stopped: (a) open list A while the backend is running, then stop the backend and pull to refresh the list: one banner appears in the items section with Try Again and Dismiss aligned left (and, if the list detail also failed to refresh, a banner at the top saying the list could not be refreshed); Dismiss clears it; Try Again with the backend still stopped shows it again; (b) with the backend still stopped open an item: the item screen shows the error banner and it STAYS (it does not disappear and there is no endless spinner); Try Again retries; Dismiss shows a quiet 'This item could not be loaded.' message with a Try Again button; going back to the list shows no leftover item error; (c) restart the backend and press Try Again: the item loads; (d) with the backend stopped try to add an item: the error appears INSIDE the add sheet as the same banner; do not dismiss it, close the sheet and go back to the list of lists: no item error is shown anywhere else.
12. 401 refresh path: stop the backend, set JWT_EXPIRY=60s in its .env, restart it, log in as john, open list A, wait 70 seconds, pull to refresh the items: they reload without a logout; restore the .env value and restart.
13. Disabled account: in the backend repo run `set -a; source .env; set +a` then `npm run user:set-active -- --email jane.smith@example.com --active false`; with jane logged in and an item list open pull to refresh: the app returns to the login screen immediately; restore with `--active true`.
14. Log out with the backend stopped and confirm the login screen appears immediately.
15. As nate.nonmember@example.com: an empty list of lists.

Scope reminder: purchases, shipping, budgets and stats are not part of this package; purchase actions still use the old stack; the older screens have not been polished (banked).

### Which checks were run
- Checks 1 to 15: NOT PERFORMED by the iOS run (they need the local backend, the seeded users and a person at the simulator). Brian has not run them yet; mark each as run or not performed here when you do.
- What the iOS run did verify (by commands, not by the real server): scripts/verify.sh (the app suite, release-script and destination-script tests) and the TrackerAPI package tests; the end-state counts are in Docs/reports/I3c-7-forced-refresh.md (the fix pass; earlier counts in I3c-5). Behavior against the real server, the visual look of every new screen, the banner in light and dark and at large Dynamic Type, and the L16 question are unverified until the steps above are run.
