# PH1: Purchase History

Branch `feat/ph1-purchase-history` (from master at a23cf53, the VER1 merge). Package brief:
`/Users/brian/Development/christmasTracker/prompts/mobile-ui/PH1-purchase-history.md` (Brian, 2026-11-15).

## Goal

iOS can record a purchase (I4a) and open and manage one the caller made (I4b, `ManagePurchaseView`), but no
screen lists the caller's purchases. The web has a `/purchases` page. This package adds the iOS equivalent:
a Purchase History screen, reachable from Statistics, listing the caller's purchases with year, recipient and
shipping filters and cursor paging, opening the existing purchase screen per row.

## Baseline (Step 0, 2026-11-15, branch clean at a23cf53)

- `scripts/verify.sh`: `--- tests: 4786 passed, 0 failed, 0 skipped ---`, TrackerAPI package tests
  `Test run with 212 tests in 16 suites passed`, `test-release.sh: 92 passed, 0 failed`,
  `test-destination.sh: 17 passed, 0 failed`, `=== verify: OK ===`.
- `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed`.

## Contract facts (contract/openapi.json, generated client in LocalPackages/TrackerAPI)

- Operation `listPurchases`: `GET /tracker/v2/purchases`, bearer auth. Generated types:
  `Operations.ListPurchases.Input` (`query: Operations.ListPurchases.Input.Query`) and
  `Operations.ListPurchases.Output` (`.ok` with `body.json` carrying `data: [Components.Schemas.PurchaseHistoryRow]`
  and `meta: Components.Schemas.PurchaseHistoryMeta`).
- Query parameters (all optional): `recipientId` (uuid string), `year` (integer, 1000 to 9999), `listId`,
  `itemId`, `shippingStatus` (`ShippingStatus`), `limit` (integer, 1 to 100, default 50), `cursor` (opaque
  base64 string, from `meta.nextCursor`, never constructed). The generated query types: `recipientId: String?`,
  `year: Int?`, `shippingStatus: Components.Schemas.ShippingStatus?`, `limit: Int?`, `cursor: String?`.
  This package sends `year`, `recipientId`, `shippingStatus`, `limit` and `cursor` only. Unset filters send nothing.
- Documented responses: 200, 400, 401, 403, 404, 429, 500 (plus the generated `undocumented`).
- `PurchaseHistoryRow` (all required): `id`, `item {id, name, imageUrl?}`, `list {id, name, year}`,
  `recipient: PersonRef {id, displayName}`, `quantity` (>= 1), `totalCost` (Money, a number), `purchasedAt`
  (date-time), `shippingStatus` (`NOT_TRACKED`, `NOT_SHIPPED`, `SHIPPED`, `DELIVERED`).
- `PurchaseHistoryMeta` = `Meta` + `filteredCount`, `filteredTotal` (Money), `nextCursor` (string or null; null on
  the last page). Cursor shape: opaque string in `meta.nextCursor`.
