# BA1: Brand assets (app icon and launch screen)

Package BA1 (branch `feat/ba1-brand-assets`, from master at the TH1.1 merge 0b1b79b). One code story: A1 assets and configuration. Source: the unzipped brand package (read-only, outside the repo, never committed as a folder).

## Decisions (Brian, 2026-11-14)

1. The app icon uses the asset catalog route (no Icon Composer `.icon` file). The existing `AppIcon.appiconset` Default and Dark 1024 slots are filled. The tinted slot stays empty (no image supplied).
2. The launch screen uses the Info.plist route: a `UILaunchScreen` dictionary with `UIColorName` and `UIImageName`, a named background color and the glyph image, adaptive to dark mode. There is no storyboard and no title on the launch screen. The app name appears on the first app screen in the system serif accent from TH1 (not part of this package).
3. Nothing in this package changes behavior, services, screens or tokens.

## P3 resolution

The first run found `INFOPLIST_KEY_UILaunchScreen_Generation = YES` in the three app-target build configurations (project file lines 460, 497, 683), next to `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = ChristmasTracker/Info.plist`. That would have conflicted with an Info.plist `UILaunchScreen` dictionary, so the package stopped. Brian changed the setting himself and committed it as ecd7992 `BA1: stop generating the launch screen from a build setting`. Re-check on resume (read-only): the only remaining launch-screen build key is `INFOPLIST_KEY_UILaunchScreen_Generation = NO` at lines 460, 497 and 683, and Info.plist has no launch key. The project file is never edited by the agent.

## Gate 1 spec

- Contract slice: none. No networking, API model or repository change.
- New interface: none. Assets, one Info.plist key and one test file, so the solo path applies. Gate 2 runs the convention-reviewer and the acceptance-reviewer (which must read the JSON and the plist, not only the tests).
- Scoped files:
  - `ChristmasTracker/ChristmasTracker/Assets.xcassets/AppIcon.appiconset/` (two PNGs added, `Contents.json` edited)
  - `ChristmasTracker/ChristmasTracker/Assets.xcassets/LaunchGlyph.imageset/` (new: six PNGs and `Contents.json`)
  - `ChristmasTracker/ChristmasTracker/Assets.xcassets/LaunchBackground.colorset/` (new: `Contents.json`)
  - `ChristmasTracker/ChristmasTracker/Info.plist` (one new key)
  - `ChristmasTracker/ChristmasTrackerTests/DesignSystem/BrandAssetsTests.swift` (new)
  - `ChristmasTracker/ChristmasTrackerTests/DesignSystem/ThemeAssetCatalogTests.swift` (one test, see the note below)
  - Docs: this brief, reports and the handoff.
- Note on an existing test: `ThemeAssetCatalogTests.noExtraColorsets` requires exactly the 18 token colorsets plus `AccentColor` (19) and fails on any other colorset. `LaunchBackground` is a deliberate new colorset that is not a theme token, so that test's expected set and count are updated to allow it (20). No token, token value or palette changes.
- Acceptance criteria:
  - A1.1 `AppIcon.appiconset/Contents.json` names `app-icon-1024.png` in the default slot and `app-icon-dark-1024.png` in the dark slot, keeping each slot's idiom, platform, size and appearances. The tinted slot has no filename. Both files match the package hashes and are 1024 by 1024, PNG color type 2 (RGB, no alpha), bit depth 8.
  - A1.2 `LaunchGlyph.imageset` has six entries (1x, 2x, 3x for light, and the same three with the dark luminosity appearance) whose files exist, with PNG widths 120, 240 and 360 for the matching scales. No template rendering flag.
  - A1.3 `LaunchBackground.colorset` holds sRGB light 0.980392157 / 0.976470588 / 0.968627451 and dark 0.058823529 / 0.101960784 / 0.090196078, alpha 1.
  - A1.4 `Info.plist` has `UILaunchScreen` as a dictionary with `UIColorName` = `LaunchBackground` and `UIImageName` = `LaunchGlyph`, no `UILaunchStoryboardName`, and no other change. Both names resolve to existing assets in the catalog.
  - A1.5 A pure file-read test fails if `INFOPLIST_KEY_UILaunchScreen_Generation = YES` appears in the project file again.
  - A1.6 `scripts/build.sh` builds the app target (the asset catalog compiles). Nothing changes under `.claude/`, any `.pbxproj` (beyond Brian's ecd7992), `contract/`, `LocalPackages/` or the synced Docs files.
- Tests: Swift Testing, one type per file, pure file reads (no UIImage). `BrandAssetsTests` locates the source tree with `ItemSourceTree.load(from: #filePath)`, the helper the existing source-scan tests use. The project file sits next to the app folder, at `ChristmasTracker/ChristmasTracker.xcodeproj/project.pbxproj`.

## Inventory (read from disk, not assumed)

- **AppIcon set** (`Assets.xcassets/AppIcon.appiconset/Contents.json`): three slots, all `idiom: universal`, `platform: ios`, `size: 1024x1024`: default (no appearances), dark (`luminosity` = `dark`), tinted (`luminosity` = `tinted`). No slot has a `filename`, and the folder holds only `Contents.json`.
- **Info.plist launch keys**: none. There is no `UILaunchScreen` and no `UILaunchStoryboardName`. Other keys: the `$(...)` configuration values, `NSFaceIDUsageDescription` and `NSAppTransportSecurity`.
- **Project file launch keys**: `INFOPLIST_KEY_UILaunchScreen_Generation = NO` (lines 460, 497, 683) after Brian's ecd7992. Nothing else matches `LaunchScreen`.
- **Existing asset names**: `AppIcon`, `AccentColor`, and under `Colors/`: `primaryColor`, `accentColor`, `highlightColor`, `backgroundPrimaryColor`, `backgroundSecondaryColor`, `surfaceColor`, `primaryTextColor`, `mutedTextColor`, `borderColor`, `statusAvailableColor`, `statusPurchasedColor`, `statusPartialColor`, `statusShippedColor`, `statusWrappedColor`, `statusGiftedColor`, `budgetSafeColor`, `budgetWarningColor`, `budgetOverColor`. `LaunchGlyph` and `LaunchBackground` do not collide with any of them.
- **Baseline** (scripts/verify.sh on ecd7992): app tests 4638 passed, 0 failed; TrackerAPI 212 tests in 16 suites passed.
- **Source hashes** (P4): all nine files to be copied (two icons, six glyph PNGs, the LaunchBackground `Contents.json`) match `validation/SHA256SUMS.txt`.

## Stories

- A1 Assets and configuration. Report `Docs/reports/BA1-1-assets.md`.
- Handoff: `Docs/handoffs/<run date>-ios-to-brian-ba1.md` and `Docs/reports/BA1-2-handoff.md`.
