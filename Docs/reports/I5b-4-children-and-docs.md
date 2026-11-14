# I5b-4: Children enum and the docs

Package I5b, Story D. Solo path (no new interface): one implementer, then the convention-reviewer. The acceptance-reviewer was not run (CLAUDE.md: full path only).

## What changed
- Children: nothing in production. Story A already made `GeneratedClientChildRepository.createChild` use `created.relationshipType.rawValue` (`Components.Schemas.RelationshipType`), the same way `fetchChildren` does (line 37). It was not a compile-time workaround, so no further mapping change was needed. An unknown value on create now fails in generated-type decoding and still reaches the caller as `ChildError.invalidResponse`.
- Tests: no new test. The existing parameterized `createChildSuccess` already pins a 201 for each of PARENT, GUARDIAN and CARETAKER to the matching `ChildRelationship`, and `createChildUnknownRelationship` pins `invalidResponse` for "SIBLING"; both pass. Only stale wording was fixed: the header comment and two display names in `GeneratedClientChildRepositoryTests.swift` (assertions unchanged) and the doc comment at `MembersWire.swift:83`. The production comments in `GeneratedClientChildRepository.swift` were already accurate.
- `Docs/contract-issues.md` row 3 is closed: "Resolved: closed by the contract at 2ac98bb (decisions revision 36; API handoff 2026-11-13-api-to-ios-and-web-s16-p25)", stating that the typed 422 exists on `updateBudget` only, that an over-sum on create or with both fields sent on update is a 400, and that `duplicateBudget` takes no 422. Rows 1 and 2 are untouched and no other contract issue was added.

## Files
Added: this report.
Changed: `ChristmasTrackerTests/Features/Children/GeneratedClientChildRepositoryTests.swift` (comments and display names), `ChristmasTrackerTests/Features/Lists/MembersWire.swift` (comment), `Docs/contract-issues.md` (row 3 status cell).
Deleted: none.

## Tests
New: none. Changed: `createChildSuccess` and `createChildUnknownRelationship` (display names only). Deleted: none.
Test arithmetic: app suite 4230 + 0 new - 0 deleted = 4230 (measured); package suite 212 + 0 - 0 = 212 (measured).

## Verification (all from running commands)
Before the commit (`scripts/verify.sh`, summary lines):
```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 4230 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.021 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Package suite: 212 tests in 16 suites passed (inside verify). Story C after-commit run (dcc18de): `** BUILD SUCCEEDED **`, `--- tests: 4230 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`. After the Story D commit: see the Story E report.

## Gate 2
- convention-reviewer: APPROVE, no findings. Checked from reading and `jq` on the spec: the response codes of `updateBudget` (includes 422), `createBudget` and `duplicateBudget` (no 422) match the row; rows 1 and 2 untouched; no behavior change. The reviewer did not check the row's two statements about 400 responses against the spec; they come from the API handoff summary in the brief and the `createBudget` and `updateBudget` descriptions seen in the Inventory.
- acceptance-reviewer: not run (solo path).
- Stuck detector: not triggered.

## Deviations and outside scope
- The brief asked for "a test" for the enum mapping; the existing parameterized test already is that test, so none was added.

## Not done or partial
- The row 3 statements about the 400 cases: the update half (both fields sent with an over-sum is 400, one field is 422) was confirmed by the Orchestrator in the `updateBudget` description at `contract/openapi.json:2598` (grep). The create half (over-sum is 400) rests on the `createBudget` description as reported by the Inventory; it was not re-read for this report.
- No simulator run was possible, and this story has no UI change. Brian's real-mode check is the only proof of on-screen behavior (the Children flows are in step 11).
