# I3d-1: The Members section shows the owner and co-owner

Branch: feat/i3d-child-delete-members. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, one after the other).
SwiftUI guidance: the swiftui-expert-skill was loaded by the Orchestrator and its rules (small pure views, stable ForEach identity, tokens only, foregroundStyle) were put in the implementer brief. No view code changed.

## What changed
`MembersSectionState` now builds, when the roster is shown (canSeeMembers true and members non-nil): the owner row (from `detail.owner`), the co-owner row (from `detail.coOwner`, only if present), then the ACTIVE roster rows. A roster entry whose userId equals the owner or co-owner id is dropped (shown once, as the owner or co-owner row). When the roster is not shown, `rows` is empty, so nothing new is revealed. Owner and co-owner rows have `canRemove == false` and synthetic ids `owner:<id>` and `co-owner:<id>`. Roster rows get `canRemove == canManageMembers` (every remaining roster row is a member or viewer). The dead owner/co-owner detection in the roster kind function was removed. showsAdd, showsLeave, memberCountText, the flows, dialogs and services are unchanged. `MembersSectionView` needed no change: it already renders `state.rows`, hides Remove when `row.canRemove` is false and uses `row.accessibilityLabel` ("<name>, Owner", "<name>, Co-owner") (read from code, not run in the simulator).

## Files
- Changed: `ChristmasTracker/ChristmasTracker/Features/Lists/ViewState/MembersViewState.swift`
- Changed (tests): `ChristmasTrackerTests/Features/Lists/MembersFixtures.swift` (adds `memberRoster(includeInactive:)`; `fullRoster()` untouched), `MembersSectionStateTests.swift`, `MembersTruthTableTests.swift`
- Added (tests): `ChristmasTrackerTests/Features/Lists/MembersOwnerRowsTests.swift` (the target uses synchronized folders; no .pbxproj change)
- Deleted: none

## Existing tests changed (reason for each: this story, the roster no longer contains the owner or co-owner)
- `MembersSectionStateTests.makeSUT` (helper): default roster is `memberRoster()`.
- `activeRowsOnly`: ids assertion became 4 rows plus last two ids `mem-m1`, `mem-v1` (owner/co-owner ids are synthetic now); slightly looser, the new file pins ids separately.
- `kindIgnoresWireRoleForOwnerAndCoOwner`: passes `fullRoster()` explicitly and asserts the defensive duplicate case (shown once).
- `noCoOwnerOnList`: roster `memberRoster()`, expected kinds unchanged.
- `displayNames`: title only; expectation now comes from the detail.
- `emptyRoster`: `rows.isEmpty` became kinds `[.owner, .coOwner]` (an empty roster still shows who owns the list).
- `MembersTruthTableTests.exhaustiveTruthTable` and `personaOutcome`: roster is `memberRoster()`; expected kinds and removable flags unchanged.
Nothing deleted or skipped.

## Test arithmetic
App suite: 2937 + 13 new - 0 deleted or rewritten-as-new = 2950. Package suite: 212 (unchanged). The 13 new entries are all in `MembersOwnerRowsTests`: 1 parameterized truth table (128 cases: 2 x 2 x 2 flags x members present or nil x 8 roster shapes) plus 12 focused tests (owner and co-owner first with labels; no co-owner row; ids distinct; ids stable; accessibility labels; hidden roster x3 cases; no owner row when hidden and no co-owner; inactive entries hidden; empty roster; owner duplicate; co-owner duplicate; both duplicates) as counted by the test-writer; the 2937 to 2950 delta was confirmed by a command run (below).

## Raw output (commands run by the Orchestrator)
Before the commit, `scripts/verify.sh` (summary lines):
```
--- xcodebuild exit status: 0 ---
--- tests: 2950 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Before the commit, `swift test --package-path "LocalPackages/TrackerAPI"`:
```
Test run with 212 tests in 16 suites passed after 0.020 seconds.
```
After-commit run: see the section "After-commit run" below (appended after the commit; this file's update is committed with the next story).

## Gate 2
- convention-reviewer: APPROVED. No findings. Checked @Instrumented (not applicable, view state only), tokens, no Combine/GCD (DispatchQueue absent), no force unwraps, no logging, identifiers unchanged and without names or ids, no forbidden path touched.
- acceptance-reviewer: APPROVED. Focus list (6): MembersViewState.swift:60 (roster only with canSeeMembers), :66-69 (rows empty without roster), :71-77 (owner, co-owner, duplicate guard), :86 (canRemove), :121 (owner rows not removable), MembersSectionView.swift:99, :101; ListDetailView.swift:182 removes by `row.userId` and is reachable only from rows with canRemove. (7): no logging added, identifiers unchanged. (8): changed tests are the ones listed above. (10): only the five expected files changed. The reviewer did NOT run tests and did NOT take a simulator screenshot (visual check not performed); it could not query `.claude/` because a hook blocked the command, but `git status` showed no change there.
- No rejection. Stuck detector: not triggered (green on the first implementer attempt).

## Verification source
Test counts and verify: from running commands. Behavior claims about the view: from reading code, not from running the app.

## Deviations and findings
None. (An owner who is also the co-owner would be shown once as the owner; the server cannot produce that.)

## Not done or partial
- No simulator or real-mode check of the Members section (Brian's real-mode check in Story D4, steps 6 and 7).
- The after-commit verify run is recorded below, after the commit.
