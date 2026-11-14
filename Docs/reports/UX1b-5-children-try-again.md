# UX1b Story B5: Children Try Again re-confirms

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, sequential).

## What changed
- `ChildDeletionPlan`: `archiveListIds` and `hasUnconfirmedLists(comparedTo:)` (true when the plan would archive any list id not in the confirmed plan; subset and equal false; superset, disjoint and partial overlap true; deleteNow false; order-insensitive).
- `ChildDeletionPresentation.retryPlanReady(childId:plan:confirmedPlan:)`: only from `.planning(childId)`; calls the unchanged `planReady` with `requiresConfirmation = plan.hasUnconfirmedLists(comparedTo: confirmedPlan)`, so a blocked plan still goes to idle with the blocked banner, an unconfirmed plan goes to `.confirming(childId, newPlan)` with nothing to run, otherwise `.executing` with the plan.
- `ChildrenView`: `DeletionFailure` gains `confirmedPlan`; screen state `confirmedPlans[childId]` is set in `confirm` (a confirmed re-confirmation replaces it), cleared in `requestDelete` for that child and in `cancelAndReset` for all; `retryDeletion` uses `retryPlanReady`; on re-confirm the existing dialog opens with the new plan, no retry announcement is posted, and confirming it runs `confirm` with the progress announcement and exactly the new plan. A missing confirmed plan falls back to `.deleteNow` (any archive then counts as unconfirmed: safe side).
- Unchanged: ChildDeletionFlow, services, repositories; first-failure stop, never deleting the child after a failed archive, cancel on disappear, session guards, red controls, announcements.

## Files
Added (tests, Features/Children): ChildDeletionPlanUnconfirmedTests.swift (13), ChildDeletionPresentationRetryTests.swift (12), ChildrenRetryScanTests.swift (5). Changed: Features/Children/ChildDeletionPlan.swift, ChildDeletionPresentation.swift, Views/ChildrenView.swift; test ChildrenDeleteViewScanTests.swift (one assertion); Docs/epics/UX1b-dialogs-colors-and-polish.md (Gate 1); Docs/reports/UX1b-4-face-id-hint.md (after-commit verify line). Deleted: none.

## Existing test changed
`ChildrenDeleteViewScanTests.requestDeleteGoesThroughThePresentation`: its assertion that Try Again contains `requiresConfirmation: false` asserted exactly the behavior B5 deliberately changes; it now asserts `retryPlanReady(` in the retry function. Equivalent and stronger coverage: ChildrenRetryScanTests (retryPlanReady present, `requiresConfirmation: false` absent, `confirmedPlan` declared and passed). All other assertions of that test are unchanged.

## Test arithmetic (app suite)
4368 + 30 new (13 + 12 + 5, grep -c @Test; parameterized counts once) - 0 deleted (one assertion rewritten inside an existing test) = 4398. Measured by scripts/verify.sh: 4398. Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Implementer: first verify failed 3 tests (structure scans: it had moved plan-applying code into helpers, so `planReadyIsFollowedByChildrenChanged` and the retry scan failed); it reverted `applyPlanReady` to its original shape and inlined the retry transition; second run green. Before commit:
```
--- tests: 4398 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit: see the line added at the end of this report after the commit run.

## Gate 2
- convention-reviewer: APPROVE. Warnings: ChildrenView.swift is 402 lines (soft 400, hard 600); the ChildrenView struct body was already over the type-body limit before this story; test display strings over 120 characters (ChildDeletionPlanUnconfirmedTests 76, 82, 101; ChildrenRetryScanTests 35, 42, 53; ChildDeletionPresentationRetryTests 29, 52, 67, 78, 144, 156, 164); a pre-existing #Preview line over 120.
- acceptance-reviewer: APPROVE (read the view, presentation and plan with file:line). Notes: if the first plan call fails, nothing was ever confirmed, so Try Again plans and a deleteNow plan runs with no dialog (same as before B5); a successful delete leaves its `confirmedPlans` entry until disappear or session reset (harmless); the confirm-button ordering concern from B1 applies equally to the Children dialog but is pre-existing (confirm requires the presentation's confirming plan to equal the passed plan, so if the setter ran first it would be a no-op), not made worse by B5.
- Rejections: none. Stuck detector (implementer): one structural fix, two attempts, no repeated signature.

## Verification sources
Totals from running commands; behavior claims from the reviewers reading code. No simulator run.

## Not done or partial
- No simulator run: the re-confirmation dialog opening and its anchoring on the row are proven only by unit and scan tests; the situation (a new active list appearing between the failure and Try Again) cannot be reproduced by hand, so B7 marks it NOT PERFORMED, covered by unit tests.
- Banked: ChildrenView.swift is over the soft file-length limit (402 lines).
