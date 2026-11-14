# Handoff: iOS to Brian, package UX1b (anchored dialogs, destructive colors, the tab bar, the Face ID hint and cleanups)

Date: 2026-11-14. Branch: feat/ux1b-dialogs-colors-and-polish (from master, after the UX1a and I5b merges). Nothing was pushed.

## Contract issues found
None. No contract change in this package, and no server behavior was observed (the session had no network or database access).

## What changed
- Story B0 (UX1a leftovers): a reload or refetch that fails after a successful archive, add-member or remove-member is now recorded (the detail failure for that list, or the lists failure for the dashboard) and shows "Couldn't update. Showing saved data."; the mutation still succeeds silently. The detail failure is keyed by list id (a failure for list A is never shown on list B). With the items never loaded and the items load failed, the items section shows "Items unavailable. Pull to refresh or tap Try Again." instead of the empty copy (a pure `ItemsSectionAvailability`). Review finding F5 (dismissed stale banner count) is banked: see open risks.
- Story B1 (anchored dialogs): the leave and remove-member dialogs now sit on their buttons, the remove co-owner dialog on its button (it was on the form), the log-out dialog on the Log out button (it was on the scroll view); the dashboard archive keeps its row. Their state lives in a pure `ConfirmationPresentation` owned by the screen, so a re-render, reload or swipe close does not dismiss an open dialog; competing controls are disabled while one is open. A scan test (`DialogScanner`) fails on a confirmation attached to a container or a "set then clear" flag.
- Story B2 (destructive colors): archive, leave, member Remove, remove co-owner and every dialog button now use the destructive token; the dashboard Archive swipe action has an explicit tint; the member Remove icon button gained the destructive role; Sign out is neutral (no destructive role on the dialog button, and the Logout button is no longer raw red). New `DestructiveActionKind` and `destructiveTint()` in DesignSystem; scan tests enforce it.
- Story B3 (tab bar): `.tabBarMinimizeBehavior(.onScrollDown)` on the TabView, once.
- Story B4 (Face ID hint): after a wrong-password sign-in, when biometric sign-in is usable (the existing enrolled state), a muted caption "You can also sign in with Face ID." (or Touch ID, or the generic wording) shows just below the Sign In button, stays after the error alert is dismissed, and clears when a field is edited or a sign-in starts. The alert is unchanged. Brian chose this placement during the package (the original brief said "under the error" and "announced with the error", but the error is a modal alert); the caption is a normal accessibility element read after Sign In, with no extra announcement.
- Story B5 (Children Try Again): Try Again recomputes the plan; if it would archive a list the user did not confirm, the confirmation dialog opens again with the new plan; a subset or equal plan continues as before.
- Story B6 (cleanups): 50 stale "Fails today" test headers and other stale comments rewritten (comment-only, proven by an empty diff check); `ChildrenState.errorMessage` and the recipient options' `errorMessage` removed; the unused `ItemPermissions.currentUserId` removed; the "flag-free" comment and a long comment line fixed. The orphaned Keychain item was NOT cleaned up (banked).
- Tests: app suite 4230 (baseline) -> 4250 (B0, +20) -> 4305 (B1, +55) -> 4340 (B2, +35) -> 4345 (B3, +5) -> 4368 (B4, +23) -> 4398 (B5, +30) -> 4398 (B6, comment-only and assertion removals, +0); package suite 212, release script tests 92, destination script tests 17 unchanged.

## Commits (git log --oneline master..HEAD, before this handoff commit)
```
8675501 UX1b: remove the unused ItemPermissions current user property
7c18189 UX1b: remove dead error message properties
3a721df UX1b: replace stale test headers and comments
c2f0e4d UX1b: ask again when Try Again would archive lists the user did not confirm
2eb069b UX1b: add a quiet Face ID hint after a credentials failure
7de8476 UX1b: minimize the tab bar on scroll
6f599d5 UX1b: show every destructive action in the destructive color
78aa67c UX1b: anchor every confirmation to its control and keep its state above the rows
f9379b0 UX1b: close the UX1a stale-data gaps
85639bf UX1b: add epic brief and inventory
```
The handoff commit "UX1b: add the package handoff note" follows these. Reports: Docs/reports/UX1b-0-ux1a-leftovers.md, UX1b-1-dialogs.md, UX1b-2-destructive-colors.md, UX1b-3-tab-bar.md, UX1b-4-face-id-hint.md, UX1b-5-children-try-again.md, UX1b-6-cleanups.md, UX1b-7-handoff.md. Epic: Docs/epics/UX1b-dialogs-colors-and-polish.md.

