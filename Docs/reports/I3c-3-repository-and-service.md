# I3c-3: Item operations on the generated client and a session-safe item service (Story C)

Branch: feat/i3c-items. Path: full pipeline (generated-client and repository layer, session handling). Gate 1: Docs/epics/I3c-items.md "Story C" and "Story C Gate 1 addendum". Applied deviations: D1, D3, D4, D5 (compile-only adaptations of the old item screens).

## What changed
- `ItemRepository` protocol now speaks `ListItem`, `CreateItemInput`, `UpdateItemInput`; `ItemError` moved into ItemRepository.swift and trimmed to the new cases (`errorDescription` equals `userMessage`).
- `GeneratedClientItemRepository(client:)` (new): five operations on the generated client, each `@Instrumented`. Mapping: 400 INVALID_PRICE (errorCode or code 3007) -> `.invalidPrice`, other 400 -> `.validation(message:)` from the envelope only; 401 -> `.unauthorized`; 403 -> `.forbidden`; 404 -> `.notFound`; 422 on delete with CANNOT_DELETE_ITEM_WITH_PURCHASES -> `.cannotDeleteWithPurchases`, other 422 -> `.validation`; 429 and `TrackerAPIError.rateLimited` -> `.rateLimited`; 5xx -> `.server`; other undocumented or undecodable -> `.invalidResponse`; transport -> `.network`; `CancellationError` rethrown. No blanket default. The create body has no `offList`. Money crosses the boundary through `doubleToDecimal` / `decimalToDouble`.
- `MockItemRepository` rewritten as an actor mirroring the server privacy rules (`init(capabilities:currentUser:)`, no-arg init kept); seed in `MockItemSeed`; legacy fixtures moved to `MockItemData.swift`. `NetworkItemRepository.swift` deleted.
- `ItemService` rewritten: items, currentListId, currentItem, isLoadingItems, isLoadingDetail, isMutating (counter), loadError, goneItemId; load/refresh/detail/create/update/delete; mutations throw typed errors and never touch `loadError`; generation counter, mutation counter, `clearForSession`; manual Sentry spans with the explaining comment. Old `error`, `isLoading`, `filteredItems`, `showPurchased`, `showOffList` removed.
- `ItemDataStore` on `[ListItem]` (+ `removeItem(id:)`).
- Composition: real mode uses the generated client for items (legacy `NetworkAPIClient` stays for purchases); mock mode reads capabilities from `MockListRepository.capabilities(forListId:)` (new static); inert repository on new signatures.
- `GiftItem.swift`: `CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, `ItemData`, `ItemResponse` deleted. `GiftItem` and the bridge unchanged.
- D5 compile-only screen adaptations: ItemRow, ItemDetailView, AddItemView, EditItemView, ListDetailView item section. Behavior changes: the "Surprise Gift" toggle was removed from AddItemView (create has no `offList`); Description placeholders are now "Description" (server requires it); a force unwrap (`URL(string:)!`, `expectedUnitPrice!`) removed in each of two views.

## Files
Added (production): Features/Items/Repositories/{GeneratedClientItemRepository,MockItemData}.swift.
Changed (production): Features/Items/Repositories/{ItemRepository,MockItemRepository}.swift, Features/Items/Services/ItemService.swift, Features/Items/DataStores/ItemDataStore.swift, Features/Items/Components/ItemRow.swift, Features/Items/Views/{ItemDetailView,AddItemView,EditItemView}.swift, Core/Models/GiftItem.swift, App/InertRepositories.swift, ChristmasTrackerApp.swift, Features/Lists/Repositories/MockListRepository.swift, Features/Lists/Views/ListDetailView.swift.
Deleted: Features/Items/Repositories/NetworkItemRepository.swift.
Added (tests): Features/Items/{ItemWireSupport, GeneratedClientItemRepositoryTests, GeneratedClientItemRepositoryErrorTests, ItemMockSupport, MockItemRepositoryTests, GatedItemRepository, ItemServiceHarness, ItemServiceLoadTests, ItemServiceMutationTests, ItemServiceSessionSafetyTests}.swift, Features/Lists/MockListRepositoryCapabilitiesTests.swift.
Changed (tests): App/AppDependenciesResolveTests.swift (+5), Features/Authentication/SessionTeardownTests.swift (2 rewritten onto new signatures), Features/Items/LegacyGiftItemScanTests.swift (allowlist shrunk: App/InertRepositories.swift and PreviewContent removed; the four new-stack files are scanned for the token).
Docs: Docs/epics/I3c-items.md (Story C addendum), Docs/reports/I3c-2 (after-commit block), this report.

## Test arithmetic (source: command output)
1768 (end of Story B) + 153 new (GeneratedClientItemRepositoryTests 25, ErrorTests 29, MockItemRepositoryTests 23, ItemServiceLoadTests 22, MutationTests 19, SessionSafetyTests 26, MockListRepositoryCapabilitiesTests 4, AppDependenciesResolveTests 5) + 0 rewritten net - 0 deleted = 1921, matches the run. Package 212, release-script 92, destination-script 17.

## Verification (source: commands I ran)
Before the commit:
```
--- xcodebuild exit status: 0 ---
--- tests: 1921 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.019 seconds.
```
After the commit: filled in the Story D commit (commits are never amended).

Story B after-commit block (1fa75c7, source: commands run then): `--- tests: 1768 passed, 0 failed, 0 skipped ---`, package 212, release 92, destination 17, `=== verify: OK ===`, working tree clean.

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warnings: W1 `ItemRepository` is not an `-ing` name (pre-existing, fixed by spec); W2 mock methods lack `@Instrumented` (consistent with MockListRepository); W3 `private nonisolated let` on a MainActor class (build is clean); W4 Edit price seed uses `"\($0)"`.
- Acceptance-reviewer: APPROVE, no blocking defects. Carry-forward answers: `.validation` message from the envelope only (GeneratedClientItemRepository.swift:188, :211, :267) and the decode-failure fix at :230-233 never forwards a raw error; 401 vs 403 distinct (:38-41, :107-110, :177-180); 404 never forbidden; no blanket default (:216-218); CancellationError rethrown (:240-242); mutation errors never reach `loadError` (ItemService.swift:340, :349); generation and mutation guards (:172-174, :202-204, :234-236, :253-276, :287, :310); `GiftItem` absent from the four scan files; `legacyPurchaseItem` only at ItemDetailView.swift:63 and :68; no id/error/email/token logging; mock privacy at MockItemRepository.swift:56-169.
  Findings carried forward:
  1. MEDIUM, ItemService.swift:63-90: inside one session, a failed `loadItems(A)` after `loadItems(B)` started can set `loadError` to A's error and clear `isLoadingItems` while B loads. The items write is guarded; the error and flag are not. Not fixed here. Story D fixes it (compare `currentListId` in `recordLoadError`) and adds a list-switch test.
  2. MEDIUM, ItemDetailView.swift:103: `try? await deleteItem` then dismiss, so a failed delete is silent (inherited). `loadError` is read by no view yet. Story D surfaces both through the banner.
  3. LOW: status-level 429 carries `retryAfter: 0` (the real Retry-After arrives via `TrackerAPIError.rateLimited`). Untested: price above 999999.99 / three decimals at repository level, empty refresh over a populated cache, the `shouldRefresh` stale branch, and a dedicated test for both 400 and 422 decode-failure fix. Not added.
  4. LOW (W4): the Edit price field shows "12.5" not "12.50"; no phantom change is produced (compared as Decimal).
- Accepted: `updateItemStatus` not built (Gate 1 note); Edit/Delete visibility on the old screens is still status-based until Story D.

## Process notes
- First implementer run stopped on a test-file compile error (`ItemServiceHarness.swift` lacked `import Testing`); the test-writer added the line (only test change after the implementer started). One test failed on the first run (400 with no envelope message decoded to `.invalidResponse`); production fix in `itemFailure` (decode failure on 400/422 -> `.validation(message: "")`). Error signatures differed, so the stuck detector did not trigger.
- `NetworkItemRepository.swift` was deleted with `rm` (no edit tool can delete a file). No scratch scripts.

## Deviations, bugs, scope
- D1, D3, D4, D5 as above. No contract disagreement found; nothing added to Docs/contract-issues.md. No real bugs found in pre-existing code beyond the inherited silent delete (finding 2).
- Screenshot sanity check: not taken (compile-only view changes).

## Not done or partial
- The item screens are not yet rebuilt on capability flags and `ItemPermissions`; Edit/Delete visibility on them still derives from item status (Story D).
- Load errors and delete errors are not shown to the user yet (Story D banner).
- Findings 1 to 3 above are not fixed; finding 1 is scheduled for Story D.
- `GiftItem` still exists for the purchase screens (deleted in I4); `MockItemData` stays for purchase previews.
- L16 remains unconfirmed (D2).
