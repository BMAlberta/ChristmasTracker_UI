# I4c-1: Regenerate from contract revision 34 (Story P0)

Date: 2026-11-12. Branch: feat/i4c-clear-tracking. Pipeline: full pipeline per the brief, with no test-writer step (the story writes no code and no test; the existing SpecConformance test is the check). Implementer ran the script, then the convention-reviewer and the acceptance-reviewer reviewed the diff, one after the other. Gate 1: Docs/epics/I4c-clear-tracking.md ("Gate 1: Story P0"). No UI change, so the SwiftUI skill does not apply.

## Files
- Changed: LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json (4 insertions, 1 deletion; descriptions only).
- Added: Docs/reports/I4c-1-regenerate.md (this report).
- Deleted: none. Nothing under contract/, .claude/, any .pbxproj or the synced Docs files changed.

## What changed (came from reading `git diff`)
Four description edits, identical in content to the three S15 hunks in contract/openapi.json plus the getPurchase description:
1. getPurchase description: "purchaser only; anyone else gets 404 PURCHASE_NOT_FOUND (P11)" (was "purchaser or list owner only").
2. updatePurchase body, `notes`: added description "An empty string clears the field."
3. updatePurchase body, `trackingNumber`: same description.
4. updatePurchaseShipping body, `trackingNumber`: same description.
No type, required list, operationId, path or status code changed. The transformed null-schema property count stayed 5 (script output `Transformed 5 null-schema properties.`), so the guard and its pinning test did not change.

## Commands and raw output (came from running commands)
Before the commit (working tree with the regenerated spec), `scripts/verify.sh`: `Transformed 5 null-schema properties.`, `Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3107 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.020 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.
Before the commit, `swift test --package-path "LocalPackages/TrackerAPI"` (implementer's run): `Test run with 212 tests in 16 suites passed after 0.019 seconds.` The same run inside verify.sh: `Test run with 212 tests in 16 suites passed after 0.020 seconds.` The test "Derived spec file matches the Swift-transform applied to contract/openapi.json" passed (it failed before this story, as expected).
Previous commit (105cf7f, brief) after-commit run, for the record: `scripts/verify.sh` stopped at `ERROR: Derived spec is out of date.` / `=== verify: DERIVED SPEC OUT OF DATE`, and the package suite was `Test run with 212 tests in 16 suites failed after 0.019 seconds with 1 issue.` (the derived-spec test), both by design before P0.
The after-commit run for THIS commit is pasted at the top of the Story A report.

## Test arithmetic
App suite baseline (recorded in P3 on the unchanged code): 3107. This story: +0 new, -0 deleted, 0 rewritten = 3107; verify.sh says 3107 passed. Package suite: 212 + 0 = 212 (211 passed and 1 expected failure before; 212 passed now). Release-script tests 92, destination-script tests 17 (unchanged).

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE. Exactly one modified file (the derived spec), no stray files, nothing under contract/, .claude/, .pbxproj or the synced Docs, no Swift change, branch name follows feat/<slug>.
- Acceptance-reviewer: APPROVE. Each hunk of the derived-spec diff matches a hunk of `git diff master..HEAD -- contract/openapi.json` (only line numbers differ); every changed line is a `description`; `scripts/make-client-spec.sh --check` printed the count 5 and "Derived spec is up to date."; nothing else changed.
- Rejections and re-reviews: none. Stuck-detector log: nothing repeated.

## Verification claims
Script output, build, test totals and the verify result: from running commands. The "only descriptions changed" claim: from reading the diff myself (Orchestrator) and from both reviewers reading it. One implementer command was blocked by a hook because it read a tool-output file under .claude/; it re-ran the test with a pipe to grep instead; no file under .claude/ was touched.

## Deviations, real bugs, scope
Deviation: none. Real bugs found: none. Outside the scope: none.

## Not done or partial
None for this story. (The real-server behavior of S15 is not exercised by this story; the real-mode check in the Story D handoff covers it and needs Brian.)
