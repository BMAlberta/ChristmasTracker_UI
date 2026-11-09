# I6b-1b K2 — The missing report corrections, Gate 2 verdicts, and not-run list

Package I6b-1b, story K2 (docs only). Branch `fix/i6b1b-release-lookups`. Pipeline: solo implementer (the Orchestrator's edits were docs only), then convention-reviewer, then acceptance-reviewer, strictly one after the other.

## What changed

| File | Change |
|------|--------|
| `Docs/reports/I6b1-1-script-core.md` | First line "Corrected in the I6b-1 fix passes."; new "Gate 2" section with real verdicts and focus-list answers (file and line evidence on the FINAL script); "Not done or partial" now lists what was NOT RUN instead of "None". |
| `Docs/reports/I6b1-3-signing-and-fixes.md` | "Not done or partial: None" replaced by the same not-run list; Gate 2 file and line evidence added; the two statements that are no longer true of the final script are marked as superseded. |
| `Docs/handoffs/2026-11-06-ios-to-brian-i6b1.md` | Removed the "grep/PlistBuddy" statement (the script uses `plutil -extract`, `release.sh:419-483`); added "Not run by the agents"; added the full commit list (`git log --oneline master..HEAD` plus the six earlier merged commits); added the fixture, anchored lookups, export discovery and `policy:set` recipe to "What changed"; test count 92; unverified-assumptions list corrected (identity check now cited at line 495); added "Open risks" including the pre-existing raw `CODE_SIGN_IDENTITY` echo (`release.sh:327`). |
| `Docs/reports/I6b1-5-anchored-lookups-fixture-and-recipe.md` | (K1 report, edited under the sanitization procedure below, not by the K2 docs commit's own scope.) |

No script, test, fixture, or runbook file is changed by the K2 commit.

## Gate 2

**convention-reviewer — PASS** on both the K2 diff and the final `scripts/release.sh` / `scripts/test-release.sh`. Checklist with file and line evidence is recorded in `I6b1-1-script-core.md`, "Gate 2". No blocking findings. Informational: the fixture still contained a DerivedData folder name derived from this Mac's project path (fixed, see the process finding); `release.sh:327` echoes the raw `CODE_SIGN_IDENTITY` on a mismatch (known, in the handoff's open risks).

**acceptance-reviewer — PASS**, with one required correction: the handoff's commit list named the K1 commit by a hash that changed when Brian amended the commit (now `dc13ca8`). Corrected. Its R1 and G1 focus-list answers (with file and line evidence on the final script) are recorded in `I6b1-1-script-core.md` and `I6b1-3-signing-and-fixes.md`. It also noted two statements in the I6b1-3 "What Changed" row that are no longer true of the final script (`cmd_export` now finds the single exported IPA; `cmd_install_info` prints the confirmed recipe again); both are marked superseded in that report.

Stuck-detector log: convention review 1 run, acceptance review 1 run, no rejections, no repeated error signature.

## Process finding: the first sanitization was a subset

The K1 fixture sanitization (see `I6b1-5-...`, "Fixture sanitization") replaced a list of known values (team id, username, `/var/folders` hash, device identifier). All later checks were value-based searches for those same values, so they could not find a per-user value that was never on the list. The K2 convention reviewer noticed the Xcode DerivedData folder name (a hash derived from this Mac's project path) in the fixture. The K1 commit therefore briefly held it in local history (never pushed).

Handling, per Brian's instructions: the working tree was sanitized without committing; a pattern-based scan was run; Brian amended the K1 commit himself (the old commit is now unreachable from the branch; K1 is `dc13ca8`); the scan was re-run over the amended branch.

The permanent check is the PATTERN-BASED scan, over every file in `git diff --name-only master...HEAD` plus modified and untracked files, and over `git log -p master..HEAD` after any history change:
- DerivedData paths; `/var/folders/<x>/<hash>` paths; `/Users/<name>` paths;
- lowercase-letter tokens of 28 or more characters; hex tokens of 16 or more (and 32 or more) characters; 36-character UUID-looking tokens;
- the words "Provisioning Profiles" followed by a file name.

Replacements made in the fixture (same line structure, 56 lines touched): the DerivedData folder name (54 lines), `PROJECT_GUID` (line 447) and the hash inside `SDK_STAT_CACHE_PATH` (line 486); the last two are not present in the committed project file, so they may be machine- or path-derived. In the K1 report, the first two characters of the real `/var/folders` per-user prefix (a real path fragment) were generalized to `<xx>` in two places.

Scan results (matched text shown as [value] where it is not a plain placeholder), working tree before the amend and `git log -p` after it:
- DerivedData: only `ChristmasTracker-fakehash...` and generic cache folders (`ModuleCache.noindex`, `CompilationCache.noindex`, `SDKStatCaches.noindex`).
- `/var/folders`: only `/var/folders/xx/FAKEFOLDERHASH...` and prose.
- `/Users/`: only `/Users/test`.
- Long hex and UUID-looking tokens: only placeholders (`0000...`, `fake...`) and `scripts/test-release.sh:484` (`abc123def456...`, a test value); in the full history, only commit hashes.
- "Provisioning Profiles": only the generic folder name in prose and tests (`TestAdHocProfile.mobileprovision`).
- A check for the specific real values (team id, per-user folder hash, DerivedData hash, hardware identifiers) in the changed files and the branch history found none, with one pre-existing exception below.

Open item for Brian, not changed by this package: the Apple team id appears in `Docs/epics/I6b1-release-script.md` (lines 45, 61, 114). It is already on `master` (the same file, three occurrences) and in the committed project file, so this branch did not add it. Line 114 of that file says the team id is already in the project. If it should be removed from the epic, that is a separate edit.

## Observation (not changed)

`Docs/reports/I6b1-2-runbook-and-handoff.md` (R2) also ends with "Not done or partial: None." and cites the R1 test count. It was outside the K2 scope. The runbook and handoff it describes have since been corrected; consider the same one-line fix there.

## Not done or partial

NOT RUN by the agents (stubs and fixtures only): `xcodebuild archive`, `xcodebuild -exportArchive`, the upload and any `aws` command, the real certificate lookup in a keychain (`security find-identity`), the real profile lookup in `~/Library/MobileDevice/Provisioning Profiles`, signing (`codesign` against a real identity), any on-device install, and `policy:set` in either form. The only real xcodebuild call in the package was the read-only `-showBuildSettings` capture behind the fixture.

Partial: the K2 post-commit `scripts/verify.sh` output cannot be inside the commit it measures; it is given in the final message of the session. The Gate 2 reviewers reviewed the K2 diff before this report file existed; the report itself was written afterward from their verdicts.

## Post-commit verification (K1 commit `dc13ca8`, after Brian's amend)

Raw summary of `scripts/verify.sh` run on 2026-11-09 on the amended branch (K2 files modified in the working tree, K1 commit as HEAD):

```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
  Test run with 191 tests in 13 suites passed after 0.014 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

`scripts/test-release.sh` standalone after the amend: `=== test-release.sh: 92 passed, 0 failed ===`.

The earlier post-commit run on the pre-amend commit (`1fb3285`, now unreachable) had the same summary.
