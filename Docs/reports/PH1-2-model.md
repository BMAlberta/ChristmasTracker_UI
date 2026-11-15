# PH1-2: Purchase History model (story H2)

Branch `feat/ph1-purchase-history`. Pipeline: solo implementer (tests first), then convention-reviewer (APPROVED)
and acceptance-reviewer (first review REJECTED on one point, fixed, re-reviewed by the same reviewer: APPROVED).

## What changed

New, under `ChristmasTracker/ChristmasTracker/Features/PurchaseHistory/`:

- `Domain/PurchaseHistoryRecipient.swift` (13 lines): id and name of a person in the recipient menu.
- `ViewState/PurchaseHistoryModel.swift` (311): `@MainActor @Observable`. Holds the filter, rows, next cursor,
  load phase (`loading`, `content`, `failed`), `isLoadingNextPage`, `isRefreshing`, `nextPageFailed`, the stale and
  failure banners, the recipient options and the empty-state kind. Events: `onAppear`, `loadNextPageIfNeeded`,
  `retryNextPage`, `refresh`, `tryAgain`, `select(year:)`, `select(shipping:)`, `select(recipient:)`,
  `clearFilters`, `returnedFromPurchase`, `reconcileSession`, `dismissStaleBanner`.
- `ViewState/PurchaseHistoryFailureBanners.swift` (45): failure to banner mapping through the shared
  `ScreenLoadPresentation` and `LoadBannerPresentation` (UX1a policy).

Behavior: one request token for first page, refresh and filter change (a result with an older token is dropped for
success and failure); at most one page request in flight (a refresh or filter change cancels it); a filter change
clears the rows at once, a refresh keeps them until the new first page replaces them (so a deleted purchase
disappears and a changed shipping status updates); a failed next page sets only `nextPageFailed` (no auto retry);
a failed refresh keeps the rows and shows exactly "Couldn't update. Showing saved data." for connectivity
failures; cancellation is silent; the model compares `service.sessionGeneration` on every event and resets to its
initial state when it changed; recipient options accumulate in order of first sighting with the preselected person
first and survive filter changes. The model logs nothing and does not import SwiftUI.

Tests (new folder `ChristmasTrackerTests/Features/PurchaseHistory/Model/`, 9 files, one type each, no sleeps, the
H1 gated loader): initial state, load, paging, refresh, filter, recipient options, session, source scan.
No existing production or test file was edited. The only edited tracked file is `Docs/reports/PH1-1-data.md`
(the verify lesson recorded in the previous commit's report).

## Commands and raw output

Red run (tests only): `scripts/test.sh` exit status 65, `--- tests: 0 passed, 0 failed, 0 skipped ---`, only
missing-symbol errors (`PurchaseHistoryRecipient`, `PurchaseHistoryModel`) and their follow-on errors.

First green run: `--- tests: 4987 passed, 0 failed, 0 skipped ---`.

After the review fix, before this commit (`scripts/verify.sh`, filtered with grep):

```
--- tests: 4992 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.031 seconds.
=== verify: OK ===
```

`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

## Review rejection and fix

The acceptance reviewer rejected the first version: a first-page failure that the shared policy sends to
"leave screen" (`notFound`) was dropped without a banner, so `loadPhase` stayed `.loading` and the spinner would
never go away (the model has no navigation channel). Fix (Code wrong, routed to the implementer): `notFound` is now
an ordinary failure on this screen (full error with Try Again when nothing is shown; the dismissible stale banner
with its own message over saved rows). Only the sign-in outcomes (`unauthorized`, `sessionEnded`) still show
nothing and leave the state alone, because the app-level sign-in owns the screen and a session end resets the
model. Tests added: `notFoundIsAFailure`, `notFoundRefreshIsStale`, `phaseNeverStuckLoading` (all non-sign-in
errors), `secondOnAppearWhileHeld`, `refreshOverRefresh`; `takeoverFailuresShowNothing` now covers only
`unauthorized` and `sessionEnded`.

## Deviations and decisions where the brief was silent

- `notFound` is a retryable failure, not a "leave screen" (above). The H3 view must not assume a leave-screen signal.
- The model keeps its extensions in the one file (the members they mutate are `private(set)`); the class body is
  under 200 lines, the file 311.
- `retryNextPage()` requests the next page whenever a cursor exists and nothing is in flight.
- `select(recipient:)` adds the person to the options if missing, so the selected person is always listed.
- A session reset also restores the initial filter (with the preselected person) and re-arms `onAppear`.
- For other categories over saved rows (rate limited, validation) the typed error's own message is shown, not the
  "Couldn't update" text, which the policy reserves for connectivity failures.

## Not done or partial

- Known limit, accepted and documented in the model header: a first page that is empty but carries a cursor shows a
  blank content state and never pages (no auto-paging, to avoid an endless loop against a misbehaving server).
  Not expected from the real API.
- No UI, previews, filter option lists, label builders or entry points yet (story H3).
- Nothing was run on a simulator or against the real API.
