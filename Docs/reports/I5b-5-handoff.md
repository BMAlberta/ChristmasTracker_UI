# I5b-5: Package handoff note and the real-mode check

Package I5b, Story E. Docs only; no code. Reviewers: convention-reviewer, then acceptance-reviewer (package-level focus items 9, 10, 12 and 14).

## What changed
- `Docs/handoffs/2026-11-14-ios-to-brian-i5b.md`: contract issues (none; row 3 closed; the API handoff file was not synced into this repo, so the package worked from the brief and the synced contract files), what changed per story, commits with subjects, what the API team must do (nothing), open risks (including that decoding the new item fields is strict, so an older server fails the items load), the line for section 9 of PROGRAM.md, and "Brian's real-mode check" as a numbered list of the 11 fixed steps with the required top note, steps 9 and 10 marked NOT PERFORMED, what was not part of the package, and which checks were run.
- `Docs/reports/I5b-5-handoff.md`: this report.

## Files
Added: the two files above. Changed: none. Deleted: none.

## Tests
New, rewritten, deleted: none. Test arithmetic: app suite 4230 + 0 - 0 = 4230; package suite 212 + 0 - 0 = 212 (both measured by the verify run below). Whole package: 4184 after Story A -> 4215 -> 4230 -> 4230 -> 4230.

## Verification
Before the commit (`scripts/verify.sh`, summary lines; docs-only change on top of 4a5fb72, whose after-commit run was `** BUILD SUCCEEDED **`, `--- tests: 4230 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`):
```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 4230 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
The after-commit run for this commit is reported in the Orchestrator's final message, because it can only be taken after the commit exists.

All claims in this report about the handoff text come from reading files; the totals come from running `scripts/verify.sh` after each earlier commit (see the other four reports).

## Gate 2
- convention-reviewer: APPROVE. Checked: the Package End sections, the format against the UX1a handoff, commit hashes against `git log --oneline master..HEAD`, the test totals against the four reports, the contract state against `contract/STATUS.md` and `contract/VERSION`, and a safety scan (no password, token, id, registration code, team id, username or personal path; the only emails are the three seeded demo logins). Two minor notes: the handoff named `Docs/reports/I5b-5-handoff.md` before it existed (fixed by writing this report before the commit), and the reviewer could not verify that Brian removed `/tmp/ct-derived` (he did, in the session shell with `! rm -rf`, at the Orchestrator's request; the Story A report says so).
- acceptance-reviewer: APPROVE. (12) The top note is word for word; steps 1 to 11 contain no added, dropped or changed word (only the allowed split into bold title, nested bullets and an "Expect:" bullet, and capitalization after the split); steps 9 and 10 are NOT PERFORMED with the prompt's wording. Wording outside the fixed steps differs by design: the sentence that the steps need the local backend (the prompt gives it as an instruction, the handoff states it), and the closing sections, which the prompt only asks to be stated. (9) LocalPackages changed only in `openapi.json` (derived spec, by script) and `DecodingTests.swift` (two fixtures); no generated Swift in the diff. The reviewer could not confirm the derived file byte-matches the script output; `scripts/verify.sh` runs `make-client-spec.sh --check` first and passed, which does confirm it. (14) Nothing under `contract/` or the synced Docs changed after Brian's sync commit cead388; no `.pbxproj`; no `.claude/` path in the file list. (10) No `default:` in any added Swift line. Handoff claims spot-checked against the code (strict flags `ListItem.swift:41-42`, `ItemMapping.swift:62-63`; refresh `BudgetEditorModel.swift:226`, `ListService.swift:247, 272, 288`; 404 mapping `GeneratedClientBudgetRepository.swift:226-231`; candidate rule `BudgetRecipientOptions.swift`; row 3).
- Stuck detector: not triggered.

## Deviations and outside scope
- The API handoff file named by the prompt (`Docs/handoffs/2026-11-13-api-to-ios-and-web-s16-p25.md`) is not in this repo. The prompt allowed asking Brian for its summary; the brief in the prompt carries the same facts, so I did not ask.
- The handoff states that the steps need the local backend, in place of the prompt's instruction wording.

## Not done or partial
- Brian's real-mode check was NOT PERFORMED; no simulator or backend run was possible in this session. Steps 9 and 10 cannot be reproduced by hand and are covered by unit tests only. Brian's real-mode check is the only proof of the on-screen behavior.
- The verification section of this report does not contain its own after-commit output (see above).
