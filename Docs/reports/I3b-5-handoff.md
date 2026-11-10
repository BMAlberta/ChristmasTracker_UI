# I3b-5: Real-mode check and handoff (story M4, docs only)
Date: 2026-11-09. Branch feat/i3b-members-children. Path: docs only; both reviewers still ran (convention-reviewer and acceptance-reviewer), one after the other.

## Previous commit (M3, 3e1954a), after (source: command run, grep-filtered summary lines of the full stream)
```
** BUILD SUCCEEDED **
--- tests: 1399 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

## What was written
- `Docs/handoffs/2026-11-09-ios-to-brian-i3b.md`: contract issues (row 2: the generated client cannot send `coOwnerEmail: null`), commits (`git log --oneline master..HEAD`), what changed, what the API team must do, open risks, one line for PROGRAM.md section 9, and the section "Brian's real-mode check" with exactly the 13 steps of the M4 text (step 1 to 13, same wording; the agent's notes sit after the steps). The check says that items, purchases, stats, and budgets are not part of this package, and that all 13 steps are NOT PERFORMED (no agent ran any of them).
- This report.
No code, test, contract, `.claude/`, `.pbxproj`, synced Docs, or `LocalPackages/TrackerAPI` file was touched in this story.

## Findings made while writing the handoff (for Brian's decision)
- **Step 9 of the real-mode check will probably fail on its last clause.** A left list id stays in the session-local deleted-ids guard (K0) for the rest of that session, and existing tests (`ListServiceMemberTests`, "a later refresh does not resurrect a left list") pin that behavior. When john re-adds mike after mike left B, B will not come back for mike until mike signs out and in. The cheap fix (a list-of-lists load that starts after the mark clears it and shows a list the server returns non-archived) requires rewriting those existing tests, which the rules forbid doing silently, so it was NOT made. It is written in the handoff (open risks and the notes after the 13 steps) as a decision for Brian.
- The 13 steps carry seeded-user expectations (who holds which list, that Tommy is john's child, that Jane is co-owner of B) that no agent could check against the backend seed.

## Verification (source: command run, grep-filtered summary lines; no code changed in this story)
Before the M4 commit:
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 1399 passed, 0 failed, 0 skipped ---
check-package-imports: OK
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`
After the commit: the post-commit run and the final `git diff --stat master...HEAD` are reported in the final message of the session (a commit cannot contain its own post-commit output and amending is forbidden).

### Protected-path check (taken before the M4 commit, 2026-11-09, source: command run)
`git diff --name-only master...HEAD` filtered for contract/, LocalPackages/, any hidden top-level directory, any `.pbxproj`, and the synced Docs files (client-guide, error-codes, DECISIONS, PRD, privacy-matrix) printed nothing. The only Docs files in the package diff are `Docs/contract-issues.md`, `Docs/epics/I3b-members-children.md`, the reports, and (with this commit) the handoff.
`git diff --stat master...HEAD` summary line before this commit: `106 files changed, 11919 insertions(+), 193 deletions(-)`.

## Test arithmetic (package total)
App suite: 946 (start) + 64 (K0) + 157 (M1) + 185 (M2) + 47 (M3) + 0 (M4) = 1399, minus 0 deleted, rewritten tests named in the per-story reports (15 in K0 including `failedUpdateKeepsState`, 1 in M3). Package suite: 212 + 0 = 212. Release-script 92, destination-script 17 (unchanged). Reconciled against the runner totals after every story (1010, 1167, 1352, 1399), not against a per-test listing.

## Gate 2
- Convention-reviewer: APPROVED (docs only). It compared the 13 steps word for word against the task text, checked the commit list against `git log --oneline master..HEAD`, grepped both files for machine paths, passwords, hashes, ids and the banned word (none), and verified claims against code (the deleted-ids guard at `ListService.swift` lines 50, 466, 483, 508 and the pinning test `leaveListGuardsLaterRefresh`). Observation 1 (this section was a placeholder) is fixed by this text. Observation 2 (a pointer inconsistency) was a misread: the top section of this report IS the post-M3-commit run that `I3b-4-screens.md` points to.
- Acceptance-reviewer: APPROVED (docs only). It re-read the code for focus items 1 to 13 and found the handoff honest: nothing overstated (no simulator or backend run is claimed), the step 9 limitation is accurate and not fixing it was reasonable (the fix rewrites an existing test), and the protected-path check is clean. Its minor findings are applied: the handoff now also lists the reviewed-by-reading-only items (Dynamic Type, VoiceOver actions, the simultaneous edit-sheet dismissal and detail pop, member-call 404 with an empty body), Leave shown outside the roster card, and Delete list disabled while mutating.
- No rejection and no stuck-detector event in this story.

## Deviations, bugs, scope
- None beyond those in the earlier reports and the step 9 finding above.

## Not done or partial
- The 13-step real-mode check: NOT PERFORMED (needs Brian, the backend, and the simulator). No new screen was run by any agent.
- The step 9 limitation (a left list stays hidden for the session) is documented, not fixed.
- Clearing a co-owner is blocked by contract-issues row 2.
