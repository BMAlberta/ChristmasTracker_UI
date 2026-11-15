# PAL1-1: Tokens and contrast tests

Branch `feat/pal1-palette-revision`. Solo mode (tests first, then the build and test loop). No view changes. Not committed (the Orchestrator commits).

## What changed

### Token values (table, colorsets and test expectations all agree)

| Token | Colorset | Before (light / dark) | After (light / dark) |
|---|---|---|---|
| textMuted | mutedTextColor | #6B7280 / #9AA5A1 | #656B77 / #9AA5A1 |
| accent | accentColor | #B23A48 / #E06A75 | #B23A48 / #E8737E |
| statusWrapped | statusWrappedColor | #B23A48 / #E06A75 | #B23A48 / #E8737E |
| budgetOver | budgetOverColor | #B23A48 / #E06A75 | #B23A48 / #E8737E |
| highlightStrong (new) | highlightStrongColor | n/a | #9C7A2E / #E4C76A |
| budgetWarningBar (new) | budgetWarningBarColor | n/a | #9C7A2E / #E4C76A |

Every other token is unchanged. Colorset edits touched only the light entry (mutedTextColor) or only the dark entry (the three cranberry colorsets); fallback entries are unchanged. The two new colorsets copy the shape of `highlightColor.colorset` (0xNN strings, fallback 0xFE 0xFF 0xFF, light, dark).

### destructiveColor and shared-value tokens

- `Color.destructiveColor` is `Color("accentColor")` (`AppColors.swift`, the line under "MARK: Destructive"), so it is the accent colorset and moved with it with no edit of its own (only its doc comment hex was updated). `ThemeAccessorTests.destructiveIsAccent` and `DestructiveColorTests` pin that.
- Tokens whose dark value equaled the accent's and which are defined as the same cranberry, each its own colorset, all changed: `statusWrapped` and `budgetOver`.

### Files changed

App target:
- `ChristmasTracker/ChristmasTracker/DesignSystem/Colors/ThemeTokenTable.swift`: two values, two new cases (colorset names and hex), new `ThemeEdgeRule.fillsNeedingEdge()` (pure; computed from `ThemeTokenTable.rgb` and `StatusStyle.style(for:)` over `StatusKind.allCases`: light fills under 3.0 against BOTH `backgroundPrimary` and `surface`).
- `ChristmasTracker/ChristmasTracker/DesignSystem/Colors/AppColors.swift`: accessors `highlightStrongColor` and `budgetWarningBarColor`; doc comment hex updated for textMuted, accent, statusWrapped, budgetOver, destructive.
- `ChristmasTracker/ChristmasTracker/Features/Items/Components/ItemStatusStyle.swift`: the two new `Color(token:)` cases only.
- Assets.xcassets: `Colors/Text/mutedTextColor`, `Colors/Accent/accentColor`, `Colors/Status/statusWrappedColor`, `Colors/Budget/budgetOverColor` (changed); `Colors/Highlight/highlightStrongColor`, `Colors/Budget/budgetWarningBarColor` (new).

Tests (`ChristmasTracker/ChristmasTrackerTests/DesignSystem/`): `ThemeTestSupport.swift`, `ThemeContrastPairTests.swift`, `ThemeAssetCatalogTests.swift`, `ThemeTokenTableTests.swift`, `DestructiveColorTests.swift`.

## Ratios

All from `scripts/test.sh` (attempt 1 run), printed by `ThemeContrastReportTests` (`CONTRAST|...` rows in `/tmp/ct-test.log`).

Changed or new pairs:

| Pair | Before | After |
|---|---|---|
| light textMuted on backgroundSecondary (text) | 4.22 (pinned floor 4.21) | 4.67 |
| light textMuted on backgroundPrimary / surface | not recorded here | 5.09 / 5.35 |
| dark accent on surface (text) | 4.39 (pinned floor 4.38) | 4.86 |
| dark budgetOver on surface (text) | 4.39 (pinned floor 4.38) | 4.86 |
| dark accent / budgetOver on backgroundPrimary | not recorded here | 6.09 |
| dark backgroundPrimary on statusWrapped (label) | not recorded here | 6.09 |
| dark statusWrapped on surface / backgroundPrimary (supplementary) | not recorded here | 4.86 / 6.09 |
| light highlightStrong on backgroundPrimary / surface (graphic) | n/a | 3.81 / 4.01 |
| dark highlightStrong on backgroundPrimary / surface (graphic) | n/a | 10.74 / 8.57 |
| light budgetWarningBar on backgroundPrimary / surface / backgroundSecondary (graphic) | n/a | 3.81 / 4.01 / 3.50 |
| dark budgetWarningBar on backgroundPrimary / surface / backgroundSecondary (graphic) | n/a | 10.74 / 8.57 / 9.50 |

Unchanged but relevant: light statusPartial 2.02 (surface) / 1.92 (backgroundPrimary), light statusGifted 2.42 / 2.30, light budgetWarning 2.02 / 1.92. Light text-on-gold labels: textPrimary on statusPartial 7.30, on statusGifted 6.10. Every text pair (36 rows) is at or above 4.5; the lowest are light white on statusShipped 4.56 and dark primary on surface 4.79. These match the brief (4.67, 4.86, 3.81, 3.50; highlightStrong 3.8 and 4.0).

