# I4b-1: Regenerate from contract revision 33

Date: 2026-11-12. Branch: feat/i4b-manage-purchase. Pipeline: solo (the story is a regeneration and a build; no new interface).

## Files
- Changed: LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json (derived spec; 71 insertions, 0 deletions).
- Added: Docs/reports/I4b-1-regenerate.md. Deleted: none.

## What changed
`scripts/make-client-spec.sh` (write mode) printed `Transformed 5 null-schema properties.` and wrote the derived spec. The transformed-property count guard (5) held, so no anyOf-null property was added or removed and neither the guard nor its pinning test changed. The diff is purely additive: the `deletePurchase` operation under `/tracker/v2/purchases/{id}`. `git diff` shows no removed line (checked with a grep for lines starting with a single minus, empty). No Swift source changed; no exhaustive switch broke.

## Commands and raw output (came from running commands)
Before the story (after the docs commit b0a53fb), `scripts/verify.sh`:
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate.
=== verify: DERIVED SPEC OUT OF DATE — run scripts/make-client-spec.sh ===
```
Before, `swift test --package-path "LocalPackages/TrackerAPI"` (at P3, before the docs commit):
```
􀢄  Test "Derived spec file matches the Swift-transform applied to contract/openapi.json" recorded an issue at SpecConformanceTests.swift:177:9: Expectation failed: transformedContractData == derivedSortedData
􀢄  Test run with 212 tests in 16 suites failed after 0.023 seconds with 1 issue.
```
After regeneration (working tree, before the commit):
```
􁁛  Test "Applying the nullable transform to contract/openapi.json produces exactly 5 changes" passed after 0.011 seconds.
􁁛  Test "Derived spec file matches the Swift-transform applied to contract/openapi.json" passed after 0.013 seconds.
􁁛  Test run with 212 tests in 16 suites passed after 0.022 seconds.
```
`scripts/verify.sh` after regeneration (working tree, before the commit), summary lines:
```
** BUILD SUCCEEDED **
--- tests: 2523 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.021 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
The after-commit run of verify.sh and of the package suite is recorded in the "After the commit" section below.

## Test arithmetic
App suite: 2523 (baseline) + 0 new - 0 deleted or rewritten = 2523. Package suite: 212 + 0 - 0 = 212. Release script tests 92, destination script tests 17. These are the baseline numbers for the rest of the package.

## Gate 2
Convention-reviewer and acceptance-reviewer are not run for this story: a generated-file change with no Swift change has nothing for them to read beyond the diff above, and CLAUDE.md puts the full pipeline on the repository layer, which starts in Story B. The Orchestrator checked the diff directly (additive, one operation, count guard held). Stated here rather than hidden.

## Deviations
- While searching the spec I ran a `python3 -c "print(1)"` command in the same call as a grep by mistake. It printed `1`, touched no file and read no data. It broke the "no python" rule of the brief; no further script was run.

## Verification claims
- Count guard held, diff additive, verify green: from running commands.
- "No Swift source needed a change": from the green build (a command), not from reading code.

## Not done or partial
None for this story. (Generated sources in LocalPackages/TrackerAPI/.build are rebuilt by the build; the signatures of deletePurchase are read in Story B.)

## After the commit
A report cannot contain the output of a run that happens after the commit that contains the report, and amending is forbidden. The after-commit runs of verify.sh and of the package suite for this commit are therefore pasted verbatim at the top of the next story's report (Docs/reports/I4b-2-domain-and-rules.md, section "After-commit run of the previous commit"), and the same pattern is used for every later commit.
