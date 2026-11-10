# iOS Handoff: Package I3b-2 (remove the co-owner through removeCoOwner)
**Date:** 2026-11-10
**From:** iOS agent (Orchestrator)
**To:** Brian (PROGRAM.md) and the API team
**Branch:** feat/i3b-members-children (also holds the whole I3b package; neither is merged; not pushed).
**Contract:** STATUS.md CONFORMANT, decisions revision 28, backend cf6b90c, spec sha256 begins 88d054721d59. No contract file was changed by this package (Brian's sync commit ce80457 brought revision 28).

## The real-mode check
Brian runs ONE check for both packages. The steps are in Docs/handoffs/2026-11-09-ios-to-brian-i3b.md ("Brian's real-mode check", 15 steps): step 7 was rewritten for this package, and steps 14 and 15 were appended. They are not repeated here.

## Commits (package I3b-2)
```
ef27275 I3b-2: add the Remove co-owner action to the edit screen
aedc89d I3b-2: remove a co-owner through the new operation and update the list from the response
7f0039b I3b-2: regenerate the client from contract revision 28
bc5657a I3b-2: add epic brief and inventory
```
Plus the final docs commit ("I3b-2: resolve the co-owner contract issue and update the combined handoff"), which contains this file and cannot name its own hash. Run `git log --oneline master..HEAD` for it.

## Contract issues found
None new. Docs/contract-issues.md row 2 (the generated client cannot send a JSON null to clear the co-owner) is marked Resolved: the backend added decision L15 and `DELETE /lists/{id}/co-owner` (`removeCoOwner`), and iOS now clears the co-owner only through it.

## What changed
- Derived spec regenerated from revision 28: only the `removeCoOwner` path was added; the null-schema guard held at 5; the package pin test for public operations passed unchanged (`removeCoOwner` requires a bearer token).
- `ListRepository.removeCoOwner(listId:)` (generated client, mock, inert repository) and `ListService.removeCoOwner(listId:)`: session-safe, updates the open detail, the list entry and the cache from the returned `ListDetail`, no refetch; 403 forbidden, 404 notFound and 422 archivedReadOnly (both leave the screen), 429 rateLimited.
- Removed `CoOwnerChange.clear`, the repository's typed refusal and `CoOwnerSectionState.clearingSupported`.
- Edit screen: "Remove co-owner" with a confirmation dialog, shown when `canSetCoOwner` is true and a co-owner exists (no role read); the section updates from the service's detail; "Try Again" re-runs the failed action.
- Tests: app 1415 -> 1497 (by test function), package 212 unchanged. Reports: Docs/reports/I3b2-1 through I3b2-4.

## What the API team must do
Nothing is blocking. Optionally confirm on the real backend that the 200 of `DELETE /lists/{id}/co-owner` returns `coOwner: null` with the owner's flags (steps 7 and 14 of the combined check exercise this).

## PROGRAM.md section 9 (one line)
See the section 9 line in Docs/handoffs/2026-11-09-ios-to-brian-i3b.md, which now covers both I3b and I3b-2 (1497 app and 212 package tests; row 2 resolved; one 15-step real-mode check open).
