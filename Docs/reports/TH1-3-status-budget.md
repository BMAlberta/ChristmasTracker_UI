# TH1-3: Status and budget styles

Commit: "TH1: draw item status and budget state from the theme". Pipeline: full (Gate 1 in Docs/epics/TH1-theme-pass.md; isolated test-writer, implementer, convention-reviewer, acceptance-reviewer, in that order).
SwiftUI guidance (swiftui-expert-skill rules passed to the implementer in the brief): modern APIs, private @State and @ScaledMetric, stable ids, no AnyView, Dynamic Type text styles, DesignSystem tokens only, previews for new views.

## After-commit run of the previous commit (TH1-2, 2a64e2f), taken by running the commands
```
--- tests: 4453 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What changed
- Status: pure `StatusKind` (available, partial, purchased, shipped, wrapped, gifted; from `ItemStatus`, and `init?(shipping:)` where only `.shipped` maps) and `StatusStyle` (fill token, short label, accessibility label "Status: <name>", and `label(for: ThemeMode)` backed by the contrast-tested `ThemeStatusLabelTable`). `ItemStatusStyle.swift` is the style layer and holds the only `.white` (the ThemeLabel-to-Color mapping). `ItemStatus.color` (system colors) and `tokenColor` are deleted; `displayName` and `icon` stay (`icon` is now unused).
- `StatusPill` (capsule, short label in the label color for the current color scheme, one accessibility element, wraps) replaces the leading icon and the caption in `ItemRow` and the `Label` in the item detail header. It shows for every non-nil marker, including Available. The marker is still nil for viewers who may not see gift activity, so blind viewers and viewers see no pill.
- `StatusDotLabel` (8-point @ScaledMetric dot plus the label in the primary text color, one accessibility element) is built, previewed and unit tested, but has NO production caller: the inventory found no compact status place (the purchase rows show no status; the shipping control is an input Picker). This is the decision for Brian in the Gate 1 spec and in the handoff.
- Budget: `BudgetLevel` (under, nearLimit, over), `BudgetStyle`, and `BudgetStateStyle` with the named constant `nearLimitThreshold: Decimal = 0.9`. Rules: over when spent > limit; under when the limit is 0 or less (and not over); near when spent >= 0.9 x limit (exactly 90 percent and exactly at the limit are near); otherwise under. `BudgetCardState` and `BudgetPersonRowState` carry `level`; `isOver` is `level == .over`. Wording: "Over by X", "X remaining", and new "Near limit. X remaining". The person row accessibility label includes the status text.
- `BudgetCardView`: the progress bar tint comes from the level token (Evergreen, Warm Gold, Cranberry); TEXT uses the primary text color for under and near (gold text fails contrast) and the budgetOver token for over (the accepted dark-mode exception). The words always render. `BudgetWarningPanel` and the purchase confirmation flow are untouched.

## Files
Added: Features/Budgets/ViewState/BudgetStateStyle.swift; Features/Items/Components/StatusPill.swift, StatusDotLabel.swift; tests Features/Items/StatusStyleTests.swift, StatusStyleScanTests.swift; Features/Budgets/BudgetStateStyleTests.swift, BudgetCardStateLevelTests.swift, BudgetStyleScanTests.swift.
Changed: Core/Models/ItemStatus.swift; Features/Items/Components/ItemStatusStyle.swift, ItemRow.swift; Features/Items/Views/ItemDetailView.swift; Features/Budgets/ViewState/BudgetCardState.swift; Features/Statistics/Views/BudgetCardView.swift; tests Features/Budgets/BudgetCardStateTests.swift, Features/Statistics/StatsScreenStateTests.swift. No asset catalog file changed. Deleted: none.

## Deviations
- Visible: under-limit person rows were muted text and are now the primary text color; Available now shows a pill (the row previously showed an icon and no caption for Available).
- `init?(shipping:)` is labeled (the spec wrote `init(_ PurchaseShippingStatus)?`) to avoid an overload clash with `init(_ ItemStatus)`. `StatusStyle` exposes `label(for:)` instead of two stored label tokens; behavior is the same.
- `BudgetCardView` calls `Color.budget(level:)` in the style layer because an existing scan (`BudgetViewScanTests/viewsUseTokens`) bans a `Color(` initializer in budget views.
- The budget progress bar for the near-limit state is Warm Gold at about 2:1 against white in light mode (the supplementary-graphic exception from the TH1-1 report); the words "Near limit" carry the state.
- `ItemStatus.swift` still imports SwiftUI (cosmetic); `ItemDetailView.swift` is 411 lines (soft limit 400; this change reduced it by 2).

## Existing tests changed (each asserts the exactly-at-limit wording this story deliberately changes: exactly at the limit is now the near range)
BudgetCardStateTests: budgetExactlyAtTotalIsNotOver, statsBudgetAtTotal, personRowExactlyAtLimitIsNotOver; StatsScreenStateTests: budgetUnderAtAndOverThroughTheScreen. Each changed one expected string from "$0.00 remaining" to "Near limit. $0.00 remaining"; the `isOver == false` assertions beside them are kept. The near wording is covered by the new BudgetCardStateLevelTests as well. None deleted.

## Tests: arithmetic
4453 + 84 = 4537. New (parameterized counted as one): StatusStyle 20 (thereAreSixKinds, styleCarriesItsKind, fillTokenPerKind, shortLabelPerKind, accessibilityLabelPerKind, lightLabelPerKind, darkLabelPerKind, labelEqualsTheLabelTableForTheFill, styleIsEquatableAndStable, everyLabelReachesFourPointFiveAgainstItsFillInBothModes, itemStatusAvailable/Partial/Purchased/Wrapped/GiftedMaps, noItemStatusMapsToShipped, shippedShippingStatusMapsToShipped, everyOtherShippingStatusIsNil, onlyShippedIsNonNilAcrossAllShippingCases, displayNamesAreUnchanged); Status style scans 10 (statusFilesUseNoSystemColor, statusFilesUseNoUIColor, itemStatusHasNoColorProperty, tokenColorExistsNowhereInTheAppSources, itemRowAndItemDetailUseStatusPill, itemRowAndItemDetailDoNotRenderTheMarkerNameThemselves, pillAndDotAreOneAccessibilityElement, dotSizeScalesWithDynamicType, pillAndDotHardCodeNoHexString, whiteAppearsOnlyInTheAllowlistedFiles); BudgetStateStyle 24 (threshold, three levels, under/just-under/exactly-90/95/just-under-limit/exactly-at-limit/one-cent-over/19.98/well-over, scaling with the limit, zero limit cases, negative spent, zero spent, three style tests, accessibility, distinct tokens); BudgetCardState level 23 (card and person rows: under, just under 90, at 90, between, exactly at limit, one cent over, 19.98, zero totals, stats forms, server over flag ignored, isOver equality, wording only in the near range, accessibility text); Budget style scans 7 (no destructiveColor, primaryColor only in CreateBudgetButton, no isOver ternary, uses the budget style, status text always Text, the threshold declared in one file, no literal 90 percent elsewhere). Rewritten or deleted: the four assertion edits above (no test count change). Package 212, release 92, destination 17 unchanged. (Reviewer residual-risk check: the Decimal literal 0.9 compares exactly; the exactly-90-percent test passes in verify.)

## Raw verification (before the commit, by running the commands)
```
--- tests: 4537 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is recorded in the TH1-4 report.

## Gate 2
- convention-reviewer: APPROVED. Warnings (the deviations above, ItemDetailView over 400 lines, the unneeded import, StatusDotLabel without a production caller). Checked: no DispatchQueue, Combine, force unwrap or `as!`; Decimal for money; no amount logged; previews present; the only raw `.white` is ItemStatusStyle.swift:95.
- acceptance-reviewer: APPROVED. Evidence: pill only via ItemRow.swift:23-24 and ItemDetailView.swift:225-226; words always rendered (StatusPill.swift:25; BudgetCardView.swift:22-24, :76-78); accessibility modifiers StatusPill.swift:33-34, StatusDotLabel.swift:34-35; threshold BudgetStateStyle.swift:26; gold text avoided (BudgetCardView.swift:93-101); `statusMarker` nil rule unchanged (ItemViewState.swift:90, :211); BudgetWarningPanel and the editor unchanged; no other status display exists.
- Rejections: none. Stuck detector: two implementer attempts with different error signatures (a scan banned `Color(` in budget views; then one existing-test expectation I approved); no repeat.

## Not done or partial
- Nothing in scope. StatusDotLabel has no production caller (stated above and in the handoff). No simulator run was possible: Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout and the thumbnails all need eyes on the simulator).
