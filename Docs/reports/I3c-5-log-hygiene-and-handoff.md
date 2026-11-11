# I3c-5: Log hygiene scan and the package handoff (Story E)

Branch: feat/i3c-items. Path: solo scope (docs plus a scan test) with both reviewers. Gate 1: Docs/epics/I3c-items.md "Story E".

## What changed
- `LogErrorValueScanTests` (new): scans every `Log*` call in Features/Items and Features/Lists and fails on an interpolation of a raw error value: a path component `error`, `err`, `e`, `ex`, `exception`, `failure` (whole word), an identifier ending in `Error`, or a name bound by `catch let` in the same file. Counts, constants, `operation`, `statusCode`, `errorCode` are allowed. The allowlist starts empty and a completeness test checks its fields. The scanner is proven by 11 positive and 6 negative synthetic forms, multi-line and literal-paren cases, and a test that the scan reaches both folders.
- `LogHygieneScanTests.interpolations(inCallTail:)` changed from `private static` to `static` so the new suite can reuse it (one word; no test weakened).
- Handoff: Docs/handoffs/2026-11-10-ios-to-brian-i3c.md with the exact 15-step "Brian's real-mode check" (compared word by word by the acceptance reviewer), contract issues, commits, API-team asks, legacy bridge, purchases in real mode, open risks, the PROGRAM.md section 9 line, and the checks Brian has run versus NOT PERFORMED (all 15 are NOT PERFORMED).

## Files
Added: ChristmasTrackerTests/Core/Logging/LogErrorValueScanTests.swift; Docs/handoffs/2026-11-10-ios-to-brian-i3c.md; this report.
Changed: ChristmasTrackerTests/Core/Logging/LogHygieneScanTests.swift. Deleted: none. No production file changed.

## Test arithmetic (source: command output and grep of `@Test`)
1973 (end of Story D) + 12 new (LogErrorValueScanTests; two parameterized tests count as one each) + 0 rewritten - 0 deleted = 1985, matches the run. Package 212, release 92, destination 17.

## Violations
- Features/Items and Features/Lists: none (29 Log calls; interpolations are `visible.count`, `fetched.count`, `operation` only). The scan therefore guards against regressions; no production code was changed in this story. Source: grep by the test-writer and the acceptance reviewer, and the passing scan.
- Carried to I4, unchanged (source: my grep, confirmed by the acceptance reviewer for Core/Networking): Features/Purchases/Views/PurchaseHistoryView.swift:175 (`Mock error: \(error)`); Core/Networking/NetworkAPIClient.swift:71, :103, :167 and Core/Networking/MockAPIClient.swift:57. Listed in the handoff.
- Correction recorded: the acceptance reviewer stated Features/Purchases was free of raw-error logging; my grep found PurchaseHistoryView.swift:175. The handoff reflects my grep.

## Verification (source: commands I ran)
Before the commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 1985 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.021 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.021 seconds.
```
After the commit: see the closing block at the end of this file (added in a final docs commit, since commits are never amended). Story D after-commit: no separate run on the clean 2d22686 tree; the run above is 2d22686 plus Story E only (no production change), so it covers it.

## Package end check
`git diff --stat master...HEAD` taken Tue Nov 10 22:24 EST 2026 (five committed commits, before the Story E commit): `101 files changed, 12776 insertions(+), 1809 deletions(-)`. The acceptance reviewer listed the paths and found nothing changed under contract/, .claude/, any .pbxproj, the synced Docs (client-guide, error-codes, DECISIONS, PRD, privacy-matrix), LocalPackages/TrackerAPI, Features/Purchases or Core/Networking. Docs changes are only Docs/epics/I3c-items.md and the Docs/reports/I3c-1 to I3c-4 files. Re-run after the final docs commit: see the closing block.

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warning: a trailing `//` comment or a `//` inside a string ahead of a log call makes the scanner skip that call (the same heuristic as LogHygieneScanTests). Cosmetic: the handoff has no From/To/Contract header block.
- Acceptance-reviewer: APPROVE, no blocking findings. MEDIUM: the handoff omitted the old-stack logging that interpolates a raw error; fixed by the "Log hygiene carried to I4" section (and my own grep added PurchaseHistoryView.swift:175). LOW: the scanner inspects interpolations only (a Log argument built without `\(...)` is not caught; none exists; stated in the handoff); non-Log sinks (`print`, `os_log`, `Logger`) are not scanned and none exist in the two folders; the handoff's "what changed" does not name DashboardView.swift, ChristmasTrackerApp.swift and InertRepositories.swift (not required).
- The step text of the 15 checks matches the task text word by word (leading capitals only).

## Deviations, bugs, scope
- No production code changed. No contract disagreement found. Decision L16 remains unconfirmed in the synced docs (epic D2, handoff).
- Process notes across the package: a Python scratch script and a heredoc in Story A (recorded in the I3c-1 report); `cd` used by implementers and once by me in a survey command (no effect on files).

## Not done or partial
- Real-mode checks 1 to 15 are NOT PERFORMED; they need Brian, the local backend and the simulator.
- No simulator or screenshot verification of any new screen (see the I3c-4 report).
- Banked, not fixed: the items listed under Open risks in the handoff (including the `.notFound` close without a list message, the old-screen UI-rule gaps, ListService.swift size, and the scanner limits above).
- Purchases and Core/Networking raw-error log lines are carried to I4 unchanged.
