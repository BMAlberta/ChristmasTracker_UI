# I4a-3: Record purchases through the generated client with a session-safe service

Branch: feat/i4a-record-purchase. Pipeline: full (isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer one after the other). Gate 1 spec: Docs/epics/I4a-record-purchase.md, section "Story B". No view is added in this story (Story C).

## What changed
- `PurchaseRecording` (Features/Purchases/Repositories): the new -ing protocol, `createPurchase(itemId:draft:confirmationToken:) async throws -> PurchaseOutcome`. It conforms to `Sendable` only and does NOT inherit the legacy `Repository` protocol (that protocol lives in Core/Networking, which package I4b deletes). The legacy `PurchaseRepository` protocol is untouched.
- `GeneratedClientPurchaseRepository`: `@Instrumented createPurchase` on the generated client. The request body is the generated `CreatePurchase` payload built from the draft only (money through `decimalToDouble`; optional fields and the token only when non-nil; no `offList`). Every generated Output case is mapped explicitly with no `default`: 201 to `mapCreatedOutcome`; 200 to `mapConfirmationOutcome`; 400 INVALID_PRICE (errorCode or 3007) to `.invalidPrice`, other 400 to `.validation(message:)`; 401; 403 CANNOT_PURCHASE_OWN_LIST (errorCode or 6104) to `.cannotPurchaseOwnList`, other 403 to `.forbidden`; 404; 429 (`retryAfter` kept when the middleware throws it); 500; undocumented 5xx to `.server`, other undocumented (including 422, which the spec does not document for this operation) to `.invalidResponse`. Thrown `TrackerAPIError`, `ClientError` wrapping a `DecodingError`, `URLError`, `SessionRefreshError` and `CancellationError` are classified like the item repository does. `.sessionEnded` is never produced here. The repository logs nothing.
- `MockPurchaseRecorder` (actor, a new mock; the legacy `MockPurchaseRepository` is untouched) with `MockPurchaseAccess` and `MockPurchaseRules` (recipient budget limit 50, total budget limit 50, token lifetime 300 s, documented mock data). It reproduces S12: an over-budget request without a valid token returns `confirmationRequired` with one warning per exceeded level sharing ONE fresh token and records nothing; the token is bound to (item, quantity, amount, recipient spend, total spend) and expires through the injected clock; ANY recorded purchase clears every outstanding token, so a repeat overage purchase gets a NEW token; an expired, unknown or mismatched token behaves like no token (a fresh `confirmationRequired`, never an error, as the contract says); `canPurchase` is honored through `access`; any quantity of at least 1 and any item status are accepted; the price bound is greater than 0 and at most 999999.99 with at most two decimals.
- `InertPurchaseRecorder` (App/InertRepositories.swift, `@Instrumented`, throws `ConfigurationError.clientUnavailable`).
- `PurchaseService` (@MainActor @Observable, Features/Purchases/Services): `recordPurchase(itemId:draft:confirmationToken:) async throws -> PurchaseOutcome`, `isMutating`, `clearForSession()`. Generation captured before the first await; the repository call runs in a cancellable task registered for teardown; a stale or cancelled call throws `CancellationError` and writes nothing; typed `RecordPurchaseError` is rethrown as is, anything else becomes `.server`; no error is stored or published (no error property); the token is a parameter only and is kept nowhere; one constant log line (`record purchase failed`); manual Sentry span `service.purchases.recordPurchase` with an explaining comment (the method is @MainActor, so `@Instrumented` cannot apply).
- Composition: `AppDependencies.purchaseRecorder` (`makeMock`: `MockPurchaseRecorder` with access derived from the mock seed items and `MockListRepository.capabilities`; `makeReal`: `GeneratedClientPurchaseRepository`; `makeInert`: `InertPurchaseRecorder`); `PurchaseService` built in the app, injected with `.environment(\.purchaseService, ...)` (new environment key, default backed by a mock recorder like the item key); `makeProductionClearables` gains a final `purchaseService` parameter and returns it LAST (8 clearables, index 7).
- Story A follow-ups decided by Brian (see below): the cost parser and the token redaction.

