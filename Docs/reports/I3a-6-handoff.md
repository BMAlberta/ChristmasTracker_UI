# I3a-6: Real-mode check and handoff (docs only)

Branch feat/i3a-lists. Gate 1: Docs/epics/I3a-lists.md (L4). Path: docs only.

## What changed
- Added Docs/handoffs/2026-11-09-ios-to-brian-i3a.md (contract issues: none; what changed; commits from `git log --oneline master..HEAD`; what the API team must do: nothing; open risks and deferred items; the section "Brian's real-mode check" with the 13 steps; one line for PROGRAM.md section 9).
- Added this report. No code, tests, scripts, contract or synced Docs were touched in this story.

## Files
Added: Docs/handoffs/2026-11-09-ios-to-brian-i3a.md; Docs/reports/I3a-6-handoff.md. Changed: none. Deleted: none.

## Handoff text check (read against the L4 brief)
- The 13 steps were transcribed from the L4 text; the seeded users, the `-apiModeOverride real` argument, the JWT_EXPIRY and `user:set-active` commands appear as written. No password, id or registration code is written anywhere in the repo. (Verified by reading; the handoff contains only the seeded email addresses given in the L4 text.)
- States that items, members, children, co-owner changes, leaving a list and purchases are out of scope, and says which checks were run: none; all 13 are NOT PERFORMED (they need Brian and the local backend).
- Commit list taken with `git log --oneline master..HEAD` before this commit; it will gain the L4 commit.
- Numbers quoted in the handoff: app 677 -> 946 (+269), package 191 -> 212 (+21), matching the story reports.

## Raw outputs
No code changed in this story, so the state is that of commit de81bd0 (L3). Commands run by the Orchestrator at that state (before this commit), summary lines:
```
Test run with 212 tests in 16 suites passed after 0.017 seconds.
--- tests: 946 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Test arithmetic: unchanged by this story (946 app, 212 package).

## Package end checks (taken 2026-11-09 20:16 UTC, before the L4 commit; re-run after it in the final summary)
- `git diff --stat master...HEAD | tail -3`: `72 files changed, 9472 insertions(+), 1842 deletions(-)`. That total includes Brian's sync commit 557b69c (contract/VERSION, contract/openapi.json, STATUS.md and the synced Docs files).
- `git diff --stat 557b69c...HEAD -- contract Docs/client-guide.md Docs/error-codes.md Docs/DECISIONS.md Docs/PRD.md Docs/privacy-matrix.md ChristmasTracker/ChristmasTracker.xcodeproj`: empty output, i.e. nothing under contract/, the synced Docs files or the Xcode project changed after the sync commit.
- `git diff --name-only master...HEAD` filtered for the hidden agent-configuration directory and for `pbxproj`: 0 files each. (A guard hook refuses commands that spell the hidden directory's path, so it was checked by pattern.)
- `git diff --stat master...HEAD -- LocalPackages`: `9 files changed, 638 insertions(+), 18 deletions(-)`: Sources: Middleware/RateLimitMiddleware.swift (H2), TrackerAPIError.swift (H1 classification), openapi.json (H1 regeneration); Tests: DecodingTests, DefaultSleeperTests, OperationResponseTests, RateLimitRetryAfterSafetyTests, SessionEndingMiddlewareTests, TrackerAPIErrorTests. That is within what H1 and H2 allow.

## Gate 2
- Convention-reviewer: APPROVED. It could not diff the 13 steps against the brief, because the exact step text exists only in the Orchestrator's session instructions, not on disk (the epic's L4 section is a scope note). The Orchestrator transcribed the steps from those instructions when writing the handoff; this is a reading-based claim, not a command result. Minor notes taken: the Gate 2 text of this report (updated here) and the commit list gaining one line.
- Acceptance-reviewer: APPROVED. It verified the commit list, the test arithmetic (677 -> 946, 191 -> 212), and every open-risk claim against the code (silent mock fallback at ChristmasTrackerApp.swift lines 158 to 171 and 257 to 262, no callers of the legacy `make()`, the L1 placeholder only in commit 1e0d86c, ItemService.swift:99, ItemRow styling, DesignSystem raw styling) and found the 13 steps internally consistent with the app (`-apiModeOverride` exists and works in Debug; the privacy expectations agree with Docs/privacy-matrix.md; the duplicate message and delete flow match step 10). Two small inaccuracies it found were corrected in the handoff: `ListError.sessionEnded` is used by CreateListView for the no-signed-in-user message (the repository and service never produce it), and the dashboard also uses `EmptyStateView`. It also suggested notes (line cites; the Debug-only caveat for step 2; the zero-item no-progress caveat), added to the handoff as a note after the steps without changing the 13 steps.
- Rejections: none. Stuck-detector log: no retries.

## Deviations, bugs, scope
- None beyond those recorded in the earlier reports and the handoff.

## Not done or partial
- The 13 steps could not be machine-compared with the brief (no on-disk source); they were transcribed by the Orchestrator and checked for consistency by the reviewers.
- The 13-step real-mode check is Brian's and was not performed. No real server or backend was used at any point in this package.
- The L3 screens have never been seen running (simulator check not performed by any agent).
- Final package-end `git diff --stat` re-run after this commit is in the Orchestrator's final summary, not in this file (a file cannot contain the stat of the commit that adds it).
