# I3c-2: Item domain, errors, and the permissions function (Story B)

Branch: feat/i3c-items. Path: full pipeline (capability-flag-driven UI and the model layer). Gate 1: Docs/epics/I3c-items.md "Story B" and "Story B Gate 1 addendum". Applied deviations: D1 (`ListItem` plus the legacy `GiftItem` bridge, per Brian's answer), D3 (additive: deletions land in C and D so every commit builds), D4 (the server requires a description). The commit also carries the Story A report's after-commit verification block (commits are never amended).

## What changed
- `ListItem`, `ListItemPerson`, `ListItemPurchaseSummary` (Decimal money, optional `updatedAt`, `purchases`, `totalQuantityPurchased`), `CreateItemInput` (no offList member), `UpdateItemInput` (changed fields only, `isEmpty`) in Core/Models/ListItem.swift.
- `ItemPermissions` (Features/Items/ViewState): the one flag-derived rights function: `canAddItem`, `canSeeGiftActivity`, `canSeeOffListItems`, `canPurchase` (the flag), `showsOffListNotice`, `canEdit`/`canDelete`, `visibleItems`. No role read, no list-status input. Comments cite the privacy matrix and the missing per-item flags.
- View-state functions: `ItemRowState`, `ItemListState`, `ItemSectionState`, `ItemDetailState`, `PurchaseRowState` (status marker, completion, progress, remaining quantity, purchases and `updatedAt` only when `canSeeGiftActivity`; off-list only when `canSeeOffList`; identical empty copy for everyone; price via `Decimal.FormatStyle.Currency`).
- Forms: `ItemFormValidation` (name 1 to 200, description 1 to 2000, url and imageUrl absolute http(s) or empty, price strict `digits[.d|.dd]` parsed with en_US_POSIX into `Decimal`, 0 to 999999.99, quantity 1 to 999, priority 1 to 10), `makeCreateInput`, `makeUpdateInput` (only changed fields; clearing an optional field is not a change), `ItemFormCopy.offListSentence`.
- `ItemMapping.swift`: `mapListItem` for the generated `Item` and the `getItem` DataPayload (`purchases`/`totalQuantityPurchased` only from `value2`); money through `doubleToDecimal`; NaN or infinite throws `ItemError.invalidResponse`; absent optionals stay nil.
- `ItemError` (declared in MockItemRepository.swift, not ItemRepository.swift as Gate 1 assumed; the scope was widened by the Orchestrator for this enum only): now `nonisolated`, `Equatable`, `Sendable`; new cases forbidden, validation(message:), invalidPrice, cannotDeleteWithPurchases, rateLimited(retryAfter:), sessionEnded, network, invalidResponse, server; `userMessage`; the seven old cases (incl. purchaseFailed) stay until Story C.
- Legacy bridge in Core/Models/GiftItem.swift: `ListItem.legacyPurchaseItem: GiftItem` (LEGACY, delete in I4; the only Double money path, via `decimalToDouble`; `updatedAt ?? createdAt`; `purchases: nil`). `GiftItem` itself is marked LEGACY and otherwise untouched.
- Scans: `.myRole` scan extended to Features/Items and Core/Models/ListItem.swift (`noRoleReadsInScope`, additive); `LegacyGiftItemScanTests` (the token `GiftItem` is forbidden outside Features/Purchases, GiftItem.swift and a documented TRANSITIONAL allowlist; the five new files must exist and be clean); `CreateItemInputShapeTests` (Mirror labels and a text scan: no offList).

## Files
Added (production): Core/Models/ListItem.swift; Features/Items/ViewState/{ItemPermissions,ItemViewState,ItemFormValidation}.swift; Features/Items/Repositories/ItemMapping.swift.
Changed (production): Core/Models/GiftItem.swift (import, LEGACY comments, bridge); Features/Items/Repositories/MockItemRepository.swift (the `ItemError` enum only).
Added (tests, ChristmasTrackerTests): Features/Items/{ItemFixtures (helper), ItemSourceScanSupport (helper), ItemPermissionsTests, ItemMappingTests, ItemListStateTests, ItemRowStateTests, ItemDetailStateTests, ItemFormValidationTests, ItemInputBuildingTests, ItemErrorTests, LegacyGiftItemScanTests, CreateItemInputShapeTests}.swift; Core/GiftItemLegacyBridgeTests.swift.
Changed (tests): Features/Lists/ListSourceScanTests.swift `noRoleReadsInScope` (a second block was appended; nothing removed or weakened). Deleted: none.
Docs: Docs/epics/I3c-items.md (Story B addendum, D3, D4, the ItemError location correction), Docs/reports/I3c-1-archived-lists.md (after-commit block).

## Test arithmetic (source: command output and grep of `@Test`)
1619 (end of Story A) + 149 new (ItemPermissionsTests 13, ItemMappingTests 17, ItemListStateTests 17, ItemDetailStateTests 23, ItemRowStateTests 10, ItemFormValidationTests 20, ItemInputBuildingTests 24, ItemErrorTests 11, LegacyGiftItemScanTests 5, CreateItemInputShapeTests 2, GiftItemLegacyBridgeTests 7; a parameterized test counts as one) + 0 rewritten (the one extended scan test keeps its count) - 0 deleted = 1768, which matches the run. (The test-writer's own report said 147; the grep gives 149 and the run agrees.) Package suite 212 (unchanged), release-script 92, destination-script 17.

## Truth-table reduction (ItemPermissionsTests header)
`canEdit`/`canDelete` depend on (canCreateItem, canAddOffList, item.offList, creator is the current user / someone else / nil user id). canSeeGiftActivity and canSeeOffList only drive display outputs, so the full 2^4 flag grid x offList x 3 creator relations is checked against a boolean oracle, plus the seven named personas (owner, blind owner, co-owner, blind co-owner, MEMBER, VIEWER-role member, PUBLIC non-member) on an active and an archived list with identical results. The acceptance reviewer notes the oracle shares the rule's boolean structure; its independence comes from the matrix-derived persona fixtures with literal expectations.

## Verification (source: commands I ran)
Before the commit:
```
--- tests: 1768 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.      (inside verify)
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI":
Test run with 212 tests in 16 suites passed after 0.017 seconds.
```
After the commit (1fa75c7; added in the Story C commit, since commits are never amended):
```
--- tests: 1768 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Working tree clean at 1fa75c7.

## Gate 2 (real verdicts, written after the reviews)
- Convention-reviewer: APPROVE, no hard blocks. Warnings: `ItemDetailState.init` body about 41 lines (one over the 40 warning); lines over 120 characters in ItemMapping.swift (:35, :68) and several test files (all under 160); stale "fails today" comments in ItemErrorTests.swift and GiftItemLegacyBridgeTests.swift; `import TrackerAPI` in GiftItem.swift only for the LEGACY bridge (acceptable, deleted in I4); new top-level declarations rely on the internal default like the existing code. Carried to Story C: `.validation(message:)` surfaces a server message, so the repository must feed it only the contract's validation message (never a raw error, id, or email).
- Acceptance-reviewer: APPROVE, no blocking defects. Findings: (1) MEDIUM, Orchestrator decision: the brief's off-list rule ignores flags, so a VIEWER or PUBLIC persona whose id equals an off-list item's creator would show Edit/Delete while the matrix says 403 (only reachable for a member demoted after creating an item; the server hides off-list items from those personas). DECISION: keep the brief's literal rule (Brian's stated spec); the reviewer's tightening (`canAddOffList && creator == me`) is recorded for Brian: it would also remove Edit/Delete from a member promoted to co-owner, which the matrix does not clearly say the server refuses. The persona expectation `editsOwnOffListItem: true` for viewer and public in ItemPermissionsTests documents this and is not a claim of matrix conformance. (2) LOW test-writer: the oracle is partly independent. (3) LOW test-writer: untested invalid prices (".5", "5.", "+5", interior space, Unicode digits, "0.001", "999999.991") and the padded-valid case through `validate`; code reviewed and rejects them. (4) LOW: `remainingQuantity` is unclamped (over-purchase gives a negative number); Story D must not print a negative remaining. (5) LOW: defensive filtering lives only in the view-state types; the Story C service and Story D views must read items only through them. `legacyPurchaseItem` passes status unfiltered and is safe only because the purchase entry is gated on `canPurchase`. (6) LOW: `.unauthorized` has two texts (legacy `errorDescription`, new `userMessage`); Story C must use `.forbidden` for 403 and `.unauthorized` only for 401. (7) LOW: the scan allowlist does not force itself to shrink; Stories C and D shrink it and Story D asserts the final list.
- No rework loop was needed. None of the LOW items were fixed in this story (carried to C and D as stated).

## Deviations, bugs, scope
- D1, D3, D4 as above. `ItemError` lives in MockItemRepository.swift (scope widened for that enum only). `userMessage` wording for `.unauthorized` ("Your session has expired. Please sign in again.") and `.sessionEnded` ("You were signed out. Please sign in again.") is the implementer's choice. `updatedText` is "Updated " plus a relative date string. Quantity and priority texts are "Qty N" and "Priority N".
- The Story A report received its after-commit block in this commit.
- No real bugs found in existing code. No contract disagreement found.
- Screenshot sanity check: not applicable (no views).

## Not done or partial
- The item screens, repository, service and mock do not use these types yet (Stories C and D). The old stack is intact by design (D3), so the end-state deletions in the task text are not done yet: CreateItemRequest, UpdateItemRequest, ItemsResponse, ItemData, ItemResponse, the old ItemError cases, and the `GiftItem` computed members `isAvailable`, `isPurchased`, `canEdit` (C and D).
- The LOW test gaps above (price edge cases, oracle independence, allowlist-shrink guard) were not added.
