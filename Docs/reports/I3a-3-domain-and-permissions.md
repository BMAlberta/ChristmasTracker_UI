# I3a-3: Flag-driven list models and the single permissions function

Branch feat/i3a-lists. Gate 1: Docs/epics/I3a-lists.md (L1 and its addendum). Path: full pipeline (capability-flag-driven).

## What changed
- New Core/Models (all `nonisolated`, Sendable): `ListCapabilities` (twelve booleans), `ListPermissions` (+ `ListCategory`), `ListRoleBadge` (the only production file that reads `.myRole`, for the badge title and tone, and for mapping the wire role).
- `GiftList` and `ListDetail` rebuilt: capabilities, memberCount, optional itemCount/purchasedCount, `members: [ListMember]?` (nil when absent), `progress` only from present counts with itemCount > 0. Removed: isOwner, canEdit, description, totalBudget, totalSpent (the generated ListSummary/ListDetail have no description or money fields; this is why the brief's "if those fields exist" clause dropped them). `ListVisibility` gains `.friendsOnly`; new `ListMemberRole`, `ListMemberStatus`, `ListMember`, `ListPerson`, `CreateListInput`, `UpdateListInput` (domain values, no wire concerns).
- `Features/Lists/Repositories/ListMapping.swift`: pure `mapListPerson`, `mapListSummary`, `mapListDetail` from the generated types. The six original flags come from `summary.value2` (CapabilityFlags), the six new flags from `summary.value1` (read from the code by the acceptance reviewer and checked against contract/openapi.json). Enum mappings are exhaustive switches with no default.
- Consumers adapted minimally so the app builds (the full redesign is L3): MockListRepository (deterministic data, every flag scenario available via `init(withMockData:includeAllScenarios:)`; the default seed stays at 3 lists because existing tests need it), MockData, ListDataStore, ListService (inputs, category filter from flags, log lines scrubbed of names and ids, manual Sentry spans `service.lists.createList/updateList/deleteList` with the explaining comment), ListDetailView, EditListView, CreateListView (recipient is the signed-in user's id; description, metadata and recipient-name inputs removed; large commented-out block removed), DashboardView, ListPreviewCard.
- Deleted wire types: `CreateListRequest`, `UpdateListRequest`, `ListResponse<T>` (old ListDetail.swift), `ListsData` (old NetworkListRepository.swift and DashboardListResponse.swift), `DashboardListsResponse`. Deleted files: Features/Lists/Repositories/NetworkListRepository.swift, Features/Dashboard/ViewModels/DashboardListResponse.swift, Features/Dashboard/ViewModels/DashboardViewModel.swift (only contained dead `DashboardViewModel_old`; no references, confirmed by grep and by the acceptance reviewer). The local `EmptyData` copies in the Purchase and Item repositories are separate and untouched. No test of NetworkListRepository existed, so no test was deleted for that.
- MockAPIClient.withMockData() no longer registers a `/lists` response.

## Files
Added: Core/Models/{ListCapabilities,ListPermissions,ListRoleBadge}.swift; Features/Lists/Repositories/ListMapping.swift; tests Features/Lists/{ListFixtures,ListMappingTests,ListSourceScanTests}.swift, Core/{ListPermissionsTests,GiftListProgressTests,ListRoleBadgeTests}.swift.
Changed: GiftList.swift, ListDetail.swift, ListRespository.swift, MockListRepository.swift, MockData.swift, ListDataStore.swift, ListService.swift, ChristmasTrackerApp.swift, MockAPIClient.swift, ListDetailView.swift, EditListView.swift, CreateListView.swift, DashboardView.swift, ListPreviewCard.swift; tests ListServiceTests, LogoutPathTests, SessionTeardownTests; Docs/epics/I3a-lists.md (Gate 1 addendum).
Deleted: NetworkListRepository.swift, DashboardListResponse.swift, DashboardViewModel.swift.

## Test arithmetic
App: 684 (after H2) + 63 new + 1 added in ListServiceTests = 748 (verify: `--- tests: 748 passed, 0 failed, 0 skipped ---`). Counted by `@Test` declarations in the new files: ListMappingTests 25, ListPermissionsTests 17, GiftListProgressTests 8, ListRoleBadgeTests 6, ListSourceScanTests 7 = 63; ListServiceTests 13 -> 14 (+1: testFilterSplitsByFlagsNotRole). A parameterized test is one entry. Rewritten (same count): testCreateList, testLoadListsAfterCreateReflectsNewList, testUpdateList (new input types), testFilterOwned and testFilterShared (flag-based using ListPermissions category instead of myRole, names changed), makeSampleList in LogoutPathTests, FastMockListRepository and two fetch tests in SessionTeardownTests (fixed fixture lists instead of MockListData.allLists). Deleted: none.
Package: 212 -> 212 (unchanged).

## Raw outputs (commands run by the Orchestrator after the last change)
```
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: unit tests ===
--- tests: 748 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Before (state after H2, command run): 684 app, 212 package, verify OK.

## Truth table reduction
ListPermissions depends on the twelve flags (plus counts for the count functions). The test enumerates all 2^12 = 4096 flag combinations, each combined with seven count pairs, against an oracle written separately in the test. The reviewer notes the oracle restates the same one-line formulas (each named result mirrors one flag, category = any management flag), which is acceptable because the logic is a direct mirror. Named scenario tests (blind owner, blind co-owner, viewer, public non-member, archived) are hand-written independently.

## Scan test
`ListSourceScanTests` strips comments and then fails on `\.myRole\b`, `\bisOwner\b`, `\bcanEdit\b` in Features/Lists, Features/Dashboard, PreviewContent and Core/Models/{GiftList,ListDetail,ListCapabilities,ListPermissions}.swift (ListRoleBadge.swift exempt for `.myRole`), asserts ListPermissions/ListCapabilities never mention myRole, and asserts NetworkListRepository and the hand-written wire types are gone from app sources. Known limit: a string literal containing `//` hides the rest of its line from the scan.

## Gate 2
- Convention-reviewer: first REJECTED (hard block): ListService createList/updateList (and deleteList) lacked the manual Sentry span CLAUDE.md requires for actor-isolated service methods; a comment alone does not satisfy it. Routed to the implementer; fixed with `SentrySDK.startTransaction` spans with fixed names, `defer { finish }`, the comment, and a "mock intentionally uninstrumented" comment. Re-check by the same reviewer: APPROVED.
- Acceptance-reviewer: APPROVED. Evidence: `.myRole` read only in ListRoleBadge.swift:28, :32, :51; no isOwner; remaining `canEdit` hits are item/purchase (GiftItem.swift:54, ItemDetailView, PurchaseDetailView); mapping lines 33 to 38 (original six from value2) and 39 to 44 (new six from value1); `members` maps with `.map` so absent stays nil (ListMapping.swift:55); views require `showsCounts` before any count, ring or stats card (ListPreviewCard.swift:27, ListDetailView.swift:63); CreateListView uses the signed-in user's id (lines 187 to 194).
- The reviewer could not inspect `.claude/` directly (a hook blocked that command); `git status` shows no tracked change there.
- Stuck detector: one rejection, fixed on the second attempt.

## Decisions and advisories
- Legacy raw colors (`.white`, `Color.red`, `.cornerRadius(12)`) in re-indented lines of ListDetailView's actions section are deferred to L3 (that screen is rebuilt there). Existing views also keep legacy `.appXxx`/`Color.*Color` styles until L3.
- Advisory A (defence in depth): the mapper passes itemCount/purchasedCount through even if canSeeGiftActivity were false, and `progress` ignores the flag. Views are safe because they go through ListPermissions and the server omits the counts. Planned for L2: the repository mapping nils the counts when canSeeGiftActivity is false.
- Advisory B: the Items section of ListDetailView shows "No items yet" whenever the received item list is empty, which may be wrong or hint at hidden content for a blind owner. This is item behaviour (package I3c); check Docs/privacy-matrix.md then. Not a list-count leak.
- The brief says "thirteen" booleans; the guide has twelve (isRecipient, canSeeGiftActivity, canPurchase, canAddOffList, canSeeOffList, canCreateItem, canSeeMembers, canEditList, canDeleteList, canManageMembers, canSetCoOwner, canLeaveList). The struct holds twelve; myRole is display only.
- `CreateListInput.visibility` is optional (`ListVisibility?`), as is `UpdateListInput.visibility`.
- Create visibility picker still offers only Private, Public and Invite Only (Friends Only is on the edit picker); L3 decides.
- The pre-existing `Task.sleep` in ListServiceTests.testRefreshLists is untouched here; L2 rewrites the service tests with deterministic handshakes.
- Sequencing deviation: the brief puts NetworkListRepository's deletion in L2, but its wire types had to go in L1 for the app to build. L1 therefore deleted it and composed real mode on a placeholder (below); L2 replaces the placeholder.
- Process deviations: the implementer used one scratch `python3 -I` heredoc to batch-edit ListDetailView.swift and `git rm` (deletions are staged); all other edits used Edit/Write. These deviate from the command habits in CLAUDE.md.

## Not done or partial
- **TEMPORARY, NOT SHIPPABLE:** ChristmasTrackerApp.swift real mode (both the `makeReal` path and the legacy `make()` real branch) uses `MockListRepository(withMockData: false)` (an empty in-memory list repository) with a `// TEMPORARY until I3a-L2` comment and no `#if DEBUG` guard. Real mode shows no lists and writes go to memory until L2 lands. This branch must not be merged or released before L2.
- No new screens or view-state functions (L3). Archived lists are not hidden yet (L2). ListError not expanded yet (L2).
- Real-mode (server) behaviour not exercised; those checks are Brian's (L4).
