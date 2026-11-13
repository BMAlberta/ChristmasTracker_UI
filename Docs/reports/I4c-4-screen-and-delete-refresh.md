# I4c-4: The screen and the delete refresh (Story C)

Date: 2026-11-13. Branch: feat/i4c-clear-tracking. Pipeline: full pipeline (test-writer, implementer, convention-reviewer, a test-only cleanup by the test-writer, then acceptance-reviewer). Gate 1: Docs/epics/I4c-clear-tracking.md ("Gate 1: Story C"). SwiftUI guidance: the swiftui-expert-skill was loaded by me and its rules (state from the @Observable model, no logic in body, handlers call model methods, private @State, tokens only, scoped InlineErrorBanner, destructive role) were put in the implementer brief, since subagents cannot invoke skills. The actual view change is small (environment reads and the dependency built in `buildModelOnce()`); no layout changed, so no simulator screenshot was taken.

## After-commit run for the previous commit (091ca8e, Story B), came from running `scripts/verify.sh` on the committed tree
`Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3188 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.023 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.

## Files
- Added (tests, ChristmasTrackerTests/Features/Purchases/): PurchaseDetailModelClearTrackingTests.swift, PurchaseDetailModelDeleteRefreshTests.swift, PurchaseServiceSessionGenerationTests.swift, PurchaseRefreshRunnerGuardTests.swift, DeleteRefreshMoveScanTests.swift. Added: this report.
- Changed (production): Features/Purchases/Services/PurchaseService.swift (read-only `sessionGeneration`), Features/Purchases/ViewState/PurchaseRefreshRunner.swift (`run(_:while:)`; `run(_:)` calls it with an always-true check), Features/Purchases/ViewState/PurchaseDetailModel.swift (`PurchaseDetailRefresh` struct with a do-nothing default, optional `refresh:` last init parameter, announcement by change, `confirmDelete` runs the refresh), Features/Purchases/Views/ManagePurchaseView.swift (reads itemService and listService from the environment, builds the dependency in `buildModelOnce()`), Features/Items/Views/ItemDetailView.swift (`handlePurchaseDetailFinish`: `.deleted` only closes; `.gone` unchanged).
- Changed (tests): PurchaseDetailModelHarness.swift (additive: RefreshProbe, `makeRefreshDependency`, optional `refresh:`), PurchaseDetailModelDeleteTests.swift (comment only), Items/ItemDetailPurchaseOpenScanTests.swift (one test, below). Header comments only (stale "Fails today" wording replaced) in PurchaseTrackingChangeTests, PurchaseTrackingLimitTests, PurchaseUpdateBuilderTests and PurchaseShippingSectionStateTests, which were committed in Story A; the diff on those four is comments only.
- Deleted: none. Nothing under contract/, .claude/, any .pbxproj, the synced Docs files or LocalPackages/TrackerAPI changed.

## Existing tests changed, with reason
- ItemDetailPurchaseOpenScanTests.handlesDeleted: it asserted the item views contain `PurchaseRefreshPlan.stepsAfterDelete(`. The brief moves the delete plan to the model, so it now asserts the host views do NOT name it and still asserts `.deleted`, `.gone` and `PurchaseDetailFinish`. Only the changed behavior was touched; the moved behavior is covered by the model tests below.
- Comment-only edits listed above. No test deleted, skipped or weakened.

## What the delete flow does now (came from reading code; behavior also proven by tests)
`confirmDelete` runs in the unstructured task the Delete button starts (ManagePurchaseView.swift, `Task { await model.confirmDelete() }`), which the view disappearing does not cancel. It captures `service.sessionGeneration` before the delete call; on success or not-found it clears the banner, announces "Purchase deleted.", sets `finish = .deleted`, then runs `PurchaseRefreshPlan.stepsAfterDelete` through the dependency with the check `sessionGeneration == captured && !Task.isCancelled`, asked before every step. If the delete throws (teardown, user switch, cancellation, or any error) no refresh runs. The refresh cannot change `finish`, set a banner or turn the delete into an error. A 404 on the item refetch is handled by ItemService (drops the item, sets goneItemId). `currentItemsListId` is read when the refresh starts.

## Commands and raw output before the commit (came from running commands)
Implementer's `scripts/test.sh`: `--- tests: 3241 passed, 0 failed, 0 skipped ---`. After the test-only cleanups, `scripts/verify.sh`: `Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3241 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.022 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. The package suite is inside verify.sh and printed 212 tests passed.
The after-commit run for THIS commit is pasted at the top of the Story D report.

## Test arithmetic
App: 3188 + 53 new @Test functions - 0 deleted - 0 rewritten (ItemDetailPurchaseOpenScanTests.handlesDeleted was edited in place, same count) = 3241; verify.sh says 3241 passed. New by file: ClearTracking 14, DeleteRefresh 18, ServiceSessionGeneration 3, RunnerGuard 8, MoveScan 10. Parameterized tests count as one entry; I did not reconcile expansions against a per-test listing, but the total moved by exactly the function count. Package: 212 + 0 = 212.

## Red, then green
Test-writer's red run: scripts/test.sh exited with status 65 and printed 0 tests; the xcresult build results showed 36 compile errors, all from the missing interface (`PurchaseDetailRefresh`, `refresh:`, `sessionGeneration`, `run(_:while:)` and inference cascades). The implementer made it green on the first attempt with no deviation from the assumed shape.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE. Notes acted on by a test-only cleanup (then re-verified): the word DispatchQueue appeared four times in negative scans of DeleteRefreshMoveScanTests, which the package rule forbids in any changed file, so they now use `Rules.combineAndDispatchViolations(inBare:)`; stale "Fails today" headers reworded; stale harness "adaptation point" comments reworded and the duplicated init call merged. Older, untouched test files still carry "Fails today" headers (out of scope).
- Acceptance-reviewer: APPROVE, no rejections. Evidence (PurchaseDetailModel.swift unless noted): saveShipping :161-174 (applying the returned purchase :167, announcement :169, failure keeps the draft :171); confirmDelete :205-231 (generation captured :209 before deletePurchase :212; not-found treated as done :214-215; guard before finish :220; refresh :225-230; finishDeleted :237-241); runner check per step PurchaseRefreshRunner.swift:28-37; cancellation/stale generation becomes CancellationError at PurchaseService.swift:172-173; ItemService.dropIfGone ItemService.swift:331-338; ManagePurchaseView.swift:326 unstructured Task; ItemDetailView.swift:348-362; the swipe-back gesture is not disabled. Behavioral tests: deleteWhileViewGone, teardownMidDelete, cancelledTaskDoesNotRefresh, userSwitchMidDelete, sessionEndBetweenSteps, cancellationBetweenSteps, failingRefreshStep, itemRefetchNotFound, notFoundRefreshes, listIdReadAtRefreshTime. No logging in the diff. Reviewers did not run the build; the totals above came from my runs.
- Stuck-detector log: nothing repeated.

## Verification claims
Build and test totals: from running commands. Delete-flow, cancellation and session-guard behavior: from reading code (me and both reviewers) and from tests with deterministic gates (no sleeps, no yield loops). Host behavior of ItemDetailView (`.deleted` only closes, `.gone` runs the plan): from reading code and a source scan; there is no behavioral view test.

## Deviations, real bugs, scope
- Deviation: none against the brief. The model gained the refresh dependency as an optional struct of two closures with a do-nothing default (previews compile unchanged).
- Real bug fixed: the I4b defect (refresh skipped when the user left during a delete) is fixed by moving the launch into the model.
- Limits (by design): the continue-check runs between steps; a step already running is protected by ItemService's and ListService's own guards. A cancellation that arrives after the delete returned successfully skips the refresh (teardown).
- Outside the scope: the mock recorder observation from Story B stays open.

## Not done or partial
- Real-server and real-device behavior of the clear and of swipe-back during a delete: not exercised (Brian's real-mode check, Story D handoff).
- No simulator screenshot (no layout change).
- Behavioral (non-scan) test of ItemDetailView's `.deleted` / `.gone` handling: none; covered by source scan and review.
