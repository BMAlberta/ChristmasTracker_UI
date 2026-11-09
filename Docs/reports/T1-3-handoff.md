# T1-3 — Package handoff (docs only)

**Date:** 2026-11-09 · **Branch:** `chore/xcode-27-test-settings` · **Toolchain:** Xcode 27.2 (27B52)

## What changed

Files added (docs only):
- `Docs/handoffs/2026-11-09-ios-to-brian-t1.md` — the package handoff per CLAUDE.md: contract issues (none), what changed,
  commit hashes with subjects, exact Xcode and simulator versions, Brian's build-setting change, Xcode 27 notes, what was
  not run, open risks, nothing for the API team, and one line for section 9 of PROGRAM.md.
- `Docs/reports/T1-3-handoff.md` — this report.

No code, script, or setting changed in this story.

## Verification

Each claim says whether it came from running a command (RAN) or reading files (READ).

- RAN: `scripts/verify.sh` after the T1B commit `548f277` and before this story's commit (no `DEST`, automatic
  destination, iOS 27.2). This is the after-commit run that the T1-1 and T1-2 reports defer to this file.
  Headings and summary lines (per-test lines trimmed with grep); exit status 0:

```
=== verify: derived spec ===
=== verify: build ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.017 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

- READ: handoff facts were compared with `git log --oneline master..HEAD`, `git diff --stat master...HEAD`, the epic, and
  the T1-1 and T1-2 reports by the acceptance-reviewer.
- Verify after this story's commit: this story adds only two Markdown files, so the tree that `verify.sh` checks is the one
  verified above. The final `git diff --stat master...HEAD` taken after the commit is in the Orchestrator's closing message.

## Test arithmetic

App tests 677 + 0 - 0 = 677. Package tests 191 unchanged. Release script tests 62 unchanged. Destination script tests 17
(added in T1B). This story adds no tests.

## Gate 2

- convention-reviewer: APPROVE, no hard blocks, one minor warning. Evidence: `git status --short` showed only the new
  handoff file; `git log --oneline master..HEAD` matched the four listed commits; `git diff --stat master...HEAD` (19 files)
  matched the claims, with `project.pbxproj` +3 lines being Brian's setting commit; required CLAUDE.md "Package end" items
  present; no secrets, tokens, `DispatchQueue`, or Combine words. Warnings: the Contract line does not repeat STATUS.md,
  backend commit, or decisions revision (optional polish); the branch name is not `feat/` or `fix/` (disclosed in Open risks).
- acceptance-reviewer: APPROVE, two non-blocking notes. Verified: commits, no change under `contract/`, synced Docs, or
  production source (only `project.pbxproj` +3), 15 converted actors (15 added `@MainActor` lines, 15 removed `actor`
  lines), 34 diagnostics, 3 Family C sites, 3 Family A types, the destination script behavior, versions, totals
  (677, 191, 62, 17), a complete and true "not run" list.
  Note 1: the handoff's verification block was labelled as run after `548f277` but no report on disk recorded that run.
  Resolution: the run was made (RAN above) and its raw output is recorded in this report. Note 2: the real simctl path was
  exercised only read-only by hand plus the full verify run; the 17 tests are stub-only (already implied in Open risks).
- Rejections and re-reviews: none. Stuck detector: 1 attempt, no repeated error signature.

## Deviations, bugs, scope

- Both reviewers ran on the handoff before this report existed, so this report records their real verdicts afterwards.
- The reviewers' note 1 was resolved by recording the raw run here instead of changing the handoff wording.
- No real bugs found. Nothing outside Docs/handoffs and Docs/reports was touched in this story.

## Not done or partial

- The reviewers did not review this report file itself (it records their verdicts); the Orchestrator re-read it against the
  handoff and the earlier reports before committing.
- `ChristmasTrackerUITests`, device runs, archive and export, and `scripts/release.sh` were not run (see the handoff).
- Nothing was pushed, as required.
