# TH1-5: Glass chrome, tint and buttons

Commit: "TH1: tint the app with the primary color and style the buttons". Pipeline: full (Gate 1 in Docs/epics/TH1-theme-pass.md; isolated test-writer, implementer, convention-reviewer, acceptance-reviewer, one after the other).
SwiftUI guidance (swiftui-expert-skill rules passed to the implementer in the brief): modern APIs, private @State and @ScaledMetric, no AnyView, Dynamic Type text styles, DesignSystem tokens only, previews for the new style.

## After-commit run of the previous commit (TH1-4, 07e86b5), taken by running the commands
```
--- tests: 4558 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What changed
- **Glass chrome.** The system chrome was already untouched (the inventory found no `toolbarBackground`, `glassEffect` or appearance proxy). A scan now enforces that none of `glassEffect`, `GlassEffectContainer`, `toolbarBackground`, `toolbarColorScheme` or any UIKit appearance API appears anywhere. I did not use `.buttonStyle(.glass)` or `.glassProminent`, so no SDK interface had to be read for them: the chrome is left to the system.
- **App tint.** One `.tint(Color.primaryColor)` on the `appContent` branch in ChristmasTrackerApp.swift (reaches login, the tabs, pushed screens and every sheet). TabBarView's own tint is removed (`.tabBarMinimizeBehavior(.onScrollDown)` stays). Every other Evergreen per-control tint was removed (LoadingView, InlineErrorBanner, ListComponents, MembersSectionView, BudgetWarningPanel, ItemDetailView progress bar, the Remember-email toggle, the purchase and budget buttons): bordered buttons, toggles and progress views inherit it. Remaining tints are `destructiveTint()`, muted or destructive tokens, `BudgetLevelColors`, and the style's own label tint.
- **Primary label decision (recorded as required).** The system `.borderedProminent` draws its own label color on the tint and the SDK offers no way to guarantee a dark label on the dark-mode Evergreen (#4FA58A). White on it measures about 2.9:1, below 4.5, so a system prominent button would fail contrast in dark mode and I could not prove otherwise without a simulator. Every PRIMARY action therefore uses the small custom `PrimaryButtonStyle` (capsule, `Color.primaryColor` fill, label from the contrast-tested `PrimaryButtonLabelTable`: white on #1F4D3A in light, 9.6:1; #0F1A17 (the dark background token) on #4FA58A in dark, 6.0:1; minimum height 44; 50 percent opacity when disabled; 85 percent when pressed; `.tint(labelColor)` so a spinner inside uses the label color). `.borderedProminent` no longer appears anywhere (a scan enforces it). Secondary buttons stay `.bordered` and inherit the tint; destructive buttons stay `.bordered` with `destructiveTint()` and role `.destructive`.
- `PrimaryButtonStyle` now draws: EmptyStateView, ErrorStateView, LoginView Sign In, RegistrationView Create Account, BiometricSetupView, App/LockView Unlock, ProfileView Logout (still neutral, not destructive), BudgetCardView create button, ItemDetailView Record Purchase, ManagePurchaseView save buttons, RecordPurchaseRecordSection, RecordPurchaseExpiredNotice and BudgetWarningPanel Confirm. Their hand-built `.white` labels, backgrounds, corner radii and manual opacity are gone; accessibility labels, identifiers, hints and disabled logic are unchanged.
- ListDetailView "Archive List" is no longer a filled destructive button: `.bordered` + `.destructiveTint()` + role `.destructive`; its UX1b confirmation dialog, anchoring and disabled logic are unchanged.
- The only `.white` left in the app is in the style layer (ItemStatusStyle.swift) and the token data (ThemeTokenTable.swift).

## Files
Added: DesignSystem/Components/AppButtonStyles.swift (`PrimaryButtonStyle`, with light, dark and disabled previews); DesignSystem/Colors/AppButtonSpec.swift (`AppButtonKind`, `AppButtonAppearance`, `AppButtonSpec`, `PrimaryButtonLabelTable`); tests ChristmasTrackerTests/DesignSystem/AppButtonStyleTests.swift, ButtonChromeScanTests.swift.
Changed (app): ChristmasTrackerApp.swift; Navigation/TabBarView.swift; App/LockView.swift; DesignSystem/Components EmptyStateView, ErrorStateView, InlineErrorBanner, Loading/LoadingView; Features: LoginView, RegistrationView, BiometricSetupView, ProfileView, ListDetailView, ListComponents, MembersSectionView, ItemDetailView, BudgetCardView, BudgetWarningPanel, ManagePurchaseView, RecordPurchaseRecordSection, RecordPurchaseExpiredNotice. Changed (tests): Features/Items/StatusStyleScanTests.swift, DesignSystem/SurfaceSourceScanTests.swift, Navigation/TabBarMinimizeScanTests.swift. No asset catalog file changed. Deleted: none.

## Deviations and presentation changes (for Brian)
- `AppButtonKind`, `AppButtonSpec` and `PrimaryButtonLabelTable` are in DesignSystem/Colors/AppButtonSpec.swift, not in AppButtonStyles.swift as Gate 1 specified: the surface scan allows the accent token name only under DesignSystem/Colors/ and the style file may not contain `.white`; the new file is pure (no SwiftUI import).
- The primary buttons are now capsules with a 44-point minimum height and `AppSpacing.lg` horizontal padding (the empty and error state buttons had `xl` and a 12-point rounded rectangle).
- Sign In and Create Account now dim through the style whenever they are disabled, including while loading (before, only an invalid form dimmed them): the spinner sits on a dimmed button. Disabled logic is unchanged.
- The lock screen is hosted in its own UIKit window, so the app tint does not reach it; its Unlock button paints its own fill, so it looks right without the tint (reviewer read the code; unverified on screen).
- Previews that used the removed per-control tints fall back to the system accent (cosmetic).
- Files over 400 lines: ChristmasTrackerApp.swift (505, +2 here), ProfileView (420), ListDetailView (445), ItemDetailView (409), LoginView (407); all but the first shrank in this story. `AppButtonStyles.swift` has two raw opacity literals (0.85, 0.5); the repo has no opacity token.
- The `labelColor)` entry in the tint allowlist is a prefix match and a bit broad; the other tint scans constrain the rest.

## Existing tests changed (each asserts behavior this story deliberately changes)
StatusStyleScanTests `whiteAllowlist` trimmed to ItemStatusStyle.swift and ThemeTokenTable.swift (the five filled-button files no longer use `.white`), header comment fixed; SurfaceSourceScanTests header comment only; TabBarMinimizeScanTests `tabsUnchanged` now asserts there is NO `.tint(` in TabBarView.swift (it asserted `.tint(.primaryColor)`; the tint moved to the app root). None deleted or weakened; no other scan asserted `.tint(Color.primaryColor)` or `.borderedProminent`.

## Tests: arithmetic
4558 + 29 = 4587. New (parameterized counted as one): AppButtonStyleTests 15 (primarySpec, secondarySpec, destructiveSpec, destructiveIsNeverCustomPrimary, onlyPrimaryIsCustomPrimary, onlyDestructiveHasTheDestructiveRole, allThreeKindsExist, lightLabelIsWhite, darkLabelIsTheBackgroundPrimaryToken, labelReachesFourPointFiveOnThePrimaryFillInBothModes, lightLabelIsWhiteOnEvergreen, darkLabelIsNearBlackOnTheDarkEvergreen, whiteOnTheDarkFillWouldFail, minimumHeightIsFortyFour, minimumHeightMatchesTheBannerButtonHeight); ButtonChromeScanTests 14 (noGlassOrAppearanceApiAnywhere, appTintIsSetExactlyOnceInTheAppFile, appTintIsAppliedInsideAppContent, tabBarViewHasNoTint, borderedProminentIsGone, primaryButtonFilesUsePrimaryButtonStyle, styleFileDefinesTheStyleFromThemeTokens, whiteAppearsOnlyInTheStyleLayerAndTheTokenData, noButtonWithTheDestructiveRoleIsFilledOrPrimary, destructiveColorIsNeverAButtonBackgroundFill, archiveListIsBorderedWithDestructiveTint, remainingTintsAreAllowedTokens, noWhiteTintAnywhere, buttonsInTheThreeFilesHaveNoCornerRadiusLiteral). Rewritten/deleted: none (the three edits above change assertions, not counts). Package 212, release 92, destination 17 unchanged.

## Raw verification (before the commit, by running the commands)
```
--- tests: 4587 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is recorded in the TH1-6 report.

## Gate 2
- convention-reviewer: APPROVED (warnings: file lengths above, the opacity literals). Verified: no DispatchQueue, Combine, force unwrap, `as!` or logging added; pure types nonisolated; headers and previews present; accessibility lines untouched.
- acceptance-reviewer: APPROVED. Evidence: single app tint ChristmasTrackerApp.swift:456; no glass/appearance API; PrimaryButtonStyle AppButtonStyles.swift:12-29 with the contrast-tested label table; full-width frames moved into the labels (Sign In, Create Account, Enable, Unlock); Archive List ListDetailView.swift:371-381 bordered + destructive; Logout neutral; no UI test references the edited buttons; nothing outside appContent relied on a removed tint; no behavior change.
- Rejections: none. Stuck detector: one implementer loop, seven first-run failures that were test-allowlist/assertion adjustments and one old assertion, all different, clean on the second run.

## Not done or partial
- Nothing else in scope. The visual result of the prominent primary button in dark mode (the capsule and its dark label), the pressed and disabled looks, the spinner color inside the button, and the glass look of the navigation and tab bars are NOT verified: no simulator run was possible. Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout and the thumbnails all need eyes on the simulator).
