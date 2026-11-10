# I3a-4: The list operations on the generated client and a session-safe list service

Branch feat/i3a-lists (base commit 1e0d86c). Gate 1: Docs/epics/I3a-lists.md (L2 and its addendum). Path: full pipeline (generated-client and repository layer).

## What changed
- `Features/Lists/Repositories/GeneratedClientListRepository.swift` (new): `nonisolated final class`, Sendable, `init(client: any APIProtocol)`, `@Instrumented` on fetchLists, fetchListDetail, createList, updateList, deleteList. Every generated Output case of the five operations is switched explicitly with no `default` (the undocumented case handled explicitly: 5xx -> server, otherwise invalidResponse). fetchLists sends no query. Create sends recipientId, year, name, plus theme and visibility only when supplied, never coOwnerEmail. Update sends only the non-nil name, theme, visibility, never status or coOwnerEmail; an all-nil update sends `{}` (commented). Mapping: 400 -> validation(message), 401 (after the middleware's refresh attempt) -> unauthorized, 403 -> forbidden, 404 -> notFound except createList with error code RECIPIENT_NOT_FOUND / 4010 -> recipientNotFound, 409 -> duplicateRecipientYear, 422 -> archivedReadOnly, 429 or thrown `TrackerAPIError.rateLimited` -> rateLimited, 5xx -> server, decoding failure inside `ClientError` -> invalidResponse, URLError and `TrackerAPIError.network` -> network, `CancellationError` rethrown. The error envelope is read through the generated error payload with `try?`; no hand-parsed API models.
- `ListError` (ListRespository.swift): `forbidden, notFound, recipientNotFound, duplicateRecipientYear, archivedReadOnly, validation(message:), rateLimited(retryAfter:), unauthorized, sessionEnded, network, invalidResponse, server`; `nonisolated`, Sendable, Equatable, `userMessage` and `errorDescription`. Server text appears only in `validation`. Removed: fetchFailed, createFailed, updateFailed, deleteFailed. `sessionEnded` is defined but produced nowhere, by decision: the session-ending middleware ends the session before the error returns, and the service discards the results of a stale generation.
- `ListMapping`: itemCount and purchasedCount are nil when `canSeeGiftActivity` is false (closes L1 advisory A).
- `ListService` rewritten: session generation captured by every operation and checked after every await; repository calls run in a tracked inner Task cancelled by `clearForSession`; `clearForSession` and `clearCache` share one reset that clears lists, currentListDetail, error, isLoading, isRefreshing, lastUpdated, the filter and the ListDataStore (so registering only the service is enough); ARCHIVED dropped on load, refresh and on the cached read, DRAFT kept; delete removes locally (lists, current detail, cache) without refetching; create and update use the returned detail (no refetch); typed errors kept; no error is set after the session ended or on cancellation (a stale or cancelled write throws CancellationError); `defer` flag resets are guarded by the generation. Manual Sentry spans (fixed names, no data) on every public async function, with the explaining comment; the private helpers resetSession and perform are covered by their public callers (Orchestrator ruling).
- `ListDataStore`: atomic `storeCreated(_:)` (detail cache plus summary upsert in one actor hop); `setListDetail` skips the summary cache for an ARCHIVED detail.
- `ChristmasTrackerApp.swift`: `makeReal(generatedClient:)` builds `GeneratedClientListRepository`; the TEMPORARY placeholder from L1 is gone from the production path. The legacy `make()` real fallback has no generated client (`trackerClient: nil`, auth is a mock there too), keeps `MockListRepository(withMockData: false)` with an explaining comment, and the acceptance reviewer found no callers of `make()`.
- `MockListRepository`: removed cases now throw `.server`; every public method carries "Mock repository: intentionally uninstrumented." (waiver by Orchestrator ruling: it does no I/O).

## Files
Added (production): Features/Lists/Repositories/GeneratedClientListRepository.swift.
Changed (production): ListRespository.swift, ListMapping.swift, MockListRepository.swift, ListDataStore.swift, ListService.swift, ChristmasTrackerApp.swift; Docs/epics/I3a-lists.md (L2 Gate 1 addendum).
Added (tests, Features/Lists): GeneratedClientListRepositoryTests, ListErrorTests, ListDataStoreTests, ListServiceSessionSafetyTests, MockListRepositoryScenarioTests, ListWireSupport (support: JSON envelopes, recording fake transport, token/refresher/version fakes), GatedListRepository (continuation-gated @MainActor fake).
Changed (tests): ListServiceTests (rewritten), SessionTeardownTests (FastMockListRepository throws `.server` instead of the removed cases).
Deleted: none (NetworkListRepository was deleted in L1).

## Test arithmetic
App: 748 (after L1) + 86 new + 24 added in ListServiceTests = 858 (verify: `--- tests: 858 passed, 0 failed, 0 skipped ---`). Counted by `@Test` declarations; a parameterized test is one entry: GeneratedClientListRepositoryTests 49, ListErrorTests 9, ListServiceSessionSafetyTests 17, MockListRepositoryScenarioTests 6, ListDataStoreTests 5 = 86; ListServiceTests 14 -> 38 (+24). Rewritten without changing count: testRefreshLists (the real `Task.sleep` is gone; it scripts two results and asserts the second plus a fetch count of 2), testErrorHandling (now also asserts `.server`), testLoadListsFailureResetsIsLoading (mock delay 0), FixedListRepository (throws `.server`), SessionTeardownTests.FastMockListRepository (two throws -> `.server`). Deleted: none. Package: 212 -> 212.
New test families, by name: repository (every operation x every documented response, request shape, bodies, headers, count hardening, refresh and replay, undocumented 418/502/503, malformed bodies, transport failures, cancellation); ListError message tests; service (archived/draft, delete without refetch, create/update from the returned detail, typed errors, cancellation sets no error); session safety (in-flight success, failure and network failure discarded after teardown for all six operations, cancellation during teardown, user switch with A released before and after B, late failure not leaking, repeated teardown harmless, next load fetches fresh); data store (storeCreated x4 and clear); mock scenarios.

## Raw outputs (commands run by the Orchestrator after the last change)
```
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: unit tests ===
--- tests: 858 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(verify lines are grep-filtered.) Before (state after L1, command run): 748 app, 212 package.

## Gate 2
- Convention-reviewer: first REJECTED (hard blocks): `clearForSession()` and `clearCache()` in ListService lacked the manual span plus comment; private helpers `resetSession`/`perform` and the MockListRepository methods lacked them too. Rulings by the Orchestrator: spans on the two public functions; private helpers covered by their public callers (one comment line each); MockListRepository waived (no I/O, comment added to all five methods). Warning: a force unwrap in a test URL (GeneratedClientListRepositoryTests.swift:28) replaced by guard-let. Re-check: APPROVED. Final re-check after the data-store fix: APPROVED.
- Acceptance-reviewer: first REJECTED (item 11): `createList` awaited `setListDetail` then `upsertList` with no generation check between, so a teardown in that window left the previous user's new list in the cache, and the next session's `loadLists` served it from the cached branch. Routed to the test-writer (tests) and the implementer (fix: one atomic `storeCreated`, with `ensureCurrent` immediately before it and after it; `loadLists` cached branch now filtered). Re-review: APPROVED.
- Stuck detector: two rejections, each fixed on the second attempt; no repeated error signature.

## Focus-list answers
9. Every Output case of the five operations is mapped; the 404 RECIPIENT_NOT_FOUND special case reads the generated envelope fields (`error.errorCode == "RECIPIENT_NOT_FOUND"` or `error.code == 4010`) and applies to createList only (GeneratedClientListRepository.swift lines 107 to 114; tests GeneratedClientListRepositoryTests lines 725 to 770); 401 after refresh -> unauthorized (tests lines 661 to 700). Request shape tests lines 447 to 630. (Reviewer reading; tests run in verify.)
10. Archived lists dropped on load, refresh and the cached read; delete removes locally; a refresh that returns the list as ARCHIVED stays hidden (ListServiceTests around lines 329 to 370 and 431 to 440). Dashboard reads only `listService.lists`.
11. Every await in load, refresh, detail, create, update and delete checks the generation; defer resets are generation-guarded; the create window above was found by the reviewer and fixed. Cannot be tested deterministically: a teardown landing exactly between two cache hops needs a production seam; atomicity of `storeCreated` is covered by unit tests plus code reading.
12. Logs and spans carry only operation names and counts; no list names, ids, tokens or emails (reviewer read every log and Sentry line).
8. No money in list code.

## Deferred advisories (recorded, not fixed)
- An ARCHIVED detail fetched by id (deep link) is displayed; it is not added to the summary cache.
- A refresh already in flight when a delete completes can briefly put the deleted list back (it was fetched as ACTIVE); the next refresh drops it. A cheap fix is a session-local set of deleted ids filtered in `visibleLists`.
- `loadListDetail`, create, update and delete share the `isLoading` flag with `loadLists`; one finishing early flips it while another still runs, and `loadLists` returns silently while it is true. No data leak.
- Silent mock fallback: when `buildGeneratedClient` returns nil in real mode (factory throws), the app falls back to `makeMock()` for auth and lists with only a LogError (ChristmasTrackerApp.swift lines 258 to 261). Pre-existing; needs a decision (a visible failure would be safer) before release.
- The 429 tests use `Retry-After: 0.001` (about 1 ms of real sleep) because the factory exposes no sleeper seam; accepted exception.
- `ListService.clearCurrentDetail()` and `clearCache()` have no production callers (pre-existing).

## Deviations, bugs, scope
- Real bug found by review: the create cache window (fixed).
- Process deviations: none new from the implementer this round; the `&&` and scratch-script slips are recorded in the earlier reports.

## Not done or partial
- No view changes (L3). The Dashboard and screens still use L1's minimal adaptations.
- The two-hop teardown race has no deterministic test.
- `ListError.sessionEnded` is never produced (by decision).
- Real-server behaviour is unverified (Brian's checks in L4).
