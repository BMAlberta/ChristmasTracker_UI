# TH1-2: Typography and Dynamic Type

Commit: "TH1: use Dynamic Type text styles and the serif accent". Pipeline: full (Gate 1 in Docs/epics/TH1-theme-pass.md; isolated test-writer, implementer, convention-reviewer, acceptance-reviewer, one after the other).
SwiftUI guidance (swiftui-expert-skill rules, passed to the implementer in the brief because subagents cannot invoke skills): modern APIs, private @State and @ScaledMetric, stable ids, no AnyView, Dynamic Type text styles, no fixed font sizes, semantic color tokens.

## After-commit run of the previous commit (TH1-1, a9e08cc), taken by running the commands
```
--- tests: 4431 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What changed
- `AppTypography` tokens are built from system text styles, so all text scales with Dynamic Type: appLargeTitle largeTitle bold; appTitle1/2/3 title/title2/title3 semibold; appHeadline headline semibold; appBody body; appCallout callout; appSubheadline subheadline; appFootnote footnote; appCaption1 caption; appCaption2 caption2 (all regular). At the default text size the point sizes equal the old fixed ones (34/28/22/20/17/17/16/15/13/12/11). Token names unchanged; the Text helpers kept.
- New `appBrand`: `Font.system(.title, design: .serif, weight: .semibold)` (the system serif). Used only for the app name on the login screen (LoginView) and the registration header "Join Christmas Tracker" (RegistrationView), and for EmptyStateView's title.
- `appIconHero` (fixed 64) removed. Every fixed `.font(.system(size: N))` became a private documented `@ScaledMetric` property: EmptyStateView and ErrorStateView hero 64 (relative to .largeTitle), BiometricSetupView 96, LoginView 72 and the biometric glyph 20 (relative to .headline), ForgotPasswordView 64, RegistrationView 64, ProfileView avatar 80 (relative to .title), row icon 20, chevron 14, icon slot 28 (now `minWidth`, not a fixed width).
- New pure `TypographyToken` table (style, weight, design; no point sizes).
- No lineLimit, truncation or minimumScaleFactor was added. The inventory found no fixed-width amount layout, so no minimumScaleFactor was recorded or needed.

## Files
Added: DesignSystem/Typography/TypographyToken.swift; ChristmasTrackerTests/DesignSystem/TypographyTokenTests.swift, TypographySourceScanTests.swift.
Changed: DesignSystem/Typography/AppTypography.swift; DesignSystem/Components/EmptyStateView.swift, ErrorStateView.swift; Features/Profile/Views/ProfileView.swift; Features/Authentication/Views/BiometricSetupView.swift, LoginView.swift, ForgotPasswordView.swift, RegistrationView.swift. No asset catalog file changed. Deleted: none.

## Deviations (visible changes, none blocking)
- Profile avatar initials: fixed 32pt semibold became appTitle1 (28pt semibold at the default size), so they are slightly smaller by default; the 80pt circle scales on the same curve.
- The registration title and the EmptyStateView title went from appTitle2 (22pt) to the 28pt serif appBrand, which follows from the brief's serif on a title style.
- ProfileView.swift (418 lines) and LoginView.swift (412 lines) are over the 400-line soft limit (limit 600); the story added about 12 and 6 lines. TypographyTokenTests.swift:150 is over 120 characters.

## Tests: arithmetic
Baseline for this story 4431 + 22 = 4453. New test functions (parameterized counted as one): TypographyToken table Tests 9 (tokenCount, rawValuesUnique, tableCoversEveryToken, specMatchesBrief, textStyleCount, resolvesToTextStyle, specHasNoSize, weightsFollowTheTheme, onlyBrandIsSerif); Typography Font accessor Tests 3 (accessorMatchesSpec, bodyLiteral, brandLiteral); Typography source scan Tests 10 (typographyFileIsSizeFree, iconHeroGone, noNumericSizes, identifierSizesAreAllowlisted, allowlistHasNoStaleEntries, brandUsage, serifOnlyInTypography, typographyFileHoldsSerif, noMinimumScaleFactor, lineLimitUsage). Rewritten or deleted: none. Package suite 212 (unchanged), release script tests 92, destination script tests 17. The scan test file needed one fix by the implementer (a `try` inside `||` did not compile; the call moved to a separate `let`; behavior unchanged).
Scans cover all app sources: no numeric `.system(size:` anywhere; identifier sizes only in the seven allowlisted files that declare @ScaledMetric (ProfileView, LoginView, BiometricSetupView, RegistrationView, ForgotPasswordView, EmptyStateView, ErrorStateView; no stale entries); `appBrand` only in the three named views; `.serif` only under DesignSystem/Typography; no minimumScaleFactor in Features or DesignSystem; lineLimit only in the three existing multi-line field files.

## Raw verification (before the commit, taken by running the commands)
```
--- tests: 4453 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is recorded in the TH1-3 report.

## Gate 2
- convention-reviewer: APPROVED. Warnings: the two files over 400 lines and one test line over 120 characters (above). Verified by grep: no DispatchQueue, Combine, `try!`, `as!`; every new @ScaledMetric is private with a documented base; nothing under .claude/, any .pbxproj, contract/, LocalPackages/ or synced Docs.
- acceptance-reviewer: APPROVED. Evidence: token mapping AppTypography.swift:12-26 and TypographyToken.swift:57-68; grep of `.system(size`, `Font.system(`, `.custom`, `UIFont` finds only @ScaledMetric-backed uses (EmptyStateView:40, ErrorStateView:22, BiometricSetupView:68, RegistrationView:110, ForgotPasswordView:19, LoginView:197 and :331, ProfileView:346 and :364); `appBrand` only at LoginView:200, RegistrationView:113, EmptyStateView:45; no behavior, copy, navigation or identifier change; the scans are not vacuous (stale-entry and exact-set checks); minimumScaleFactor is scanned in Features and DesignSystem only (grep shows none in App or Navigation).
- Rejections: none. Stuck detector: two implementer attempts with different errors (test target did not compile, then green); no repeat.

## Not done or partial
- Nothing else in scope. No simulator run was possible: Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout at the largest sizes and the thumbnails all need eyes on the simulator). Text is now Dynamic Type enabled, so wrapping, clipping and overlap at accessibility sizes are unverified.
