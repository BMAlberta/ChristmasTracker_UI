# I4b-2: Domain and pure rules (Story A)

Date: 2026-11-12. Branch: feat/i4b-manage-purchase. Pipeline: full (isolated test-writer, then implementer, then convention-reviewer, then acceptance-reviewer, strictly one after the other). Gate 1 is in Docs/epics/I4b-manage-purchase.md ("Gate 1: Story A" and "Story A interface", items 1 to 13).

## After-commit runs of the previous commits (came from running commands)
- After b0a53fb (epic brief and inventory, docs only), `scripts/verify.sh` still stopped at the derived-spec check, as expected before P0: `ERROR: Derived spec is out of date.` / `=== verify: DERIVED SPEC OUT OF DATE ===`. I did NOT run the package suite after that commit (it was known to fail on the same stale derived spec); this is a gap against the "after every commit" rule and is stated here.
- After c99b8d1 (P0 regenerate), `scripts/verify.sh` summary: `** BUILD SUCCEEDED **`, `--- tests: 2523 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.019 seconds.`

## Files
Added, production (Features/Purchases): Domain/PurchaseManagementUpdates.swift, Domain/PurchaseManagementError.swift, Domain/PurchasePermissions.swift, Domain/UnconfirmedPurchaseClassifier.swift (also holds PurchaseFailureKind), ViewState/PurchaseDetailState.swift (PurchaseDetailState, PurchaseShippingSectionState, PurchaseNotesSectionState).
Changed, production: Domain/RecordedPurchase.swift (RecordedShippingStatus renamed PurchaseShippingStatus, CaseIterable with displayName; PurchaseItemReference; optional defaulted `item` through an explicit init), Domain/RecordPurchaseError.swift (`.unconfirmed`, `failureKind`), Repositories/PurchaseMapping.swift (rename and item reference only), ViewState/RecordPurchaseErrorPresentation.swift (UnconfirmedPurchaseActions), ViewState/RecordPurchaseFlow.swift (events recordAgain and checkItem, effect checkItem), ViewState/PurchaseRefreshPlan.swift (stepsAfterDelete), Features/Items/ViewState/ItemViewState.swift (PurchaseRowState.canOpen and accessibilityHint only).
Added, tests: 12 new files (PurchasePermissionsTests 7, PurchaseShippingStatusTests 3, PurchaseUpdateBuilderTests 16, PurchaseManagementErrorTests 10, PurchaseDetailStateTests 8, PurchaseShippingSectionStateTests 14, PurchaseNotesSectionStateTests 14, UnconfirmedPurchaseClassifierTests 4, RecordPurchaseUnconfirmedErrorTests 7, PurchaseDeleteRefreshPlanTests 2, RecordPurchaseFlowUnconfirmedTests 13, Features/Items/ItemPurchaseRowStateTests 7) = 105.
Changed, tests: PurchaseFixtures.swift (rename; defaulted purchaser, item, purchasedAt, itemName, listId parameters; fakeItemReference; allErrorsWithUnconfirmed), PurchaseMappingTests.swift (rename plus 2 new tests), GeneratedClientPurchaseRepositoryTests.swift (rename, two places), RecordPurchaseErrorTests.swift (the exhaustive retryable switch lists `.unconfirmed`; without it the file would not compile). No existing test was deleted, skipped or weakened; the implementer touched no test.
Docs: Docs/epics/I4b-manage-purchase.md (Gate 1 detail), this report. Deleted: none.

## Decisions taken by the Orchestrator on spec gaps (the test-writer listed them)
Initializer names (`PurchaseDetailState(purchase:currencyCode:locale:)`, `PurchaseShippingSectionState(purchase:)`, `PurchaseNotesSectionState(purchase:)`), `editing(...)` copies and draft property names, the position of `item` in the memberwise init (after recipient, before purchasedAt), `PurchaseManagementError: LocalizedError`. The implementer chose the wording of `PurchaseManagementError.notFound` ("This purchase no longer exists.").

## Commands and raw output (came from running commands; working tree, before the commit)
`scripts/verify.sh`: `** BUILD SUCCEEDED **`, `--- tests: 2630 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.017 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`
The test-writer's red run (before any production code): `--- xcodebuild exit status: 65 ---`, `--- tests: 0 passed, 0 failed, 0 skipped ---`; compile errors were only the missing Story A symbols. The implementer's first run was green (2630).

## Test arithmetic
App suite: 2523 + 107 new (105 in new files + 2 in PurchaseMappingTests) - 0 deleted or rewritten = 2630. Reconciled with the verify output (2630 passed). Package suite: 212 + 0 = 212. Renames in existing tests do not change the count. A parameterized test counts as one entry in the per-file numbers above.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE. No hard block. Low notes: `mapRecordedShippingStatus` keeps the old prefix (private function, cosmetic, left); the accessibility hint is a literal in a ViewState, as the neighbours do; the explicit `RecordedPurchase` init is needed for the defaulted `item`; `PurchaseManagementError.validation` returns the server message as given, like RecordPurchaseError (the repository, Story B, is where that message is kept free of payloads). The reviewer could not read `.claude/` (hook), `git status` shows no change there.
- Acceptance-reviewer: APPROVE, no rejection routing. Focus answers with evidence: (1) builders PurchaseManagementUpdates.swift:23-56, limits PurchaseDetailState.swift:92,126, boundary and emoji tests in the section-state tests; (2) PurchasePermissions.swift:12-15 and ItemViewState.swift:219-233 (rows only when canSeeGiftActivity; no role read; list status not an input), ItemPurchaseRowStateTests for every persona on active and archived lists; (3) classifier complete against the spec, default unconfirmed; (4) RecordPurchaseFlow.swift:209-222, no state-machine hole, new events and effect token-free in description and Mirror; (5) all brief strings exact (PurchaseDetailState.swift:13-19 etc.); (6) item reference mapped at PurchaseMapping.swift:44, money unchanged, rename behaviour-neutral; (7) the four changed existing test files are rename or extension only; (8) no spec gap of substance.
- Rejections and re-reviews: none. Stuck-detector log: no stuck loop (the implementer was green on its first attempt).

## Accepted residual risks and notes carried forward
- Classifier: `notConnectedToInternet` and `secureConnectionFailed` are DEFINITIVE as the brief specifies, but a connectivity drop after bytes were sent can in rare cases report them. Accepted per the brief; the conservative alternative is to move them to unconfirmed (handoff open risk).
- For Story B (repository): a decode or mapping failure of a 2xx record response, and the non-URL `.network` fallback, must become `.unconfirmed` (the server received the request); a non-2xx decode failure stays `.invalidResponse`. The URL error code must be carried past `GeneratedClientPurchaseRepository.swift:128-130` into the classifier. `.cancelled` stays a CancellationError.
- For Story C: `remainingCharacters` counts the untrimmed draft while `tooLong` counts the trimmed draft; Save must not be gated on `remainingCharacters`. The section states keep their original values private; if the views need them, say so.
- The "no tracking member on PurchaseNotesUpdate" test inspects Mirror labels (weak guard); the real guarantee is structural (the type has only `change`).
- Deviation from the one-commit-per-story shape: none. Real bugs found: none.

## Verification claims
Build and test results: from running commands. Everything under "Gate 2" evidence: from the reviewers reading code, which the Orchestrator accepts but did not re-read line by line. No UI in this story, so no simulator check.

## Not done or partial
None for Story A. Nothing throws `RecordPurchaseError.unconfirmed` yet and the management service does not exist yet; both are Stories B and C by design. The after-commit run for THIS commit is pasted at the top of the Story B report.
