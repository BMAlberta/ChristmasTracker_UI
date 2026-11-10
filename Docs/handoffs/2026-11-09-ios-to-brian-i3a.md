# iOS Handoff: Package I3a (lists on the generated client)
**Date:** 2026-11-09
**From:** iOS agent (Orchestrator)
**To:** Brian (PROGRAM.md) and the API team
**Branch:** feat/i3a-lists, on top of Brian's contract sync commit 557b69c. PRs target master. Not pushed.
**Contract:** STATUS.md CONFORMANT, decisions revision 26, spec sha256 3074067d16f5. contract/VERSION names backend commit 8109ef3 while the sync commit message says 4193c78; the checksum is what the brief asks for and it matches. No contract file was changed by this package.

## Commits
`git log --oneline master..HEAD`, taken before the final L4 commit:
```
de81bd0 I3a: rebuild the list screens on capability flags and the permissions function
77056a0 I3a: move the list operations onto the generated client and make the list service session-safe
1e0d86c I3a: add flag-driven list models and the single permissions function
a32383d I3a: make rate-limit waits crash-proof, protect a new session from an old end, and fix the flaky lock test
c219b90 I3a: regenerate the client from contract revision 26 and adopt C17
2b53f96 I3a: add epic brief and inventory
557b69c chore: sync the contract at 4193c78
```
The L4 commit ("I3a: add the package handoff note") adds one more line. It contains this handoff and Docs/reports/I3a-6-handoff.md.

## Contract issues found
None. No row was added to Docs/contract-issues.md. Observations that are not contract disagreements: the brief and this package's epic say "thirteen" capability booleans, but the client guide lists twelve (plus `myRole`, which is display only); GET /lists also accepts optional `year`, `visibility` and `role` query parameters that this package never sends.