## What the API team must do
Nothing.

## Open risks
- No simulator run was possible in the build session. Every on-screen result (dialog anchoring, that a dialog stays open, the red colors, the swipe tint, the tab bar minimizing, the Face ID caption) is covered only by pure-logic and source-scan tests; Brian's real-mode check below is the only proof.
- **Confirm-button ordering (the main thing to try).** In every B1 dialog the destructive button runs `confirmed(target)` in its action while the dialog's `isPresented` setter calls `cancelled()`. If SwiftUI ran the setter before the action, a confirm would silently do nothing (fail-safe: nothing destructive happens without consent, but the confirmation is lost). The Children delete (I3d-6 "Risk B") and the old Dashboard archive already depended on the action running first; B1 spreads the dependency to Leave, member Remove and co-owner Remove, which used to be order-independent. Step 10 below checks that CONFIRMING works, not only cancelling. If a confirm is dropped, tell the build team: the fix is to make the confirm button independent of the state still being "confirming".
- Banked:
  - F5 (dismissed stale banner count in `StatsScreenModel.noteLoadOutcome`): not fixed. `failureCount` increments once per failed load outcome; telling a repeat of the same failure from a new identical one needs failure identity the model does not carry, and the existing test `StatsScreenModelStaleBannerTests.newFailureShowsAgain` pins the current behavior.
  - The orphaned Keychain item from the deleted device fingerprint service (UUID under the key `com.christmastracker.deviceFingerprintUUID`): the first-launch wipe is a class-wide delete, not a plain list, so it was not changed (the brief forbids changing it in that case); a build that stored it keeps one harmless item until the app is reinstalled.
  - `ItemListState.init` still takes a `currentUserId` parameter its body never reads (out of scope for the ItemPermissions removal).
  - Over the file-length limits: ListService.swift (about 1130 lines), ListDetailView.swift (about 446), ChildrenView.swift (about 402). `DesignSystem/Components/ErrorStateView.swift:20` still uses a raw `.foregroundColor(.red)` (an error view, outside the scan scope).
  - Scanner limits (accepted): the anchoring scan misses a dialog on a non-root `VStack`/`ZStack`/`NavigationSplitView`/`LazyVStack` or behind an indirect head; the destructive scan cannot see a destructive-looking control with no `role:` and misses a conditional role.
  - The Face ID caption is not re-evaluated after it is shown: if a later biometric attempt fails, or enrollment disappears, it can still say "sign in with Face ID"; an edit made while the sign-in request is in flight is followed by the hint if the request then fails.
  - A detail failure recorded for a list the user has already left stays in the service (keyed by that list id, never shown on another list) until that list loads again or the session resets.
  - Dashboard, Statistics (briefly) and the empty/error states do not scroll, so the tab bar does not minimize there.
  - The "Covers ..." header lines in the 50 rewritten test files were checked against test bodies for 12 files; the rest only against type names.
- Behavior notes: the member Remove, Leave, co-owner Remove and Dashboard archive confirmations now close silently when their target disappears (roster change, list gone); Add member, Leave and every Remove are disabled while one of those dialogs is open; Save and Cancel are disabled in Edit List while the co-owner dialog is open.

## For section 9 of PROGRAM.md (one line)
UX1b (iOS, branch feat/ux1b-dialogs-colors-and-polish, 10 commits plus this handoff commit, app tests 4230 -> 4398): every confirmation dialog is now anchored to its control with its state held above the rows, destructive actions are red and Sign out is neutral, the tab bar minimizes on scroll, a failed wrong-password sign-in shows a quiet Face ID hint below Sign In, Children Try Again re-confirms when it would archive an unconfirmed list, and the three UX1a stale-data gaps are closed; the on-screen behavior, especially that confirming a dialog still works, is unverified until Brian's real-mode check.

