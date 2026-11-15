# PH1-3: Purchase History screen and entry points (story H3)

Branch `feat/ph1-purchase-history`. Pipeline: solo implementer (tests first), convention-reviewer (APPROVED, three
line-length warnings and two notes), acceptance-reviewer (APPROVED, non-blocking notes). Source-level review only:
no agent used the simulator.

## What changed

New, under `ChristmasTracker/ChristmasTracker/`:

- `Features/PurchaseHistory/ViewState/PurchaseHistoryScreenState.swift` (112): option lists (years: All years then
  the Statistics choices, always including the current filter year; shipping: All, Not tracked, Not shipped,
  Shipped, Delivered; recipients: All people then the model's options), menu titles, accessibility labels and
  values, and `PurchaseHistoryRoute` (year, year choices, optional recipient) with builders from the Statistics
  row and from a spend row (`SpendRowState.id` is the recipient id).
- `ViewState/PurchaseHistoryRowPresentation.swift` (52): item name ("Item" when blank), "For <name>", medium date,
  "Qty n" above 1, USD total from `Decimal` through `MoneyText`, one combined accessibility label.
- `Features/Items/Components/ShippingStatusStyle.swift` (43): token table for the four shipping statuses.
- `Features/PurchaseHistory/Views/`: `PurchaseHistoryView` (169), `PurchaseHistoryRowView` (88),
  `PurchaseHistoryFilterBar` (143), `PurchaseHistoryPreviews` (78, 8 previews: loaded, one person, first-page
  loading, empty none, empty no match, first-page failure, next-page failure, large type dark).
- `Features/Statistics/Views/PurchaseHistoryEntryRow.swift` (53, 2 previews).

Edited: `StatusDotLabel.swift` (63 to 84; `init(shipping:)` shares one private rendering, existing initializers and
tests unchanged), `StatsView.swift` (198 to 211; `historyRoute` state, `navigationDestination(item:)`, the
`onOpenHistory` closure passed down, the entry row at the end of the content for every kind),
`SpendByPersonView.swift` (102 to 112; each row is a plain `Button` calling `onSelect`, button trait, hint
"Opens purchase history for <name>", 44pt minimum height; `SpendRowView` itself unchanged).

Screen behavior: the model is built once in `.task` from the environment service; pull to refresh; loading
spinner; content; the two empty states (the "Clear filters" button is shown once: the filter bar hides its own in
the no-match state); first-page failure with `InlineErrorBanner` and Try Again; stale banners; footer spinner and
the "Couldn't load more. Try again." button row; a row opens the existing `ManagePurchaseView` through
`navigationDestination(item:)` with the row's purchase, item and list ids and the current user id, and
`onChange(of: openedPurchase)` calls `returnedFromPurchase()` when it becomes nil (finish or back button).
`sessionGeneration` changes call `reconcileSession()` and reload. ManagePurchaseView already marks the stats caches
stale after a delete, so this screen adds no second invalidation.

Tests (new, 7 files): option lists, menu text, row presentation, route builders (Statistics row passes the
selected year and no recipient; a spend row passes the selected year, the row id as recipient id and its name; a
same-name pair with different ids), the shipping style table, view source scans (tokens, bare numbers, AnyView,
lineLimit, force unwraps, one view per file, accessibility-size stacking present), and the Statistics wiring scan.

## Existing test edited

`ChristmasTrackerTests/Features/Items/DeletedLegacyNamesScanTests.swift` (`// EDITED (PH1-H3):`): the legacy name
`PurchaseHistoryView` was removed from `deletedNames` because the brief names the new screen the same. The
deleted-FILE list is untouched, so `Features/Purchases/Views/PurchaseHistoryView.swift` must still stay absent
(confirmed absent by both reviewers).

## Commands and raw output

Red run (before production code): only missing-symbol errors for the new types and their follow-on errors.
Attempt 1: 5045 passed, 3 failed (two scan-test mistakes of the implementer, one the existing test above).
Attempt 2 and the Orchestrator's run before this commit (`scripts/verify.sh`, filtered with grep):

```
--- tests: 5048 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.043 seconds.
=== verify: OK ===
```

`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.017 seconds.`

## Deviations and decisions where the brief was silent

- Shipping dot tokens: Not tracked `.border`, Not shipped `.textMuted`, Shipped `.statusShipped`, Delivered
  `.primary`. The brief says "`statusShipped` and neutral tokens"; `.primary` for Delivered is the brand token, a
  minor deviation (still a theme token, no raw color) that the acceptance reviewer accepted. Brian can swap it for
  a neutral token. The text label is always shown, so status is never color alone.
- `AppIcons` does not exist in this repo (CLAUDE.md names it); SF Symbols are written as strings the way
  `ProfileView` and `InlineErrorBanner` do (`bag`, `chevron.right`, `chevron.down`,
  `line.3.horizontal.decrease.circle`). `appBrand` (serif) is restricted by a scan to four files, so the empty
  states use the existing `EmptyStateView`, which already uses it.
- A year not in the choices is appended at the end of the year menu. A selected recipient id missing from the
  list reads "Person", never the id.
- Menus use `.buttonStyle(.bordered)` with a 44pt label (a hand-built surface capsule is forbidden by a scan).
- The row date and quantity share one line ("Jan 5, 2026 · Qty 2").
- Row layout uses `ViewThatFits` (side by side, falling back to stacked) and stacks outright at accessibility
  sizes; the filter menus sit in a horizontal scroll row and stack in a `VStack` at accessibility sizes.
- Previews use a preview-only loader; the "loading" preview waits an hour on purpose.
- Review warnings left as they are: three lines over 120 characters (`PurchaseHistoryFilterBar.swift:63`,
  `PurchaseHistoryRowPresentation.swift:32`, `PurchaseHistoryViewScanTests.swift:108`; all under 160), stale
  banners use the offset as identity (a handful at most), `onOpenHistory` has a no-op default that the wiring scan
  test guards, and the `showsClearButton` hiding is covered by source checks only.

## Not done or partial (not verifiable without the simulator; nobody saw one)

- The visual result of everything: `ViewThatFits` and stacking at accessibility sizes (no truncated amounts), light
  and dark, the filter bar scroll, previews (compiled, not rendered).
- VoiceOver on the spend row (one element, the old label, plus the button trait and the hint: wrapping
  `SpendRowView` in a `Button` is reasoned, not run; no test pins the old spend-row reading), on the history row,
  the filter menu values and the entry row.
- That the Delivered `.primary` dot is distinguishable from the Shipped dot in both color schemes.
- `Menu` and `Picker` selection with optional tags.
- Back-button and finish refresh without flicker; the stale banner on a failed pull to refresh; the footer spinner
  and the retry row at the end of a scroll; behavior on sign-out and sign-in; paging against the real API with
  more than 20 purchases.
- Known model limit: an empty first page that still carries a cursor shows a blank content state (documented in
  the model header; not expected from the real API).
