# I3d-6: keep the child delete confirmation state above the rows

Branch: feat/i3d-child-delete-members. Gate 1 spec: Docs/epics/I3d-child-delete-members.md, section "Fix pass Gate 1" (commit e1bc1ec). Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, one after the other).

## What was wrong (reading of the code, from the Orchestrator and confirmed by the acceptance reviewer by reading; NOT observed on a device)
`ChildRow.requestDelete` set the screen's `deletingChildId`, awaited `plan` (a forced network reload of the lists), then set the row-local `@State` `pendingPlan` and `showsConfirmation`, and in the same turn a `defer` cleared `deletingChildId`. The presentation state lived inside a List row that is re-rendered at that moment, so a re-created row loses its state and the dialog goes away.

## What changed
Fix = state ownership and one state change. No delay, no sleep, no `Task.yield()`, no `DispatchQueue`.
- New `Features/Children/ChildDeletionPresentation.swift`: pure, nonisolated value types `ChildDeletionPhase` (idle, planning, confirming, executing), `ChildDeletionBannerRequest`, `ChildDeletionPresentation` with pure transitions (`requestDelete`, `planReady`, `planFailed`, `cancelConfirmation`, `confirm`, `executionFinished`, `reset`, `childrenChanged`) and `Transition`. `deletingChildId` is derived from the phase.
- `ChildrenViewState.swift`: `ChildrenState.init(children:phase:deletion:)`; `ChildRowState.status` (`none`, `checking`, `removing`) and `showsProgress` (the confirming row shows no spinner); labels ", checking lists" and ", removing" (the old "being removed" is gone); `deleteControlsEnabled(isMutating:deletion:)` (all rows disabled unless idle); `planningAnnouncement` ("Checking lists"); `retryAnnouncement(for:)` (nil for a blocked plan).
- `ChildrenView.swift`: `ChildrenView` owns `@State deletion`; `ChildRow` has no `@State` and receives `isConfirmationPresented` (binding), `confirmation`, `confirmingPlan`, `controlsEnabled`, `onRequestDelete` (used once each by swipe action, context menu and accessibility action) and `onConfirm`. The `confirmationDialog` stays on `ChildRow`. Planning to confirming is one assignment. Try Again (`retryDeletion`) is a no-op unless idle and runs requestDelete, plan, planReady(requiresConfirmation: false), `retryAnnouncement`, execute, so it announces what it will do. `onChange` of the child ids calls `childrenChanged`; `onDisappear` and a change of the child service's `sessionGeneration` cancel the task and reset.
- Fix from the Gate 2 rejection loop (see below): `applyPlanReady` re-evaluates `childrenChanged` right after `planReady`.
- `ChildDeletionFlow` is unchanged (`run` stays and keeps its tests; the view no longer calls it).

## Files
Added: `Features/Children/ChildDeletionPresentation.swift`; tests `ChildDeletionPresentationTests.swift`, `ChildDeletionPresentationStabilityTests.swift`, `ChildDeletionPhaseKind.swift` (helper); this report.
Changed: `Features/Children/ViewState/ChildrenViewState.swift`, `Features/Children/Views/ChildrenView.swift`, tests `ChildrenDeleteStateTests.swift`, `ChildrenDeleteViewScanTests.swift`; `Docs/epics/I3d-child-delete-members.md` (Gate 1, separate commit e1bc1ec).
Deleted: none.

## Test arithmetic (from running the suite and from counting `@Test` functions with grep; counted per function)
- Previous total 3034.
- New: `ChildDeletionPresentationTests` 37, `ChildDeletionPresentationStabilityTests` 16 = 53.
- `ChildrenDeleteStateTests`: 25 functions before, 32 after = +7 net (rewritten in place: `deletingRow` split into `planningRow` and `executingRow`; `nobodyDeleting`, `unknownDeletingId`, `deletingLabelHasNoId` renamed `labelsHaveNoId`, `deleteControlsEnabled` rewritten as a phase x isMutating table; new: `confirmingRow`, `showsProgressTable`, `planningAnnouncementText`, `retryAnnouncementFollowsPlan`, `retryAnnouncementDeleteNow`, `newAnnouncementsCarryNoPersonalData`).
- `ChildrenDeleteViewScanTests`: 11 before, 24 after = +13 (`viewUsesTheFlow` changed meaning, below; new: `childRowHasNoState`, `oldConfirmationStateIsGone`, `screenOwnsThePresentation`, `dialogIsInChildRow`, `noDeferAndNoFlagAssignment`, `noTimingTricks`, `viewsUseTheTransitions`, `requestDeleteGoesThroughThePresentation`, `oneRequestClosureForAllEntryPoints`, `planReadyIsFollowedByChildrenChanged`, self-checks `f1PatternsAreExact`, `blockExtractorIsExact`, `reevaluationHelpersAreExact`).
- 3034 + 53 + 7 + 13 = 3107 = the reported total. No test deleted. Names above reconciled against the diff and grep counts; I did not diff a full test listing.

