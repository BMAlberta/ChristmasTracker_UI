# I5a-2: Repositories, mocks, services, and the cache hook

Commit subject: "I5a: load stats and manage budgets through the generated client with session-safe services".
Pipeline: full (isolated test-writer, implementer, both reviewers one after the other; one rejection routed and re-reviewed). No SwiftUI skill needed (no views).

## Baseline for this story (after-commit run of Story A, commit 09cc4b3)
Raw summaries of the after-commit run for the Story A commit:
```
--- tests: 3405 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(package suite: 212 passed, run separately: `Test run with 212 tests in 16 suites passed`.)

## Files
Added production (ChristmasTracker/ChristmasTracker):
- Features/Statistics/Repositories/{StatsLoading, GeneratedClientStatsRepository, MockStatsRepository}.swift
- Features/Statistics/Services/{StatsService, SpendingCacheInvalidator}.swift (the invalidator file holds the SpendingCacheInvalidating protocol and the concrete class)
- Features/Budgets/Repositories/{BudgetManaging, GeneratedClientBudgetRepository, MockBudgetStore, MockBudgetRepository}.swift
- Features/Budgets/Services/BudgetService.swift
- Core/Extensions/EnvironmentValues+StatsService.swift, EnvironmentValues+BudgetService.swift (the latter also holds `\.spendingCacheInvalidator`)

Changed production: App/InertRepositories.swift (InertStatsLoader, InertBudgetManager, both @Instrumented, throw BudgetError.server); ChristmasTrackerApp.swift (AppDependencies fields, makeMock/makeReal/makeInert, @State services, environment injection, clearables); Features/Authentication/Services/SessionClearable.swift (10 clearables: StatsService index 8, BudgetService index 9); Features/Purchases/ViewState/PurchaseRefreshPlan.swift (new last step `.invalidateSpending`, appended by both plan functions); Features/Purchases/ViewState/PurchaseRefreshRunner.swift (defaulted `spendingCaches` init argument, runs the step under the existing shouldContinue guard).

DEVIATION from "the only change to purchase code is PurchaseRefreshPlan": running the step through the existing runner needs the invalidator at the runner's two construction sites, so ItemDetailView.swift (refreshRunner) and ManagePurchaseView.swift (buildModelOnce) each gained one `@Environment(\.spendingCacheInvalidator)` line and pass it as `spendingCaches:` (6 lines each including a comment). The runner step itself had to change because its switch is exhaustive. Nothing else in purchase code changed. Declared in the Gate 1 section before coding; both reviewers confirmed the scope.

Docs: Docs/contract-issues.md row 3 (spec documents no 422 on createBudget, updateBudget, duplicateBudget although error-codes.md lists 6003 as a 422; handled by status through the undocumented Output, fixed fallback text, not blocking); Docs/epics/I5a-stats-budgets.md (Story B signatures).

Added tests (ChristmasTrackerTests): Features/Budgets/{BudgetWireSupport, GatedBudgetManager, BudgetServiceHarness, BudgetScanSupport (helpers); GeneratedClientStatsRepositoryTests, GeneratedClientBudgetRepositoryTests, GeneratedClientBudgetRequestTests, GeneratedClientBudgetErrorTests, BudgetServiceLoadTests, BudgetServiceMutationTests, BudgetServiceSessionSafetyTests, BudgetServiceMutationDuringLoadTests, MockBudgetRepositoryTests, BudgetSourceScanTests}; Features/Statistics/{GatedStatsLoader, StatsServiceHarness (helpers); StatsServiceLoadTests, StatsServiceSessionSafetyTests, StatsServiceOverlappingFetchTests, MockStatsRepositoryTests, SpendingCacheInvalidatorTests}; Features/Purchases/{RecordingSpendingInvalidator (helper), PurchaseRefreshRunnerSpendingTests}; App/BudgetCompositionTests.
Deleted: none.

## Existing tests changed (each justified; none weakened)
- Clearable count 8 to 10 plus the two new arguments and index checks for StatsService (8) and BudgetService (9), reason "two session-safe services were added to the teardown list": InactivityLockIntegrationTests (productionClearablesReturnsEightItems, now asserts 10; the function NAME still says Eight, display name updated), SessionTeardownTests (productionClearableSetContainsExpectedClearables), ChildServiceClearableTests (makeSUT, childServiceKeepsIndexSix), PurchaseServiceClearableTests (makeSUT, purchaseServiceIsEighthAndLast), PurchaseServiceManagementClearableTests (makeSUT, stillEightWithTheServiceLast; its header comment still says "stays 8", stale).
- Plan and runner arrays gained only the appended `.invalidateSpending`: PurchaseRefreshPlanTests (sameList, otherList, noCurrentList, idsAreCarried, shape 3 to 4 steps), PurchaseDeleteRefreshPlanTests (concreteSteps), PurchaseRefreshRunnerTests (runsInPlanOrder, itemsLoadWhenListNotHeld), PurchaseDetailModelDeleteRefreshTests (static arrays and checkStaysTrueInSameSession [true x3] to [true x4]). PurchaseRefreshRunnerGuardTests unchanged and still green.

## Test arithmetic (app suite)
Previous total 3405 + new 298 - deleted 0 = 3703 (verify.sh: 3703 passed, 0 failed, 0 skipped). Rewritten (edited in place, count unchanged): the tests listed above.
New entries (a parameterized test counts as one): wire tests 12+11+16+32 = 71; BudgetService load 17, mutation 15, session safety 29 = 61; MockBudgetRepository 25; BudgetSourceScan 25; StatsService load 23, session safety 22; MockStatsRepository 12; SpendingCacheInvalidator 8; BudgetComposition 16; PurchaseRefreshRunnerSpending 13; two new tests in edited files (invalidationAppearsOnce, endsWithInvalidation) = 2. Subtotal 278 (3683 reported by the first full green run). After the Gate 2 rejection: BudgetServiceMutationDuringLoad 10 (6 red, 4 guards) + StatsServiceOverlappingFetch 10 (2 red, 8 guards) = 20. 278 + 20 = 298; 3405 + 298 = 3703. Package suite 212 unchanged; release 92 and destination 17 unchanged.

## Verification (raw, run by commands)
Before commit, scripts/verify.sh:
```
--- tests: 3703 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.020 seconds.`
After-commit output: recorded in the Story C report baseline section.

## Gate 2
Convention-reviewer: APPROVED. Checklist: @Instrumented on every repository and inert async throws function (GeneratedClientStatsRepository.swift:27; GeneratedClientBudgetRepository.swift:31,56,81,117,153,180; inert types in InertRepositories.swift); none on the @MainActor services (manual Sentry transactions service.stats.* and service.budgets.* with an explaining comment); no `default:` in any Output switch; logs are constant strings only (StatsService "load stats failed", BudgetService "load budgets failed" and "budget mutation failed"); no unsafe annotations added; no force unwraps; no GCD/Combine; changed existing tests justified. Non-blocking notes: the stale test function name above (test-writer; not changed) and the unreachable `.undocumented` case in classifyBudgetAPIError.
Acceptance-reviewer, first review: REJECTED narrowly. F1: a loadBudgets in flight when a mutation completed overwrote the mutation's result (BudgetService load write, no mutation counter). F2: StatsService.fetch could leave an older result marked fresh when an older fetch landed after a newer one across markSpendingStale. Everything else passed (focus answers 1 to 9).
Rejection routing: failing tests first (test-writer: BudgetServiceMutationDuringLoadTests, StatsServiceOverlappingFetchTests; 8 failures confirmed red for the right reason, 3695 passed 8 failed), then the implementer fixed BudgetService (mutationCount; a discarded load writes nothing, forces the next load to refetch and returns nil) and StatsService (per-year fetch sequence numbers; older fetches write nothing). The first fix attempt failed two tests (the cache can already be fresh when the mutation lands); the second attempt went green. Stuck detector: no repeated signature (one fix iteration), plus one earlier test-compile stop: the first implementer run stopped on two TEST compile errors (a missing `import HTTPTypes` and a type-checker timeout in a scan test); routed to the test-writer, fixed, no production change needed. A `default:` the implementer had left in a decode-failure status switch of the two repositories was caught by the scan tests and removed (status dictionary instead).
Acceptance-reviewer, re-review: APPROVED (F1 fixed on create, update, duplicate, delete success and delete notFound; a failed mutation does not bump the counter; F2 fixed; no new race; generation guard runs before the sequence and counter checks).

Focus-list answers (file:line from the reviews, by reading code unless stated): (1) every Output case mapped, GeneratedClientBudgetRepository.swift:34-211, GeneratedClientStatsRepository.swift:32-50; request bodies: update :121-126, create :84-90, duplicate :183, stats query :31; money through decimalToDouble/doubleToDecimal only (run: wire tests). (8) the hook: PurchaseRefreshPlan appends the step in both functions, runner PurchaseRefreshRunner.swift:36-43 under the guard (run: PurchaseRefreshRunnerSpendingTests, 13). (9) session safety: generation, in-flight cancel, teardown clear; clearable tests updated with a reason (run). (10) logging: constant strings only (read; scan tests run). (11) existing tests listed above. (13) nothing under contract/, .claude/, any .pbxproj, LocalPackages/ or the synced Docs changed (git status).
Observations accepted, not changed: 426 maps to `.server` in both repositories (the version middleware handles forced update app-wide); `invalidateSpending` is the LAST step, so it is skipped if the session ends or the task is cancelled before it (the Gate 1 spec said "appended"; a purchase recorded in that window leaves Statistics fresh-marked until the next stale mark or pull to refresh); StatsService.loadFailure is not keyed by year (the spec does not require it); a discarded forced loadBudgets returns nil without refreshing (the cache is left unfresh).

## Deviations, bugs, scope
- The purchase construction-site edits above. The first implementer run built a scratch copy of the project under the scratchpad directory to verify the production code while two test files did not compile (symlinks to the repo, outside the repo; no repo test was edited).
- Real bug classes found by review: F1 and F2 above (fixed with tests).
- Spec observation: contract-issues row 3. An undocumented 422 is handled by status only; the server message is not shown for the sum rule (the fixed text "Limits add up to more than the total" is).
- Mock limitation as documented: the mock does not move item or purchase data when budgets change; the mock seed is the current year (total 1000, Tommy 600, Jordan 300; spend 255.49) plus the previous year spend 420.00 without a budget.

## Not done or partial
- No views and no screens (Story C); the services are injected but nothing reads them yet except the runner hook.
- No simulator run was possible; Brian's real-mode check (Story D) is the only proof of the on-screen behavior.
- The stale test function name and the stale header comment noted above were left as is.
