# I3b-2 R4: contract-issue row and the combined handoff (docs only)
Date: 2026-11-10. Branch: feat/i3b-members-children. Weight: docs only, solo; no code, no tests.

## What changed
- `Docs/contract-issues.md`: row 2 marked Resolved ("fixed in cf6b90c (L15), synced at cf6b90c59b4c641e54e5e2b08fcc9521db831c8f, the backend commit in `contract/VERSION`; iOS clears the co-owner through DELETE /lists/{id}/co-owner (removeCoOwner)"). Only the status cell of row 2 changed; the header and the row format are kept.
- `Docs/handoffs/2026-11-09-ios-to-brian-i3b.md`, updated in place: title, date and contract line (revision 28 sync, sha256 prefix); the commit list (`git log --oneline master..HEAD`, run 2026-11-10); the contract-issue and API-team statements (clearing is now done through `removeCoOwner`); a "What changed" bullet for I3b-2; test totals (1415 -> 1497 app, 212 package); a new open-risk bullet for the unverified Remove flow; step 7 rewritten as specified; steps 14 and 15 appended after step 13 with the specified wording; the closing notes and the step counts (13 -> 15); the section 9 line covering both packages. Steps 1 to 6 and 8 to 13 are untouched.
- `Docs/handoffs/2026-11-10-ios-to-brian-i3b2.md`: new short handoff (what changed, commits, no new contract issues, points to the I3b handoff for the check; steps not duplicated).
- `Docs/reports/I3b2-4-handoff.md`: this report. Files deleted: none; no code or test files changed.

## Commands and raw output (commands ran)
`git log --oneline master..HEAD` (taken 2026-11-10 before this commit), verbatim:
```
ef27275 I3b-2: add the Remove co-owner action to the edit screen
aedc89d I3b-2: remove a co-owner through the new operation and update the list from the response
7f0039b I3b-2: regenerate the client from contract revision 28
bc5657a I3b-2: add epic brief and inventory
ce80457 chore: sync the contract at cf6b90c
0b32e4b I3b-fix: add the guard fix report
6059163 I3b-fix: filter only loads that started before a removal completed
5085d7b I3b-fix: add fix pass Gate 1 spec
cfaa81c I3b: add the package handoff note
3e1954a I3b: add the members section, co-owner control, children screen, and child recipient picker
47bd3e6 I3b: add the generated member and child repositories and session-safe services
6614f25 I3b: add member and child models, errors, and the flag-driven view-state rules
2d4baec I3b: never fall back to mock in real mode, guard against resurrecting deleted lists, and clean up loading state and logs
8d312d2 I3b: add epic brief and inventory
```
Before the commit, `scripts/verify.sh` summary lines (command ran, with this story's docs changes in the tree):
```
=== verify: unit tests ===
--- tests: 1497 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Before the commit, `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`
The after-commit runs and the package-end diff are in the final summary of the session (a report committed in this commit cannot contain a run taken after it).

## Test arithmetic
No tests added, rewritten or deleted. App 1497 + 0 = 1497; package 212 + 0 = 212. The totals written into the handoff (1415 -> 1497: +49 net in R2 [52 new - 3 deleted], +33 in R3) match the R2 and R3 reports.

## Gate 2
Both reviewers ran after the docs were written, one after the other, read-only, and ran no builds or tests.
- convention-reviewer: APPROVE. Only four docs paths changed; nothing under `.claude/`, `contract/`, any `.pbxproj`, `LocalPackages/TrackerAPI`, any Swift file or the synced Docs files; the row 2 diff changes only its status cell and matches `contract/VERSION`; the commit list matches `git log --oneline master..HEAD` exactly; CLAUDE.md "Package end" conformance fine (the section 9 line lives in the combined handoff, which the new short handoff points to); no secrets, real paths or non-example.com emails. It raised two warnings about this report (dangling forward references, and a paraphrased `git log` instead of raw output); both are fixed in this version.
- acceptance-reviewer: APPROVE. (a) row 2 and the L15 facts match `contract/VERSION` and `Docs/DECISIONS.md:252`; (b) steps 1-6 and 8-13 unchanged and in order, step 7 rewritten and steps 14 and 15 appended with the specified wording, test arithmetic 1415 + 52 - 3 = 1464 and 1464 + 33 = 1497 agree with the R2 and R3 reports, section 9 covers both packages; no stale "clearing is blocked" statement (the remaining mentions of `clearingSupported` and "hidden" are history or say it was removed); (c) the short handoff does not duplicate the steps; (d) this report is accurate. It also read `EditListView.swift` and confirmed the handoff's claims about the screen (button and dialog, gated by `showsRemove`, no dismiss on success, dismiss only on notFound/archived, retry re-runs the removal). Items (9) and (10): no code changed and nothing out of scope was touched.
- Rejections: none. Stuck detector: not triggered.

## Deviations
- The handoff's commit list names only the four I3b-2 hashes plus the earlier I3b hashes; the final docs commit cannot name its own hash (stated in the handoff).
- The handoff's "Server did" column of row 2 is left as originally filed (history); only the status cell records the resolution.

## Not done or partial
- The 15-step real-mode check is not performed (needs Brian with the local backend). No agent ran any app screen on a simulator or device.
- PROGRAM.md was not touched (Brian updates it from section 9 of the handoff).
