# PAL1: Palette revision 1 (contrast fixes and role badges)

Package PAL1 (branch `feat/pal1-palette-revision`, from master at the BA1 merge 6405309). Three code stories (P1 tokens and contrast tests, P2 edges and bar, P3 role badges) and a handoff. Visual only: no behavior, service, repository, contract, navigation or screen change. Instruction file: `prompts/mobile-ui/PAL1-palette-revision.md` (outside the repo).

## Decisions (Brian, 2026-11-15; decision 3 revised the same day)

1. Muted text, light: `textMuted` light #6B7280 to #656B77 (4.22 to 4.67 on `backgroundSecondary`). Dark unchanged.
2. Cranberry, dark: `accent` dark #E06A75 to #E8737E (4.39 to 4.86 on the dark `surface`). Light unchanged. Every token defined as the same color in dark moves with it: `statusWrapped` and `budgetOver` (see the inventory; each has its own colorset holding the same value). `destructiveColor` is `Color("accentColor")` (AppColors.swift:74), so it follows the accent with no edit of its own.
3. Gold fills in light stay (#D6B25E, #C9A227). Add a graphic edge:
   - New token `highlightStrong` (colorset `highlightStrongColor`): light #9C7A2E, dark #E4C76A.
   - Pills whose light fill is below 3:1 against both `backgroundPrimary` and `surface` (computed from the table: Partial and Gifted today) get a 1 point `highlightStrong` border in `StatusPill` and, because it draws a fill, in `StatusDotLabel`.
   - New token `budgetWarningBar` (colorset `budgetWarningBarColor`): light #9C7A2E (revised from #A8863A), dark #E4C76A. Used for the near-limit bar FILL only. Pinned at 3:1 or better against `backgroundPrimary` (3.81), `surface` and `backgroundSecondary` (3.50). The real ProgressView track is system-drawn with no token: the view's track is not changed and not measured. Text, pills and labels that use `budgetWarning` keep it.
4. Role badges stop using gold and cranberry. Owner = primary fill with its contrast label; Co-owner = 1 point primary border, primary text, no fill; Member = `backgroundSecondary` fill, 1 point `border` edge, primary text; Viewer = no fill, 1 point `border` edge, muted text. Every badge keeps its words.
5. theme.pdf is not edited by agents.
6. No other color, token, spacing or layout change.

Orchestrator reading of "primary text" for Member (decision 4): the neutral `textPrimary` token (not the green `primary`), because Member is meant to read as a quiet neutral badge. Co-owner's "primary text" is the green `primary` token. Both are tested at 4.5:1 in P3, so either reading passes; flagged in the P3 report.

## Gate 1 spec

- Contract slice: none. No networking, API model, repository or service change. No new interface that crosses a layer.
- Weight: capability-flag, auth and purchase paths are untouched, so this is the solo path with all of Gate 2 applied by the Orchestrator's choice: convention-reviewer on every story and acceptance-reviewer on every story (the instruction file asks for the normal pipeline). The acceptance-reviewer reads the colorset JSON and the token table side by side.
- Stories:
  - **P1 Tokens and contrast tests.** `ThemeTokenTable` (two value changes, `highlightStrong` and `budgetWarningBar`), the asset catalog (three changed colorsets, two new), AppColors accessors and doc comments, the test support table, the pinned-exception lists (entries removed, not loosened), new pairs, the computed "gets a border" rule test, `noExtraColorsets` 20 to 22. Report `Docs/reports/PAL1-1-tokens.md`.
  - **P2 The edges and the bar.** `StatusPill` and `StatusDotLabel` overlay stroke driven by a pure rule computed from the table; `BudgetStateStyle` near-limit bar token to `budgetWarningBar` (the Color mapping in `ItemStatusStyle.swift` gets the two new cases). Pure tests, a source scan, previews. Report `Docs/reports/PAL1-2-edges.md`.
  - **P3 Role badges.** `ListRoleBadge.Tone` look mapping (pure), `ListBadge` view, label pairs in the contrast tests at 4.5:1 light and dark, previews for four roles. Report `Docs/reports/PAL1-3-badges.md`.
  - **Handoff.** `Docs/handoffs/<date>-ios-to-brian-pal1.md` and `Docs/reports/PAL1-4-handoff.md`.
- Acceptance criteria:
  - C1 Every changed hex in the table equals the colorset JSON, light and dark, and decisions 1 to 3 exactly. Every other token is byte-for-byte unchanged.
  - C2 The three pinned text exceptions and the budgetWarning supplementary exceptions are removed (not loosened). Partial and Gifted keep a supplementary exception entry only if the pair is still below 3:1; the exception is replaced by the "must have an edge" rule, so a new sub-3:1 light fill without an edge fails a test.
  - C3 The border set is computed from the table (light fill below 3:1 against both backgrounds), not hard-coded.
  - C4 `budgetWarningBar` is used only for the near-limit bar fill; every other `budgetWarning` use is unchanged.
  - C5 No role badge uses `highlightColor` or `accentColor`; the four badge text pairs reach 4.5:1 in light and dark.
  - C6 No raw colors or bare numbers in views; nothing changes under `.claude/`, any `.pbxproj`, `contract/`, `LocalPackages/` or the synced Docs files.
- Scoped files (under `ChristmasTracker/ChristmasTracker/` unless noted):
  - `DesignSystem/Colors/ThemeTokenTable.swift`, `DesignSystem/Colors/AppColors.swift`
  - `Assets.xcassets/Colors/Text/mutedTextColor.colorset`, `Colors/Accent/accentColor.colorset`, `Colors/Status/statusWrappedColor.colorset`, `Colors/Budget/budgetOverColor.colorset` (changed); `Colors/Highlight/highlightStrongColor.colorset` and `Colors/Budget/budgetWarningBarColor.colorset` (new)
  - `Features/Items/Components/ItemStatusStyle.swift`, `StatusPill.swift`, `StatusDotLabel.swift`
  - `Features/Budgets/ViewState/BudgetStateStyle.swift`
  - `Core/Models/ListRoleBadge.swift`, `Features/Lists/Views/ListComponents.swift`
  - Tests under `ChristmasTracker/ChristmasTrackerTests/` (DesignSystem, Features/Items, Features/Budgets, Features/Lists, Core): `ThemeTestSupport`, `ThemeAssetCatalogTests`, `ThemeContrastPairTests`, `ThemeTokenTableTests`, `ThemeContrastReportTests`, `ThemeAccessorTests`, `BudgetStateStyleTests`, `ListRoleBadgeTests`, plus new files for the border rule, the source scan and the badge looks.
  - Docs: this brief, reports, the handoff.

## Inventory (read from disk, not assumed)

### Baseline (scripts/verify.sh on 6405309, 2026-11-15)

- App tests: 4647 passed, 0 failed, 0 skipped. `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed. verify.sh reported BUILD SUCCEEDED.

### Token table and tests that pin values

- `DesignSystem/Colors/ThemeTokenTable.swift`: `ThemeToken` cases (lines 17-35), `colorsetName` (38-59), hex table (65-86): `accent` line 68, `textMuted` line 74, `statusWrapped` line 80, `budgetOver` line 84, `highlight` line 69, `statusPartial` line 78, `statusGifted` line 81, `budgetWarning` line 83. `ThemeStatusLabelTable` (106-129): light Partial and Gifted use `textPrimary`; dark uses `backgroundPrimary`.
- `ChristmasTrackerTests/DesignSystem/ThemeTestSupport.swift`: independent expected hex table (19-38) and colorset names (40-59), `statusFills` (87-89), `budgetFills` (91), `pairsPerMode = 38` (285), `measureAll` (288-338).
- `ThemeAssetCatalogTests.swift`: `tokenValues` (15-26), `noExtraColorsets` (36-45, count 20: 18 tokens + `AccentColor` + `LaunchBackground`). P1 makes it 22 (the two new token colorsets).
- `ThemeContrastPairTests.swift`: `knownTextExceptions` (35-40: light textMuted on backgroundSecondary floor 4.21; dark accent on surface 4.38; dark budgetOver on surface 4.38), `supplementaryGraphicExceptions` (44-51: light statusPartial, statusGifted and budgetWarning on surface and backgroundPrimary).
- Colorsets (all use the `0xNN` hex-string format with a no-appearance fallback entry plus light and dark entries; fallbacks are not read by the tests):
  - `Colors/Accent/accentColor.colorset`: light 0xB2 0x3A 0x48, dark 0xE0 0x6A 0x75 (lines 26-28 and 44-46). Own colorset.
  - `Colors/Status/statusWrappedColor.colorset`: light #B23A48, dark #E06A75. Own colorset, same value.
  - `Colors/Budget/budgetOverColor.colorset`: light #B23A48, dark #E06A75. Own colorset, same value.
  - `Colors/Text/mutedTextColor.colorset`: light 0x6B 0x72 0x80 (lines 26-28), dark 0x9A 0xA5 0xA1 (unchanged).
  - There is also an app-level `AccentColor.colorset` (primary values, not touched).

### `accent` in dark and the tokens that share it

- Same value in the table: `accent` (68), `statusWrapped` (80), `budgetOver` (84), and `Color.destructiveColor` which IS the accent colorset (`AppColors.swift:74`, `Color("accentColor")`; `ThemeAccessorTests.swift:58-67` pins this). Each of `statusWrapped` and `budgetOver` is its own colorset holding #E06A75 and is defined as the same cranberry (ThemeContrastPairTests.swift:38 comment says so). All three colorsets change in dark.
- Doc comments with hex to update: AppColors.swift lines 16, 36 (textMuted), 56, 69, 73.
- Uses of `accentColor`/`.accentColor`/`destructiveColor` in Features are not edited: they follow the token.

### `textMuted` uses (no edit; they follow the token)

`textMutedColor` is used in about 100 places across Features, App/LockView and DesignSystem (grep `textMutedColor`; the heavy files are LoginView, RegistrationView, ProfileView, ChildrenView, BudgetEditorView, ItemsSectionView, ListDetailView). `AppTypography.swift:50` (caption helper) and `ItemStatusStyle.swift:79` map it. No view needs a change.

### `budgetWarning` uses

- `ThemeTokenTable.swift` 34, 56, 83; `AppColors.swift:67` (`budgetWarningColor`); `ItemStatusStyle.swift:88` (token to Color map).
- `BudgetStateStyle.swift:41`: `.nearLimit` maps to token `.budgetWarning` (the only production consumer). `Color.budget(level:)` (`ItemStatusStyle.swift:101-106`) turns that token into a Color, and its only caller is `BudgetLevelColors.bar(for:)` (`BudgetCardView.swift:92-94`), used at `BudgetCardView.swift:27` for `ProgressView(...).tint(...)`. That is the near-limit FILL. Text uses `textPrimaryColor` for under and nearLimit (`BudgetCardView.swift:96-100`), so no text, pill or label uses `budgetWarning`.
- Plan: P2 changes the near-limit style token to `budgetWarningBar` at `BudgetStateStyle.swift:41`, which changes the bar only. The `BudgetStyle.token` is documented as "bars and graphics; not for small text" (`ItemStatusStyle.swift:102`).
- Tests that name it: `BudgetStateStyleTests.swift:77` (`style.token == .budgetWarning`, becomes `.budgetWarningBar`), `ThemeAccessorTests.swift:50` (accessor exists), `ThemeTestSupport` (expected table).

### `highlight` uses (gold)

- Definitions: ThemeTokenTable 69; AppColors 20. Mapping: `ItemStatusStyle.swift:74`.
- Role badge: `ListRoleBadge.swift:66` (`.member: return .highlightColor`). Removed in P3.
- Other production uses that are NOT role badges and are out of scope (decision 6; gold fills stay): `ItemRow.swift:39` (`.background(Color.highlightColor, ...)`) and `ItemDetailView.swift:224` (`.background(Color.highlightColor.opacity(0.25), ...)`). Reported, not changed.
- `SurfaceSourceScanTests.swift:92` lists `highlightColor` among allowed names. P3 confirms by search that no role badge uses `highlightColor` or `accentColor`.

### Role badge

- `Core/Models/ListRoleBadge.swift`: `Tone` enum (17-22) and `Tone.color` (60-70): owner `.primaryColor` (64), coOwner `.accentColor` (65), member `.highlightColor` (66), viewer `.textMutedColor` (67).
- The view: `Features/Lists/Views/ListComponents.swift` `ListBadge` (14-26): text `Color.surfaceColor`, `.background(tone.color, in: .rect(cornerRadius: AppSpacing.xs))` (24).
- Callers: `Features/Lists/Views/ListDetailView.swift:292`, `Features/Dashboard/Components/ListPreviewCard.swift:28`. View state carries `badgeTone` (`ListViewState.swift` 21, 42, 82, 112).
- Neighbor: `ListArchivedBadgeView` (`ListComponents.swift:29-41`) already uses muted text with a `borderColor` stroke; the Viewer look matches it. Not changed.
- Tests that touch it: `ListRoleBadgeTests.swift` (titles), `ListViewScanTests.swift` (view scans, line 192 allows `.foregroundColor(.accentColor)` as a scan pattern), `ListSourceScanTests.swift:169-192`.

### Status pills

- `StatusPill.swift`: capsule `.background(Color(token: style.fill), in: .capsule)` (30). `StatusDotLabel.swift`: `Circle().fill(Color(token: style.fill))` (28), so it does draw a fill and gets the edge too.
- `ItemStatusStyle.swift`: `StatusStyle.style(for:)` (52-65): partial uses `.statusPartial`, gifted `.statusGifted`.

## Open items resolved before the run

- Bar track: system-drawn, not measured (Brian, 2026-11-15, option 1). `budgetWarningBar` light is #9C7A2E.

## Stories

- P1 Tokens and contrast tests: `Docs/reports/PAL1-1-tokens.md`
- P2 The edges and the bar: `Docs/reports/PAL1-2-edges.md`
- P3 Role badges: `Docs/reports/PAL1-3-badges.md`
- Handoff: `Docs/handoffs/<run date>-ios-to-brian-pal1.md` and `Docs/reports/PAL1-4-handoff.md`
