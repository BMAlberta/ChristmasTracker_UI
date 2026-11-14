# I5b-2: Budgets (typed recipient 404, typed 422 on update, candidate rule)

Package I5b, Story B. Full pipeline: isolated test-writer, implementer, convention-reviewer, acceptance-reviewer. One acceptance rejection, fixed and re-reviewed.

## What changed
- `BudgetError.recipientNotFound` (new, no payload). Fixed message: "One of the people you chose can't be added to your budget right now. Check the list and try again." It names nobody. `isGone` false, `isRetryable` false. All switches over `BudgetError` stay exhaustive with no `default`.
- `GeneratedClientBudgetRepository`: on a 404 for create and update, the helper `budgetWriteNotFound` reads the generated envelope's typed fields (`error.errorCode == "RECIPIENT_NOT_FOUND"` or `error.code == 4010`) through `try? response.body.json`, the same pattern as the lists repository. That gives `.recipientNotFound`. BUDGET_NOT_FOUND, any other code and an unreadable body give `.notFound` (gone), as before. Duplicate and every other operation keep `.notFound` for every 404. The 400 (repeated recipient) maps to `.validation`; the typed 422 on update maps to `.sumExceedsTotal` (done in Story A, pinned again). Nothing is parsed by hand; the envelope exposes the code in typed fields (`errorCode` String, `code` Int), not as an enum.
- `LoadFailure.init(_ error: BudgetError, source:)`: `.recipientNotFound` is category `.other`, with the other mutation outcomes (validation, alreadyExists, sumExceedsTotal, hasPurchases). Decided at Gate 1.
- `BudgetEditorModel`: on `.recipientNotFound` from `save()` (create and edit) the draft is kept, the editor stays open (`save()` returns nil), the banner shows inside the editor with Dismiss only, and the budget is not treated as gone. It then force-refreshes the lists via `ListService.refreshLists(reportingFailure: false)` and rebuilds the person options only if no refresh was already in flight and the refresh returned no failure.
- `ListService.refreshLists(reportingFailure: Bool = true)`: new parameter passed to `performRefreshLists`. With `false` it neither sets nor clears `listsLoadFailure` (the Dashboard reads it). Default behavior and all guards (generation, archive epoch, session) are unchanged. This file was added to the Story B scope after the first acceptance rejection (scope amendment recorded in the epic).
- Candidate rule: `BudgetRecipientOptions.build(lists:existing:)` returns the recipients of lists where `canPurchase` is true (the user's own blind lists are excluded by that filter) plus the existing allocations. The spend group is removed: the `spend` parameter of `build`, the `spend` property and init argument of `BudgetEditorModel`, and the producer argument and the local `spendYear` in `StatsScreenModel`. `RecipientSpend` and `spendByRecipient` stay (statistics data).

## Files
Added (tests): `BudgetEditorModelRecipientNotFoundTests.swift`, `ListServiceQuietRefreshTests.swift`, and this report.
Changed (production): `BudgetError.swift`, `BudgetRecipientOptions.swift`, `GeneratedClientBudgetRepository.swift`, `BudgetEditorModel.swift`, `ListService.swift`, `LoadFailure.swift`, `StatsScreenModel.swift`.
Changed (tests): `BudgetEditorModelHarness.swift`, `BudgetEditorModelListsLoadTests.swift`, `BudgetEditorModelPickerTests.swift`, `BudgetErrorTests.swift`, `BudgetRecipientOptionsTests.swift`, `BudgetWireSupport.swift`, `GeneratedClientBudgetErrorTests.swift`, `LoadFailureClassificationTests.swift`, `LoadFailureFixtures.swift`.
Changed (docs): `Docs/epics/I5b-contract-sync-s16-p25.md` (scope amendment).
Deleted: none (tests only, listed below).

## Tests
New:
- `BudgetErrorTests`: table row for `.recipientNotFound` (feeds the table-driven message, errorDescription, isGone and isRetryable tests), `recipientNotFoundIsNotGoneAndNamesNobody`.
- `LoadFailureClassificationTests`: `budgetRecipientNotFoundIsOtherAndNotNotFound`; `LoadFailureFixtures` maps and lists the new case (feeds the existing budget category tests).
- `GeneratedClientBudgetErrorTests`: `recipientNotFound` (create and update), `recipientNotFoundByCode`, `recipientNotFoundByName`, `budgetNotFoundByCode`, `updateBudgetNotFoundIsGone`, `recipientNotFoundIsNotGone`, `recipientCodeOnOtherOperationsStaysNotFound`, `recipientOperationsOtherNotFound`, `repeatedRecipientIsValidation`. (The generated envelope requires both `code` and `errorCode`, so a body with only one is undecodable; the "either field decides" rule is pinned with bodies that disagree.)
- `BudgetEditorModelRecipientNotFoundTests`: `createKeepsFormAndShowsBanner`, `createRefreshesPeople`, `createRetryAfterFix`, `editKeepsFormAndShowsBanner`, `editIsNotGone`, `editRefreshesPeople`, `messageNamesNobody`, `dismissKeepsDraft`, `updateNotFoundStaysGone`, `otherFailuresDoNotRefresh` (5 arguments), and after the rejection `failingRefreshDoesNotSetListsFailure`, `successfulRefreshKeepsListsFailure`, `failingRefreshKeepsBannerAndDraft`, `failingRefreshKeepsFailedPicker`, `failingRefreshKeepsLoadedOptions`, `skippedRefreshDoesNotClaimLoaded`.
- `ListServiceQuietRefreshTests`: `quietFailureStoresNothing`, `quietFailureKeepsExistingFailure`, `quietSuccessKeepsExistingFailure`, `quietRefreshDoesNotClearAtStart`, `defaultStillReports`.
- `BudgetRecipientOptionsTests` (candidate rule): `existingAllocationsAloneKeepEveryRecipient`, `listsAndExistingAreMerged`, `existingAllocationIsKeptEvenWhenItsListIsNotPurchasable`, `nothingPurchasableAndNothingExistingGivesNoOptions`; `BudgetEditorModelPickerTests.readyHasNoSpendGroup`; `BudgetEditorModelListsLoadTests.openedDuringLoadInEditMode`.
- `BudgetEditorModelHarness`: `MutationFailureCases.nonRetryable` gained a "404 recipient not found" case, which also feeds the duplicate-model tests.

Deleted or rewritten because they exclusively asserted the removed spend group (equivalent coverage: the lists and existing tests above):
- Deleted: `spendRecipientsAreMerged`, `allThreeSourcesAreMerged` (replaced by `listsAndExistingAreMerged`), `existingNameWinsOverSpendWhenNoList`, `blankListAndExistingNamesFallThroughToSpend`, `readyMergesSpend` (replaced by `readyHasNoSpendGroup`), `readyKeepsSpendOnlyPerson`, `openedDuringLoadMergesSpend` (replaced by `openedDuringLoadInEditMode`).
- Rewritten: `sortingIsCaseInsensitive` and `equalNamesAreTiedById` (use `existing` instead of spend); renamed `sameRecipientAcrossAllSourcesAppearsOnce` to `sameRecipientAcrossBothGroupsAppearsOnce` and `listNameWinsOverExistingAndSpend` to `listNameWinsOverExisting`; eleven others lost only the `spend` argument of the helper.

Test arithmetic:
- App suite: 4184 (after Story A, measured) to 4215 (measured, final) = +31 net. Reconciling that to the per-test list above was not done: parameterized tests count per argument in the runner's total and the list above counts each as one entry, and the test listing was not enumerated. The totals are measured; the +31 is not itemized.
- Package suite: 212 + 0 new - 0 deleted = 212 (measured).

## Verification (all from running commands)
Before the commit (`scripts/verify.sh`, summary lines):
```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 4215 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Package suite alone (run by the implementer): `Test run with 212 tests in 16 suites passed after 0.018 seconds.` After the commit: see the Story C report.
Story A after-commit run (2f400d4): `** BUILD SUCCEEDED **`, `--- tests: 4184 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`.

## Gate 2
- convention-reviewer (first pass): APPROVE, no findings. It ran before the rejection fix; the fix's delta (a defaulted parameter on `ListService.refreshLists`, a guarded rebuild in `BudgetEditorModel`) was checked by the Orchestrator by reading the diff: no `default`, no forbidden framework, no force unwrap, no logging. No second convention pass was run on that delta.
- acceptance-reviewer, first pass: REJECT (narrow). `BudgetEditorModel` called `ListService.refreshLists()`, which sets and clears `listsLoadFailure` (read by the Dashboard) and rebuilt the options unconditionally, so a failed or skipped refresh could turn a failed or loading picker into loaded. Everything else verified (focus items 1, 2, 4, 11, 13). Routed to the implementer with a one-file scope widening.
- Fix: tests first (test-writer: `ListServiceQuietRefreshTests`, six editor tests), then the implementer (the `reportingFailure` parameter, guarded rebuild).
- acceptance-reviewer, second pass: APPROVE. Evidence: `ListService.swift:246-254` (parameter, `performRefreshLists` untouched), `BudgetEditorModel.swift:225-229` (read and call have no `await` between them on the MainActor; rebuild only if `!wasRefreshing` and no failure).
- Stuck detector: not triggered (the implementer needed one attempt each time).

Focus-list answers (reviewer evidence): (1) `GeneratedClientBudgetRepository.swift:102-103, 140-141, 226-234`, typed fields only; (2) `BudgetError.swift:12-14, 31-32, 63-64, 73-74`, `LoadFailure.swift:100`, no `default`, message names nobody; (3) editor behavior in `BudgetEditorModelRecipientNotFoundTests`; (4) `BudgetRecipientOptions.swift:20-28`; (11) the lists above; (13) no logging or Sentry call added.

## Deviations, risks and outside scope
- Scope widened by `ListService.swift` after the first review (recorded in the epic).
- Known edge, accepted by the reviewer: if another lists refresh is already running when the save fails, the editor's options are not rebuilt after that refresh lands (reopening the editor rebuilds them). If a refresh is cancelled or the session ends, a picker can become loaded with no options. Both are rare; no data is wrong or leaked.
- `refreshLists` returns nil both for success and for a refresh skipped because one is in flight, so the editor reads `isRefreshing` first.

## Not done or partial
- The +31 app-suite increase is not itemized against the test listing.
- No second convention-reviewer pass on the rejection-fix delta (Orchestrator read it instead).
- No simulator run was possible. Brian's real-mode check is the only proof of the on-screen behavior (the recipient error itself cannot be triggered by hand and is covered by unit tests).