## Files
Added (production): `Features/Purchases/Repositories/{PurchaseRecording,GeneratedClientPurchaseRepository,MockPurchaseRecorder}.swift`, `Features/Purchases/Services/PurchaseService.swift`, `Core/Extensions/EnvironmentValues+PurchaseService.swift`.
Changed (production): `App/InertRepositories.swift`, `ChristmasTrackerApp.swift`, `Features/Authentication/Services/SessionClearable.swift`, `Features/Purchases/ViewState/RecordPurchaseFormState.swift`, `Features/Purchases/Domain/PurchaseOutcome.swift`, `Features/Purchases/ViewState/RecordPurchaseFlow.swift`.
Added (tests, `ChristmasTrackerTests/Features/Purchases/`): PurchaseWireSupport, GatedPurchaseRecorder, PurchaseServiceHarness, MockPurchaseSupport (no tests of their own); GeneratedClientPurchaseRepositoryTests, GeneratedClientPurchaseRequestTests, GeneratedClientPurchaseRepositoryErrorTests, PurchaseServicePassThroughTests, PurchaseServiceMutatingTests, PurchaseServiceSessionSafetyTests, PurchaseServiceTokenRetentionTests, PurchaseServiceClearableTests, MockPurchaseRecorderBudgetTests, MockPurchaseRecorderAccessTests, PurchaseTokenRedactionTests, PurchaseSourceScanTests; and `ChristmasTrackerTests/App/PurchaseCompositionTests.swift`.
Changed (tests): `Features/Purchases/RecordPurchaseTotalCostParsingTests.swift` (additions only), `Features/Authentication/SessionTeardownTests.swift`, `InactivityLockIntegrationTests.swift`, `Features/Children/ChildServiceClearableTests.swift`.
Docs: this report, the Story A report addendum below, the epic (Gate 1 for Story B). Deleted: none.
Not touched (checked by both reviewers): the legacy purchase files, contract/, .claude/, any .pbxproj, the synced Docs, LocalPackages.

## Brian's decisions applied (given when Story B was started)
1. `RecordPurchaseError` is approved and is never renamed; package I4b removes the legacy `PurchaseError`.
2. Parser: `parseTotalCost` accepts ".50" (0.50) and "12." (12), and the comma variants ",50" and "12," for a comma-decimal locale (de_DE); it still rejects three decimals, grouping separators, multiple separators, signs, exponents, symbols, the lone separator, and zero (".00", "0.", "0.0", ",00", "0,", "0,0"). Each case is pinned by a test (16 new tests in RecordPurchaseTotalCostParsingTests; no existing parser test asserted the opposite).
3. Token redaction: PendingConfirmation, RecordPurchaseFlowState, RecordPurchaseFlowEvent, RecordPurchaseFlowEffect, RecordPurchaseFlow and PurchaseOutcome implement CustomStringConvertible and CustomDebugStringConvertible (and CustomReflectable where a stored token would show through a Mirror), printing `<redacted token>`. Equatable is unchanged and the `send` effect still carries the real token. 14 tests cover `String(describing:)`, `String(reflecting:)`, `dump`, interpolation, a recursive Mirror walk, and containers; the existing scanning tests for logs and accessibility identifiers remain, with a new source scan.
4. The extra state `expired` and the event `dismissError` are accepted.

## Deviations and decisions
1. RETURN TYPE: the brief says the service returns the RecordedPurchase. The two-step budget flow needs the warnings and the token on the first answer, so `recordPurchase` returns `PurchaseOutcome` (`created(RecordedPurchase)` or `confirmationRequired(warnings, token)`); Story C treats `created` as success.
2. 200 `created` BODY WITHOUT `warnings` (stuck detector, resolved by the Orchestrator): the Gate 1 rule "a 200 body that carries `created` maps to `created`" works in the pure mapping function (Story A tests, unchanged) but not through the real client, because the generated 200 payload requires a top-level `warnings` array and cannot decode such a body; the contract never sends that combination. The implementer's first two attempts (a plain implementation and then a speculative re-decode of the response body) both ended `.invalidResponse` with the same signature, so the stuck detector stopped it. Decision: a real wire 200 `created` envelope WITHOUT `warnings` is `.invalidResponse`; the speculative recovery code was removed (verified by grep for responseBody, Data(collecting and ISO8601DateTranscoder in the repository file: no matches). The test `okWithCreatedBody` was rewritten to `okCreatedWithoutWarningsIsInvalid` (expects `.invalidResponse`) and a sibling `okCreatedWithWarningsMapsToCreated` (a `created` envelope WITH `"warnings": []` maps to `created`) was added. This test was new in this story, so no existing test was weakened.
3. The regenerated `PurchaseConfirmationRequiredData` (re-read after P0) has no `purchase` member at all; a 200 `confirmation_required` maps to `confirmationRequired` and never to `created` whatever the null purchase looks like (pinned by tests, including a literal JSON body with `purchase: null`).
4. MOCK LIMITATION: the mock recorder does not change the mock items, so counts and status in mock mode do not move after a mock purchase. The mock adds no artificial delay (unlike MockItemRepository). The mock token expires strictly after `tokenLifetime`; the tests use `tokenLifetime - 1` and `+ 1`, so the exact 300 s boundary is not pinned.
5. The mock access derivation in `makeMock` was inferred from the tests: an unknown item or list is `.unknown`; `isRecipient` gives `.ownList`; `!canPurchase` gives `.forbidden`; otherwise `.allowed(recipient:)` with a fake recipient person. The blind co-owner mock item accepts either refusal in its test.
6. `.tooManyRequests` as a direct Output case maps to `retryAfter: 0` per the spec; in practice the middleware throws `rateLimited` with the real Retry-After first. A 409 is not covered by the undocumented-status test (the middleware may throw `.conflict`, which the spec leaves unmapped).
7. The environment key's default builds a `MockPurchaseRecorder` outside `makeMock`, as the item key does; the composition scan constrains ChristmasTrackerApp.swift only.
8. No `@unchecked Sendable` and no new `nonisolated(unsafe)`.

