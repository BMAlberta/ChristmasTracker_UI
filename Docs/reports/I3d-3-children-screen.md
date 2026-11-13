# I3d-3: The Children screen

Branch: feat/i3d-child-delete-members. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, strictly one after the other).
SwiftUI guidance: the swiftui-expert-skill was loaded by the Orchestrator in this session and its rules (private @State, small pure bodies, Button not onTapGesture, foregroundStyle, stable ForEach identity, `.task`/cancellation for async work, no GeometryReader) were put in the implementer brief.

## What changed
- `ChildrenViewState.swift` (pure): `ChildrenState.deleteConfirmation(for:plan:)` replaces the old function (nil for blocked; texts per the Decisions); `blockedMessage`; `ChildDeletionBanner` and `banner(for:)` (counts-only partial-failure message "Archived a of t lists. The child was not removed.", Try Again only when the error is retryable, always Dismiss, blocked has no Try Again, a 422 shows the corrected childHasLists message); `progressAnnouncement(for:)`; `resultAnnouncement(for:)`; `deleteControlsEnabled(isMutating:deletingChildId:)`; `ChildRowState.isDeleting` with the "being removed" label; `ChildrenState.init(children:phase:deletingChildId:)`.
- `ChildrenView.swift`: the screen-level confirmationDialog, `.alert("Couldn't remove child")`, `childToDelete`, `actionErrorMessage` and the direct `childService.deleteChild` call are gone. A private `ChildRow` wrapper in the same file holds its own plan and presentation state and carries the ONE confirmationDialog (ChildrenView.swift:254-264). Swipe action and context menu keep `role: .destructive` and gain `.tint(Color.destructiveColor)` (:237-250). The row asks `ChildDeletionFlow.plan` (progress state while it runs), blocked shows the banner and no dialog, otherwise the dialog; confirm calls `execute`; Try Again calls `run`. Failures are held in the screen's local `@State` and shown with the existing `InlineErrorBanner` at the top of the list; Dismiss, a successful retry, and leaving the screen clear it. The shared `ChildService.error` is not read. The deletion task is stored on the screen and cancelled in `.onDisappear`; a nil result shows nothing. VoiceOver: "Archiving lists" or "Deleting child" at the start, then the result announcement on success (banners announce themselves).
- AddChildView, the add-child sheet, the toolbar and the load-error row are untouched.

## Files
- Changed (production): `Features/Children/ViewState/ChildrenViewState.swift`, `Features/Children/Views/ChildrenView.swift`
- Added (tests): `ChildrenDeleteStateTests.swift` (25 entries), `ChildrenDeleteViewScanTests.swift` (11 entries) in `ChristmasTrackerTests/Features/Children/`
- Changed (tests): `ChildrenStateTests.swift`
- Changed (docs): `Docs/epics/I3d-child-delete-members.md` (D3 Gate 1 interface), `Docs/reports/I3d-2-child-deletion-flow.md` (after-commit section)
- Deleted: none

## Existing tests changed
`ChildrenStateTests.swift`: the three old `deleteConfirmation` tests (message/fallback name/no id) targeted the function this story replaces. They are now four test functions on `deleteConfirmation(for:plan:)`: `deleteConfirmation` (archiveThenDelete plan, keeps the "undone" assertion), new `deleteConfirmationDeleteNow` (drops the "undone" assertion because the new deleteNow message is "<name> will be removed."), `deleteConfirmationFallbackName` and `deleteConfirmationHasNoId` (both parameterized over deleteNow and archiveThenDelete, the latter also checking button text and list ids). Reason: decision for D3 (Confirmation) and the signature change. `MembersChildrenViewScanTests` and `MembersChildrenLogScanTests` pass unchanged. Nothing deleted or skipped.