## What changed
- **H1 (c219b90):** regenerated the derived spec from revision 26 (transformed-property guard held at 5); classification now treats 4002 and 1008 as re-login and 4011 as not-found; package tests prove the session-ending middleware ignores 404 PERSON_NOT_FOUND (getUser included) and still fires on 404 USER_NOT_FOUND and 403 ACCOUNT_DISABLED; login still shows the administrator message for a 403 (unchanged code, existing tests).
- **H2 (a32383d):** a negative, NaN or infinite Retry-After can no longer crash (non-finite = absent, finite clamped to [0, cap], safe nanosecond conversion); a sign-in that completes while an older session end is in flight is no longer wiped by it, and that superseded end also makes no server logout call (found by review: it would have carried the new user's token); the flaky lock test is deterministic.
- **L1 (1e0d86c):** `GiftList`/`ListDetail` rebuilt from the generated types with `ListCapabilities` (twelve booleans), `ListPermissions` (the single flag-driven function, truth table over all 4096 combinations), `ListRoleBadge` (the only reader of the role), pure mapping, and the hand-written wire types and NetworkListRepository deleted.
- **L2 (77056a0):** `GeneratedClientListRepository` for list, get, create, update, delete with typed `ListError`s; `ListService` safe against sign-out and user switching (session generation, cancellation, no error after the session ended), archived lists hidden, delete removes locally, create/update use the returned detail.
- **L3 (de81bd0):** list screens rebuilt on pure view-state functions and the flags; no view reads the role.
- Commit hashes, per-story reports and raw outputs: Docs/reports/I3a-1 through I3a-6.
- Test totals: app 677 -> 946 (+269), package 191 -> 212 (+21). Final `scripts/verify.sh`: `--- tests: 946 passed, 0 failed, 0 skipped ---`, `=== verify: OK ===`.

## What the API team must do
Nothing expected.

## Open risks and deferred items
- **Silent mock fallback (needs a decision before release):** in real mode, if `buildGeneratedClient` returns nil (the factory throws), the app falls back to the mock composition for auth and lists with only a LogError (ChristmasTrackerApp.swift lines 158 to 171 and 257 to 262, pre-existing since 2026-11-06, found by review). A visible failure would be safer.
- **Legacy `AppDependencies.make()` real branch** still builds `MockListRepository(withMockData: false)`; the reviewer found no callers. Delete it or make it fail.
- **Not shippable states:** none remain on the branch. The L1 temporary placeholder (real mode on an empty mock list repository) was replaced in L2 (77056a0) and only existed in commit 1e0d86c.
- **Unverified on screen:** the list screens were never run in the simulator by an agent (simctl could not log in); Brian's real-mode check below is the first run. SwiftUI previews exist.
- **Tests that cannot be deterministic:** a teardown landing exactly between two cache writes cannot be tested without a production seam; the cache write is now one atomic data-store call, covered by unit tests and code review. The 429 repository tests use `Retry-After: 0.001` (about 1 ms real sleep) because the factory has no sleeper seam.
- **Accepted limitation (H2):** `SessionManager.teardown` is not guarded by the session generation; a clearable that finishes late is part of the old session's teardown and could clear data the new session loaded in the meantime.
- **Service edge cases (deferred):** a refresh already in flight when a delete completes can briefly show the deleted list until the next refresh (a session-local set of deleted ids is the cheap fix); loadListDetail, create, update and delete share `isLoading` with loadLists; pull-to-refresh on the detail swaps the detail for the Loading view first; an archived detail opened by id is displayed; closing the edit sheet on a gone list leaves the detail screen up. `ListError.sessionEnded` is never produced by the repository or the service (the session-ending middleware ends the session first and the service discards stale results); CreateListView uses it only for the plain message shown when there is no signed-in user.
- **For the items package (I3c):** `ItemService.swift:99` logs a list id ("Loaded N items for list <id>"); `ItemRow` still uses raw colors and fixed fonts and shows a "Surprise" badge for off-list items; the detail screen's empty-items behaviour for blind viewers should be checked against Docs/privacy-matrix.md when items are rebuilt.
- **DesignSystem follow-ups:** no corner-radius token (radii borrow `AppSpacing`), `AppTypography` fonts are fixed-size so Dynamic Type does not scale, raw `44` minimum-target literals, a destructive-color token, and `ErrorStateView`/`EmptyStateView` still contain raw `.red`/`.white`/`.cornerRadius(12)` (shared with StatsView, PurchaseHistoryView and, for `EmptyStateView`, the dashboard).
- **Process notes:** the swiftui-expert-skill could not be invoked by the implementer subagent (no Skill tool); it was loaded by the Orchestrator and applied at review time. Several command-habit slips by agents are recorded in the reports (one `&&`, one `for` loop, two scratch-script edits).

## Brian's real-mode check
These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md. All seeded users share the password printed there. Never write passwords, ids or the registration code into this repo.

1. Start the backend on http://localhost:3010, re-seed so the ids are fresh, and confirm /livez.
2. In Xcode choose the ChristmasTracker scheme, Edit Scheme, Run, Arguments, add `-apiModeOverride real`; run the Debug build on the simulator.
3. Log in as john.doe@example.com: he sees list A (his self list: he is its blind owner and recipient: NO counts, NO progress) and list B (a child's list he owns, so he is not blind: counts and progress DO show); on both, Edit and Delete appear.
4. Log in as jane.smith@example.com: list A (member: counts show, no Edit, no Delete) and list B (co-owner: counts, Edit AND Delete appear).
5. Log in as mike.johnson@example.com: list B (member: no Edit, no Delete) and list C (his own self list: blind, no counts, Edit and Delete appear).
6. Log in as dana.owner@example.com (list D: blind owner, no counts, Edit and Delete), then vera.viewer@example.com: list D with NO counts, NO progress, a viewer badge, and NO Edit and NO Delete.
7. Log in as mia.member@example.com: lists D and F with counts and no Edit or Delete.
8. Log in as fiona.owner@example.com (list F: blind owner, no counts), then carl.coowner@example.com: list F as a blind co-owner: NO counts, and Edit AND Delete appear.
9. Log in as paula.public@example.com: list E (a PUBLIC self list, blind owner: no counts, Edit and Delete); nate.nonmember@example.com sees an empty list of lists (he can open list E only by id, and no screen does that yet, so that case is covered by unit tests only).
10. As john: create a list for yourself for a year that already has one and confirm the duplicate message; create one for a free year (name, year, visibility) and confirm it appears with no counts (he is the recipient); edit its name and visibility and confirm the detail updates; delete it and confirm the confirmation dialog, that it disappears, and that it stays gone after pull to refresh (the server archives it).
11. 401 refresh path: stop the backend, set JWT_EXPIRY=60s in its .env, restart it, log in as john, wait 70 seconds, pull to refresh: the lists reload without a logout (refresh-once-and-replay); then restore the .env value and restart.
12. Disabled account: in the backend repo run `set -a; source .env; set +a` then `npm run user:set-active -- --email jane.smith@example.com --active false`; with jane logged in pull to refresh: the app returns to the login screen immediately; run the same command with `--active true` to restore.
13. Log out with the backend stopped and confirm the login screen appears immediately.

Items, members, children, co-owner changes, leaving a list, and purchases are not part of this package, so none of them should be checked here.

Notes on the check (added by the agent; the 13 steps above are unchanged): `-apiModeOverride real` works in a Debug build (Config-Debug sets `API_MODE = mock`, `APP_ENVIRONMENT = development`, `API_BASE_URL = http://localhost:3010`) and is ignored in a production environment build. Progress shows only when the list has at least one item, so a seeded list with zero items shows counts but no progress bar in steps 3, 4 and 7. Which seeded user holds which list and role comes from the backend seed and was not checked by an agent. Steps 11 to 13 rest on session behaviour from earlier packages (refresh once and replay, 403 ACCOUNT_DISABLED ends the session, logout without a server).

Checks Brian ran: none yet (this handoff was written by the agent; no agent ran any of the 13 steps, and no agent used a real backend). All 13 steps are NOT PERFORMED. Everything above was verified only by unit and integration tests against fakes (fake transport, fake sessions), by `scripts/verify.sh`, and by reviewers reading the code.

## PROGRAM.md section 9 (one line)
I3a (lists on the generated client: capability flags, the single flag-driven ListPermissions, list screens, plus C17 and the H2 hardening) is done on branch feat/i3a-lists at 946 app and 212 package tests; Brian's 13-step real-mode check is open, I3b (members, children, co-owner, leave) and I3c (items) are unblocked.
