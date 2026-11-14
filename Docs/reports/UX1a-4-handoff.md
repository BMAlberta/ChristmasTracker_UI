# UX1a-4: Handoff and the real-mode check (docs only)

Commit subject: "UX1a: add the package handoff note".
Pipeline: docs only. Gate 2: convention-reviewer and acceptance-reviewer ran one after the other on the uncommitted handoff (there is no code in this story).

## Baseline for this story (after-commit run of the U3 commit bf7723f)
```
--- tests: 4182 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(This is the after-commit output for the U3 commit, as promised in the U3 report.)

## Files
Added: Docs/handoffs/2026-11-13-ios-to-brian-ux1a.md, Docs/reports/UX1a-4-handoff.md. Changed: none. Deleted: none. No code, test, script, contract, .claude, .pbxproj, LocalPackages or synced Docs file was touched.
The handoff contains: contract issues (none), what changed per story, the four commit hashes with subjects from `git log --oneline master..HEAD`, what the API team must do (nothing), open risks (every accepted deviation and warning from the three reports), the one line for section 9 of PROGRAM.md, "Brian's real-mode check" (the note at the top and steps 1 to 13 as a numbered list, copied from the package prompt file, step 10 stated as NOT PERFORMED, covered by unit tests), "Not part of this package" and "Which checks were run".

## Test arithmetic
No test was added, changed or deleted. App suite 4182 -> 4182; package suite 212; release script tests 92; destination script tests 17. Package totals: 3870 (P2 baseline) + 55 (U1) + 112 (U2) + 145 (U3: 160 new - 15 removed or reduced) = 4182.

## Verification (commands run)
Before commit, run by the Orchestrator, `scripts/verify.sh`:
```
--- tests: 4182 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.022 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
The package suite ran inside verify.sh (`swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests passed). The after-commit output for this commit is in the Orchestrator's final message (a report cannot contain the output of the commit that adds it).
Package-end check (run before this commit, `git diff --stat master...HEAD | tail -5`): 98 files changed, 7103 insertions(+), 846 deletions(-); the only Docs files are Docs/epics/UX1a-errors-and-stale-data.md and Docs/reports/UX1a-1, UX1a-2 and UX1a-3. `git diff --name-only master...HEAD` filtered for contract/, pbxproj, LocalPackages/ and the synced Docs files (client-guide, error-codes, DECISIONS, PRD, privacy-matrix) printed nothing, and the same list with Features sources and the UX1a docs filtered out is empty, so nothing outside Features, ChristmasTrackerTests and the UX1a docs changed (this also covers the protected tooling directory, which the shell hook does not let a command name). The re-run after the final commit is in the final message.

## Gate 2
Convention-reviewer: APPROVED (docs only). Required sections present (contract issues, what changed, API team, section 9 line); commits match git log; test totals consistent with the three reports; no secret, machine path, token or registration code (the only "password" mention says none is written; the only emails are the seeded example addresses); the real-mode check is a numbered list with a bold title and nested bullets per step and starts with the required note; git status showed only the new handoff file. Nits waived: steps 1, 10 and 13 have no "Expect:" bullet and some results are written as plain bullets (for example "tap Try Again: the banner clears"); that is the wording of the package prompt, which the brief requires to be copied word for word.
Acceptance-reviewer: APPROVED. Focus (10): the real-mode section was compared with the prompt line by line and matches word for word, including the top note, the 13 steps, every Expect bullet and step 10; the not-performed steps are stated; the claims match the reports and git log. Focus (11): `git diff --stat master...HEAD` shows nothing under contract/, .claude/, any .pbxproj, the synced Docs files or LocalPackages/. Gaps it listed and the disposition: (a) the claim that the Children load "already had" its own failure was not supported by the reports: corrected in the handoff (the Children load keeps its `phase`; its shared `error` is gone); (b) I5a findings F and G now point at the I5a handoff; (c) omissions from Open risks (silent leaveList and Create list with no user, the Children banner row, the shared `ChildService.phase`, mutations no longer clearing load failures, Statistics cancelling loads on disappear, the quiet-waiter gap, finding F5, the dropped ListErrorDismissal cases and ChildService assertions) were added; (d) "before and after every commit": the reports record the before-commit run of each commit and carry its after-commit output into the next report (the U1 commit's after-run is in the U2 report, and so on); the after-run of this final commit is in the final message.
Rejections: none. Stuck-detector: not triggered.

## Deviations
- The handoff has one extra sentence under the note ("These steps need the local backend and its seeded users from the backend repo's Docs/local-development.md ..."), which paraphrases the prompt's sentence and writes no secret.

## Not done or partial
- Brian's real-mode check was NOT performed (no backend, no simulator, no network in the session); it is the only proof of the on-screen behavior of the whole package. Step 10 (two banners for different causes) cannot be reproduced by hand and is covered by unit tests only.
- The handoff is not pushed; the human pushes.
