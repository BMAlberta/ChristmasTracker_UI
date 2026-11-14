# Handoff: iOS to Brian, package UX1a (one error and stale-data policy for every screen)

Date: 2026-11-13. Branch: feat/ux1a-errors-and-stale-data (from master). Nothing was pushed.

## Contract issues found
None. No contract change in this package, and no server behavior was observed (the session had no network or database access).

## What changed
- Story U1: a pure `LoadFailurePolicy` (Features/Shared/ErrorPolicy) that decides what a screen shows after a failed load: none, a stale-data banner ("Couldn't update. Showing saved data."), a merged banner, up to two banners, a full error, leave the screen, or the sign-in flow takes over. The category mapping covers every case of ListError, ItemError, ChildError and BudgetError with no default.
- Story U2: services. `ListService.error` and `ChildService.error` are gone. Each load has its own failure value (`listsLoadFailure`, `detailLoadFailure`; the item and stats loads already had theirs; the Children load keeps its own `phase` and its shared `error` is gone; Statistics failures are now keyed by year). All mutations throw the typed error and publish nothing. A revalidation failure with cached data is recorded. `loadLists` waits for a load already in flight (I5a finding D). I5a findings A, B, C and E are fixed (Edit Budget and Duplicate load the budget first; a successful delete drops the budget locally; a stats load after the screen disappeared or for another year sets no failure; the budget editor's list load writes no shared value).
- Story U3: every screen in Scope shows errors only through `InlineErrorBanner`. The list detail screen shows ONE merged banner for same-category detail, refresh and items failures with a Try Again that retries both. Mutation errors are held in the initiating view. The old `ListErrorBanner`, the Children error row, the Add Child error label, the Create List child-load row, the item detail Text row and the Profile alert are removed. A scan test (`UX1aErrorScanTests`) fails on an ad-hoc error row, an error alert or a view reading a shared error.
- Tests: app suite 3870 -> 3925 (U1, +55) -> 4037 (U2, +112) -> 4182 (U3, +145: 160 new, 15 removed or reduced); package suite 212, release script tests 92 and destination script tests 17 unchanged.

## Commits (git log --oneline master..HEAD, before this handoff commit)
```
bf7723f UX1a: show every error through the inline banner with the stale-data policy
3903440 UX1a: scope service failures to one screen and throw mutation errors
ada18fd UX1a: add the pure load failure policy
ede6a10 UX1a: add epic brief and inventory
```
The handoff commit "UX1a: add the package handoff note" follows these. Reports: Docs/reports/UX1a-1-load-failure-policy.md, UX1a-2-services.md, UX1a-3-screens.md, UX1a-4-handoff.md. Epic: Docs/epics/UX1a-errors-and-stale-data.md.

## What the API team must do
Nothing.

## Open risks
- No simulator run was possible in the build session. The screens are covered by view-state tests and source-scan tests, not by on-screen checks. Brian's real-mode check below is the only proof of the on-screen behavior (banner layout, centering of the full errors, Dynamic Type reflow, light and dark, VoiceOver announcement and order, the two-banner case). The retry closures in the views are private view code and no unit test drives them.
- Behavior changes the reviewers accepted against the brief (details in Docs/reports/UX1a-2-services.md and UX1a-3-screens.md):
  - An items 404 now leaves the LIST screen (the policy treats any not-found as "leave"); before, it showed an items banner. An items 404 on a list that still exists would eject the user.
  - A reload or refetch that fails AFTER a successful archive, add-member or remove-member is no longer shown (it was shown through the shared error); the next load shows an honest failure.
  - Mutation failures with not-found or forbidden no longer show a Close button (a not-found still leaves the screen through the gone-list handling).
  - 403 load banners now offer Try Again.
  - The dashboard clears its lists failure whenever it disappears, including when a list is opened, so a dashboard banner is gone after going into a list and back.
  - On the Dashboard, Children, Statistics and the budget editor a not-found or session-end outcome renders nothing (they cannot leave; session end hands over to the sign-in flow).
  - With the items never loaded and the load failing, the list detail items section shows its empty copy under "Couldn't update. Showing saved data." because the brief defines "cached data shown" as "the detail is shown". Candidate for UX1b.
  - Two connectivity categories with cached data (for example unreachable and server) would give two banners with the same stale text; only unreachable and server can occur together today, and the brief asks for one banner per distinct category.
  - Two Statistics banners share one dismissal.
- More behavior notes from the reports (Docs/reports/UX1a-2-services.md and UX1a-3-screens.md): `leaveList` and Create list with no signed-in user now return silently; the Children full error is a banner row at the top of the list, not a centered container; `ChildService.phase` is still a load channel read by both the Children screen and the Create list child picker (each clears it on disappear); mutations no longer clear the load failures when they start; leaving the Statistics screen now cancels its in-flight loads including a pull to refresh; Edit and Duplicate Budget can now perform a forced budgets fetch; a reporting waiter (the dashboard) behind a non-reporting in-flight lists load (the budget editor) gets the failure back but nothing is stored, so the Lists screen shows no error until the user retries; review finding F5 is open and accepted (a dismissed stale banner count in `noteLoadOutcome` can resurface a banner, and `detailLoadFailure` is not keyed by list id; task cancellation mostly prevents both).
- Test changes to be aware of: two old ListErrorDismissal cases have no equivalent (the new dismissal is by source), and the ChildService session-safety `error == nil` assertions were dropped because the property is gone (the `phase` assertions remain).
- Warnings not reworked: ListService.swift is 1072 lines (it was already over the 600 limit; the story added 55) and StatsScreenModel.swift about 412 lines; `ForEach(Array(x.enumerated()), id: \.offset)` is used for banner lists of at most two entries; `ChildrenState.errorMessage` and the recipient options' `errorMessage` are dead production code kept for existing tests; no new error-state previews for Dashboard, Children, item detail, Profile or Statistics.
- Known test gaps: no test for a quiet (`reportingFailure: false`) waiter's own retry after a cancelled load; the editor's cancelled-load test cannot prove the waiter path deterministically.
- Carried over, unchanged and not part of this package: I5a findings F and G (see the I5a handoff, 2026-11-13-ios-to-brian-i5a.md), the `ListService` file size, the Face ID hint and anchored dialogs (UX1b).

## For section 9 of PROGRAM.md (one line)
UX1a (iOS, branch feat/ux1a-errors-and-stale-data, 4 commits plus this handoff commit, app tests 3870 -> 4182): one pure LoadFailurePolicy and the InlineErrorBanner now drive every error in the lists, list detail, members, create and edit list, Children, Profile, item and Statistics screens; load failures are scoped to one screen, mutation errors are thrown to the initiating view, a failed revalidation shows "Couldn't update. Showing saved data.", the list detail shows one merged banner, and I5a findings A to E are fixed; the on-screen behavior is unverified until Brian's real-mode check.

## Brian's real-mode check
Restart the backend with `npm run dev` ONLY. Do not run the seed when you restart it: re-seeding creates new user ids and the app correctly signs you out.

These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (all seeded users share the password printed there; no password, id, token or registration code is written in this repo).

1. **Start and log in as John.**
   - Start the backend on http://localhost:3010, re-seed ONCE so the ids are fresh and confirm /livez.
   - Use the "ChristmasTracker (Real)" scheme copy that carries the launch argument -apiModeOverride real (never edit the shared scheme), and run the Debug build on the simulator.
   - Log in as john.doe@example.com and open the lists.

2. **Stale data on the list screen.**
   - Open list A so its detail and items load, then go back.
   - Stop the backend (stop `npm run dev` only), then open list A again.
   - Expect: within a moment ONE banner at the top reads "Couldn't update. Showing saved data." with Try Again and Dismiss, and the list and its items stay visible.
   - Expect: no second banner in the items section for the same problem.

3. **Pull to refresh on list A with the backend still stopped.**
   - Expect: still ONE banner.
   - Dismiss clears it; pull again: it comes back.

4. **Recover.**
   - Restart the backend with `npm run dev` only and tap Try Again.
   - Expect: the banner disappears and the data refreshes.

5. **The dashboard.**
   - Go back to the lists, stop the backend, and pull to refresh.
   - Expect: one banner "Couldn't update. Showing saved data." above the lists, which stay visible.
   - Restart the backend (no seed) and tap Try Again: the banner clears.

6. **Children.**
   - Open Profile, then Children, stop the backend, and pull to refresh.
   - Expect: the same single banner style (same layout and buttons as the lists screen).
   - Restart and tap Try Again: the banner clears.

7. **Item detail.**
   - Open an item, stop the backend, and pull to refresh or reopen.
   - Expect: the same banner style, and the item stays visible.
   - Restart and tap Try Again: the banner clears.

8. **No leaking.**
   - With the backend running, as john open list B, then Members, and add mike.johnson@example.com (already a member).
   - Expect: the error appears INSIDE the add sheet as the banner.
   - Do not dismiss it: close the sheet and go back to the list of lists.
   - Expect: NO error is shown there or on any other screen.
   - Reopen list B. Expect: no leftover error.

9. **Older mutations.**
   - Stop the backend and try each of: Archive List, Leave list (as mike on list B), Remove member, Change co-owner (set one on list A as john), Create list.
   - Expect: each error appears inside its own sheet or section as the banner and never on another screen.
   - Restart (no seed) and confirm each Try Again works once.

10. **Different causes, two banners.**
    - This cannot be reproduced by hand: NOT PERFORMED, covered by unit tests.

11. **Disabled account.**
    - With list A open as jane, run `set -a; source .env; set +a` and then `npm run user:set-active -- --email jane.smith@example.com --active false` in the backend repo.
    - Pull to refresh.
    - Expect: the app returns to the login screen immediately (no "Couldn't update" banner).
    - Restore with `--active true`.

12. **Statistics.**
    - As john, open the Statistics tab and let it load, then stop the backend and pull to refresh.
    - Expect: ONE banner "Couldn't update. Showing saved data." with the data still visible.
    - With the backend still stopped, switch to another year in the year picker.
    - Expect: the other year does NOT show a stale banner left over from the previous year's failure.
    - Restart the backend (no seed) and tap Try Again: the banner clears.
    - With a budget showing, open the budget menu and choose Edit Budget.
    - Expect: the editor opens and the person picker shows the people (never "Nobody to add yet" while the lists are still loading).

13. **Normal flows still work with the backend up.**
    - Lists, list detail, items, record a purchase, Children, Members add and remove, archive and the Archived tab, Statistics create, edit, duplicate and delete budget.

### Not part of this package
Confirmation dialogs and their anchoring, destructive colors, the tab bar, the Face ID hint, the Children Try Again confirmation (all UX1b), the theme pass, any contract or repository change, the purchase screens (already conforming), new screens, and the Login, Registration and lock screens (they keep their own alert or inline error patterns).

### Which checks were run
Brian's real-mode check was NOT PERFORMED by the build session: none of steps 1 to 13 was run. No backend was started, no simulator was driven and no screenshot was taken; the session had no network or database access (by rule) and no booted simulator. Step 10 cannot be reproduced by hand and is NOT PERFORMED by design: it is covered by unit tests (ListDetailLoadStateTests and ScreenLoadPresentationTests). Brian runs steps 1 to 9 and 11 to 13 and records which ones passed. Also worth a look during the check, because only the real app proves them: the items-404 leave behavior, the dashboard banner disappearing after opening a list and going back, the Face ID failure banner on Profile and its Try Again, and the archive Try Again from the dashboard.
What WAS run in the session: scripts/verify.sh (4182 app tests, 92 release script tests, 17 destination script tests, all passing) and `swift test --package-path "LocalPackages/TrackerAPI"` (212 tests), before and after every commit.
