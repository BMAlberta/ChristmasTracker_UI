# PAL1-3: Role badges

Branch `feat/pal1-palette-revision`. Solo mode, tests written first. Not committed (the Orchestrator commits).

## What changed

- `Core/Models/ListRoleBadge.swift`: removed `Tone.color` (gold and cranberry). Added the pure, nonisolated `RoleBadgeLook` (fill token or nil, border token or nil, text rule, `borderWidth` = 1, `label(for: ThemeMode)`) and `Tone.look`. The mapping reads only the tone, never a role.
- `Features/Items/Components/ItemStatusStyle.swift`: added `RoleBadgeLook.fillColor`, `.borderColor`, `.textColor(for:)` beside the existing token-to-Color mapping. Reason: the existing `ListViewScanTests.viewsUseTokensOnly` forbids any `Color(` initializer in `ListComponents.swift`, so the token-to-Color step could not live in the view. (This file is in the Gate 1 list.)
- `Features/Lists/Views/ListComponents.swift`: `ListBadge` draws the look: fill via `.background` only when non-nil, edge via `strokeBorder` overlay (size unchanged, padding unchanged), text color by `colorScheme.themeMode`. Init `(title, tone)` unchanged, so `ListDetailView.swift:292` and `ListPreviewCard.swift:28` are untouched. Added three previews (light, dark, large type) of all four roles on the page color and the card color. File is 135 lines.

## Before and after

| Tone | Before | After |
|---|---|---|
| owner | `primary` fill, `surface` text | `primary` fill, contrast label from `ThemeStatusLabelTable` (white in light, `backgroundPrimary` in dark) |
| coOwner | `accent` (cranberry) fill, `surface` text | no fill, 1 pt `primary` edge, `primary` text |
| member | `highlight` (gold) fill, `surface` text | `backgroundSecondary` fill, 1 pt `border` edge, `textPrimary` text |
| viewer | `textMuted` fill, `surface` text | no fill, 1 pt `border` edge, `textMuted` text |

Every badge keeps its words (Owner, Co-Owner, Member, Viewer).

## Contrast (text, from the real colorset JSON via `ListRoleBadgeContrastTests`, all >= 4.5)

| Tone | Text on background | Light | Dark |
|---|---|---|---|
| owner | label on `primary` fill (white light, `backgroundPrimary` dark) | 9.63 | 6.00 |
| coOwner | `primary` on `surface` | 9.63 | 4.79 |
| coOwner | `primary` on `backgroundPrimary` | 9.15 | 6.00 |
| member | `textPrimary` on `backgroundSecondary` | 12.87 | 13.15 |
| viewer | `textMuted` on `surface` | 5.35 | 5.59 |
| viewer | `textMuted` on `backgroundPrimary` | 5.09 | 7.01 |

Decorative edge ratios (printed, not asserted; the brief does not require 3:1 for the `border` edge):
- `border` edge (member, viewer): light 1.30 on surface, 1.23 on backgroundPrimary; dark 1.27 on surface, 1.59 on backgroundPrimary. These are low, as expected for the neutral hairline; the member fill and the words carry the badge, not the edge.
- `primary` edge (coOwner): the same as the text numbers above (9.63 / 9.15 light, 4.79 / 6.00 dark).

Note: Member's fill sits on `backgroundSecondary`; the member badge on a `surface` card is a quiet tint with a light edge. Not measured against the page (decorative).

## No role badge uses highlightColor or accentColor

`grep -rnE "highlightColor|accentColor|\.highlight\b|\.accent\b"` over `Features/` and `ListRoleBadge.swift`:

```
Features/Items/Components/ItemRow.swift:39:  .background(Color.highlightColor, in: .rect(cornerRadius: AppSpacing.xs))
Features/Items/Components/ItemStatusStyle.swift:88:  case .accent: self = .accentColor
Features/Items/Components/ItemStatusStyle.swift:89:  case .highlight: self = .highlightColor
Features/Items/Views/ItemDetailView.swift:224:  .background(Color.highlightColor.opacity(0.25), in: .rect(cornerRadius: AppSpacing.xs))
```