- Page size chosen: `limit = 20` (the web's `DEFAULT_LIMIT`; the contract default is 50). With the mock at 30
  rows this pages in two.
- Ordering: the contract and the client guide (section 5.2) do not state an order. The client shows the
  server's order and never re-sorts. The brief expects newest first; this is unverified and goes to the handoff
  as an open risk (not a contract issue: the contract is silent, not contradicted).
- Where the brief and the contract differ: the brief says "when `item` is absent show 'Item'". In the contract
  `item` and `item.name` are required, so `item` cannot be absent. The "Item" fallback applies only to a blank
  name. The brief says money comes through "the existing conversion helpers": `doubleToDecimal` (TrackerAPI
  Money helpers) is used, and NaN or infinity throws `invalidResponse`.
- No contract gap for the row: item name, recipient name and id, list id and year are all in the response, so no
  per-row fetch is needed and no `Docs/contract-issues.md` row is added.
- Row to `ManagePurchaseView`: needs `purchaseId` (`id`), `itemId` (`item.id`), `listId` (`list.id`),
  `currentUserId` (`authenticationService.currentUser?.id`, as `ItemDetailView` does).
- `SpendRowState.id` is `spend.recipientId` (StatsScreenState.swift:53), so the Statistics models already carry
  the recipient id on the spend row. Decision 1 holds; no STOP.

## Decisions (from the package brief; numbering kept)

1. Entry points: a "Purchase History" card row (chevron, like the Profile rows) at the bottom of the Statistics
   scroll content when content shows; each "Spend by person" row opens the history for that person and the
   selected year. No tab.
2. Screen "Purchase History" pushed on the Statistics stack; filter bar: Year (Statistics year choices plus
   "All years"), Shipping (All, Not tracked, Not shipped, Shipped, Delivered), Recipient (All people plus the
   people seen in loaded rows plus the preselected one). "Clear filters" when any filter is not at its default.
3. Rows: item name, "For <recipient>", `purchasedAt` (medium date), "Qty n" above 1, total (existing
   `MoneyText`), shipping via `StatusDotLabel`; one combined accessibility element; tap opens
   `ManagePurchaseView`.
4. Server order, no re-sort; first page on appear; next page when the last row appears and a cursor exists, with
   a footer spinner; one page request in flight at most; a filter change cancels, clears and reloads; a stale
   result (older filter or refresh) is dropped by a request token; pull to refresh reloads the first page.
5. States: loading, content, empty ("No purchases yet." with no filters, "No purchases match these filters."
   plus Clear filters otherwise), failures per UX1a (`LoadFailurePolicy`, `InlineErrorBanner`; next-page row
   "Couldn't load more. Try again."; refresh failure "Couldn't update. Showing saved data.").
6. Changes on the purchase screen show on return: refresh the first page; delete already marks the stats caches
   stale through `PurchaseDetailModel` and `PurchaseRefreshRunner` (`invalidateSpending`), so the history adds
   no second invalidation. A shipping or notes change does not touch spending.
7. Session safety as `StatsService`/`PurchaseService`: generation guard, cancellation silent, dropped on
   session end, registered with the session manager. Nothing on disk. Nothing sensitive in logs.
8. Data layer: `PurchaseHistoryLoading`, `GeneratedClientPurchaseHistoryRepository`,
   `MockPurchaseHistoryRepository` (30 rows, mixed statuses and recipients).
9. Out of scope: contract change, editing from the list, search, sort controls, export, totals (the
   `filteredCount` and `filteredTotal` meta values are decoded and dropped; the web's summary line is
   deliberately not matched), a tab, widgets, changes to the record flow.

## Web parity

Matched: year filter (year or all; web default is the current year, iOS default is the Statistics year),
shipping filter, recipient filter (web: only via click-through from Statistics, iOS adds a menu), cursor paging,
click-through from "Spend by person", row content (item, recipient, date, total, quantity, shipping), empty and
error states, retry. Deliberately omitted or different: list filter chip and the list name line (not in the
brief), item thumbnails, the "N purchases, $X total" summary, inline "Update shipping" and "Delete" buttons
(iOS opens the existing `ManagePurchaseView`, which owns shipping, notes and delete), "Load more" button (iOS
loads on scroll).

## Gate 1 spec

### Types (new, nonisolated, Sendable)

- `PurchaseHistoryFilter { year: Int? ; recipientId: String? ; shippingStatus: PurchaseShippingStatus? }`
  (`year == nil` is all years) with `isDefault(defaultYear:)`.
- `PurchaseHistoryRow: Identifiable, Equatable { id, itemId, itemName, listId, recipientId, recipientName,
  purchasedAt, quantity, totalCost: Decimal, shippingStatus: PurchaseShippingStatus }`.
- `PurchaseHistoryPage { rows: [PurchaseHistoryRow]; nextCursor: String? }`.
- `PurchaseHistoryError` (typed, with `userMessage`): unauthorized, forbidden, notFound, validation,
  rateLimited(retryAfter), network, server, invalidResponse, sessionEnded.

### New interface (yes: this is a full pipeline story for H1)

```swift
nonisolated protocol PurchaseHistoryLoading: Sendable {
    func loadPage(filter: PurchaseHistoryFilter, cursor: String?) async throws -> PurchaseHistoryPage
}
```

`PurchaseHistoryService` (`@MainActor @Observable`, `SessionClearable`): `loadPage(filter:cursor:) async throws ->
PurchaseHistoryPage` runs the repository call through `perform` (cancellable), captures `generation` before the
first await, and throws `CancellationError` for a cancelled call or an ended session; typed
`PurchaseHistoryError` otherwise; manual Sentry span (actor-isolated, with the usual comment); publishes no
data and has no cache. `sessionGeneration` is readable. `clearForSession()` bumps the generation and cancels
in-flight calls.

`PurchaseHistoryModel` (`@MainActor @Observable`): filters, rows, `nextCursor`, phase (`loading`, `content`,
`failed`), banners, `isLoadingNextPage`, request token; events `onAppear`, `loadNextPageIfNeeded(rowId:)`,
`refresh`, `tryAgain`, `retryNextPage`, `select(year:)`, `select(shipping:)`, `select(recipient:)`,
`clearFilters`, `returnedFromPurchase`, `sessionEnded`; derived `recipientOptions`, `emptyKind`.

### Acceptance criteria

- **H1 (data layer).** AC1 the query sent equals the filter (year, recipientId, shippingStatus, limit 20, cursor)
  and unset filters send nothing; AC2 200 with and without `nextCursor` maps to a page; an empty page maps to an
  empty page; AC3 each documented status (400, 401, 403, 404, 429, 500), an undocumented status, a transport
  error and an undecodable body map to a typed `PurchaseHistoryError`; AC4 cancellation passes through unchanged;
  AC5 money is `Decimal` (19.99 stays 19.99; NaN throws `invalidResponse`); AC6 a row maps all fields, a blank
  item name becomes "Item" at presentation, `purchasedAt` is kept as sent; AC7 a result after the session ended
  changes nothing and raises no error; AC8 the new files log nothing sensitive (source scan); AC9 the service is
  registered with the session manager (`makeProductionClearables`, index 10) and the environment key, the real
  composition and the mock composition are wired; `@Instrumented` on the repository method.
- **H2 (model).** The behavior table of the brief (first load success and failure; next page appends and stops
  at no cursor; a second next-page call while one is in flight is ignored; next-page failure keeps rows and
  shows the small row; refresh failure keeps rows and shows the stale banner; filter change cancels and drops
  the old result; clear filters; recipient options deduplicated, stable order, preselected one kept with no
  rows; the two empty kinds; a deleted purchase is gone after the refresh; a result after the session ended
  changes nothing). No sleeps.
- **H3 (screen).** The filter bar, rows, states and previews of decisions 2, 3, 5; the row opens
  `ManagePurchaseView`; the Statistics row and the tappable spend rows (one accessibility element, button
  trait, hint "Opens purchase history for <name>") pass the selected year and the recipient id; at
  accessibility sizes menus and row parts stack and the amount is never truncated; source scans (no raw colors,
  no bare numbers, no `AnyView`, one view per file).

### Pipeline weight

H1: full (repository and generated-client layer, session safety). H2: solo implementer with failing tests first,
then both reviewers (stale-result and session logic). H3: solo implementer, convention reviewer, and the
acceptance reviewer over the whole package diff.

## Inventory

New (all under `ChristmasTracker/ChristmasTracker/`):

- `Features/PurchaseHistory/Domain/`: `PurchaseHistoryFilter.swift`, `PurchaseHistoryRow.swift`,
  `PurchaseHistoryPage.swift`, `PurchaseHistoryError.swift`.
- `Features/PurchaseHistory/Repositories/`: `PurchaseHistoryLoading.swift`,
  `GeneratedClientPurchaseHistoryRepository.swift`, `PurchaseHistoryMapping.swift`,
  `MockPurchaseHistoryRepository.swift`.
- `Features/PurchaseHistory/Services/PurchaseHistoryService.swift`.
- `Features/PurchaseHistory/ViewState/`: `PurchaseHistoryModel.swift`, `PurchaseHistoryScreenState.swift`
  (option lists, label builders, empty kind).
- `Features/PurchaseHistory/Views/`: `PurchaseHistoryView.swift`, `PurchaseHistoryRowView.swift`,
  `PurchaseHistoryFilterBar.swift`, `PurchaseHistoryPreviews.swift`; `Features/Statistics/Views/
  PurchaseHistoryEntryRow.swift`.
- `Core/Extensions/EnvironmentValues+PurchaseHistoryService.swift`.
- `Features/Shared/ErrorPolicy/LoadFailure+PurchaseHistory.swift` (init from `PurchaseHistoryError`, built on the
  internal `init(category:source:retryAfter:plainMessage:)`).
- Tests under `ChristmasTrackerTests/Features/PurchaseHistory/` (one type per file) and `.../App/`.

Touched (length at start; limits: warning 400, error 600):

| File | Lines | Change |
|---|---|---|
| `ChristmasTrackerApp.swift` | 533 | `AppDependencies.purchaseHistoryLoader` (3 inits), service state, clearables argument, environment line: about +12, stays under 600 |
| `Features/Authentication/Services/SessionClearable.swift` | 43 | one parameter, one array entry (index 10) |
| `App/InertRepositories.swift` | 212 | `InertPurchaseHistoryLoader` |
| `Features/Shared/ErrorPolicy/LoadFailureCategory.swift` | n/a | add `LoadSource.purchaseHistory` (check exhaustive switches and tests) |
| `Features/Statistics/Views/StatsView.swift` | 198 | entry row plus destination: small |
| `Features/Statistics/Views/SpendByPersonView.swift` | 102 | tappable rows, trait, hint |
| `Features/Items/Components/StatusDotLabel.swift` | 63 | `init(shipping:)` (extended minimally; tests kept) |
| `Features/Items/Components/ItemStatusStyle.swift` | 140 | only if the shipping style needs a new pure type; otherwise a new file |

Not touched: `StatsScreenModel.swift` (408, over the warning line), `ListService.swift` (1130),
`StatsScreenState.swift`, anything under `.claude/`, `contract/`, `LocalPackages/`, `*.pbxproj`, synced Docs.

Expected edits to existing tests: the three that pin the clearables list at 10
(`PurchaseServiceClearableTests`, `PurchaseServiceManagementClearableTests`, `BudgetCompositionTests`) change to
11 and to the new parameter; every such edit is listed in the H1 report as EDITED.

## Risks

- Server ordering is undocumented (above).
- Returning from the purchase screen refreshes the first page, so a user deep in the list returns to the top.
- `PBXFileSystemSynchronizedRootGroup` is assumed for new files (no pbxproj edits allowed); the H1 build will
  show whether new files are picked up.
