# I5b-1: Regenerate the client at decisions revision 36 and fix the compile errors

Package I5b, Story A. Path: full pipeline (generated-client and repository layer). Solo implementer, then both reviewers.

## What changed
Regeneration: `scripts/make-client-spec.sh` was run (the repository's own procedure; `scripts/sync-contract.sh` was not run). It rewrote `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`. The Swift client is generated from it by the build plugin. Nothing generated was hand-edited.

Generated-surface changes found (from the Inventory, confirmed by the compile errors):
- `Operations.UpdateBudget.Output.unprocessableContent` is new. createBudget and duplicateBudget gained no 422.
- `createChild` 201 `relationshipType` is `Components.Schemas.RelationshipType` (was String).
- `Components.Schemas.Item` has required `canEdit` and `canDelete`; getItem keeps the allOf shape and the flags are in `value1`.
- The error envelope still carries codes only as the generic `error.errorCode` (String) and `error.code` (Int).

Compile errors seen on the first build after regeneration: a non-exhaustive switch in the update budget path and `relationshipType` String to enum in createChild. Nothing else failed.

Fixes (no behavior change beyond compiling):
- `GeneratedClientBudgetRepository.swift`: update handles `.unprocessableContent` as `BudgetError.sumExceedsTotal` with the envelope message. No `default` was added. An unreadable-body 422 on update now maps to `sumExceedsTotal` (via a `unprocessableFailure` parameter on `budgetFailure`, default `hasPurchases` so delete is unchanged). Header comment about contract issue 3 updated.
- `GeneratedClientChildRepository.swift`: `created.relationshipType.rawValue`.
- `ListItem.swift`: stored `canEdit` and `canDelete` (Bool, non-optional); `ItemMapping.swift` maps them (getItem from `value1`). Not read by `ItemPermissions` or any view yet (Story C).
- `MockItemRepository.swift`, `RecordPurchasePreviews.swift`: pass the new arguments (mock create true/true, update keeps the existing values, `hidden()` uses `mayChange`, seed `creator == me`; preview false/false).
- Fixtures with the new required fields: `ItemFixtures.swift` (`item`, `wireItem`, `wireDetail`, defaults true), `ItemWireSupport.swift` (`itemJSON`), and `LocalPackages/TrackerAPI/Tests/TrackerAPITests/DecodingTests.swift` (two Item literals).

## Files
Added: `Docs/reports/I5b-1-regenerate.md`.
Changed: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` (by script), `LocalPackages/TrackerAPI/Tests/TrackerAPITests/DecodingTests.swift`, `GeneratedClientBudgetRepository.swift`, `GeneratedClientChildRepository.swift`, `ListItem.swift`, `ItemMapping.swift`, `MockItemRepository.swift`, `RecordPurchasePreviews.swift`, `ItemFixtures.swift`, `ItemWireSupport.swift`, `GeneratedClientBudgetErrorTests.swift`.
Deleted: none.

## Tests
Rewritten (all in `GeneratedClientBudgetErrorTests.swift`, because update's 422 is now documented and no longer undocumented):
- `undocumented422IsTheSumRule` now asserts create and duplicate only (list `undocumentedSumRuleWrites` replaces `sumRuleWrites`). Update's equivalent coverage: `updateTypedSumRule`.
- `sumRuleMessage` narrowed to create and duplicate; assertion unchanged.
Added: `updateTypedSumRule` (typed 422 gives `sumExceedsTotal` with the envelope message), `updateTypedSumRuleNoMessage` (unreadable 422 body on update gives `sumExceedsTotal`, not `hasPurchases`, with the fixed fallback message).
Deleted: none.

Test arithmetic:
- App suite: the baseline could not be measured before the change (P3: verify stops at the derived-spec gate, and the build could not resolve packages until `/tmp/ct-derived` was cleared). First green run after the change: 4184. With +2 new, 0 deleted and 2 rewritten in place, the implied previous total is 4182. That figure is arithmetic, not a measurement.
- Package suite: 212 before (1 failing, SpecConformance) + 0 new - 0 deleted = 212 after (all passing). Measured.
- Reconciliation against the test listing: not done (count came from the script summary only).

## Verification (all from running commands)
Baseline P3 (before any change), raw:
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate.
=== verify: DERIVED SPEC OUT OF DATE — run scripts/make-client-spec.sh ===
```
```
Test "Derived spec file matches the Swift-transform applied to contract/openapi.json" failed after 0.020 seconds with 1 issue.
Test run with 212 tests in 16 suites failed after 0.021 seconds with 1 issue.
```
The same two results were recorded again after the Step 1 docs commit (da06d6c).

Before the Story A commit (`scripts/verify.sh`, summary lines):
```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 4184 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed` (also inside verify above).
After the commit: see the Story B report, which records the after-commit run for this commit.

## Gate 2
- convention-reviewer: APPROVE. No findings. Warning (non-blocking): `MockItemRepository.hidden(...)` still calls `mayChange`; Story C replaces it.
- acceptance-reviewer: APPROVE. Checked (a) update 422 gives `sumExceedsTotal`, delete 422 still `hasPurchases`, create and duplicate unchanged; (b) no `default`; (c) flags non-optional, getItem from `value1` (ItemMapping.swift:33); (d) createChild behavior unchanged; (e) fixtures; (f) no test weakened or deleted; (g) LocalPackages changes limited to the regenerated openapi.json and DecodingTests, nothing under contract/, .claude/, .pbxproj or synced Docs; (h) mock behavior unchanged. Note: the seed flags (`creator == me`) are approximate stored values; Story C replaces them.
- Rejections: none. Stuck detector: implementer needed 2 attempts (one fixture argument-order compile error); not triggered.

## Deviations and outside scope
- The build first failed with "Could not resolve package dependencies" because the derived-data folder `/tmp/ct-derived` held an incomplete sentry-cocoa checkout. At Brian's instruction the folder was removed (by Brian, in the session shell) and the build re-resolved. Environment only; no repo change.
- The `budgetFailure` parameter for the update 422 goes slightly beyond the minimum; it keeps the delete path byte-for-byte as before.
- The IDE showed SourceKit "no such module" diagnostics after the edits; the build and tests are clean, so they were indexer noise.

## Not done or partial
- The pre-change app test count was not measured (see arithmetic).
- Test listing reconciliation was not done.
- No simulator run was possible, and this story has no UI change. Brian's real-mode check (Story E) is the only proof of on-screen behavior.
