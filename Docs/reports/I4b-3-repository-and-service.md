# I4b-3: The generated repository, the mock, and the service (Story B)

Date: 2026-11-12. Branch: feat/i4b-manage-purchase. Pipeline: full (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer, strictly one after the other). Gate 1: Docs/epics/I4b-manage-purchase.md ("Gate 1: Story B", "Story B interface" items 1 to 7).

## After-commit run of the previous commit (59871ae, Story A; came from running commands)
`scripts/verify.sh`: `** BUILD SUCCEEDED **`, `--- tests: 2630 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.021 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.017 seconds.`

## Files
Added, production (Features/Purchases/Repositories): PurchaseManaging.swift (protocol), GeneratedClientPurchaseManagementRepository.swift (four operations, `@Instrumented`, every Output case explicit, no default), MockPurchaseManager.swift (`MockPurchaseStore` actor, `MockPurchaseManager`, `seedPurchases(from:for:)`).
Changed, production: Repositories/GeneratedClientPurchaseRepository.swift (record path unconfirmed rules only), Repositories/MockPurchaseRecorder.swift (optional `store:` last, appends created purchases), Services/PurchaseService.swift (management dependency, `init(repository:management:)`, four methods), App/InertRepositories.swift (`InertPurchaseManager`), ChristmasTrackerApp.swift (`AppDependencies.purchaseManager`, real/mock/inert composition, service construction), Features/Items/Repositories/MockItemRepository.swift (the one allowed seed exception: the Cookbook purchase summary is now bought by the mock user instead of `pat`; `pat` is now unused in MockItemSeed, left as is).
Added, tests: 4 support files without tests (PurchaseManagementWireSupport, GatedPurchaseManager, PurchaseServiceManagementHarness, MockPurchaseManagerSupport) and 9 test files: GeneratedClientPurchaseManagementRepositoryTests 8, GeneratedClientPurchaseManagementErrorTests 24, GeneratedClientPurchaseManagementRequestTests 15, GeneratedClientPurchaseUnconfirmedTests 17, PurchaseServiceManagementTests 13, PurchaseServiceManagementSessionSafetyTests 14, PurchaseServiceManagementClearableTests 4, MockPurchaseManagerTests 32, App/PurchaseManagementCompositionTests 13 = 140.
Changed, tests: GeneratedClientPurchaseRepositoryErrorTests.swift only (see "Existing tests changed"). Docs: Docs/epics/I4b-manage-purchase.md, this report. Deleted: none. Nothing under .claude/, any .pbxproj, contract/, LocalPackages/, the synced Docs files or the legacy purchase files changed (convention-reviewer ran `git diff --stat` on those paths: empty).