## Brian's real-mode check
Restart the backend with `npm run dev` ONLY. Do not run the seed when you restart it: re-seeding creates new user ids and the app correctly signs you out.

These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (all seeded users share the password printed there; no password, id, token or registration code is written in this repo). Who can see which control is decided by the server's capability flags: where a step says the control "should" appear for an account, that is the seed's expectation, not something verified against the server here; if the control does not appear for that account, say so and use the account that has it.

1. **Start and log in as John.**
   - Start the backend on http://localhost:3010, re-seed ONCE and confirm /livez.
   - Use the "ChristmasTracker (Real)" scheme copy that carries -apiModeOverride real (never edit the shared scheme).
   - Run the Debug build on the simulator.
   - Log in as john.doe@example.com.

2. **One step per dialog in the final inventory.** Tap paths below come from the code (view files and labels); the account is the seed's expectation. For each dialog repeat the three checks.
   - (To avoid repeating it ten times, the Expect line is written once here and applies to every sub-step from 2.1 to 2.10; 2.11 has its own.)
   - Expect (for every dialog below): the dialog appears next to the control you tapped (not at the screen's edge) and STAYS open; its destructive button is red; Cancel closes it and nothing changes; repeat three times, once swiping or opening from a different row where applicable.
   - 2.1 **Archive a list from the lists screen (swipe).** John, Dashboard tab (the lists screen), swipe a list row left, tap Archive (the row shows it only when you may archive that list). Repeat from a different row.
   - 2.2 **Archive a list from its detail.** John, Dashboard tab (the lists screen), open a list, scroll to the bottom, tap the Archive List button (below the Items and Members cards).
   - 2.3 **Leave a list.** Mike (log out first), Dashboard tab (the lists screen), open list B, scroll to the Members card, tap Leave list (shown only to a member who may leave).
   - 2.4 **Remove a member.** John, Dashboard tab (the lists screen), open list A, scroll to the Members card, tap the minus-person icon on Jane's row. Repeat from a different member row if the list has one (list B has Mike).
   - 2.5 **Remove a co-owner.** John, Dashboard tab (the lists screen), open list B, tap Edit (top right), scroll to the Co-owner section, tap Remove co-owner.
   - 2.6 **Delete an item.** John, Dashboard tab (the lists screen), open list B, tap an item (for example the LEGO Technic Set), scroll to the bottom of the item screen, tap Delete Item (shown only when the server allows that item to be deleted).
   - 2.7 **Delete a purchase.** Jane (log out first), Dashboard tab (the lists screen), open list A, open the DeWalt Cordless Drill, tap its purchase row to open the purchase screen, scroll to the bottom, tap Delete Purchase (shown only to the buyer).
   - 2.8 **Delete a budget.** Jane, Stats tab, on the budget card tap the three-dots menu ("Budget options"), tap Delete Budget.
   - 2.9 **Delete a child.** John, Profile tab, Children, swipe the child's row left and tap Delete (or long-press the row and tap Delete). Cancel in the dialog and make sure nothing is deleted.
   - 2.10 **Log out.** Any account, Profile tab, tap Logout (the Logout button at the bottom). The dialog should appear next to that button.
   - 2.11 **The over-purchase prompt (not destructive).** Jane, Dashboard tab (the lists screen), open list A, open the Socket Set, tap Record Purchase, raise the Quantity stepper above the quantity still remaining on that item and tap Record Purchase. The prompt (title "Record anyway?", button "Continue Anyway") is built from the quantity compared with the remaining quantity, not from the cost; whether the Socket Set has more than one remaining is not verifiable from the seed doc, so if the stepper cannot go above the remaining quantity, use an item that is already fully purchased, or tell the build team that this path could not be reached (this path is NOT verified). A budget over-limit is a different, server-driven flow and is not this prompt. Expect: the prompt appears next to the Record Purchase button and stays open; Cancel closes it and records nothing. There is no red button in this prompt.
   - 2.12 **Alerts that are not confirmations** (login error, the biometric setup alerts, the registration error) keep their own pattern and are not part of this check.

3. **A dialog survives a refresh.**
   - Open any row-opened dialog from step 2 (2.1, 2.4 or 2.9), then pull to refresh or wait for a reload where possible.
   - Expect: the dialog stays open.

4. **Destructive colors.**
   - Look at every destructive swipe action, menu item and button from step 2 (also Children delete).
   - Expect: red, never green.
   - Sign out (Profile) is NOT red.

5. **The tab bar.**
   - On the lists tab scroll down.
   - Expect: the tab bar shrinks; scroll up: it comes back.
   - Repeat on Statistics and on Profile. Switching tabs is unaffected.

6. **The Face ID hint.**
   - Log out. On the login screen enter a wrong password for john.doe@example.com.
   - Expect: the error alert appears; after you tap OK, if Face ID sign-in is available on this device or simulator (enrolled user), ONE quiet line "You can also sign in with Face ID." stays just below the Sign In button; editing a field or signing in clears it.
   - With the backend stopped, sign in: the network error appears WITHOUT the hint.

7. **Children Try Again.**
   - As john, Profile, Children: delete a child that has two active lists (or create the situation: Tommy has list B).
   - With the backend running, stop it only after the dialog is confirmed so the first archive fails; restart the backend (no seed) and tap Try Again.
   - Expect: when the recomputed plan is the same or smaller, it continues without a new dialog.
   - (A second dialog appears only if a new active list for that child appeared in between; this cannot be reproduced by hand: NOT PERFORMED, covered by unit tests.)

8. **UX1a leftovers.**
   - The three stale-data gaps closed in Story B0 (a reload that fails after a successful mutation, items never loaded, a failure recorded on another list) cannot be reproduced by hand: NOT PERFORMED, covered by unit tests.

9. **Normal flows still work with the backend up.**
   - Lists, list detail, items, record a purchase, Children, Members add and remove, archive and the Archived tab, Statistics.

10. **Confirming works, not only cancelling (added by the build session, not in the brief).**
    - For each of 2.1 (archive from the swipe), 2.2 (archive from the detail), 2.3 (leave), 2.4 (remove member), 2.5 (remove co-owner) and 2.10 (logout) tap the red CONFIRM button once, with the backend running.
    - Expect: the action happens (the list is archived and moves to Archived, you leave the list, the member or co-owner disappears, you are logged out). If the dialog just closes and nothing happens, that is the confirm-ordering risk described in the open risks: report which dialog.
    - Restore the data afterwards by re-seeding once (this signs you out; that is expected).

### Notes on the steps above
- Step 5: the tab bar will not shrink where there is nothing to scroll (an empty or error lists screen, the brief first moment of Statistics).
- Step 4: the Logout dialog button is also neutral, not only the Profile button.

### Not part of this package
The theme pass, any contract or repository change, new screens, the purchase screens' behavior (including the unconfirmed-purchase classifier), the Login, Registration and lock screens' own error and explanation alerts (only the Face ID caption was added to Login), UX1a's banners and stale-data policy (except the three gaps above), the F5 stats banner finding, and the Keychain orphan cleanup.

### Which checks were run
Brian's real-mode check was NOT PERFORMED by the build session: none of steps 1 to 10 was run. No backend was started, no simulator was driven and no screenshot was taken; the session had no network or database access (by rule) and no booted simulator for this check. Step 7's second dialog and step 8 cannot be reproduced by hand and are NOT PERFORMED by design: they are covered by unit tests (ChildDeletionPresentationRetryTests and ChildDeletionPlanUnconfirmedTests for step 7; ListServiceReloadFailureRecordingTests, ListServiceKeyedDetailFailureTests and ItemsSectionAvailabilityTests for step 8). Brian runs steps 1 to 7 (first part), 9 and 10 and records which ones passed. Where a control does not appear for the named account, the account choice in step 2 was an expectation from the seed and not verified. Sub-step 2.11 (the over-purchase prompt) is the least certain path: its trigger comes from the code (quantity above the remaining quantity), but no seeded item is known to allow it.
What WAS run in the session: scripts/verify.sh (4398 app tests, 92 release script tests, 17 destination script tests, all passing) and `swift test --package-path "LocalPackages/TrackerAPI"` (212 tests), before and after every commit.
