# TH1: The theme pass
Track: iOS. Depends on: UX1b (merged). Blocks: the release rehearsal and the iOS image package (the preview call, after the API's link-preview endpoint).
Contract state: unchanged; no contract change in this package.

Why: Brian's design theme (theme.pdf) defines the Christmas Tracker palette, status and budget colors, typography intent and component rules. The v2 app has most color tokens in the asset catalog but still draws item status in system colors, uses fixed font sizes that ignore Dynamic Type, and shows no product thumbnails. This package makes the app look like the theme, adapted to iOS 26.

The theme, copied from theme.pdf (the values are the authority; Brian decided on 2026-11-14 to KEEP these colors exactly and revisit the palette in a later UX pass):
- Brand: primary Evergreen light #1F4D3A, dark #4FA58A; accent Cranberry light #B23A48, dark #E06A75; highlight Warm Gold light #D6B25E, dark #E4C76A.
- Backgrounds and surfaces: background primary light #FAF9F7, dark #0F1A17; background secondary light #F2EFEA, dark #162622; surface (cards, modals) light #FFFFFF, dark #1E2E2A.
- Text: primary light #1F2933, dark #E6ECEA; muted light #6B7280, dark #9AA5A1. Border and divider: light #E2E2E2, dark #2C3F3A.
- Item status: AVAILABLE light #1F4D3A dark #4FA58A; PURCHASED light #2F7F6D dark #63BFA8; PARTIAL light #D6B25E dark #E4C76A; SHIPPED light #3A7CA5 dark #6FAED6; WRAPPED light #B23A48 dark #E06A75; GIFTED light #C9A227 dark #F0D97C.
- Budget state: under budget (safe) light #1F4D3A dark #4FA58A; near limit (warning) light #D6B25E dark #E4C76A; over budget light #B23A48 dark #E06A75.
- Typography intent: Inter for UI with weights body 400, labels 500, buttons 500 to 600, headings 600 to 700; Playfair Display for the app name, seasonal headers and empty or celebratory states, used sparingly.

iOS adaptation (decisions by Brian, 2026-11-14; these deviations from the PDF are intended):
1. FONTS. The UI uses the system font (SF) through Dynamic Type text styles, never fixed point sizes. The accent font is the system serif (`design: .serif`, New York), used ONLY for the app name, empty states and celebratory moments. No font files are bundled.
2. GLASS. The system chrome (navigation bars, toolbars, tab bar, system sheets and the system's own buttons) takes the iOS 26 glass look and is left to the system: no opaque custom backgrounds behind navigation or tab bars, no UIKit appearance overrides, no glassEffect on content. Content (cards, rows, lists, banners) is solid theme surfaces. The brand shows through the tint: the app tint is the Evergreen primary token.
3. CARDS AND SHADOWS. Cards are surface color with a hairline border token and continuous rounded corners; no drop shadows (the PDF's "subtle shadow" is replaced by the hairline).
4. STATUS STYLES. Item status uses TWO styles: the PILL WITH LABEL (a capsule with the status name in text; colored fill and a text color chosen for contrast) on item rows and on the item detail, and DOT AND TEXT (a small colored dot beside the status name in the primary text color) in compact places. The label text is ALWAYS present: color is never the only signal. The PDF's left-border style is not used.
5. DESTRUCTIVE. The destructive token becomes the theme's Cranberry (the accent colorset: light #B23A48, dark #E06A75) instead of the system red. Destructive buttons use the bordered style with the destructive tint (never a filled destructive button with a white label, which fails contrast in dark mode).
6. NO SEASONAL MODE in this build. No app icon work (see the report note below).
7. KNOWN CONTRAST EXCEPTIONS (accepted, to be fixed in the later palette pass): muted text on the secondary background in light mode is about 4.2:1, and the destructive color as small text on the surface in dark mode is about 4.4:1. Both are recorded in the contrast test's exception list with their measured ratio and must not get worse. If any OTHER pair the app uses fails, STOP and report it (do not change a token value yourself).

Scope: Assets.xcassets colorsets and DesignSystem tokens; contrast and token tests; typography tokens and every fixed-size font use; status and budget styles and every place they show; screen backgrounds, cards and list rows; navigation and tab tint, buttons and the destructive token; empty and error states; item thumbnails (display only).

Non-goals: behavior, logic, services, repositories, authentication, the lock, purchase behavior, UX1a and UX1b behavior, the product-image preview call (a later package), the seasonal mode, the app icon, new screens, bundled fonts, any contract change.

Acceptance
- Every theme color exists as a colorset with exactly the light and dark values above (a test reads the asset JSON and compares); the Color accessors exist for every token; the budget tokens exist.
- A pure contrast helper computes WCAG contrast from the colorset values; a test requires 4.5:1 for every text pair and pill label pair the app uses, in light and dark, and 3:1 for large text and meaningful graphics, with the exception list from decision 7 pinned at its measured ratios.
- No fixed font size remains in DesignSystem or Features (a scan test, with a documented allowlist for icon and hero sizes that use @ScaledMetric or are decorative); every text style scales with Dynamic Type.
- ItemStatus colors come from the tokens (no system colors); the pill and the dot-and-text components exist with a pure style function per status and a test for every status in light and dark; every status display in the app uses one of the two components.
- The budget card, progress and summary use the budget tokens through a pure style function, with the near-limit threshold constant (decision below); the text always states the state in words.
- No system color literal (`.red`, `.green`, `.orange`, `.blue`, `.purple`, `.gray`, `.yellow`, `.pink`, `Color(red:`, hex strings) remains in Features or DesignSystem views (a scan test with a documented allowlist: `.white` or `.black` only where a pure style function chooses a text color for a fill, and `.clear`).
- Glass: no glassEffect, no custom opaque navigation or tab bar background, and no UIKit appearance override anywhere (a scan test); the app tint is the primary token; buttons use the theme styles.
- Thumbnails: one ItemThumbnail component; only a valid https URL is ever requested; any other value shows the placeholder; the failure state equals the placeholder; the image cache is cleared on every session end through the existing teardown (a test with a fake cache seam).
- Session safety and every behavior outside presentation unchanged; no change under contract/, .claude/, any .pbxproj, the synced Docs files, or LocalPackages/.

Decision (a default that Brian can change): the near-limit threshold is 90 percent of a limit spent and not over. The theme does not define it.

---

# Inventory (read-only, taken on branch feat/th1-theme-pas, which is the branch Brian created, spelled with one "s"; HEAD 81a1aed, the merged UX1b PR 36)

"A/" = ChristmasTracker/ChristmasTracker/. "T/" = ChristmasTracker/ChristmasTrackerTests/.

Baseline (P2): scripts/verify.sh ends `verify: OK` with `tests: 4398 passed, 0 failed, 0 skipped`, release-script tests 92, destination-script tests 17; `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.

## Colorsets
Every colorset has three entries: a no-appearance fallback placeholder (#FEFFFF, or 255,255,255 in accentColor), then light and dark luminosity entries; all srgb, alpha 1.000. Number formats are mixed: hex strings ("0x4F"), and decimal strings in primaryColor's light entry ("32","77","58"). The token test parser must therefore accept hex strings, decimal strings and floats.
- All 15 theme colorsets (primary, accent, highlight, backgroundPrimary, backgroundSecondary, surface, primaryText, mutedText, border, and the six status colorsets) match the brief EXCEPT primaryColor light, which is #204D3A (R 32) instead of #1F4D3A (R 31). T1 fixes it. statusAvailableColor is already #1F4D3A.
- Colors/Budget holds only a folder Contents.json: no budget colorsets and no budget accessors. T1 adds them.
- AccentColor.colorset (A/Assets.xcassets/AccentColor.colorset) has no color value (system blue); ProfileView.swift:338 uses `.foregroundStyle(.accent)` and so renders system blue.
- A/DesignSystem/Colors/AppColors.swift:17 defines `Color.accentColor` as the Cranberry asset, shadowing SwiftUI's accent. Every `Color.accentColor` use resolves to Cranberry today (LoginView.swift:283,383; RegistrationView.swift:205,232; AddMemberView.swift:48; EditListView.swift:248; ListDetailView.swift:301; CreateListView.swift:201; AddChildView.swift:111).
- AppColors.swift:34 and :37 map textPrimaryColor and textMutedColor to the colorsets "primaryTextColor" and "mutedTextColor". Line 51: `destructiveColor = Color(uiColor: .systemRed)`.
- AppIcon.appiconset: only Contents.json; three slots (default, dark, tinted), none with a filename. NO image exists. (State only; no work in this package.)

## Color literals in Features and DesignSystem
- DesignSystem: EmptyStateView.swift:56 and ErrorStateView.swift:43 `.white` labels on primary-filled buttons; ErrorStateView.swift:20 `.red`; Loading/SkeletonView.swift:39-41 `Color.gray.opacity` shimmer and :60 `.shadow(.black.opacity(0.05))`; InlineErrorBanner.swift:45 `destructiveColor.opacity(0.12)`.
- Features: white labels on primary-filled buttons at LoginView.swift:297,303, RegistrationView.swift:317,323, BiometricSetupView.swift:90,96, App/LockView.swift:163; opacity 0.5 disabled state at LoginView.swift:309 and RegistrationView.swift:329; ProfileView.swift:95 `primaryColor.opacity(0.2)`, :373 shadow; ItemDetailView.swift:223 `highlightColor.opacity(0.25)`; ListDetailView.swift:379 a FILLED destructive Archive button with a `surfaceColor` label (:371-380); ProfileView.swift:277 Logout label `surfaceColor` on a primary fill; ListComponents.swift:43-46 ListBadge label and `tone.color` fill.
- Core: ItemStatus.swift:41-45 `ItemStatus.color` returns .gray/.orange/.green/.blue/.purple with ZERO callers in app code (only a generic `kind.color` in a test). Core/Models/ListRoleBadge.swift:62-67 `Tone.color` (role badges: owner primary, coOwner Color.accentColor, member highlight, viewer muted).
- Not present: other system color names, `Color(red:`, hex strings, UIColor in app sources.

## Fonts
- A/DesignSystem/Typography/AppTypography.swift:11-23: every token is a fixed `Font.system(size:)` (appIconHero 64; LargeTitle 34 bold; Title1 28 semibold; Title2 22; Title3 20; Headline 17 semibold; Body 17; Callout 16; Subheadline 15; Footnote 13; Caption1 12; Caption2 11). Text helpers `appLargeTitle()` etc. (lines 25-49) have no callers outside.
- Token usage: appIconHero 2 (ForgotPasswordView.swift:16, RegistrationView.swift:107), appLargeTitle 1, appTitle1 9, appTitle2 7, appTitle3 7, appHeadline 41, appBody 56, appCallout 8, appSubheadline 4, appFootnote 0, appCaption1 45, appCaption2 4.
- Fixed `.font(.system(size:))` outside the tokens: EmptyStateView.swift:37 (64); ErrorStateView.swift:19 (64); ProfileView.swift:99 (32), :337 (20), :355 (14); BiometricSetupView.swift:65 (96); LoginView.swift:194 (72), :325 (20).
- Fixed frames: ProfileView.swift:96 (80x80 avatar), :339 (width 28 icon); LoadingView.swift:42 and SkeletonView.swift:24 (height 200); LoginView.swift:361,368 (1pt dividers).
- `minimumScaleFactor`: none. `lineLimit`: only multi-line text fields (ManagePurchaseView.swift:249, RecordPurchaseFormFields.swift:39, ItemFormFields.swift:33). Amount and name texts use `.fixedSize(horizontal: false, vertical: true)` (BudgetCardView.swift:25,73,79,126; SpendByPersonView.swift:71,82; StatsSummaryCardView.swift:59). Large-type reflow already exists in BudgetAmountLine (BudgetCardView.swift:88-128), SpendRowView, StatsSummaryCardView and ItemPurchaseRow.swift:34. No fixed-width layout needing minimumScaleFactor exists, so none is added.
- Semantic fonts (`.font(.title)` etc.): none.

## Item status and shipping status
- A/Core/Models/ItemStatus.swift: cases available, partial, purchased, wrapped, gifted (NO shipped case); `displayName` ("Available", "Partially Purchased", "Purchased", "Wrapped", "Gifted"), `icon`, and the dead `color` at line 39.
- A/Features/Items/Components/ItemStatusStyle.swift:11-20: `ItemStatus.tokenColor` maps to the status colorsets; this is what the views use. (The brief's "ItemStatus.color" is therefore `tokenColor` plus the dead `color`; T3 removes the system-color `color` and routes everything through the new style layer.)
- A/Core/Models/ListItem.swift: `imageUrl: String?` (line 32), `status` (line 36). ItemViewState.swift: `statusMarker: ItemStatus?` in ItemRowState (lines 48, 58-67, 90) and ItemDetailState (177, 211); it is nil when the viewer may not see gift activity (blind viewers and viewers see no status).
- Display sites:
  1. ROW: Features/Items/Components/ItemRow.swift:17-22 (leading status icon, tokenColor) and :29-33 (caption with `displayName`, shown when the marker is not available). Reached by: Dashboard tab, tap a list row, ListDetailView items section (ItemsSectionView.swift:95-100).
  2. DETAIL: Features/Items/Views/ItemDetailView.swift:225-229 (`Label(marker.displayName, systemImage:)` in headerCard). Reached by: Dashboard tab, a list row, an item row.
  3. DETAIL: ItemDetailView.swift:179 and :240-264, the "Purchase Status" card: progress, "N remaining" and ItemPurchaseRow. ItemPurchaseRow.swift (Features/Items/Views) shows the purchaser, quantity and cost only; it displays NO status.
  4. SHIPPING: Features/Purchases/Views/ManagePurchaseView.swift:180-184 is a `Picker("Status")` over `PurchaseShippingStatus.allCases` (RecordedPurchase.swift:12-22: notTracked, notShipped, shipped, delivered) as plain text, uncolored. It is an input control, not a status display; `statusShippedColor` has no view use.
  5. NO other place shows item status: ListPreviewCard and ListCountsView show counts and a progress bar only.
- COMPACT places (neither row nor detail): NONE found. T3 builds and tests `StatusDotLabel`, but no production screen needs it today (see the T3 Gate 1 decision). The handoff's step 7 therefore states that there are no compact places.

## Budget
- Features/Budgets/ViewState/BudgetCardState.swift: `BudgetPersonRowState` (lines 11-33) and `BudgetCardState` (35-109); NO under/near/over enum, only `isOver` (`spent > limit`, Decimal, lines 21 and 96). Status wording (74-79): "Over by <money>" or "<money> remaining". Progress clamps to 0...1 (103-108).
- Features/Statistics/Views/BudgetCardView.swift: statusText :22-25 (`isOver ? destructive : textPrimary`), card ProgressView :26-27 (`isOver ? destructive : primary`), person rows :55-85 (statusText `isOver ? destructive : textMuted`; no per-person bar), CreateBudgetButton :162 (borderedProminent primary).
- Related: StatsSummaryCardView.swift (card style `statsCardStyle()` :66-71), SpendByPersonView.swift (no color logic), BudgetCardMenu.swift, Purchases/Views/BudgetWarningPanel.swift (:64-66 destructive icon on over-budget rows; buttons Record Anyway prominent, Edit Details bordered, Cancel bordered muted; this is the server-driven confirmation flow and keeps its behavior), Budgets/Views/BudgetEditorView.swift (:95,257,274 destructive error text).

## Surfaces, tints, appearance
- Page backgrounds use backgroundPrimaryColor on about 20 screens (StatsView:32, DashboardView:28, ProfileView:65, ListDetailView:46, ItemDetailView:61, and the form screens, DesignSystem state views, ConfigurationErrorView:20 and PrivacyCoverView:11).
- `scrollContentBackground(.hidden)`: AddMemberView:60, EditListView:143, AddChildView:76, ChildrenView:79, DashboardView:278. `listRowBackground(Color.clear)`: ManagePurchaseView:82,177,243,300; RecordPurchaseView:92; DashboardView:347; EditItemView:64; AddItemView:56; ChildrenView:143,156. `listRowBackground(Color.surfaceColor)`: ChildrenView:170,186,360.
- Hand-built cards: `listCard()` (ListComponents.swift:13-31; surface, clip radius md, border stroke; used by ListPreviewCard:44 and ItemDetailView:237,263); `statsCardStyle()` (surface only); ProfileView.swift:372-373 CardContainerView (surface, radius 12, SHADOW); SkeletonView.swift:58-60 (surface, radius 12, SHADOW); LoadingView.swift:43; LoginView.swift:337-339 (biometric button, 2pt primary stroke), :392-396 (field style, 1pt border, radius 8); RegistrationView.swift:287-288; CreateListView.swift:192 (backgroundSecondary); ListComponents.swift:56-61 archived badge; ItemRow.swift:42 Surprise badge; InlineErrorBanner.swift:45.
- Tints: `.tint(Color.primaryColor)` on many individual controls; the only app-level tint is TabBarView.swift:37 `.tint(.primaryColor)` on the TabView. `.tabBarMinimizeBehavior(.onScrollDown)` at TabBarView.swift:39 (guarded by T/Navigation/TabBarMinimizeScanTests.swift).
- No `toolbarBackground`, `toolbarColorScheme`, `glassEffect`, UIKit appearance proxy or `.appearance()` anywhere. `preferredColorScheme` appears only in previews.
- Root: ChristmasTrackerApp.swift:442-451 (`WindowGroup` with `ConfigurationErrorView` or `appContent`, :453-); ContentView.swift:9-24 (`TabBarView()` or `LoginView()`). The lock and privacy covers are separate UIKit windows that use explicit colors and do not inherit a SwiftUI tint.

## Buttons
- No custom `ButtonStyle`. borderedProminent (primary tint): BudgetCardView:162; RecordPurchaseRecordSection:28; RecordPurchaseExpiredNotice:24; BudgetWarningPanel:35; ManagePurchaseView:216,278; ItemDetailView:278. bordered: InlineErrorBanner:93; BudgetWarningPanel:42,49; MembersSectionView:74,89; ManagePurchaseView:321; ItemDetailView:296. plain: DashboardView:288; ProfileView:281,325; ItemsSectionView:101; ItemPurchaseRow:25; MembersSectionView:147. borderless: BudgetEditorView:264. No glass styles.
- Hand-built filled primary buttons with hardcoded white labels: EmptyStateView:56, ErrorStateView:43, LoginView:303, RegistrationView:323, BiometricSetupView:96, App/LockView:163; label `surfaceColor` on primary: ProfileView:277 (Logout, intentionally neutral). Filled destructive: ListDetailView:371-380 (Archive List).
- DesignSystem/Components/DestructiveAction.swift: `DestructiveActionKind` (archive, delete, remove, leave, clear), `.color` = `Color.destructiveColor`, `View.destructiveTint()`. `role: .destructive` sites are listed in the UX1b epic; T/Features/Shared/DestructiveRealFilesTests.swift scans only Features/ and App/ and allowlists the ErrorStateView raw red.

## States
- EmptyStateView.swift: icon size 64 muted (:37-38), title appTitle2 (:42-43), message appBody, optional action button white on primary with `.cornerRadius(12)` (:53-61), background backgroundPrimary (:66).
- ErrorStateView.swift: icon size 64 with raw `.red` (:18-20), title appTitle2, message, Try Again white on primary (:36-47).
- InlineErrorBanner.swift: padding, `destructiveColor.opacity(0.12)` background, radius md (:44-45), destructive icon (:53-54), bordered buttons tint primary (:84-95), min height 44. InlineErrorBannerState.swift has no color or font references.

## App name
LoginView.swift:196 ("Christmas Tracker", appTitle1, under a gift.fill size 72 icon at :194); RegistrationView.swift:109 ("Join Christmas Tracker", appTitle2); App/LockView.swift:114 and App/PrivacyCoverView.swift:13 (appTitle1). Empty states do not show the name.

## Images
No AsyncImage, UIImage or image loading exists. `ListItem.imageUrl` is carried end to end (model, mapping at Items/Repositories/ItemMapping.swift:55, form field ItemFormFields.swift:17,40, validation in ItemFormValidation.swift, which accepts absolute http or https) but NEVER displayed; ItemRowState and ItemDetailState do not carry it. ItemRow.swift: outer `HStack(spacing: AppSpacing.md)` (:16): optional status icon (leading, :17-22), text VStack, Spacer, Surprise badge, chevron; wrapped in a plain Button in ItemsSectionView.swift:95-100. ItemDetailView headerCard (lines 192-238) is a VStack: title, description, price, quantity, priority, product link, surprise label, status, updated.

## Teardown
- A/Features/Authentication/Services/SessionClearable.swift: `protocol SessionClearable: AnyObject, Sendable { func clearForSession() async throws }`; `makeProductionClearables(...)` returns a 10-element array; tests assert its count, indices and parameter order (PurchaseServiceManagementClearableTests.swift:56, BudgetCompositionTests.swift:15,221-227, PurchaseCompositionTests.swift:223-224).
- A/Features/Authentication/Services/SessionManager.swift (an actor): `register(_:)` appends a clearable (lines 26-28); `teardown(reason:)` (33-52) awaits every clearable (a failure is caught and logged and does not stop the rest), then ALREADY calls `URLCache.shared.removeAllCachedResponses()` (:46) and deletes cookies. ChristmasTrackerApp.swift:356-368 builds the clearables and the SessionManager.
- Fake: T/Features/Authentication/MockSessionClearable.swift. A suitable registry exists, so T6 does not stop: the new image cache clearable registers through `SessionManager.register` (leaving the 10-element array and its scan tests alone).
- Note for the T6 report: the teardown already clears URLCache.shared directly, which untested code covers today; the new clearable makes the clear explicit and testable through a seam. The existing direct call is session logic and is left unchanged.

## Tests
Swift Testing; source scans locate the tree with `ItemSourceTree.load(from: #filePath)` (T/Features/Items/ItemSourceScanSupport.swift:12-57; `ItemSourceScan.codeOnly`, `matchingLines`, `braceBody(after:)`); scanner files under T/Features/Shared/ (DialogScanner, DestructiveScanner and their real-file tests; UX1aErrorScanTests). DestructiveColorTests.swift (T/DesignSystem) asserts destructiveColor == UIColor.systemRed in both modes and DestructiveActionKindTests.swift:29 asserts `kind.color == Color.destructiveColor`; both change in T1 (they exclusively assert the system-red behavior this package deliberately changes). Other scans that assert specific tokens in view files must be checked before editing a view: Features/Lists/*ScanTests, Features/Budgets/BudgetViewScan*, Features/Purchases/*ScanTests, Features/Items/ItemUIRulesScanTests.swift, ItemDetailPurchaseOpenScanTests.swift, LoginFaceIDHintScanTests.swift, App/BootstrapSourceScanTests.swift.

---

# Gate 1 specs

Common rules for every subagent brief: edit files with the edit tool only (no python, perl, sed -i, heredocs or scratch scripts); no Combine, no GCD, the word DispatchQueue must not appear in any changed file even in a comment; no force unwraps or `as!`; no logging of URLs, names, amounts or raw errors; SwiftUI rules: modern APIs, private @State, stable ids, no AnyView, Dynamic Type text styles, no fixed font sizes, semantic color tokens. Applied by the Orchestrator from the swiftui-expert-skill.

## Gate 1: T1 Tokens, asset catalog and contrast tests
Contract slice: none.
Acceptance:
- primaryColor light becomes #1F4D3A (the light entry is rewritten in the same string format as its neighbors); the fallback placeholder entries are left alone.
- Add colorsets Colors/Budget/budgetSafeColor, budgetWarningColor, budgetOverColor with the brief's budget values (Contents.json for the folder already exists) and the accessors `Color.budgetSafeColor`, `budgetWarningColor`, `budgetOverColor`.
- `destructiveColor` becomes `Color("accentColor")`, the same asset as `Color.accentColor` (one destructive token; doc comment updated; the doc comment of every token lists its light and dark hex). The AccentColor.colorset (the app-icon-style global accent) is filled with the primary values so any remaining system accent lookup is Evergreen, not blue.
- New interface (pure, nonisolated, in DesignSystem): `ThemeContrast` (relative luminance and contrast ratio from sRGB bytes); `ThemeTokenTable` (the expected hex per token, light and dark, the brief's values; a token enum with the colorset name and group); `ThemeHex` parse helper if needed. The tests read every Contents.json under Assets.xcassets from the source tree, parse the light and dark entries (hex strings, decimal strings, floats), and compare to the table; they also assert every accessor in AppColors.swift names an existing colorset and every colorset is reachable from an accessor.
- Contrast pairs (light and dark), threshold 4.5 for text and pill labels, 3.0 for large text and graphics: textPrimary and textMuted each on backgroundPrimary, backgroundSecondary and surface; the budget colors against surface and background (text 4.5 where the app draws them as text, otherwise graphics 3.0); destructive against surface and background (text); primary against surface and background (text and tint); each status fill against the background and surface as a graphic (3.0); and the pill label pairs chosen in T3 (declared in T1 as a `ThemeStatusLabelTable` of fill token and label token per mode: white `#FFFFFF` on available, purchased, shipped, wrapped in light; primaryText on partial and gifted in light; backgroundPrimary dark on every fill in dark). Exceptions pinned with floors: textMuted on backgroundSecondary in light (about 4.2) and destructive text on surface in dark (about 4.4); everything else at the threshold. If another pair fails, STOP and report; no token value is changed by us. White-on-gifted and similar pairs that fail are exactly such a STOP.
- Existing tests rewritten: DestructiveColorTests (now compares to the accent colorset values in both modes) and DestructiveActionKindTests line 29 remains valid. Name them in the report.
Scoped files: A/Assets.xcassets/Colors/**, A/DesignSystem/Colors/AppColors.swift, new DesignSystem/Colors/ThemeContrast.swift and ThemeTokenTable.swift, T/DesignSystem/*.
New interface: yes (ThemeContrast, ThemeTokenTable). Full pipeline.

## Gate 1: T2 Typography and Dynamic Type
Contract slice: none.
Acceptance:
- Every AppTypography token maps to a text style: appLargeTitle .largeTitle bold; appTitle1 .title semibold; appTitle2 .title2 semibold; appTitle3 .title3 semibold; appHeadline .headline (semibold); appBody .body; appCallout .callout; appSubheadline .subheadline; appFootnote .footnote; appCaption1 .caption; appCaption2 .caption2; a label weight (medium) is available as `appLabel` only if a caller needs it. Token names stay. New `appBrand` (`.largeTitle`/.title design .serif, semibold). `appIconHero` stays decorative and is replaced at its two call sites by @ScaledMetric sizes.
- A pure `TypographyToken` table (token name to text style and weight, no point sizes) tested; every token resolves to a text style.
- Every fixed `.font(.system(size:` in DesignSystem and Features is replaced by a token or a @ScaledMetric base (documented in a comment): EmptyStateView:37, ErrorStateView:19, ProfileView:99,337,355, BiometricSetupView:65, LoginView:194,325, ForgotPasswordView:16, RegistrationView:107. Fixed frames around text are replaced by @ScaledMetric or a minHeight (ProfileView:96,339). No lineLimit or truncation is added; no minimumScaleFactor (the inventory shows no fixed-width amount layout).
- Serif accent only on: the app name in LoginView:196 and RegistrationView:109, and EmptyStateView's title. LockView and PrivacyCoverView keep appTitle1 (they show the name but are system-window covers; Brian's list names login and registration headers). 
- Scans: no `Font.system(size:` or `.font(.system(` in DesignSystem/ or Features/ outside a documented allowlist (the AppTypography file itself holds none); `appBrand` appears only in LoginView, RegistrationView and EmptyStateView.
Scoped files: DesignSystem/Typography, EmptyStateView, ErrorStateView, ProfileView, BiometricSetupView, LoginView, ForgotPasswordView, RegistrationView, T/DesignSystem.
New interface: yes (TypographyToken table, appBrand). Full pipeline.

## Gate 1: T3 Status and budget styles
Contract slice: none.
Acceptance:
- New pure nonisolated `StatusKind` (available, partial, purchased, shipped, wrapped, gifted) with `init(_ ItemStatus)` and `init(_ PurchaseShippingStatus)?` (shipped maps; the other shipping cases return nil), and `StatusStyle.style(for:)` returning the fill token, the label token for light and for dark, the short label (Available, Partial, Purchased, Shipped, Wrapped, Gifted) and the accessibility label ("Status: <name>"). `displayName` on ItemStatus stays. The dead system-color `ItemStatus.color` and `ItemStatus.tokenColor`'s duplicate are removed; ItemStatusStyle.swift becomes the style layer.
- `StatusPill` (capsule, short label, label color from the style; one accessibility element reading "Status: <name>") replaces the icon and caption in ItemRow (:17-33) and the Label in ItemDetailView (:225-229). The row keeps its text layout; the pill sits where the caption was, and it is shown for every marker including available (the theme shows AVAILABLE as a pill; the marker is still nil for viewers who may not see activity).
- `StatusDotLabel` (8 point dot, via @ScaledMetric, plus the label in the primary text color; one accessibility element). Decision for Brian: no production place shows item or shipping status compactly, and the shipping `Picker` in ManagePurchaseView is an input control, so no UI is added there. The component is built, previewed and unit tested but has no production caller. The handoff states this.
- Budget: `BudgetLevel` (under, nearLimit, over) and pure `BudgetStateStyle.style(spent:limit:)` with `nearLimitThreshold = 0.9` as a named constant: over when spent > limit; nearLimit when spent >= 0.9 * limit and not over (exactly 90 percent is near; exactly at the limit is nearLimit, since not over); otherwise under; limit <= 0 with spent > 0 is over, with spent 0 under. Returns the token, a word label ("Under budget", "Near limit", "Over budget"), and accessibility text. BudgetCardState gains the level and its token for the card and each person row; the card's statusText wording stays ("Over by X", "X remaining") and the level words are added as a separate line or prefix only for nearLimit ("Near limit" is part of the status text, for example "Near limit. X remaining"). Over budget is never color alone ("Over by X" exists). ProgressView tint, the figures and the person status use the style. Existing BudgetCardState tests that pin wording for the near range are adjusted and named.
- Scans: no system color on a status; `ItemStatus.color` and system color use gone; status views use StatusPill.
Scoped files: Core/Models/ItemStatus.swift, Features/Items/Components/ItemStatusStyle.swift, ItemRow.swift, ItemDetailView.swift, new Features/Items/Components/StatusPill.swift and StatusDotLabel.swift, Features/Budgets/ViewState/BudgetCardState.swift, new BudgetStateStyle.swift, Features/Statistics/Views/BudgetCardView.swift, T/**.
New interface: yes. Full pipeline.

## Gate 1: T4 Surfaces, cards and list rows
Contract slice: none.
Acceptance:
- `AppCard` modifier (surface fill, hairline border token at 1 point, continuous rounded corners at the named constant `AppCard.cornerRadius` = AppSpacing.md, standard padding AppSpacing.md, no shadow). Used by listCard() (which becomes a thin wrapper or is replaced), statsCardStyle(), ProfileView CardContainerView, SkeletonView and LoadingView cards. Shadows removed.
- Raw colors removed from views: ErrorStateView `.red` becomes the destructive token; skeleton shimmer uses border and backgroundSecondary tokens; InlineErrorBanner keeps `destructiveColor.opacity(0.12)` (a token tint, documented, allowlisted as a token-derived fill); ProfileView avatar `primaryColor.opacity(0.2)` is the same documented token-derived tint; ItemDetailView:223 highlight tint likewise. `.white` and `.black` remain only inside a pure style function that picks a label color for a fill (T3/T5); `.clear` allowed.
- Screen backgrounds stay backgroundPrimary; grouped panels backgroundSecondary; List rows that sit on cards use surface through listRowBackground (ChildrenView keeps surface; the `Color.clear` rows on screens with their own background stay).
- The role badge Tone colors and ListBadge keep their tokens; `Color.accentColor` uses (Cranberry today) move to a neutral link color: hint and link text uses primaryColor; this is a deliberate presentation change recorded in the report (a Cranberry link reads as destructive).
- Scans: no system color literal in Features or DesignSystem (allowlist documented); no hand-built card (surface fill plus border or clip) outside AppCard, with a documented allowlist (field style, biometric button).
- Keeps DestructiveRealFilesTests green; its documented ErrorStateView exception is removed, and the scan scope widens to DesignSystem/.
Scoped files: DesignSystem/Components/*, Loading/*, ListComponents.swift, StatsSummaryCardView.swift, ProfileView.swift, LoginView.swift (field and biometric button), CreateListView, plus the `Color.accentColor` sites listed in the inventory, T/**.
New interface: yes (AppCard). Full pipeline.

## Gate 1: T5 Glass chrome, tint and buttons
Contract slice: none.
Acceptance:
- One `.tint(Color.primaryColor)` at the root (the existing TabBarView.swift:37 tint moves to the root: on ContentView's group in ChristmasTrackerApp `appContent`, so login and tabs both get it; exactly one `.tint(` for the app tint). Per-control `.tint(Color.primaryColor)` calls that merely repeat the app tint are removed; other tints (destructive, muted) stay.
- No glassEffect, toolbarBackground, UIKit appearance proxy anywhere (scan). Before using `.buttonStyle(.glass)` or `.glassProminent`, the implementer reads the iOS 26 SDK swiftinterface to confirm names and availability; not required to use them.
- Pure `ButtonRole`-style mapping `AppButtonKind` (primary, secondary, destructive) to a style value (prominent, bordered) and tint token. Primary = prominent with the primary tint; secondary = bordered with the primary tint; destructive = bordered with the destructive tint and `role: .destructive`.
- Primary label contrast: system `.borderedProminent` draws a white label on the tint, which fails in dark mode on #4FA58A (about 2.5 to 1). The implementer proves the pair with ThemeContrast; if the system cannot draw a dark label in dark mode, a small `PrimaryButtonStyle` (capsule, primary fill, label from the contrast-tested table: white in light, backgroundPrimary dark token in dark) replaces the hand-built filled buttons at EmptyStateView:56, ErrorStateView:43, LoginView:303, RegistrationView:323, BiometricSetupView:96, LockView:163, ProfileView:277 and `.borderedProminent` primary actions. The decision and reason are recorded in the report.
- ListDetailView:371-380 filled destructive Archive becomes bordered with the destructive tint and role destructive (UX1b's Archive dialog behavior unchanged).
- Scans: no glassEffect, no opaque nav or tab background, no appearance proxy, tint set exactly once, no `.borderedProminent` with a destructive tint, destructive kinds never prominent.
Scoped files: ChristmasTrackerApp.swift (the tint only), Navigation/TabBarView.swift, DesignSystem/Components (button style), the button sites above, T/**.
New interface: yes. Full pipeline (touches the Login and Lock screens' button styling only; no auth logic).

## Gate 1: T6 Item thumbnails (display only)
Contract slice: none (`imageUrl` already in the generated model).
Acceptance:
- `ThumbnailURL.validate(_ String?) -> URL?` (pure, nonisolated): absolute https URL, non-empty host, at most 2048 characters; anything else is nil. `ItemThumbnail` (size from @ScaledMetric, base 56, capped so accessibility sizes shrink the thumbnail to a bound; at accessibility sizes the row thumbnail is hidden, detail keeps it; decision recorded), continuous corners, AsyncImage only for a valid URL; placeholder and failure are one view (backgroundSecondary with a gift symbol in muted). Accessibility hidden. No URL logged or reported.
- `ItemRowState` and `ItemDetailState` gain `imageUrl: String?` (presentation only); ItemRow gets a leading thumbnail; the detail header gets it as the first child.
- `ImageCacheClearing` seam (`func removeAllCachedResponses()`), `URLCacheClearer` (calls URLCache.shared) and `ImageCacheClearable: SessionClearable` (calls the seam once per `clearForSession`). Registered through `SessionManager.register` in ChristmasTrackerApp composition. Test with a fake seam and the existing SessionManager (MockSessionClearable pattern): one clear per teardown. The 10-element production array and its scan tests are not changed.
- Scan: AsyncImage and `URLSession` image use appear only in ItemThumbnail.
- No test loads an image or touches the real URLCache.
Scoped files: new DesignSystem or Features/Items/Components/ItemThumbnail.swift, ThumbnailURL.swift, ImageCacheClearable.swift; ItemRow.swift, ItemDetailView.swift, ItemViewState.swift, ChristmasTrackerApp.swift (one register call), T/**.
New interface: yes. Full pipeline (touches session composition: one register line only).

## Gate 1: T7 Handoff and real-mode check
Docs only: Docs/handoffs/2026-11-14-ios-to-brian-th1.md (date of the run) with the fixed steps from the prompt, step 7 derived from the final inventory (currently: no compact places, so the step says so and is NOT PERFORMED), and report TH1-7-handoff.md.
