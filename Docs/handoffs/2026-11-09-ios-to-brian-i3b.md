# iOS Handoff: Package I3b (members, co-owner, leaving a list, children, child lists, carried-forward fixes)
**Date:** 2026-11-09
**From:** iOS agent (Orchestrator)
**To:** Brian (PROGRAM.md) and the API team
**Branch:** feat/i3b-members-children, on top of master (I3a merged, PR 26). PRs target master. Not pushed.
**Contract:** STATUS.md CONFORMANT, decisions revision 26, spec sha256 3074067d16f5. No contract file was changed by this package.

## Commits
`git log --oneline master..HEAD`, taken before the final M4 commit:
```
3e1954a I3b: add the members section, co-owner control, children screen, and child recipient picker
47bd3e6 I3b: add the generated member and child repositories and session-safe services
6614f25 I3b: add member and child models, errors, and the flag-driven view-state rules
2d4baec I3b: never fall back to mock in real mode, guard against resurrecting deleted lists, and clean up loading state and logs
8d312d2 I3b: add epic brief and inventory
```
The M4 commit ("I3b: add the package handoff note") adds one more line. It contains this handoff and Docs/reports/I3b-5-handoff.md.

## Contract issues found
- **Row 2 in Docs/contract-issues.md (Open): the co-owner cannot be cleared through the generated client.** The contract types `coOwnerEmail` as `["string","null"]` ("Set or clear the co-owner by email", PATCH /lists/{id}), but the generated `Operations.UpdateList.Input.Body.JsonPayload.coOwnerEmail` is a plain `Swift.String?` with synthesized `Codable`, which omits a nil and cannot send an explicit JSON null. No request was sent and no workaround was built. Proposal for the API team: an explicit clearing mechanism the generated client can express (for example an empty string meaning "clear", or a dedicated operation such as `DELETE /lists/{id}/co-owner`). In the app, "Remove co-owner" is hidden (`CoOwnerSectionState.clearingSupported = false`) and the repository refuses `CoOwnerChange.clear` with a typed error before any request. Setting a co-owner works.
- Observations that are not contract disagreements: the client guide (section 7.3) does not mention the 409 on addMember although the spec and error codes have it (MEMBERSHIP_ALREADY_EXISTS 5004); the privacy matrix does not show the 422 on deleteChild (CANNOT_DELETE_RESOURCE 6501); the guide does not say whether the owner appears in `ListDetail.members` (the app is safe either way); the spec has NO update-role operation for members (member role changes were out of scope and are not built); `listMembers` (GET /lists/{id}/members) exists but the app deliberately never calls it (the roster comes from the detail).