## Design decision: one service, not a sibling
The management methods were added to PurchaseService instead of a sibling service. Reason: one session boundary, one generation counter, one in-flight registry, and the production clearable count stays at 8, so the three pinned clearable tests did not change. A sibling would have duplicated the whole session machinery and moved the count to 9. The management methods publish nothing and do not touch `isMutating` (the Record screen's flag), which is pinned by tests.

## Existing tests changed (spec item 3; each carries an "I4b CHANGE" comment)
All in GeneratedClientPurchaseRepositoryErrorTests.swift, all because a delivered 201 now means the purchase exists and is `.unconfirmed` instead of `.invalidResponse`: `createdStatusWithConfirmationBody`; `malformedSuccessBody` (split into `malformedOkBody` for 200, which stays `.invalidResponse`, and `malformedCreatedBody` for 201, now `.unconfirmed`); `purchaseMissingRequiredField` (201); `unknownShippingStatus` (201); `emptySuccessBody` (201). Left unchanged on purpose: `transportFailure` (notConnectedToInternet is definitive and stays `.network`), `middlewareNetworkError` (a thrown `TrackerAPIError.network` stays `.network`), the refresh-failure, 200-shape and 422 tests. Equivalent coverage of the new behavior: GeneratedClientPurchaseUnconfirmedTests.

## Behavior notes
- Record path (GeneratedClientPurchaseRepository.swift): URLError classified by UnconfirmedPurchaseClassifier (definitive gives `.network`, unconfirmed gives `.unconfirmed`, `.cancelled` stays CancellationError); any error reading or mapping a 201 body gives `.unconfirmed`; a ClientError with a 201 response gives `.unconfirmed`; the unknown non-client non-URL fallback gives `.unconfirmed`; SessionRefreshError stays `.network`; invalidServerURL stays `.invalidResponse`; every HTTP error with a response and an unreadable 200 keep their old mapping.
- Management repository: a ClientError with a DecodingError underneath is decided by its HTTP status (400, 403, 404, 500); 401 and 429 never reach the repository as responses (the refresh and rate-limit middlewares turn them into thrown TrackerAPIError, RefreshOn401Middleware.swift:41-43,61-63,104-106 and RateLimitMiddleware.swift:69-79, read by the acceptance reviewer), so the `.unauthorized`/`.rateLimited` Output cases there are defensive. getPurchase has no 400 in the contract; a 400 there arrives as undocumented and is `.invalidResponse`.
- Mock: DELIVERED sets `deliveredAt` to `Date()` when none exists (the mock has no clock); `shippedAt` is never invented; a nil or empty current user and any other user's purchase are `.notFound`. The mock never moves item counts or statuses (documented limitation, in a comment; no test assumes otherwise).
- `@unchecked Sendable` / `nonisolated(unsafe)`: none added.

## Commands and raw output (came from running commands; working tree, before the commit)
Test-writer red run: `--- xcodebuild exit status: 65 ---`, `--- tests: 0 passed, 0 failed, 0 skipped ---` (compile errors only on the missing Story B symbols). Implementer: attempt 1 `2770 passed, 1 failed` (404 with an undecodable body was mapped `.invalidResponse`; fixed by deciding by status), attempt 2 green.
`scripts/verify.sh`: `** BUILD SUCCEEDED **`, `--- tests: 2771 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.017 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.020 seconds.`

## Test arithmetic
App suite: 2630 + 141 new (140 in new test files, plus 1 from splitting `malformedSuccessBody` into two) - 0 deleted = 2771; the verify output says 2771 passed. Package suite: 212 + 0 = 212. A parameterized test counts as one entry in the per-file numbers.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE, no hard blocks. Nits: a misaligned arrow in a test header comment; `MockPurchaseManager` uses `Date()` for `deliveredAt` (mock only); a 401 or 429 with an undecodable body falls to `.invalidResponse` in the management repository (judged by the acceptance reviewer, see below). `@Instrumented` present on the four repository methods (GeneratedClientPurchaseManagementRepository.swift lines 27, 52, 83, 116) and on InertPurchaseManager; manual Sentry spans with the explaining comment on the four @MainActor service methods and `runManagement` (PurchaseService.swift:94-165); only new log line is the static `"purchase management failed"` (PurchaseService.swift:171); no DispatchQueue/Combine/force unwraps/sleeps in new files.
- Acceptance-reviewer: APPROVE, no routing. It read the production code, the request tests and the diff of the changed existing tests; it did NOT read the bodies of the mock, service-harness, wire-support and fixture tests (stated by the reviewer). Focus answers: (1) the four operations and wire (GeneratedClientPurchaseManagementRepository.swift:30-46, 56, 86-89; wire pinned in GeneratedClientPurchaseManagementRequestTests); (2) the 401/429-unreadable-body concern is NOT a defect, reasoned from the middleware order in TrackerClientFactory.swift:81-89; (3) no path found where a recorded purchase gets a definitive error, none wrongly unconfirmed (GeneratedClientPurchaseRepository.swift:49-56, 121-123, 139-146, 154); (4) session safety, no race found (PurchaseService.swift:149-173, generation read before the first await); (5) mock matches the server rules (MockPurchaseManager.swift:32-38, 117), seed exception minimal; (6) composition (ChristmasTrackerApp.swift:92, 103-126, 141, 161, 336-339), no mock in real mode (scan test); (7) nothing sensitive logged or sent to Sentry; (8) gaps below.
- Rejections and re-reviews: none. Stuck-detector log: no repeated signature (the one failing test was fixed on the second attempt).

## Gaps and accepted notes
- The "unknown non-client, non-URL error becomes `.unconfirmed`" line and the management repository's unknown-error `.network` line cannot be reached through the real client (the runtime wraps transport errors in a ClientError); they have no test (would need a hand-written APIProtocol stub). Stated, not hidden.
- A `ClientError` with a nil response and a non-URL underlying error maps to `.invalidResponse` on the record path; not reachable with the URLSession transport. Minor note from the reviewer.
- A delete that completes on the server but is dropped as stale after teardown reports CancellationError (by spec; the next session refetches).
- Spec item 4 seeding: the mock user's purchase row is openable after the one-token seed change; `pat` in MockItemSeed is now unused and may be deleted by a later cleanup.
- Optional comment suggested by the reviewer (401/429 unreachable at the management repository status switch) was not added.

## Deviations and real bugs
No deviation from the brief beyond the seed exception, which the Orchestrator allowed in the implementer's brief and which did not break any test. Real bugs found: none in existing code. No hidden tests were added or skipped.

## Verification claims
Test results and the diff-stat on protected paths: from running commands. Gate 2 findings: from the reviewers reading code. I did not re-read the production files line by line myself beyond the reviewers' evidence.

## Not done or partial
None for Story B. No view uses the service yet (Story C). The real-mode checks need Brian (Story E). The after-commit run for THIS commit is pasted at the top of the Story C report.
