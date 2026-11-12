# I3c-8: Handoff update for the corrected item error behavior (Story F3, docs only)

Branch: feat/i3c-items. Path: docs only, convention review. Gate 1: Docs/epics/I3c-items.md "Fix pass Gate 1" > "F3".

## What changed
Docs/handoffs/2026-11-10-ios-to-brian-i3c.md, updated in place:
- Step 11 of "Brian's real-mode check" rewritten to the exact text of the task (it starts with "(11)", so the rendered list line reads "11. (11) Item errors..."). Steps 1 to 10 and 12 to 15 are unchanged (checked by the reviewer against the diff).
- "What changed": a fix-pass bullet (separate list and detail load errors, the detail screen shows the banner and then a quiet placeholder and spins only while loading, forced pull to refresh for the detail and the items, initial open still cache-first).
- Open risks: the shared `loadError` line removed (fixed); the `.refreshable` audit added (ListDetailView.swift:111 fixed, DashboardView.swift:55 and ChildrenView.swift:86 need no change) with the banked items from the fix-pass reviews; the `ListService.swift` size line updated to about 880 lines.
- Commit list refreshed from `git log --oneline master..HEAD` (ten commits at that point), test totals added (2079 / 212 / 92 / 17), the "Which checks were run" pointer moved to the I3c-7 report, and the section 9 line updated.

## Files
Changed: Docs/handoffs/2026-11-10-ios-to-brian-i3c.md. Added: this report. Deleted: none. No production or test file changed.

## Test arithmetic
2079 (end of F2) + 0 - 0 = 2079; no test added, rewritten or deleted.

## Verification (source: commands I ran)
Before this commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 2079 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.027 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
F2 after-commit (88b3a7b, clean tree, run by me):
```
--- xcodebuild exit status: 0 ---
--- tests: 2079 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.018 seconds.   (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
After this commit: the run is pasted in the final message (commits are never amended).

## Gate 2 (real verdict, written after the review)
- Convention-reviewer: APPROVE, no hard blocks. Verified: only the handoff file changed; step 11 text matches; other steps unchanged; the commit list matches `git log`; totals match the I3c-6 and I3c-7 reports; no machine paths, secrets or ids added. One warning (a stale "about 830 lines" for `ListService.swift`) was fixed before the commit.
- Acceptance review: not required for a docs-only story (CLAUDE.md: acceptance-reviewer on the full path); the acceptance reviewer already checked the F1 and F2 content this handoff describes.

## Deviations, bugs, scope
- No deviation. The doubled "(11)" in the rendered step is literally what the task text specifies.

## Not done or partial
- Real-mode checks 1 to 15 NOT PERFORMED; they need Brian, the local backend and the simulator. Step 11 in its new form is the first check of the fix pass.
- The local scheme edit (`-apiModeOverride real`) is stashed and is restored after the final commit; it is not part of any commit.