## What changed
- **K0 (2d4baec):** in real mode the app no longer falls back to mock data. If the generated client cannot be built, a blocking screen shows ("This version can't connect to the server. Please reinstall the latest version."), nothing else, no sign-in, one category-only Sentry event, and every repository is an inert one that throws. `AppDependencies.make()` was deleted. `ListService` keeps a session-local deleted-ids guard (an in-flight load can no longer bring a deleted list back), has separate `isLoadingLists`, `isLoadingDetail` and `isMutating` flags, and drops a list that the server reports gone; the detail and edit screens leave when their list is gone (`goneListId`). Log hygiene: no Log call in `Features/` interpolates a list id, list name, email, or person value, enforced by a text-scanning test with an empty allowlist.
- **M1 (6614f25):** pure domain models (members, children, co-owner change), member and child errors with plain messages, and the flag-driven view-state functions (Members section, per-row Remove, Leave, co-owner section, children, recipient options, form validation) with a truth table; the only roster-row role read is inside the members view-state file.
- **M2 (47bd3e6):** `GeneratedClientMemberRepository` and `GeneratedClientChildRepository` (every documented response mapped, tested through the real factory-built client), the co-owner change through update-list (set only), `ListService` add, remove, leave and set-co-owner (refetch after add and remove; leave drops the list everywhere), `ChildService`, mocks with privacy scenarios, a 7th session clearable (the pinned count moved 6 to 7 because `ChildService` holds the signed-in user's children).
- **M3 (3e1954a):** the Members section, Add member sheet, Leave list, the co-owner control in Edit list, the Children screen under Profile ("Family" section), and the recipient picker in Create list.
- Test totals: app 946 -> 1399 (+453), package 212 -> 212 (unchanged), release-script 92, destination-script 17. Final `scripts/verify.sh`: `--- tests: 1399 passed, 0 failed, 0 skipped ---`, `=== verify: OK ===`. Per-story reports with raw outputs: Docs/reports/I3b-1 through I3b-5.

## What the API team must do
- Decide row 2: provide a way to clear the co-owner that the generated client can send (see Contract issues). Until then iOS cannot remove a co-owner.
- Optionally: document the 409 on `POST /lists/{id}/members` in the client guide and the 422 on `DELETE /users/me/children/{id}` in the privacy matrix, and state whether the owner appears in `ListDetail.members`.

## Open risks and deferred items
- **Unverified on screen:** no agent ran any new screen in the simulator or against the backend (no agent could log in). The screens are verified by view-state tests, text-scanning tests and reviewers reading the code. Brian's real-mode check below is the first run.
- **K0 behavior changes to know:** `loadListDetail` now shows the cached detail first and ALWAYS revalidates with the server (one extra GET per open); a spurious 404 hides a list for the rest of the session (the deleted-ids guard is session-local); `goneListId` notifies only on a value change, so a second "gone" report for the same id in one session does not re-fire the automatic screen exit (the error banner with its Leave action still shows).
- **Double submission:** the service does not guard against double submission of add, remove or leave; the views disable the controls while `isMutating`, and the sheets gate Save with `canSubmit`. `isMutating` is a Bool, so overlapping operations could flip it early (existing pattern).
- **A left (or gone) list stays hidden for the rest of the session, even if the user is re-added** (the deleted-ids guard is session-local and never cleared before sign-out; this is what makes step 9's last clause of the real-mode check likely fail). Same for a PUBLIC list the user leaves. Proposed fix, needing a decision because it rewrites existing tests: a list-of-lists load that starts after the mark clears it when the server returns the list non-archived (in-flight loads started before the mark stay blocked).
- **Reviewed by reading only (not exercised):** Dynamic Type behavior, the VoiceOver delete action, the simultaneous edit-sheet dismissal plus detail pop when a list is gone, and a 404 with an empty or non-JSON body from the member calls (the code falls back to a plain not-found).
- **Reviewed deviations:** "Leave list" is shown on `canLeaveList` alone, outside the roster card (a viewer who cannot see the roster must still be able to leave); "Delete list" is also disabled while a mutation is in flight; the ListDetail preview named "Blind owner" was renamed because a scan checks string literals for blindness wording.
- **If only the refetch fails** after a successful add or remove, `service.error` is set but the detail screen shows it only when no detail is loaded; the sheet dismisses and pull to refresh catches up.
- **A malformed 200 body** on removeMember or deleteChild is reported as an invalid response although the server already acted (removeMember then does not refetch).
- **Re-typing the current co-owner's email** re-sends it as a set (the client holds only the display name); harmless. Child delete has no visible button (swipe, context menu, VoiceOver action).
- **Mock mode:** the mock does not reject unknown recipient ids (two existing tests create lists for arbitrary recipients); `recipientNotFound` is covered through the real client only. The mock child and list were renamed from "Charlie" to "Tommy" (a cosmetic id string `mock-child-charlie` remains).
- **Log hygiene limits:** opaque item and purchase ids and raw `\(error)` values in unchanged Items and Purchases log lines are not covered by the scanning test (I3c scope).
- **DesignSystem follow-ups:** no `AppIcons` and no minimum-touch-target token exist (new views use `minHeight: 44` and literal SF Symbol names like the existing views); `ListDetailState.showsMembersSection` is now unused.
- **Process notes:** the swiftui-expert-skill was loaded by the Orchestrator and its rules were passed to the implementer (subagents cannot invoke skills). One implementer used a short Python heredoc to apply edits (command-habit slip; no stray file remained). One existing test (`failedUpdateKeepsState`) had its injected error changed from archived-read-only to forbidden because archived-read-only now means "list gone"; two tests' pinned clearables count moved 6 to 7 (stated reason).

## Brian's real-mode check
These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md. All seeded users share the password printed there. Never write passwords, ids or the registration code into this repo.

1. Start the backend on http://localhost:3010, re-seed so the ids are fresh, confirm /livez, add the launch argument `-apiModeOverride real` to the scheme, and run the Debug build on the simulator.
2. Carried over from package I3a, as john: 401 refresh path: stop the backend, set JWT_EXPIRY=60s in its .env, restart it, log in, wait 70 seconds, pull to refresh: the lists reload without a logout; restore the .env value and restart.
3. Carried over from I3a: disabled account: in the backend repo run `set -a; source .env; set +a` then `npm run user:set-active -- --email jane.smith@example.com --active false`; with jane logged in pull to refresh: the app returns to the login screen immediately; restore with `--active true`.
4. Carried over from I3a: log out with the backend stopped and confirm the login screen appears immediately.
5. As john open Profile, Children: Tommy is listed; add a child (first name, last name), delete it again (it has no lists, so it is deleted); add another, create a list for it from Create list ("For" picker shows the child), confirm the new list shows counts and Edit and Delete (john is not blind on a child's list); try deleting that child and record the message (it has a list: the 422 message); delete the list and try again and record what happens.
6. As john open list B (child's list): the Members section shows the roster with Jane and Mike; add nate.nonmember@example.com as a viewer and confirm the roster and the member count update; remove him; add an unknown email and confirm the plain "no account" message; add mike.johnson@example.com again and confirm the "already a member" message; the owner and co-owner rows have no Remove.
7. As john open list A (his self list): edit it and set carl.coowner@example.com as co-owner; confirm the co-owner shows; then try to remove the co-owner and record what the app does (or confirm the control is hidden because clearing is blocked by the contract question).
8. As jane (co-owner of B): the Members section shows, Add and Remove show, there is no Change co-owner and no Leave.
9. As mike (member of B): the roster shows, no Add or Remove, "Leave list" shows; leave B and confirm it disappears from his lists and stays gone after pull to refresh; as john re-add mike.johnson@example.com as a member of B and confirm B is back for mike.
10. As vera.viewer@example.com (viewer on list D): NO roster (member count only), "Leave list" shows; do not leave.
11. As dana.owner@example.com (list D): the roster shows vera and mia; add and remove a member; "Change co-owner" shows.
12. As carl.coowner@example.com (blind co-owner of list F): Add and Remove show, no Change co-owner, no Leave.
13. As nate.nonmember@example.com: an empty list of lists.

Items, purchases, stats, and budgets are not part of this package, so none of them should be checked here.

Notes on the check (added by the agent; the 13 steps above are unchanged): **step 9 will probably FAIL on its last clause as the code stands.** After mike leaves B, the list id stays in the session-local deleted-ids guard (K0) for the rest of mike's session, and existing tests (`ListServiceMemberTests`: a later refresh does not resurrect a left list) pin that behavior, so when john re-adds mike, B will NOT come back for mike until mike signs out and in again (a new session clears the guard). Record what you see. This is a decision for you, not a silent fix: the cheap change is to let a list-of-lists load that STARTS after the leave (or delete) mark clear the mark and show the list if the server returns it non-archived, which requires rewriting those tests; I did not make it because the rules forbid weakening existing tests. Step 7 depends on the seeded data: the guide does not say who may be the co-owner of list A beyond the rules in the brief.

Checks Brian ran: none yet (this handoff was written by the agent; no agent ran any of the 13 steps, and no agent used a real backend or the simulator). All 13 steps are NOT PERFORMED. Everything above was verified only by unit and integration tests against fakes (fake transport, fake sessions), by `scripts/verify.sh`, and by reviewers reading the code.

## PROGRAM.md section 9 (one line)
I3b (members roster, add and remove member, leave a list, co-owner set, children and child lists, plus the real-mode no-mock-fallback and K0 fixes) is done on branch feat/i3b-members-children at 1399 app and 212 package tests; clearing a co-owner is blocked by contract-issues row 2 (the generated client cannot send null); Brian's 13-step real-mode check is open, and I3c (items) is unblocked.
