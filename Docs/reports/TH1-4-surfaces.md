# TH1-4: Surfaces, cards and list rows

Commit: "TH1: draw screens, cards and rows from the theme surfaces". Pipeline: full (Gate 1 in Docs/epics/TH1-theme-pass.md; isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer, one after the other).
SwiftUI guidance (swiftui-expert-skill rules passed to the implementer in the brief): modern APIs, private @State and @ScaledMetric, stable ids, no AnyView, Dynamic Type text styles, DesignSystem tokens only.

## After-commit run of the previous commit (TH1-3, 69ab6b4), taken by running the commands
```
--- tests: 4537 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What changed
- New `AppCard` (DesignSystem/Components/AppCard.swift): `View.appCard()` = standard padding, `Color.surfaceColor` fill, continuous rounded corners, hairline `Color.borderColor` stroke, no shadow. Named constants in `AppCardStyle`: cornerRadius = AppSpacing.md (12), borderWidth = 1, padding = AppSpacing.md.
- Every hand-built card now uses it: the list preview card, the item detail cards, the list detail and create list cards, the members card, the three Statistics cards and the Statistics screen, the Profile `CardContainerView` and the skeleton and loading cards. `listCard()` and `statsCardStyle()` are deleted. The two drop shadows (Profile, skeleton) are gone.
- `ErrorStateView` icon uses the destructive token (was raw `.red`); the skeleton shimmer uses the border and secondary background tokens (was gray); `InlineErrorBannerStyle.backgroundOpacity = 0.12` is the named constant behind the banner's destructive tint (layout unchanged).
- Link and hint colors: `Color.accentColor` (which was Cranberry through the app's own extension) and `.foregroundStyle(.accent)` (system blue) became `Color.primaryColor` at the real links and hints: LoginView "Forgot?" and "Sign up", the ListDetailView theme label, the Profile row icon. VALIDATION ERROR text (RegistrationView x2, AddMemberView, CreateListView, EditListView, AddChildView) stays Cranberry through `Color.destructiveColor` (the acceptance reviewer caught that the first pass had turned error text Evergreen; fixed and re-reviewed).
- Page backgrounds already were `backgroundPrimaryColor`; List rows keep `surfaceColor` (ChildrenView) or `Color.clear` over the screen background as before, so no list-row code changed.

## Files
Added: DesignSystem/Components/AppCard.swift; tests ChristmasTrackerTests/DesignSystem/AppCardStyleTests.swift, SurfaceSourceScanTests.swift.
Changed (app): DesignSystem/Components/ErrorStateView.swift, InlineErrorBanner.swift, Loading/LoadingView.swift, Loading/SkeletonView.swift; Features: LoginView, RegistrationView, AddChildView, ListPreviewCard (Dashboard/Components), ItemDetailView, AddMemberView, CreateListView, EditListView, ListComponents, ListDetailView, MembersSectionView, ProfileView, BudgetCardView, SpendByPersonView, StatsSummaryCardView, StatsView. Changed (test): Features/Shared/DestructiveRealFilesTests.swift. No asset catalog file changed. Deleted: none (two helper functions removed).

## Deviations and presentation changes (for Brian)
- Card padding is 12 (`AppSpacing.md`) where the old cards used 16; Statistics cards gained the hairline border; corner radius is the same 12, now continuous.
- Profile: row padding changed from 12 all round to 8 vertical (the card adds 12), the user card vertical padding 24 to 12 plus the card's 12, the divider inset 52 to a Dynamic Type scaled `iconSlotWidth + AppSpacing.md` inside a private `SettingsDividerView` (28 scaled + 12, plus the card's 12 = 52 at the default size), and dividers stop 12 points short of the card edge. Not verifiable without a simulator.
- Gate 1 named the constant `AppCard.cornerRadius`; the type is `AppCardStyle`. `AppCardStyle` is left MainActor-isolated (its values are `AppSpacing.md`, main-actor inferred, and making AppSpacing nonisolated is out of this story); `InlineErrorBannerStyle` is `nonisolated`.
- Open from the brief: "grouped sections and panels use backgroundSecondary" is not done, because form and list screens that hide the scroll background keep the system row background. No layout change was demanded in this story; backgroundSecondary is used only by the skeleton shimmer and the Create List field fill. Reported as open.
- `ListRoleBadge` (Core) still uses the accent token (Cranberry) for the co-owner tone; the new scan covers Features and DesignSystem only.
- The `.white` allowlist still holds the six filled-button files T5 will fix (EmptyStateView, ErrorStateView, LoginView, RegistrationView, BiometricSetupView, App/LockView) plus the style layer; ProfileView's Logout button (surface label on a primary fill, hard-coded radius 12) is also a T5 item.
- ProfileView.swift (about 417 lines) and ListDetailView.swift (446) are over the 400-line soft limit (pre-existing; not worsened). A few test lines in SurfaceSourceScanTests.swift are over 120 characters.
- The validation error test only requires the string `Color.destructiveColor` in each of the five files (weak by design; optional to tighten).

## Existing tests changed
`DestructiveRealFilesTests.swift`: the documented ErrorStateView raw-red exception was removed and `DesignSystem/` added to the scanned prefixes (the behavior this story changes), one long line wrapped. None deleted or weakened. No other existing test pinned `listCard`, `statsCardStyle` or `Color.accentColor` (the matches in ListViewScanTests and DestructiveScannerTests are fixture strings).

## Tests: arithmetic
4537 + 21 = 4558. New (parameterized counted as one): AppCardStyleTests 5 (cornerRadiusIsTheMediumSpacing, borderWidthIsAHairlineOfOnePoint, paddingIsTheMediumSpacing, appCardModifierComposesOnAView, inlineErrorBannerBackgroundOpacityIsTwelvePercent); SurfaceSourceScanTests 16 (noSystemColorLiteralsOutsideTheTokenDefinitions, whiteAppearsOnlyInTheAllowlistedFiles, opacityOnAColorIsOnlyDerivedFromAThemeToken, noShadowAnywhereInTheAppSources, handBuiltCardsExistOnlyInAppCardAndTheAllowlist, handBuiltCardAllowlistHasNoStaleEntries, appCardFileDefinesTheCardWithThemeTokensAndNoShadow, formerHandBuiltCardFilesUseAppCard, statsCardsUseAppCard, listCardAndStatsCardStyleAreGone, noAccentColorOrAccentShapeStyleInFeaturesOrDesignSystem, errorStateViewUsesTheDestructiveTokenAndNoRed, stateScreensUseThePrimaryBackgroundToken, skeletonShimmerUsesThemeTokensNotGray, inlineErrorBannerUsesTheStyleConstantAndDestructiveToken, validationErrorTextUsesTheDestructiveToken). Rewritten/deleted: none (the edit above changes scan scope only). Package 212, release 92, destination 17 unchanged.

## Raw verification (before the commit, by running the commands)
```
--- tests: 4558 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is recorded in the TH1-5 report.

## Gate 2
- convention-reviewer: first REJECTED (four bare `.padding(.leading, 40)` divider insets in ProfileView, plus missing `nonisolated` on the two constant enums). Fixed (SettingsDividerView built from a scaled metric and AppSpacing.md; `InlineErrorBannerStyle` made nonisolated; `AppCardStyle` could not be, see above) and re-reviewed by the same reviewer: APPROVED.
- acceptance-reviewer: first REJECTED (validation error text had become Evergreen). Fixed (six sites in five files back to `Color.destructiveColor`, a new test) and re-reviewed by the same reviewer: APPROVED. It also verified: no color literal outside the allowlist, no shadow, AppCard definition AppCard.swift:22-29, backgrounds unchanged, scans substantive, nothing under contract/, .claude/, any .pbxproj, LocalPackages/ or synced Docs.
- Stuck detector: three implementer loops for the first pass (two test-allowlist errors, then green), then two fix rounds with different errors; no repeated signature.

## Not done or partial
- The backgroundSecondary grouped-panel rule (above). The Profile layout, card padding and border look, and all dark-mode appearance are unverified. No simulator run was possible: Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout and the thumbnails all need eyes on the simulator).