## Test arithmetic
App suite: 2997 + 36 new + 1 net (three old tests became four) - 0 deleted = 3034. New entries: `ChildrenDeleteStateTests` 25 + `ChildrenDeleteViewScanTests` 11 = 36; `ChildrenStateTests` net +1; 2997 + 36 + 1 = 3034, confirmed by running `scripts/verify.sh`. Per-file entry counts are from the test-writer's report (no independent test listing was produced). Package suite: 212 (unchanged).

## Raw output (commands run by the Orchestrator, before the commit)
```
--- xcodebuild exit status: 0 ---
--- tests: 3034 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
Test run with 212 tests in 16 suites passed after 0.019 seconds.   (swift test, TrackerAPI package)
```
After-commit run: see below (added after the commit; committed with Story D4).

## Gate 2
- convention-reviewer: APPROVED, no findings. Tokens only (AppSpacing, `.appBody`, `.appCaption1`, `Color.*Color`; the pre-existing 44-point values and the "trash" symbol were already there); the four UI rules hold (dialog on the row at ChildrenView.swift:254-264; local errors in `@State deletionFailure` :18; destructive role plus token :238-249; `InlineErrorBanner` :100-104); no force unwraps, Combine or GCD; no logging; the only accessibility identifier is the literal "children.addButton" (:78). Observations: `pendingPlan` is not cleared on dialog Cancel (overwritten by the next request).
- acceptance-reviewer: APPROVED, no rejection. Focus list: (4) dialog on the row wrapper, destructive and `Color.destructiveColor`, texts match the Decisions (ChildrenViewState.swift:88-108), blocked returns nil and shows a dismiss-only banner (ChildrenView.swift:284-286, ChildrenViewState.swift:127-132); (1) `.partialFailure` is returned before `deleteChild` can be reached (ChildDeletionFlow.swift:134-143), Try Again runs `flow.run` and re-plans from fresh lists (ChildrenView.swift:185-197); (5) `onDisappear` cancels the task (:90-94), a nil result writes nothing (:178); (7) no names or ids in logs, spans, identifiers or banner/announcement text; (8) only `ChildrenStateTests.swift` changed among existing tests and each change is justified; the scan tests (a), (b), (c) would have failed on the old UI; (10) nothing forbidden changed. The reviewer ran no tests and took NO simulator screenshot (visual check not performed).
- Non-blocking findings from the reviewer, recorded as open items, NOT fixed in this package:
  1. `requestDelete` clears `deletingChildId` (via `defer`, ChildrenView.swift:281) as soon as the plan returns, so while the confirmation is open the row's progress state is gone and the delete controls are enabled again. On iPhone the dialog is modal; on iPad (popover) another row could in principle start a second plan. No wrong deletion can result because each plan needs its own explicit confirmation; suggested follow-up: keep `deletingChildId` set until the dialog resolves, or gate the controls on any row's presentation state. Untested by the view-level tests.
  2. `retry` ignores `controlsEnabled`: a double tap on Try Again cancels the first task and starts a second.
  3. The row label already says "being removed" during the plan phase, before the user confirms (slightly early wording).
  4. The retry announcement is always "Archiving lists", even when the re-plan turns out to be deleteNow.
- Stuck detector: not triggered (implementer green on the first attempt).

## Verification source
Test counts and verify: from running commands. View behavior (dialog attachment, task cancellation, banner lifecycle): from reading code and the passing scan and state tests; the view was NOT run in a simulator.

## Deviations and findings
- Deletion work runs in a Task stored on `ChildrenView` (row actions call a `start` closure), not in a row-owned Task, because List rows fire `onDisappear` when scrolled off screen, which would cancel an in-flight deletion.
- The row wrapper stays in `ChildrenView.swift` (not a new file) so the existing `MembersChildrenViewScanTests` keeps passing unchanged.
- Open items 1 to 4 above.

## Not done or partial
- No simulator or real-mode check of the Children screen (Story D4, Brian's steps 2 to 5), and no screenshot or Dynamic Type check.
- The four reviewer findings above are not fixed.
- The after-commit verify run is recorded below, after the commit.