## Existing tests that changed, and why
- `ChildrenDeleteStateTests` (the rewrites above): they asserted `deletingChildId`, `isDeleting` and the label "being removed", which this fix deliberately replaces (spec: "Checking lists" while planning, "Removing" only while executing; all rows disabled while confirming).
- `ChildrenDeleteViewScanTests.viewUsesTheFlow` (f): it required `.run(childId:)` for Try Again; it now requires `plan` and `execute` and forbids `.run(`, because Try Again must announce from the recomputed plan. The `plan` and `execute` assertions are kept.
- `ChildrenStateTests`: unchanged (did not use `deletingChildId`). Nothing else changed, nothing skipped or weakened.

## Verification (commands run by me)
Before (HEAD at the start, P2):
```
--- tests: 3034 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
􁁛  Test run with 212 tests in 16 suites passed after 0.021 seconds.
```
After the Gate 1 docs commit e1bc1ec (same code): 3034 passed, 92, 17, `=== verify: OK ===`.
After the implementation, before the commit (working tree = the commit content):
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- tests: 3107 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
􁁛  Test run with 212 tests in 16 suites passed after 0.019 seconds.
```
The run after the commit is recorded at the end of this report.
Source of each claim: totals and OK lines come from running the commands; statements about behavior come from reading code (reviewers) or from the pure-transition tests. The first compile of the test target failed once during implementation (an ambiguous `banner(for:)` overload added by the implementer, removed in attempt 2); stuck detector never triggered.

## Gate 2
- Convention-reviewer: ACCEPT, no findings (could not run commands against `.claude/`, `contract/`, Docs due to the guard hook; the change set was confirmed with `git status` and `git diff --stat`: only Features/Children and the Children tests).
- Acceptance-reviewer, first review: ACCEPT with one real bug and two risks.
  - Real bug (low to medium): if the child disappears from the children list while the phase is planning, `planReady` landed in confirming for a child with no row, so all delete controls stayed disabled until the screen was left. Routed as a rejection: test-writer added `childVanishedDuringPlanning`, `childPresentAfterPlanning`, `planReadyIsFollowedByChildrenChanged`, `reevaluationHelpersAreExact`; implementer added `applyPlanReady` (`ChildrenView.swift` about :234-243), used by `requestDelete` and `retryDeletion`.
  - Re-review by the same reviewer: ACCEPT (the helper is synchronous, no suspension point between `planReady` and the re-check; when the child exists the second assignment is an equal value).
  - Risk A (very low): an old cancelled execute task finishing after the user started and confirmed a new delete of the same child could return the new task to idle early. Practically unreachable; not changed.
  - Risk B (needs a device): if SwiftUI runs the dialog's `isPresented` setter(false) BEFORE the confirm button action, the setter cancels the confirmation and the confirm is then ignored by the guard in `confirm`. That is safe (nothing is deleted without confirmation) but the user's confirmed deletion would be silently dropped. If the action runs first (the expected order), it works. Brian's real-mode check decides; if the confirm is dropped, route as code-wrong to the implementer.
- Stuck-detector log: implementer attempt 1 compile failure (ambiguous overload), attempt 2 green; the rejection fix went green on its first run. No repeated error signature.

## Focus-list answers (from the acceptance reviewer, file and line evidence, by reading)
1. State: `ChildrenView.swift:18` (`@State deletion`); `ChildRow` (about :296-355) has no `@State` (scan-tested). Writers of the state: the binding setter (about :209-218, cancels only while that child is confirming), `onChange` of ids (about :93-95), `cancelAndReset` (about :201-205), and the request/confirm/retry/apply paths. Rows re-created, children reloaded with the same ids, progress changes and the swipe closing cannot reset it (stability tests).
2. No `defer`, no flag assignment around presentation; `planReady` applied once (`ChildDeletionPresentation.swift` about :70-87); scan test `noDeferAndNoFlagAssignment`, `noTimingTricks`.
3. Dialog: `ChildRow`, `ChildrenView.swift` about :341-353; `isPresented` from `confirmationBinding(for:)` (about :209) reading `deletion.isConfirming`, `presenting:` from `deletion.confirmingPlan(for:)` (about :56-58).
4. Re-entrancy: `requestDelete` (about :233) and `retryDeletion` (about :264) return unless idle; transitions are guarded (`ChildDeletionPresentation.swift` about :66, :100); tests `doubleRequestDelete`, `secondConfirmIgnored`, `confirmWrongPhaseIgnored`, `confirmMismatchedPlanIgnored`. Delete without a new confirmation happens only through Try Again (accepted decision). Setter-vs-action ordering: see Risk B.
5. Controls: computed once at screen level (about :34) as `!isMutating && deletion.isIdle` (`ChildrenViewState.swift` about :191), used by swipe, context menu and accessibility action; table test over phase x isMutating.
6. Session safety: `onDisappear` and `sessionGeneration` change call `cancelAndReset`; `ChildDeletionFlow` unchanged (generation checks between steps); a nil result writes nothing (`finish` about :185).
7. Planning: spinner, ", checking lists", announcement "Checking lists"; confirming: no spinner, plain label; executing: spinner, ", removing"; retry announces `retryAnnouncement` of the recomputed plan. All unit-tested as strings.
8. No logging, Sentry call or accessibility identifier with a name, id or raw error was added (only `children.addButton` exists); the child's name appears only in the dialog message.
9. See "Existing tests that changed".
10. Only Features/Children, the Children tests and Docs changed (git status).

## Audit (read-only, BANKED; nothing outside Features/Children changed)
I grepped every `confirmationDialog` and `.alert` in Features/ and read the state declarations for most of them. None matches "presented from a row's swipe action or an async result with the state inside the row" the way ChildRow did. Banked observations:
- `Features/Dashboard/Views/DashboardView.swift:274` (dialog on the list row, state `listToArchive` at screen level :14, set synchronously from the swipe action :267; binding setter :142-146). Same setter-false pattern as ours, so it shares Risk B in principle; state is above the row, so not exposed to the reported bug.
- `Features/Lists/Views/ListDetailView.swift:77, :89` (leave and remove-member dialogs attached to the screen container, not to the triggering row; state `memberToRemove` :23 at screen level, set synchronously from the row's Remove :323). UI rule 1 deviation of older code; not async.
- `Features/Lists/Views/ListDetailView.swift:343`, `Features/Items/Views/ItemDetailView.swift:283` (state :23), `Features/Purchases/Views/ManagePurchaseView.swift:311` (state :276): dialog on the delete button with the button's own local state set synchronously by a tap; not exposed.
- `Features/Lists/Views/EditListView.swift:143`, `Features/Purchases/Views/RecordPurchaseRecordSection.swift:31`, `Features/Profile/Views/ProfileView.swift:76 (alert), :87`, and the `.alert` calls in `Features/Authentication/Views/LoginView.swift:82, :87, :105` and `RegistrationView.swift:30`: located by grep only; I did not read their presentation state or check whether an async result drives them. Not audited in depth.

## Deviations
- `ChildRow` also takes `confirmingPlan` (not in Gate 1), because `ChildDeleteConfirmation` carries no plan and the dialog button must call `onConfirm(plan)`.
- `retryAnnouncement(for:)` returns `String?` (nil for a blocked plan).
- Try Again no longer calls `ChildDeletionFlow.run`; it does plan then execute (needed to announce the recomputed plan).

## Not done or partial
- No simulator run was possible in this session. The reported bug (dialog disappearing on the first swipe) is NOT observed fixed; the evidence is code reading, the pure transition tests and source-scan tests. Brian's real-mode check is the only proof of the on-screen behavior, including Risk B (dialog Delete button must start the deletion) and VoiceOver announcements.
- Risk A (very low) left unchanged.
- The audit of the Authentication, Profile, EditList and RecordPurchase presentations is shallow (see above).
- Try Again still continues without a new confirmation (accepted decision, remains an open risk).

## Verification after the commit (433d697; run by me, added by the F2 commit)
```
** BUILD SUCCEEDED **
--- tests: 3107 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
􁁛  Test run with 212 tests in 16 suites passed after 0.019 seconds.
```
