# Handoff: iOS to Brian, package I3d (deleting a child by archiving their active lists first, and the Members section fix)

Date: 2026-11-12. Branch: feat/i3d-child-delete-members (from master, on top of the merged I4b PR). Not pushed. Contract state: CONFORMANT, decisions revision 33 (L16, L17), spec sha256 prefix 88f9826196c5 (no contract sync was needed or run).

## Contract issues found
- None. Docs/contract-issues.md is unchanged. No server-versus-contract disagreement could be observed because the real-mode check has not been run. Observations for the API team (no action required):
  1. Archiving is `DELETE /lists/{id}`, whose documented responses are 200, 401, 403, 404, 429 and 500. The client treats a 404 on an archive as "already gone, counts as archived". An attempt to archive an already archived list is not documented for this operation, so the client has no specific handling for it (an unexpected status would be shown as a failure for that list; the retry then recomputes the plan from fresh data, in which an archived list never counts).
  2. The synced guide describes the member roster as "owner, co-owner, then members" and says `members` never contains the owner, co-owner or recipient (L13, line 416). The app now relies on this; a roster entry that duplicates the owner or co-owner id is still shown only once.

## What changed
- Story D1 (report I3d-1): the Members section shows an Owner row (from `detail.owner`) and a Co-owner row (from `detail.coOwner`, if set) first, without Remove, then the member and viewer rows (Remove only with `canManageMembers`). Both rows appear only when the roster is shown (`canSeeMembers` and members present); a viewer or public non-member still sees only the member count. A roster entry that matches the owner or co-owner is shown once. The recipient is not a row.
- Story D2 (report I3d-2): `ChildDeletionPlan` (pure: deleteNow, archiveThenDelete, blocked; only ACTIVE and DRAFT lists of that child count; blocked if any of them has `canDeleteList` false), `ListService.freshLists()` (forced fetch, no shared error), `ListService.archiveLists(ids:)` (sequential, stops at the first failure, 404 counts as archived, exactly one reload at the end, no shared error), `ChildDeletionFlow` (plan, execute, run; typed `ChildDeletionResult`; cancellation and both services' session generations checked between steps; the child is never deleted after a failed or stopped archive), the new `ChildError.childHasLists` text ("This child still has active lists. Archive them first."), and the mock repository follows L17 (only active or draft lists block). Read-only `sessionGeneration` accessors on `ChildService` and `ListService` were added so the flow can detect a user switch.
- Story D3 (report I3d-3): the Children screen delete UI: one confirmation dialog attached to the child's row (texts per plan), destructive and red swipe action and context menu, a progress state on the row, `InlineErrorBanner` for partial failure ("Archived 2 of 3 lists. The child was not removed."), blocked (no Try Again) and other errors, VoiceOver announcements, and cancellation when the screen disappears. The old screen-level dialog and alert are gone.
- Behavior changes you will notice: deleting a child with active lists is now possible (after the confirmation the lists move to Archived), the Members section shows who owns the list, and the old message "Delete those lists first" is gone.

## Commits (git log --oneline master..HEAD, taken before the handoff commit)
```
755ef71 I3d: rebuild the child delete UI on the new flow
330939d I3d: archive a child's active lists before deleting the child
c96c753 I3d: show the owner and co-owner in the Members section
8a298a5 I3d: add epic brief and inventory
```
The handoff commit follows these. Test totals: app suite 2937 at the start, 2950 after D1 (+13), 2997 after D2 (+47), 3034 after D3 (+37: 36 new and one net from three rewritten tests becoming four); TrackerAPI package 212; release-script 92; destination-script 17. Every `scripts/verify.sh` and `swift test --package-path "LocalPackages/TrackerAPI"` run before and after each of these commits was green (raw summaries are in the reports I3d-1 to I3d-4). Per-file entry counts come from the test-writers' reports; the totals were confirmed by running `scripts/verify.sh`.

## What the API team must do
- Nothing required. Optional: confirm what `DELETE /lists/{id}` returns for a list that is already archived (a 200 would be the friendliest for a client retry).

## Open risks
- **Never rendered by me.** No simulator run of this build: the Children screen (row dialog, progress state, banner) and the Members section were NOT visually checked, in light or dark mode or at large Dynamic Type, and no VoiceOver run was made. Your real-mode check is the first visual verification.
- **Try Again after a failed plan fetch runs the deletion without a new confirmation dialog.** When the lists fetch that precedes the dialog fails (for example the backend is down), the banner offers Try Again, which calls `ChildDeletionFlow.run(childId:)` (plan afresh, then archive and delete) and never shows the dialog. This matches step (5) of the real-mode check below (and the brief), but the user never confirmed the archive in that sequence. Decide whether Try Again should instead repeat the plan and show the dialog. Not changed in this package.
- **Same mechanism after a PARTIAL failure** (added from the acceptance review): Try Again after "Archived 2 of 3 lists. The child was not removed." also goes through `ChildDeletionFlow.run`, which re-plans from fresh data without a new dialog. A list that became active since the first confirmation would be archived without being confirmed, and the plan can turn into a plain delete. The first confirmation covered the lists at that time; this is the same decision for you as the previous item.
- **Controls re-enabled while the dialog is open** (reviewer finding, not fixed): `requestDelete` clears the row's progress state as soon as the plan returns (ChildrenView.swift:281), so while the confirmation is open the delete controls are enabled again. On iPhone the dialog is modal; on iPad (popover) another row could start a second plan. No wrong deletion can result because each plan needs its own confirmation.
- **Try Again double tap:** `retry` ignores `controlsEnabled`, so a double tap cancels the first task and starts a second.
- **Wording nits:** the row label says "being removed" already during the plan fetch; the Try Again announcement is always "Archiving lists", even if the re-plan turns out to be a plain delete.
- **Plan scope:** the plan looks only at lists the signed-in user can see in `GET /lists`. A hidden active list (not visible to the parent) makes the child delete fail with 422; the screen then shows the corrected message "This child still has active lists. Archive them first." with no Try Again.
- **Partial progress is not rolled back:** if the second of three archives fails, the first stays archived (archiving is permanent). The banner says so with counts only; Try Again continues from fresh data.
- **Stale comment:** GeneratedClientChildRepository.swift:124 still says "the child still has lists" (comment only, left alone, outside the package scope).
- Mock mode: the mock `deleteList` archives lists, so the flow works in mock mode; nothing was run there either.

## One line for PROGRAM.md section 9
I3d (iOS): deleting a child with active lists now works as a confirmed client flow (fresh plan, archive each active list in order, then delete the child; partial failures stop with counts only and Try Again continues; nothing is deleted after a failed archive) with the confirmation on the child's row and errors in an InlineErrorBanner, and the Members section shows the Owner and Co-owner rows from the detail (only when the roster is shown); open question: Try Again after a failed plan fetch skips the confirmation; real-mode check pending.

## Brian's real-mode check
These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (all seeded users share the password printed there; never write passwords, ids, tokens or the registration code into this repo).

(1) start the backend on http://localhost:3010, re-seed so the ids are fresh and confirm /livez, use the "ChristmasTracker (Real)" scheme copy that carries the launch argument -apiModeOverride real (never edit the shared scheme), run the Debug build on the simulator;
(2) as john.doe@example.com open Profile, Children: add a child "Test Child" and delete it at once: the dialog says the child will be removed (no lists), the confirmation points at that child's row and the destructive button is red, and the child disappears;
(3) add a child again, create a list for that child for a free year, add an item to it, then delete the child: the dialog says one list will be archived; confirm: the list appears under Archived (open it: the child's name is preserved, it is archived, and it still accepts items), and the child is gone from Children;
(4) delete Tommy (the seeded child whose list B has members Jane and Mike): the dialog says his active list(s) will be archived; confirm; B moves to Archived for john, then log in as jane.smith@example.com (co-owner of B) and mike.johnson@example.com (member of B) and confirm B is under Archived for each; re-seed afterwards to restore Tommy;
(5) failure path: re-seed, add a child with a list, stop the backend, try to delete the child: an error banner appears on the Children screen, nothing was deleted; restart the backend and press Try Again: the lists are archived and the child is deleted once;
(6) as john open list B (re-seed first): the Members section shows an Owner row and, if one is set, a Co-owner row, then Mike and others, with Remove only on the member and viewer rows; as mike.johnson@example.com the same section shows the Owner and Co-owner rows and the roster with NO Remove; as vera.viewer@example.com (viewer on list D) there is NO roster and none of the owner and co-owner rows, only the member count;
(7) as carl.coowner@example.com (blind co-owner of list F) the Members section shows Owner and Co-owner rows and Remove on member rows.

### What was not part of this package, and which checks ran
- Not part of this package: restoring or unarchiving a list (not possible), deleting archived lists, editing a child, changing who can archive, the polish and theme passes, items, purchases, stats, budgets, authentication, the lock, the release scripts, and the profile screen beyond the Children screen it already links to.
- Checks run by me (Claude Code), all as automated runs: `scripts/verify.sh` and `swift test --package-path "LocalPackages/TrackerAPI"` before and after every commit (see the reports), and the Gate 2 reviews (both reviewers on every story, one after the other). The reviewers read the code; neither took a simulator screenshot.
- Checks run by you: none yet. **Steps (1) to (7) above are NOT PERFORMED and need you.** No visual, Dynamic Type or VoiceOver check was performed for any screen touched in this package.
