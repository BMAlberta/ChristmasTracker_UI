# I4c-3: Repository and mock (Story B)

Date: 2026-11-13. Branch: feat/i4c-clear-tracking. Pipeline: full pipeline (test-writer, implementer, convention-reviewer, then acceptance-reviewer). Gate 1: Docs/epics/I4c-clear-tracking.md ("Gate 1: Story B"). No view changed, so the SwiftUI skill did not apply.

## After-commit run for the previous commit (354f1e5, Story A), came from running `scripts/verify.sh` and `swift test --package-path "LocalPackages/TrackerAPI"` on the committed tree
`Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3138 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.021 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`.

## Files
- Added (tests, ChristmasTrackerTests/Features/Purchases/): GeneratedClientPurchaseManagementShippingBodyTests.swift, GeneratedClientPurchaseManagementClearResponseTests.swift, GeneratedClientPurchaseCreateClearResponseTests.swift, PurchaseMappingClearTests.swift, MockPurchaseManagerClearTrackingTests.swift. Added: this report.
- Changed (production): Features/Purchases/Repositories/PurchaseMapping.swift (private `nilIfBlank`; `mapRecordedPurchase` applies it to `notes` and `trackingNumber` only), Features/Purchases/Repositories/MockPurchaseManager.swift (`updateShipping` follows `update.trackingChange`; a blank `.set` stores nil).
- Changed (tests): PurchaseManagementWireSupport.swift (helpers only: `WireText`, `purchaseJSON`, `canonicalBody`; additions, no existing line removed).
- Deleted: none. Nothing under contract/, .claude/, any .pbxproj, the synced Docs files or LocalPackages/TrackerAPI changed.
- GeneratedClientPurchaseManagementRepository.swift: NO change in this story. Story A's one-line `trackingNumber: update.wireTrackingNumber` already produced the S15 request shapes, so the request-body tests pin existing behavior and were green before the implementer ran (not red-first). That is stated on purpose.

## Existing tests changed
None. The Gate 1 list predicted MockPurchaseManagerTests ~263/276 and GeneratedClientPurchaseManagementRequestTests ~177/197 might change; they already used `trackingChange:` from Story A and asserted nothing about "" staying "". No existing test deleted, skipped or weakened.

## Red run, then green (came from running commands)
Test-writer's red run: 9 failing tests, all in the mapping (the mapped value was "" where nil was expected): ClearResponse trackingNumberMapping, notesMapping, bothEmpty, fieldsAreIndependent; CreateClearResponse trackingNumberMapping, notesMapping; PurchaseMappingClear trackingNumber, notes, otherFieldsUntouched. The request-body, error and mock tests were already green. After the implementer: `scripts/test.sh` 3188 passed, 0 failed.

## Commands and raw output before the commit (came from running commands)
`scripts/verify.sh`: `Derived spec is up to date.`, `** BUILD SUCCEEDED **`, `--- tests: 3188 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed after 0.019 seconds.`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: OK ===`. The package suite inside verify.sh is the `swift test --package-path "LocalPackages/TrackerAPI"` run (212 tests, passed).
The after-commit run for THIS commit is pasted at the top of the Story C report.

## Test arithmetic
App: 3138 + 50 new @Test functions - 0 deleted - 0 rewritten = 3188; verify.sh says 3188 passed. New tests by file: ShippingBody 22, ManagementClearResponse 6, CreateClearResponse 2, MappingClear 4, MockClearTracking 16 (names in the files; parameterized tests count as one). The total moved by exactly the number of @Test functions; I did not reconcile parameterized expansions against a per-test listing. Package: 212 + 0 = 212.

## Gate 2 (verdicts written after the reviews ran)
- Convention-reviewer: APPROVE, no warnings. No banned APIs, no logging, fake fixtures, no new linkage, Swift Testing, headers present.
- Acceptance-reviewer: APPROVE. Evidence (paths under Features/Purchases/Repositories unless noted):
  (1) Shipping body: GeneratedClientPurchaseManagementRepository.swift:84-92 sends shippingStatus and `update.wireTrackingNumber` (PurchaseManagementUpdates.swift:73-79: unchanged nil, set value, clear ""); updateNotes line 56 sends notes and `trackingNumber: nil`. Exact-JSON tests in ShippingBodyTests (clear :47, set :55, unchanged :62, absent key :65-72, tracking-only carries status :86-108, all statuses :115, notes :239-264).
  (2) PurchaseMapping.swift:29-33 `nilIfBlank`, applied at :43 and :45; used by get, update, shipping, delete (repository :149) and create (:79, :93); ClearResponseTests :48-62 over four operations by six text cases; fixtures carry the full meta (ListWireSupport.swift:40-47) and item {id, name, listId}.
  (3) MockPurchaseManager.swift:138-149 and :115-117; 16 mock tests.
  (6) Error tests ShippingBodyTests :164-224 (400, 401 twice, 403, 404, 429, 500, 418, transport), each asserting the clear body was sent.
  (7) Nothing out of scope changed; no logging.
- Rejections and re-reviews: none. Stuck-detector log: nothing repeated (implementer green on the first attempt).

## Verification claims
Build, test totals, red/green results: from running commands. Request/mapping/mock behavior claims: from reading code (me and both reviewers) and from the tests. Reviewers did not run the build.

## Deviations, real bugs, scope
- Deviation: none against the brief. The test-writer dropped a planned 200 variant for create (the generated 200 payload requires `warnings`, which the contract never sends; GeneratedClientPurchaseRepositoryTests covers it) and the planned record-with-"" mock tests (see below).
- Observation (open item, not a bug in the app): `MockPurchaseRecorder.swift:187` copies `draft.trackingNumber` and notes as given, so a test that builds a `PurchaseDraft` with "" directly would store "" in the mock. Not reachable from the app: the only production draft construction (RecordPurchaseFormState.swift:75-82) trims and maps empty to nil. The Gate 1 sentence "the recorder already stores nil" holds for the app path only. The recorder is outside this story's file list; left as is.
- Minor gaps: no mock test for `.set("   ")` (code handles it, MockPurchaseManager.swift:147-148); `updateNotes` with a whitespace-only wire value would store it (unreachable, the builder never produces it).

## Not done or partial
- Mock recorder normalization (above) not done by design.
- Real-server behavior of S15: not exercised (Story D handoff, needs Brian).
