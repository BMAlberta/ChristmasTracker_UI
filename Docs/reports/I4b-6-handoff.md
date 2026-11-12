# I4b-6: Handoff and the real-mode check (Story E, docs only)

Date: 2026-11-12. Branch: feat/i4b-manage-purchase. Pipeline: docs only; both reviewers ran (the convention-reviewer twice). No production code, test or contract change in this commit.

## After-commit run of the previous commit (f57fd28, Story D; came from running commands)
`scripts/verify.sh`: `** BUILD SUCCEEDED **`, `--- tests: 2937 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.017 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

## Files
Added: Docs/handoffs/2026-11-12-ios-to-brian-i4b.md (the package handoff with "Brian's real-mode check"), Docs/reports/I4b-6-handoff.md (this report).
Changed (wording only): Docs/reports/I4b-3-repository-and-service.md (one line), I4b-4-purchase-screens.md (two lines), I4b-5-legacy-deletion.md (one line): the convention reviewer's first Story E review rejected because the banned GCD type name appeared in prose in these already-committed reports; the four lines now say "GCD" and nothing else about them changed (the second review confirmed with `git diff -U0`: 4 lines in 3 files, no fact changed). These edits are folded into this commit instead of an amend, because amending is forbidden. Deleted: none. Nothing under contract/, .claude/, any .pbxproj, the synced Docs files or LocalPackages/ changed.

## What the handoff contains
Contract issues found (the trackingNumber clearing question; the guide's wording on the delete response versus the spec; the getPurchase description versus S14), what changed per story, the commit list (`git log --oneline master..HEAD` before the handoff commit), what the API team must do (nothing required; the possible idempotency-key proposal), what was kept and why (ItemStatus; NetworkCache, CacheScope, Repository), open risks (visual check not performed, classifier residual risk, delete-in-flight advisory, Record Again re-sends the stored draft, a 404 on a save closes the screen, mock limitation, unreachable fallback lines, process notes), one line for PROGRAM.md section 9, and "Brian's real-mode check" with the fifteen steps of the prompt's Story E word for word (numbered "1." to "15."), plus the statement of what was not part of the package and which checks are NOT PERFORMED (steps 1 to 10 and 12 to 15 need Brian; step 11 is NOT PERFORMED by design and covered by unit tests only).

## Commands and raw output (came from running commands; working tree, before the commit)
`scripts/verify.sh`: `** BUILD SUCCEEDED **`, `--- tests: 2937 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.018 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

## Test arithmetic
App suite: 2937 + 0 new - 0 deleted = 2937. Package suite: 212. Release-script 92, destination-script 17. Package totals across the whole package: 2523 (baseline and after P0), 2630 (A), 2771 (B), 2919 (C), 2937 (D, E).

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer, first review: REJECT on one item (the banned GCD type name appeared in prose in three committed reports). Fixed by the Orchestrator (four lines reworded, above). Re-review by the same reviewer: APPROVE; it confirmed no match in any file the branch touched and that the four edits change wording only. All its other checks passed: file name and location, required sections, no secrets or machine paths, commit list equal to `git log --oneline master..HEAD`, test totals equal to the reports, kept and deleted claims equal to `git diff --stat master...HEAD` and report I4b-5, honest "not run" statements, only the handoff untracked.
- Acceptance-reviewer: APPROVE. The fifteen real-mode steps in the handoff (lines 57 to 71) were compared character by character with the prompt: no difference except the numbering format; the file has no non-ASCII characters; step 11 is NOT PERFORMED and covered by unit tests only. Eight of nine sampled claims were confirmed (test totals, guide line 673 and openapi line 4424 citations, kept files, DeviceFingerprintService deletion and its Keychain remark, classifier default and residual risk, Advisory A). The ninth was imprecise: "17 production files deleted" counts the rename of RecordPurchaseError.swift as a deletion; the handoff now says 16 deleted and 1 renamed (fixed by the Orchestrator before this commit). All fifteen steps are workable against the implemented behavior (checked against ManagePurchaseView.swift:156-165 and 295-323, PurchaseDetailState.swift:13-19, RecordedPurchase.swift:20, ItemViewState.swift:221-230); no secrets or machine paths.
- Reviewer notes carried here: step 6's "the confirmation points at the Delete button" is literally a popover only on iPad; on iPhone the dialog is a bottom action sheet (the dialog is attached to the Delete button in code either way). The handoff's remark about the Story A test-writer's `sed` pipe is not recorded in any I4b report (the test-writer reported it in its hand-back; it produced no output and was not used). The handoff's mention of a management-repository unknown-error fallback being untested is slightly looser than the Story B report, which supports the record-path fallback and the 401/429 status switch only.
- Rejections and re-reviews: one (convention, above). Stuck-detector log: none.

## Package-end check
`git diff --stat master...HEAD` is run after this commit and pasted in the final message of the session; this report cannot contain its own commit's output. The acceptance reviewer confirmed before the commit that `git log master..HEAD` for contract/, the synced Docs files and LocalPackages shows only db5a18d (your sync) and c99b8d1 (P0), and that error-codes.md is unchanged.

## Verification claims
Build, test and diff checks: from running commands. The handoff's step text equality: from the acceptance reviewer's comparison (the Orchestrator also copied the steps from the prompt text in this session). Gate 2 evidence: from the reviewers.

## Deviations and real bugs
The four report lines edited after their commits (see above). Real bugs found: none. The `python3 -c "print(1)"` slip during P0 is recorded in report I4b-1 and the handoff.

## Not done or partial
The real-mode check (all steps except 11) needs Brian; the visual check, VoiceOver and Dynamic Type were not run by me; the after-commit run of this commit is not in this report (it is in the final message of the session).
