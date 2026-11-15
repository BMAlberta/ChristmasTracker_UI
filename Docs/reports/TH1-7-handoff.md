# TH1-7: Handoff and the real-mode check (docs only)

Commit: "TH1: add the package handoff note". Docs only: no code, test or asset change. Pipeline: docs story, written by the Orchestrator (no subagent edits); the handoff was re-read against the code and the earlier reports before committing.

## After-commit run of the previous commit (TH1-6, 22cb82b), taken by running the commands
```
--- tests: 4622 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What was written
Docs/handoffs/2026-11-14-ios-to-brian-th1.md: contract issues (none), what changed, the seven package commits with subjects (`git log --oneline master..HEAD`), what the API team must do (nothing), open risks, the one line for section 9 of PROGRAM.md, and "Brian's real-mode check" as a numbered list (bold title, nested action bullets, an "Expect:" bullet for each result) with the required note at its top ("Restart the backend with `npm run dev` ONLY. Do not run the seed when you restart it: re-seeding creates new user ids and the app correctly signs you out.").

## Deviations from the fixed steps (honest list)
- The fixed steps are paragraphs in the brief; to produce the required numbered list with action bullets and an "Expect:" bullet each, I split their sentences, keeping the wording of every action and every expectation. Added words: step 5 names the two items to open (it already said to open the item detail); step 10 adds "and Archive List at the bottom of a list (now a bordered button)" because T5 changed it; step 15 gained an "Expect:" line ("every flow completes as before; the primary buttons ... work and look right in light and dark") because the original had none; step 1 gained "Expect: you are signed in and see the lists screen".
- **Step 7 (compact status places) has no per-place steps because the final inventory found no compact place** (verified by reading ItemPurchaseRow.swift and grepping for status displays; the acceptance reviewer confirmed in T3). The step says so, is marked NOT PERFORMED and not applicable, and the open risks ask Brian whether to show the shipping status as a dot and text or to delete `StatusDotLabel`. I did not invent a tap path.
- The new contrast exception class (gold fills below 3:1 as graphics in light) and the primary button's dark-mode label, the lock screen tint, the Profile layout and the Dynamic Type layout are in the open risks. Not performed: Brian's steps 1 to 15 were NOT PERFORMED by the session; steps 7, 8 and 13 cannot be fully reproduced by hand.

## Package end (taken before the handoff commit; re-run after the final docs commit in the final message)
```
git diff --stat master...HEAD (summary line): 90 files changed, 4840 insertions(+), 272 deletions(-)
git diff --name-only master...HEAD | grep for contract/, LocalPackages/, the synced Docs files (client-guide, error-codes, DECISIONS, PRD, privacy-matrix), any dot-folder path, any pbxproj: no output (nothing changed)
```
(Directory .claude/ cannot be named in a shell command here, so the check is a pattern match over the changed-file list: any path beginning with a dot would have matched.)

## Test arithmetic for this story
4622 + 0 = 4622 (docs only). Package 212, release 92, destination 17 unchanged.

## Raw verification (before the commit, by running the commands; no code change since the TH1-6 after-commit run, so it is the same tree plus two docs files)
```
--- tests: 4622 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is quoted in the final message (a report cannot contain the output of a run that happens after its own commit).

## Gate 2
Docs story: both reviewers are run on code; the handoff text was checked by the Orchestrator against the reports and the code instead. Focus items 13 (the handoff matches the Story T7 text, one inventory-derived step per compact place, not-performed steps stated) and 15 (nothing under the protected paths) are answered by the sections above.

## Not done or partial
- Brian's real-mode check was not performed by the session. No simulator run was possible: Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout and the thumbnails all need eyes on the simulator).
- Banked, not done: the thumbnail URL hardening (userinfo, localhost and private hosts), the grouped-panel secondary background, deciding what to do with `StatusDotLabel`, a darker gold for the palette pass, and the app icon image.