## Tests
Previous total (after Story A): 2209 app tests, 212 package tests. New: 193 = repository 11 + request 9 + error mapping 35 (= 55, including the sibling test `okCreatedWithWarningsMapsToCreated` added after the Orchestrator decision) + service 33 (pass-through 9, mutating 7, session safety 11, token retention 6) + clearable registration 4 + mock 36 (budget 24, access 12) + redaction 14 + source scan 20 + composition 15 + parser 16. Rewritten (count unchanged): the clearable and count tests in SessionTeardownTests (`productionClearableSetContainsExpectedClearables`: 7 to 8, adds index 7), InactivityLockIntegrationTests (`productionClearablesReturnsSevenItems` renamed `productionClearablesReturnsEightItems`, 7 to 8; every `makeProductionClearables` call gains `purchaseService:`), ChildServiceClearableTests (`childServiceIsSeventhAndLast` renamed `childServiceKeepsIndexSix`, count 8, index 7 pinned; `existingIndicesUnchanged` now covers the existing seven). Reason for all: the PurchaseService clearable is appended last. Deleted: 0. New total: 2209 + 193 = 2402 app tests (matches the run below); package 212.
The test-writer first reported 192 new tests (repository 10 before the sibling); the sibling test makes it 193. The reconciliation authority is the run: 2402 = 2209 + 193. The per-file counts above come from the test-writer's report and were not recounted by hand.

## Raw output (command run)
Story A commit 05be1e0 ("I4a: add the purchase domain, the budget confirmation state machine, and the form rules"), after-commit `scripts/verify.sh` summary lines (recorded here as agreed):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2209 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.017 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
and `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.019 seconds.`

Before the Story B commit (the Story B working tree), `scripts/verify.sh`:
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2402 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.021 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.020 seconds.`
The after-commit runs for the Story B commit are recorded in the Story C report.

## Gate 2
- convention-reviewer: APPROVE. `@Instrumented` on the real and inert `createPurchase` (GeneratedClientPurchaseRepository.swift:27, InertRepositories.swift:131-140); the mock is an uninstrumented actor like MockItemRepository; the @MainActor service uses a manual Sentry span with the explaining comment (PurchaseService.swift:48-59, :85-91); all nine Output cases explicit (:47-67); the single log is the constant string at PurchaseService.swift:140; redaction in PurchaseOutcome.swift:10-47 and RecordPurchaseFlow.swift:50-160; the protocol does not inherit the legacy Repository protocol (PurchaseRecording.swift:12); `MockPurchaseRecorder(` is constructed only in `makeMock` (ChristmasTrackerApp.swift:114) and the environment-key default (EnvironmentValues+PurchaseService.swift:12); no force unwraps, Combine, GCD, `@unchecked Sendable` or Double arithmetic; no stray files. Warnings (not blocking): a `default:` in `RecordPurchaseFlowEvent.customMirror` (redaction code, not a repository switch); `.rateLimited(retryAfter: 0)` on the direct 429 case matches the spec; a cosmetic note on the epic path "App/App/InertRepositories.swift" (it is correct: the second App is the folder).
- acceptance-reviewer: APPROVE, after running `scripts/verify.sh` itself (2402 passed, `verify: OK`). Evidence: every documented response mapped through the real client (GeneratedClientPurchaseRepository.swift:47-67, :80-92, :110-112; PurchaseMapping.swift:72-91); the resubmit carries the same draft plus the token and a follow-up call carries none (GeneratedClientPurchaseRequestTests.swift:51-145); the service holds no token (PurchaseService.swift:17-44, :68-72) and a Mirror scan proves it (PurchaseServiceTokenRetentionTests.swift:31-132; the in-flight task closure is bounded by `inFlight` cleanup at :95 and :123); generation and cancellation (:61, :74, :86-100, :111, :132-142); clearable index 7 (SessionClearable.swift:35-38); mock S12 table (MockPurchaseRecorder.swift:96-196); composition (ChristmasTrackerApp.swift:114, :130, :149, :324, :430). No vacuous test; weaker spots accepted (the repository-level `tokenIsNotRemembered` is trivially true for a stateless class and the service-level tests carry it).
- Rejections: none. Stuck-detector log: it tripped ONCE (the implementer's attempts 1 and 2 on `okWithCreatedBody` ended with the identical `.invalidResponse` signature); it stopped and reported; the Orchestrator resolved it with the decision in deviation 2; the counter restarted and the next run was green on the first attempt.

## Not done or partial
- No view, screen, item-detail integration, refresh plan, or real-mode check exists yet (Stories C and D). No real network was used; the real-mode checks need Brian.
- The mock does not move item counts after a purchase (deviation 4).
- The exact 300 s mock token boundary and a 409 mapping are not pinned by tests.
- The after-commit `scripts/verify.sh` for the Story B commit is not in this report (it is in the Story C report).
