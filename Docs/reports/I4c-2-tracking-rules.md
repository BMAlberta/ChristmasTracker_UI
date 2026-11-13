# I4c-2: Tracking number change rules (Story A)

Date: 2026-11-13. Branch: feat/i4c-clear-tracking. Pipeline: full pipeline (test-writer, implementer, convention-reviewer, then acceptance-reviewer). Gate 1: Docs/epics/I4c-clear-tracking.md ("Gate 1: Story A"). No view changed, so the SwiftUI skill did not apply.

## After-commit run for the previous commit (dbcaf16, Story P0)
Not captured. The P0 report promised this run here, but I did not record a separate after-commit run on a clean tree for dbcaf16, and I will not reconstruct one from memory. What exists: the before-commit run in I4c-1 (3107 passed, package 212 passed). The tree for dbcaf16 differs from that run only by the report file. This is a gap in the P0 evidence and is listed under "Not done or partial".

## Files
- Added: ChristmasTrackerTests/Features/Purchases/PurchaseTrackingChangeTests.swift, ChristmasTrackerTests/Features/Purchases/PurchaseTrackingLimitTests.swift, this report.
- Changed (app): Features/Purchases/Domain/PurchaseManagementUpdates.swift (PurchaseTrackingChange, PurchaseEmptyValue, PurchaseShippingUpdate with trackingChange and wireTrackingNumber); Features/Purchases/ViewState/PurchaseDetailState.swift (display of nil/"" values, trackingChange); Repositories/GeneratedClientPurchaseManagementRepository.swift (one line: sends update.wireTrackingNumber); Repositories/MockPurchaseManager.swift (one line: wire "" stores nil; Story B refines and tests it).
- Changed (tests): PurchaseUpdateBuilderTests, PurchaseShippingSectionStateTests, PurchaseDetailModelShippingTests, GeneratedClientPurchaseManagementRequestTests, MockPurchaseManagerTests, PurchaseServiceManagementTests, PurchaseManagementWireSupport.
- Deleted: none. Nothing under contract/, .claude/, any .pbxproj, the synced Docs files or LocalPackages/TrackerAPI changed.

## Changed existing tests, with reason
Rewritten because they asserted the old rule "empty tracking means unchanged", which decision S15 replaces with "empty clears":
- PurchaseShippingSectionStateTests: emptyTracking became emptyTrackingClears.
- PurchaseUpdateBuilderTests: emptyTrackingNeverSent became emptyTrackingClears; trackingOnly split into trackingOnlySet and trackingOnlyClear.
- PurchaseDetailModelShippingTests: emptyTrackingNeverSent became emptyTrackingSendsClear. This file was not in the Gate 1 list; its old test asserted the removed rule.
Construction-only edits (trackingNumber: x became trackingChange: .set(x), nil became .unchanged), values and assertions unchanged: the request, mock, wire-support, service and detail-model tests (14 spots). No test deleted, skipped or weakened.

## Commands and raw output (came from running commands)
Before the commit, `scripts/verify.sh`: `Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3138 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.018 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.
Before the commit, `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`
The after-commit run for THIS commit is pasted at the top of the Story B report.

## Test arithmetic
App baseline 3107. Added: 33 @Test functions (9 in the two new files, 24 elsewhere); several are parameterized, so the run total grows by 31 net after the 3 rewritten tests replace their old versions. Deleted: 0. Rewritten: 3 (same count, new behavior). 3107 + 31 = 3138; verify.sh says 3138 passed. Package: 212 + 0 = 212. Release 92, destination 17 (unchanged). The +31 comes from the test run totals; I did not reconcile each parameterized case against a per-test listing.

## The crash and the case order
`emptyTrackingSendsClear` first crashed (EXC_BAD_ACCESS, swift_retain inside PurchaseService.updateShipping when the update carried `.clear`). The first implementer stopped as the stuck detector requires (inconclusive instrumentation, reverted). A diagnosis agent read the exported crash report and found a bogus String retain when `PurchaseTrackingChange` was declared `unchanged, set(String), clear`. Reordering to `unchanged, clear, set(String)` fixed it. Why it works was not confirmed (empirical, looks like a toolchain code-generation bug on the iOS 27.2 simulator). A doc comment tells readers to keep `set` last. Fallbacks if it returns: `indirect case set`, or a string plus a clear flag.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE. Non-blocking notes: the headers of PurchaseTrackingChangeTests, PurchaseTrackingLimitTests, PurchaseUpdateBuilderTests (and an older line in PurchaseShippingSectionStateTests) still say "Fails today because ... does not exist yet"; stale, left for Story D.
- Acceptance-reviewer: APPROVE. Focus answers with evidence: truth table and Save enablement (PurchaseManagementUpdates.swift derive, make; PurchaseDetailState canSave), nil/"" display (PurchaseEmptyValue, PurchaseDetailState), rewritten tests justified by S15, notes behavior unchanged, the two one-line edits acceptable, nothing out of scope changed. Nit: the case-order comment could say it is a workaround to remove when the toolchain is fixed. Neither reviewer ran the build; the totals above came from my own run.
- Rejections: none. Stuck-detector log: one stop (implementer, crash test, inconclusive); resolved by the diagnosis agent in one attempt.

## Verification claims
Build and test totals: from running commands. Crash cause: from the exported crash report plus scratch tests (since deleted). Review claims: from reading code by the reviewers. Out-of-scope check: from git status.

## Deviations, real bugs, scope
Deviation: PurchaseDetailModelShippingTests changed though not in the Gate 1 list (reason above). The mock line goes slightly beyond minimum to keep the build compiling. Real bug: a toolchain layout crash worked around by the case order. Outside the scope: none.

## Not done or partial
- The after-commit run of dbcaf16 (Story P0) was not recorded (see top).
- Stale "Fails today" header comments in the new and changed tests: left for Story D.
- Wire behavior against the real server: not exercised here (Story D handoff covers it).