## Exceptions

- The three `knownTextExceptions` entries and the whole text-exception mechanism (`knownTextExceptionsPinned` test, the text filter in `textPairs`) are deleted. `textPairs` now requires all 36 text pairs to reach 4.5 and asserts the count.
- The hard-coded Partial/Gifted/budgetWarning list is gone. Replaced by `ThemeEdgeRule.fillsNeedingEdge()` plus tests (below). `supplementaryPairs` skips only light pairs whose foreground is in the computed set, and the pinned light budgetWarning pairs.
- Pinned exception kept (precisely): light `budgetWarning` (#D6B25E) on `surface` (floor 2.02) and on `backgroundPrimary` (floor 1.92), each required to stay below 3.0 and at or above the floor (measured, rounded down). Reason: after PAL1-P2 the near-limit bar uses `budgetWarningBar`; no graphic draws `budgetWarning`, but the token stays. The previous placeholder floors already equaled the measured values, so no change in number.

## Test arithmetic

Baseline (before this story): 4647 app tests, 212 package tests. After (scripts/verify.sh): 4652 app tests passed, 0 failed, 0 skipped; 212 package tests in 16 suites passed.

The runner counts a parameterised test once however many arguments it has, so the extra token arguments do not change the total. Count: 4647 + 6 new functions - 1 removed function = 4652.

New test functions:
- `ThemeContrastPairTests.formerExceptionsMeasure` (muted 4.67 / dark accent and budgetOver 4.86 with floors 4.66 / 4.85 / 4.85, since the unrounded values are just under the rounded figures)
- `ThemeContrastPairTests.newGraphicPairsPresent`
- `ThemeContrastPairTests.edgeSetIsPartialAndGifted` (computed set equals {statusPartial, statusGifted})
- `ThemeContrastPairTests.everyWeakFillHasAnEdge` (every light status fill under 3.0 on backgroundPrimary or surface, measured from the catalog, is in the set)
- `ThemeContrastPairTests.edgeFillsAreWeak` (set members still under 3.0 on both; guards a stale rule)
- `ThemeTokenTableTests.pal1Tokens`

Removed: `ThemeContrastPairTests.knownTextExceptionsPinned`.

Changed (same name): `textPairs` (no exceptions, count 36), `graphicPairs` (count 4 to 14: per mode primary x2, highlightStrong x2, budgetWarningBar x3, two modes), `supplementaryPairs` (computed exclusion), `supplementaryExceptionsPinned` renamed `budgetWarningExceptionsPinned` (two pairs only), `ThemeTokenTableTests.tokenCount` (18 to 20), `ThemeAssetCatalogTests.noExtraColorsets` (20 to 22, title "20 tokens"), `ThemeTestSupport` (expectedHex, expectedColorsetNames, `pairsPerMode` 38 to 43, `measureAll` with 5 new graphic pairs per mode), `DestructiveColorTests` (dark expected #E8737E). The parameterised tests (`tokenValues`, `colorsetName`, `tableValues`, `tokenHasAccessor`, `docCommentsHaveHex`) now run for 20 tokens with no edit.

## Command log

- `scripts/build.sh`: BUILD SUCCEEDED (attempt 1).
- `scripts/test.sh` attempt 1: 4650 passed, 2 failed. (1) `formerExceptionsMeasure` floor 4.67 too tight against the unrounded 4.67; (2) `DestructiveColorTests.matchesAccent(dark)` still expected #E06A75. Both fixed (floors 4.66 / 4.85; expected hex #E8737E). Both are genuine test fixes, not flakes. Different signatures, one attempt used.
- `scripts/verify.sh`: BUILD SUCCEEDED; check-config OK; `tests: 4652 passed, 0 failed, 0 skipped`; package 212 tests in 16 suites passed; `verify: OK`.

## Deviations

- `DestructiveColorTests.swift` is not in the epic's named scoped test list. It hard-coded the old dark accent hex and had to follow the accent (it is under the permitted `ChristmasTrackerTests/DesignSystem` folder). Flagged for the Orchestrator.
- `ThemeRGBTests` still uses "#E06A75" as a hex-parse sample string; it is not a palette claim, left alone.
- `ThemeEdgeRule` lives in `ThemeTokenTable.swift` (as suggested) and reads `StatusKind`/`StatusStyle` from `ItemStatusStyle.swift` for the list of status fills.

## Not done or partial

- The real `ProgressView` bar track is system-drawn with no token; it is not measured. `budgetWarningBar` is pinned at 3:1 or better against `backgroundPrimary`, `surface` and `backgroundSecondary` only.
- `theme.pdf` is not regenerated (Brian does that).
- Views are not changed in this story: `StatusPill`, `StatusDotLabel` and `BudgetStateStyle` do not yet use `highlightStrong` or `budgetWarningBar` (P2). No screenshot or simulator check was done (no view change).
- The "before" ratios for a few pairs (dark statusWrapped and related) were not captured before the change; only the ones in the brief and the TH1 pinned floors are listed as before.