ItemRow:39 and ItemDetailView:224 are not role badges (unchanged, out of scope per decision 6). ItemStatusStyle 88-89 is the generic token mapping. `ListRoleBadge.swift` and the `ListBadge` struct have none; `ListRoleBadgeSourceScanTests` enforces it.

## Tests

New files (one type each, `ChristmasTrackerTests/Core/`):
- `ListRoleBadgeLookTests` (7): the four looks by token, the owner label equals the status label table on `primary` in both modes, width is 1, no gold/cranberry tokens in any look.
- `ListRoleBadgeContrastTests` (2): all 12 text pairs >= 4.5 (6 per mode) from the catalog; the decorative edge ratios are printed.
- `ListRoleBadgeSourceScanTests` (4): `ListRoleBadge.swift` and the `ListBadge` struct contain none of `highlightColor`, `accentColor`, `.highlight`, `.accent`, `highlightStrong`, `destructiveColor`, wrapped/gifted/partial tokens; the view uses `tone.look`, `look.fillColor/borderColor/textColor`, `strokeBorder`, `RoleBadgeLook.borderWidth`, no `Color(` initializer, no `.white/.black`, no bare line width; the look region mentions no role.

I put the pairs in a new file rather than `ThemePairs.measureAll`, so `pairsPerMode` and the existing counts are unchanged.

Arithmetic: baseline 4666 app tests (after P2) + 13 new test functions (7 + 2 + 4; parameterized count once, and none of these is parameterized) = 4679. verify reports 4679 passed. Package: 212 unchanged.

## Commands and raw output

`scripts/verify.sh | grep ...`:

```
** BUILD SUCCEEDED **
--- tests: 4679 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== verify: OK ===
```

Attempt log:
- Red: the three new test files did not compile against the old code (no `look`, no `RoleBadgeLook`), the right reason.
- Attempt 1: production written; test target failed to compile (`String(format:)` needs `import Foundation` in the contrast test). Fixed.
- Attempt 2: 4677 passed, 2 failed: my pair count was wrong (6 per mode, not 7; fixed to 12), and the existing `ListViewScanTests.viewsUseTokensOnly` rejected `Color(token:)` in `ListComponents.swift`. Fixed by moving the Color step to `ItemStatusStyle.swift`.
- Attempt 3: 4678 passed, 1 failed: my own scan matched `textColor(` as `Color(`; switched to a word-boundary regex. Different signatures each time.
- Attempt 4 (full run) green. This is the fourth `scripts/test.sh` run counting the compile fix; the substantive failures were all distinct and caused by test authoring, not repeated.

## Deviations

- Member "primary text": read as the neutral `textPrimary` token (not the green `primary`), per the Orchestrator's reading in the epic brief; tested at 12.87 light and 13.15 dark. Co-owner "primary text" is the green `primary` token.
- Owner label reuses `ThemeStatusLabelTable.label(onFill: .primary, ...)` (white in light, `backgroundPrimary` in dark), not `surface`: dark `surface` on `primary` is 4.79 against 6.00 for `backgroundPrimary`; both pass, the table is the existing rule.
- Co-owner in dark on `surface` is 4.79, the tightest text pair, but over 4.5.
- The token-to-Color helpers sit in `ItemStatusStyle.swift`, not in the badge view (see above).
- Previews are in `ListComponents.swift`, not a new file.

## Not done or partial

- The agents never saw the simulator. The previews compiled but were not looked at, and no screenshot was taken, so the look of the edge and fill is only verified by token tests.
- The `border` edge on Member and Viewer is low contrast (1.23 to 1.59) by design; no 3:1 check was applied or asserted.
- Not committed. `theme.pdf` not touched. The handoff story is not started.
