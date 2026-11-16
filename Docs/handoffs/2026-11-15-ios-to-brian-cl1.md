# Handoff: iOS to Brian, package CL1 (cleanup after VER1, PH1 and IMG1)

Date: 2026-11-15. Branch: feat/cl1-cleanup (from master at the IMG1 merge, 3654b03). Nothing was pushed.

## Contract issues found
None. No API model, contract file or network behavior was touched.

## What changed (per story, with commit)
- **C1, install link edges** (e75a1bd). `UpdateInstallLink`: the https scheme is matched case-insensitively and the built link always carries lowercase `https://`; an authority with a backslash, whitespace or a control character gives nil. Beyond the literal brief: an itms-services input whose decoded inner URL has an uppercase or mixed-case scheme is now rejected too (it is not the canonical form the type builds). Tests added only; none removed. Report: Docs/reports/CL1-1-install-link.md.
- **C2, a failed version check must not use up the interval** (21b25a7, fix 7f2afc8). `VersionService` keeps a success time and a failure time. After a success the next automatic check waits 15 minutes (unchanged); after a failure it waits at most 60 seconds (`failureRetryInterval`, injectable). A failure clears the earlier success time so the 60 second window governs; a success clears the failure time. Failure still keeps the last policy and never blocks or shows an error; manual Check again always runs. The acceptance review found a regression in my first version (a second request could go out while the launch check was still in flight, because times were recorded only after the await); fixed in a NEW commit 7f2afc8 with a private in-flight flag that makes `checkIfDue()` skip while a check runs (manual `check()` is never gated), and re-approved. Report: Docs/reports/CL1-2-check-interval.md.
- **C3, line lengths** (5b8a7ea). 70 lines over 120 characters that VER1, PH1 and IMG1 added in the listed folders; 64 rewrapped (whitespace and line breaks, plus one `//` comment split in two; a whitespace-stripped comparison of all 31 changed files was identical apart from that comment). 6 remain on purpose (string or regex literals; listed with reasons in the report). 1 added long line outside the listed folders (Authentication test) was not touched. Pre-existing long lines from earlier packages were not touched. Report: Docs/reports/CL1-3-line-lengths.md.
- **C4, split the app composition file: STOPPED** (report only, 56e28be). `ChristmasTrackerApp.swift` is 551 lines and stays so. Reaching 400 needs `AppDependencies` (`makeMock`/`makeReal`/`makeInert`) moved, which would change 5 scan-test files (more than the brief's limit of 4) and would also change what those scans prove. No code changed. Report: Docs/reports/CL1-4-app-file.md (it lists three options).
- **C5, release runbook note** (afd10b3). Docs/release-runbook.md has a new section "Before any App Store submission" naming the `imageMetadata` key path blocker; ad hoc distribution is unaffected. Report: Docs/reports/CL1-5-runbook.md.

## Test counts
- Baseline (Step 0): app 5320 passed, 0 failed, 0 skipped; TrackerAPI package 212 tests in 16 suites.
- After C1: 5326. After C2: 5331. After C3, C4 (no code), C5: 5331. After the C2 fix: 5334. Package suite 212 throughout; release script tests 92, destination script tests 17.
- Final `scripts/verify.sh` (after commit 7f2afc8): `--- tests: 5334 passed, 0 failed, 0 skipped ---`, package `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`.

## EDITED tests (marker `EDITED (CL1-<story>)`)
- `VersionServiceCadenceTests.failedAttemptCounts` (CL1-C2): followed the stated rule change (60 s after a failure no longer blocks; 30 s does).
- `VersionServiceCadenceTests.failedAttemptRetriesAfterInterval` (CL1-C2): comment and marker only.
- `FakeAppVersionChecker` (CL1-C2, in the fix commit): added an off-by-default one-shot `holdFirstCall` gate and `release()` so a test can hold a call open; existing tests unaffected.
- No test was removed or weakened.

## Stories stopped or partly done
- **C4 stopped** (see above); nothing to revert.
- **C2, partial against the brief:** the brief's test "session end resets both times" was NOT written. `VersionService` has no session state and is not a clearable (the policy is pre-auth and VER1 clears nothing on sign-out), so there is nothing to reset. Say so if you want a reset added.

## What the API team must do
Nothing.

## Open risks
- Nothing ran on a simulator or the network; the agents never saw either. C1 to C3 and C5 are covered by unit tests and static review only.
- Known limit in the C2 fix: with two overlapping MANUAL checks, the first to finish clears the in-flight flag while the other still runs, so at most one extra automatic check can go out. The reviewer judged it acceptable; a counter would remove it (two lines).
- C2 behavior change to know: the success time is now recorded when the check finishes (it was the attempt start before). The in-flight flag covers the overlap this opened.
- `ChristmasTrackerApp.swift` stays at 551 lines (over the 400 warning, under the 600 error).
- 6 in-scope long lines remain over 120 (literals), plus 1 outside the folders.
- The hit list for C3 was attributed from the net diff of the three packages, not line-by-line blame; the reviewer did not re-check it line by line.

## Banked items (not done, for later)
- C4 decision: pick option 1, 2 or 3 from Docs/reports/CL1-4-app-file.md (about 5 scan-test files would follow a move of `AppDependencies`).
- Session-end reset for `VersionService`, only if you want one.
- In-flight counter instead of a flag (overlapping manual checks).
- Out-of-scope items from the brief stay open: ListService.swift split, window-level cover for sheets over the update screen, Delivered status dot color, unused `budgetWarning` token and dark-mode Gifted pill edge, PH1 reload-on-return.

## PROGRAM.md section 9 line
CL1 (cleanup after VER1, PH1, IMG1) on feat/cl1-cleanup: install link edges tightened (C1), failed version check retries within 60 seconds with an in-flight guard (C2), long lines wrapped (C3), App Store blocker noted in the runbook (C5); C4 (app file split) stopped by its own rule and awaits your decision; 5334 app and 212 package tests green; nothing pushed.

## Package-end diff
`git diff --name-only master...HEAD` (before this handoff commit) lists only app and test sources under ChristmasTracker/, Docs/epics/CL1-cleanup.md, Docs/release-runbook.md and Docs/reports/CL1-*.md: nothing under contract/, LocalPackages/, any `.pbxproj`, the synced Docs files, or the dot-folders. Re-run after the final commit; the result is in the final message.

## Brian's real-mode check
1. **Launch in mock mode.**
   - Debug build with `-apiModeOverride mock`.
   - Expect: the app opens, you can sign in and use the tabs as before.
2. **Update screens still work.**
   - Launch with `-mockVersionState required`, then `recommended`, then `requiredNoLink`.
   - Expect: the same screens as before (VER1 checks 1, 4 and 5). An uppercase `HTTPS://` manifest from the server now builds the same Install link as a lowercase one.
3. **Real mode starts.**
   - `-apiModeOverride real` against the local API, sign in.
   - Expect: lists, Statistics and Purchase History open as before.
4. **Offline then online (optional).**
   - Launch real mode with the network off, then turn it on and bring the app to the foreground after one minute.
   - Expect: no update screen appears; the next check runs without waiting 15 minutes. This is not visible on screen; the cadence tests are the proof, so this step is optional.
5. **Add item with a link.**
   - Add Item with a product URL (IMG1 behavior).
   - Expect: unchanged from IMG1.

Which checks Brian ran: NOT PERFORMED yet (to be filled in by Brian). The agents never saw the simulator or the network.

## Commits (git log --oneline master..HEAD, before this handoff commit)
```
7f2afc8 CL1: stop a second version check while one is in flight
afd10b3 CL1: note the App Store blocker in the release runbook
56e28be CL1: report that the app file split was stopped
5b8a7ea CL1: wrap lines over 120 characters
21b25a7 CL1: let a failed version check retry sooner
e75a1bd CL1: tighten the update install link
89c489e CL1: add epic brief and inventory
```
