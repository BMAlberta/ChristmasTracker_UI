# Handoff: iOS to Brian, package I5b (contract sync at decisions S16 and P25)

Date: 2026-11-14. Branch: feat/i5b-contract-sync-s16-p25 (from master, after UX1a merged). Nothing was pushed.

## Contract issues found
None. The synced contract (backend 2ac98bb, decisions revision 36, spec sha256 prefix f092125d6375, status CONFORMANT) matched the API handoff summary in the brief. The API handoff file `Docs/handoffs/2026-11-13-api-to-ios-and-web-s16-p25.md` was NOT synced into this repo; the package worked from the brief, the synced contract files and the guide. Contract issue row 3 is closed (it was filed by iOS in I5a).

## What changed
- Story A (regenerate and compile-fix): `scripts/make-client-spec.sh` was run (the derived spec was out of date after Brian's sync commit); the client regenerated through the build plugin. Compile fixes: the new `updateBudget` 422 case maps to the sum-rule error (an unreadable 422 body on update now maps to it too; delete keeps its has-purchases 422), the `createChild` 201 relationship type is the enum, and `ListItem` stores the new required `canEdit` and `canDelete`.
- Story B (budgets): a new `BudgetError.recipientNotFound` for a 404 on create or update whose envelope error code is RECIPIENT_NOT_FOUND (4010), read through the generated envelope's typed `errorCode` and `code` fields (nothing parsed by hand). It has a fixed message that names nobody, is not "gone", and is category `.other` in the load failure policy. BUDGET_NOT_FOUND and any other or unreadable 404 still mean "gone". The editor keeps the form, shows the banner inside itself, stays open and refreshes its person options. The refresh goes through `ListService.refreshLists(reportingFailure:)` (new parameter, default unchanged) with `false`, so it never sets or clears the Lists screen's failure that the Dashboard reads. The candidate rule now matches the guide: recipients of lists where `canPurchase` is true (own blind lists excluded) plus the recipients already in the budget; the "people the user has spent on" group and its inputs are gone.
- Story C (items): Edit and Delete on the item detail read only the item's `canEdit` and `canDelete` from the server (`ItemPermissions` no longer derives them; its other rules are unchanged; item rows have no such controls). Decoding is strict: a response missing either flag is an invalid-response failure, pinned by tests. The defensive 422 CANNOT_DELETE_ITEM_WITH_PURCHASES mapping stays. The mock repository computes consistent flags with one mock-only function.
- Story D (children and docs): the createChild 201 mapping uses the enum like the list mapping (done in Story A; the existing parameterized test pins all three values and the unknown-value failure); `Docs/contract-issues.md` row 3 is closed.
- Tests: app suite 4184 (after Story A; the pre-change count could not be measured because the build was blocked) -> 4215 (B, +31) -> 4230 (C, +15) -> 4230 (D, +0). Package suite 212 throughout (it had 1 failing test, SpecConformance, before the derived spec was regenerated). Release script tests 92 and destination script tests 17 unchanged.

## Commits (git log --oneline master..HEAD, before this handoff commit)
```
4a5fb72 I5b: use the relationship enum for created children and close contract issue 3
dcc18de I5b: read per-item edit and delete rights from the server
7014d86 I5b: handle the recipient 404 and the typed 422 and align the budget candidate rule
2f400d4 I5b: regenerate the client at decisions revision 36 and fix the compile errors
da06d6c I5b: add epic brief and inventory
cead388 chore: sync contract 2ac98bb
```
`cead388` is Brian's contract sync commit. The handoff commit "I5b: add the package handoff note" follows these. Reports: Docs/reports/I5b-1-regenerate.md, I5b-2-budgets.md, I5b-3-items.md, I5b-4-children-and-docs.md, I5b-5-handoff.md. Epic: Docs/epics/I5b-contract-sync-s16-p25.md.

## What the API team must do
Nothing.

## Open risks
- Strict decoding: the item fields `canEdit` and `canDelete` are required. An older server that lacks them (before backend commit 2ac98bb) fails the items load as an invalid response.
- No simulator run was possible in the build session. Brian's real-mode check below is the only proof of the on-screen behavior (Edit and Delete visibility per person, the budget editor).
- Behavior changes against the old client:
  - Budget person options no longer include people the user has only spent on (decision of 2026-11-13). Existing allocations are still offered; people who are no longer connected cannot be newly added (the server answers RECIPIENT_NOT_FOUND).
  - Edit and Delete on the item detail now follow the server's flags. A non-blind owner no longer sees Delete on an item that has purchases; before, the client offered it and relied on the 422.
- Edge cases accepted by the reviewers: if another lists refresh is already running when a recipient error happens, the editor's person options are not rebuilt after that refresh lands (reopening the editor rebuilds them); if the forced refresh is cancelled or the session ends, the picker can show no options.
- `ItemPermissions.currentUserId` is now an unused stored property (kept for the init signature, `Equatable` and call sites). Candidate for a later cleanup, as are two stale test comments (`ItemMappingTests.swift:13` still says the mapper is "flag-free") and one long comment line in `ItemMapping.swift:7`.
- The build first failed with a corrupted package checkout in the script's derived-data folder `/tmp/ct-derived`; Brian removed it and the build re-resolved. Environment only.
- Known gaps in the reports: the app-suite deltas (+31, +15) are measured totals, not itemized against the test listing; no second convention-review pass ran on the small rejection fix in Story B (the Orchestrator read it).

## For section 9 of PROGRAM.md (one line)
I5b (iOS, branch feat/i5b-contract-sync-s16-p25, 5 commits plus Brian's contract sync and this handoff commit, app tests 4184 -> 4230 after the regeneration, package 212): synced at backend 2ac98bb (decisions revision 36); budgets handle the typed recipient 404 and the typed update 422 and offer only purchasable-list recipients plus existing allocations, item Edit and Delete follow the server's canEdit and canDelete (strict decoding), the createChild enum compiles, contract issue 3 is closed; the on-screen behavior is unverified until Brian's real-mode check.

## Brian's real-mode check
Update the backend repo to commit 2ac98bb or later (its handoff is Docs/handoffs/2026-11-13-api-to-ios-and-web-s16-p25.md), then restart it with `npm run dev` ONLY. Do not run the seed when you restart it after step 1: re-seeding creates new user ids and the app correctly signs you out.

These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md (no password, id, token or registration code is written in this repo).

1. **Start and log in as John.**
   - Start the backend on http://localhost:3010 at commit 2ac98bb or later, re-seed ONCE and confirm /livez.
   - Use the "ChristmasTracker (Real)" scheme copy that carries -apiModeOverride real (never edit the shared scheme).
   - Run the Debug build on the simulator.
   - Log in as john.doe@example.com.

2. **The items still load.**
   - Open list A and list B.
   - Expect: both load with their items (a decoding failure of the new item fields would show an error here).

3. **Blind owner (John on his own list A).**
   - Open the Socket Set and the DeWalt drill.
   - Expect: Edit and Delete are available on both, including the DeWalt drill that Jane purchased (a blind owner can always delete; John does not see purchases).

4. **Non-blind owner (John on list B, Tommy's list).**
   - Open the LEGO Technic Set.
   - Expect: Edit and Delete are both available (no purchases).
   - Open the Nintendo Switch (Mike purchased it).
   - Expect: Edit is available and Delete is NOT offered (the item has purchases and you can see gift activity).

5. **Co-owner (log in as jane.smith@example.com, list B).**
   - Repeat step 4.
   - Expect: the same results as John on list B.

6. **Member (log in as mike.johnson@example.com, list B).**
   - Open the LEGO Technic Set and the Nintendo Switch.
   - Expect: neither Edit nor Delete is offered on these items (a member does not manage another person's items).

7. **Budgets still work (John).**
   - On the Statistics tab create a budget with Tommy, edit it, duplicate it to the next year and delete the duplicate.
   - Expect: every action works as in the I5a check.

8. **Existing allocation stays editable (Jane).**
   - Log in as jane.smith@example.com, open the Statistics tab, and choose Edit Budget on the current year.
   - Expect: Mike (an existing allocation) still appears with his limit and can be edited or removed, whether or not he is offered when adding.

9. **Recipient error.**
   - The server's 404 RECIPIENT_NOT_FOUND cannot be reproduced by hand (the app only offers connected people): NOT PERFORMED, covered by unit tests.

10. **Over-sum.**
    - The app checks the sum before sending, so the 422 and 400 over-sum responses cannot be reproduced by hand: NOT PERFORMED, covered by unit tests.

11. **Normal flows still work.**
    - Lists, list detail, add an item, edit an item you own, record a purchase, Children (add a child, then delete one), Members add and remove, archive and the Archived tab.

### Not part of this package
Any new screen, the purchase flows, services' session guards, authentication, the lock, the theme and the polish items of UX1b, a third item flag for manual status changes (iOS has no such control), and any handling of an endpoint that does not exist (there is no budget candidate endpoint).

### Which checks were run
Brian's real-mode check was NOT PERFORMED by the build session: none of steps 1 to 8 and 11 was run. No backend was started, no simulator was driven and no screenshot was taken; the session had no network or database access (by rule) and no booted simulator. Steps 9 and 10 cannot be reproduced by hand and are NOT PERFORMED by design: they are covered by unit tests (`GeneratedClientBudgetErrorTests`, `BudgetEditorModelRecipientNotFoundTests`, and the existing sum-rule tests). Brian runs steps 1 to 8 and 11 and records which ones passed.
What WAS run in the session: scripts/verify.sh (4230 app tests, 92 release script tests, 17 destination script tests, all passing) and `swift test --package-path "LocalPackages/TrackerAPI"` (212 tests), before and after every commit (the baseline before any change failed as described above).
