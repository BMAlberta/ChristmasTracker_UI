# I4c-5: Tidy stale comments, handoff and the real-mode check (Story D)

Date: 2026-11-13. Branch: feat/i4c-clear-tracking. Pipeline: Gate 1 in Docs/epics/I4c-clear-tracking.md ("Gate 1: Story D"); no test-writer (nothing to test, comments only); implementer for the comment edits; convention-reviewer, then acceptance-reviewer. No UI change, so the SwiftUI skill and a visual check do not apply.

## After-commit run for the previous commit (2539c2a, Story C), came from running `scripts/verify.sh` on the committed tree
`Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3241 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.018 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.

## Files
- Added: Docs/handoffs/2026-11-13-ios-to-brian-i4c.md, this report.
- Changed (comments only), all under ChristmasTracker/ChristmasTrackerTests: App/BootstrapSourceScanTests.swift, Features/Authentication/SessionTeardownTests.swift, Features/Items/DeletedLegacyNamesScanTests.swift, Features/Lists/ListSourceScanTests.swift, Features/Purchases/PurchaseSourceScanTests.swift, Features/Purchases/RecordPurchaseErrorTests.swift, Features/Purchases/RecordPurchaseViewScanTests.swift.
- Deleted: none. Nothing under contract/, .claude/, any .pbxproj, the synced Docs files, production code or LocalPackages/TrackerAPI changed in this story.

## Exactly which lines changed (came from reading `git diff -U0`; I also grepped the diff for non-comment changed lines and found none)
- ListSourceScanTests.swift:15-16: "(GiftItem.swift, ItemDetailView, PurchaseDetailView)" now says GiftItem.swift and the old PurchaseDetailView were deleted in I4b.
- SessionTeardownTests.swift:44: "(legacy GiftItem) so this file no longer touches the legacy type" became "(the old GiftItem type, deleted in I4b) so this file does not use it". Line 107: added "(deleted in I4b)" after MockItemData.
- PurchaseSourceScanTests.swift:6-8: the header says the legacy repository files, Views and Components were deleted in I4b and the exclusion entry is kept harmlessly. Line 31: new comment above `legacyFiles` that the entries name deleted files and are kept harmlessly (entries unchanged).
- RecordPurchaseViewScanTests.swift:7-8: the legacy views "were deleted in I4b and are not in this set".
- BootstrapSourceScanTests.swift:106: new comment above the regex that `MockAPIClient` was deleted in I4b and the alternative is kept harmlessly (the pattern string is unchanged).
- RecordPurchaseErrorTests.swift:12: "Fails today because PurchaseError does not exist yet" became "These tests pin the PurchaseError messages and flags described above."
- DeletedLegacyNamesScanTests.swift:21: "the inventory has not decided it" became "deleted in I4b; it is not in the scan list".
Count: 7 files, 12 changed lines in total (11 insertions and 6 deletions counted by the implementer from the `-U0` diff, `git diff --stat` says 13 insertions and 9 deletions with the wrapped lines; either way every one is a `//` line).
Other "Fails today" headers: this package reworded them only in the new tests it wrote and in nine files it touched in Stories A to C (comment-only edits, reported there). About 50 older test files (51 counted by the convention reviewer's grep across the test target) still carry a mechanical "Fails today" header; I left them because they are far outside the brief's list (stale wording only, no behavior).

## The handoff
Docs/handoffs/2026-11-13-ios-to-brian-i4c.md contains: contract issues (none), what changed, commits (compared against `git log --oneline master..HEAD`), what the API team must do (nothing), open risks, a section "Brian's real-mode check" with the nine steps copied from the prompt file (both reviewers compared each step word for word; the only difference is a list-number prefix), what was not part of the package, the performed and NOT PERFORMED checks (all nine real-mode steps are NOT PERFORMED, with a blank for Brian's results), and the one line for section 9 of PROGRAM.md. No password, token, id, registration code, machine path or username is in it (only localhost:3010 and the seeded example.com addresses the prompt names).

## Commands and raw output before the commit (came from running commands)
`scripts/verify.sh`: `Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3241 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.021 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===` (the package suite is inside verify.sh). The implementer's `scripts/test.sh` also gave 3241 passed.
The after-commit run for THIS commit is recorded in the final message of the package and the package-end section below.

## Test arithmetic
App: 3241 + 0 new - 0 deleted - 0 rewritten = 3241 (verify.sh says 3241 passed). Package: 212 + 0 = 212. Release 92, destination 17.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE. Every changed Swift line is a comment; no code, literal, pattern or assertion changed; DispatchQueue appears in no changed file; the handoff has all required parts and its commit list matches git log. Nits: (1) the handoff's count of leftover "Fails today" files was 46, the grep says 51: fixed ("about 50, 51 counted"); (2) the heading "Checks Brian ran and checks NOT PERFORMED" was misleading: renamed "Checks performed and checks NOT PERFORMED"; (3) the handoff cites this report, which had to exist before the commit: written now.
- Acceptance-reviewer: APPROVE. All stale items from the I4b report are covered; the new comments are true (git ls-files finds none of GiftItem, MockItemData, MockAPIClient, the device fingerprint service, the legacy PurchaseDetailView or the legacy repository files); the real-mode check matches word for word; the not-performed items are stated; the handoff's spot-checked claims are true against the code; nothing under contract/, any .pbxproj, the synced Docs files or LocalPackages changed beyond Brian's sync commit and P0 (`git diff --stat 36a0408..HEAD` over those paths shows only the single openapi.json, 4 insertions and 1 deletion). Nit: the PurchaseSourceScanTests header says "entry" and the line-31 comment says "entries" (harmless). The reviewer could not run a status check on the hidden config directory by name (a hook blocks it); the full `git status` and `git diff --stat master...HEAD` listings show no entry there.
- Rejections and re-reviews: none. Stuck-detector log: nothing repeated.

## Verification claims
Comment-only property: from running `git diff -U0` and grepping for non-comment changed lines (me, the implementer and both reviewers). Truth of the new comments: from the acceptance reviewer's `git ls-files` checks. Handoff step text: from comparing against the prompt file (me while writing, both reviewers). Build and tests: from running commands.

## Deviations, real bugs, scope
Deviation: none. Real bugs found: none in this story. Outside the scope: the remaining 51-file "Fails today" headers; the mock recorder observation (Story B report).

## Not done or partial
- The real-mode checks (steps 1 to 9) need Brian and are NOT PERFORMED.
- The remaining stale "Fails today" headers in older test files were left.
- Production comments naming deleted types were not grepped by the implementer; the brief's list covered tests only.
