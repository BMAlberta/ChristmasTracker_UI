# iOS to Brian: BA1 brand assets (app icon and launch screen)

Date: 2026-11-14. Branch `feat/ba1-brand-assets` (from master at the TH1.1 merge 0b1b79b). Not pushed.

**Before you check anything: delete the app from the simulator, then build and run it fresh. iOS caches launch screens and icons; a stale one proves nothing.**

## Contract issues

None. No networking, API model or repository change. contract/STATUS.md was not touched.

## What changed

- The app icon: `AppIcon.appiconset` now holds the delivered default icon and dark icon (both 1024 by 1024, RGB, no alpha, byte-identical to the unzipped brand package by SHA-256). The tinted slot is still empty because no image was supplied.
- The launch screen: new `LaunchGlyph` image set (light and dark, 1x/2x/3x) and `LaunchBackground` color set (light #FAF9F7, dark #0F1A17), wired through a `UILaunchScreen` dictionary in Info.plist (`UIColorName`, `UIImageName`). There is no storyboard and no title on the launch screen. The app name appears on the first app screen in the serif design from TH1.
- Build setting: you removed `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (now `= NO`) in ecd7992, because it would have conflicted with the Info.plist dictionary. A new test fails if `= YES` comes back.
- Tests: `BrandAssetsTests` (9 new tests) reads the JSON, the plist, the PNG header bytes and the project file. One existing test, `ThemeAssetCatalogTests.noExtraColorsets`, now also allows the `LaunchBackground` colorset (count 20), because the new colorset is deliberate and is not a theme token. App tests 4638 to 4647 passed (+9), 0 failed. TrackerAPI 212, unchanged.
- Nothing changed in behavior, services, screens or tokens.
- Reports: Docs/reports/BA1-1-assets.md, BA1-2-handoff.md.

## Commits (`git log --oneline master..HEAD`, before this handoff commit)

```
8506820 BA1: add the app icon and the launch screen assets
e32c2d9 BA1: add epic brief and inventory
ecd7992 BA1: stop generating the launch screen from a build setting
```

The handoff commit `BA1: add the package handoff note` follows these. ecd7992 is yours (the project file change).

## What the API team must do

Nothing.

## Open risks

- Nothing was seen running. No agent ran the app in the simulator, so the icon and the launch screen (colors, glyph size and centering, dark switching) are verified only by reading files and by tests of file contents. The catalog compiles (the build succeeded), which is the only build-level evidence.
- iOS caches icons and launch screens aggressively. If a check looks stale after a fresh install, treat it as inconclusive, not as a pass or a fail.
- The process deviation: the orchestrator copied the assets and edited the JSON and Info.plist itself instead of routing that to the implementer. The tests were then written against finished assets, so they were never seen failing first. They check exact values and header bytes. Details are in Docs/reports/BA1-1-assets.md.
- The tinted icon slot is empty. iOS may show a system-generated tint of the default icon when a user picks Tinted.

## For PROGRAM.md section 9

BA1 (brand assets): the app icon (default and dark) and a launch screen (adaptive background color plus the gift glyph, no title) are in the asset catalog and wired through an Info.plist `UILaunchScreen` dictionary, after Brian removed the launch-screen build setting; 9 new file-content tests guard them. Tests: app 4647 passed, TrackerAPI 212. No contract or API impact. Pending Brian's real-mode check; the tinted slot, web favicon and Icon Composer are out of scope.

## Brian's real-mode check

Delete the app from the simulator, then build and run it fresh. iOS caches launch screens and icons; a stale one proves nothing.

1. **Install fresh.**
   - Delete the app from the simulator, run the Debug build (any scheme; no backend needed for the first four steps).
   - Expect: it installs and launches.
2. **Home screen icon, light.**
   - Press Home with the simulator in light mode.
   - Expect: the cream gift with the cranberry ribbon and a gold-edged check on a deep green background, no text, the system rounds the corners.
3. **Home screen icon, dark.**
   - Switch the simulator to dark mode (Features, Toggle Appearance) and look at the home screen. If the icon does not change, settle the home screen once; icons refresh on the appearance change. If it never changes, note it: iOS also lets a user force Dark in the home screen's Customize menu.
   - Expect: the same gift on a near-black green background.
4. **Launch screen, light and dark.**
   - Force-quit the app, then launch it in light mode, then again in dark mode.
   - Expect: a warm off-white (light) or deep green-charcoal (dark) background with the small gift centered, and NO text. The first screen after it shows the app name in the serif design (from TH1).
5. **Settings and spotlight.**
   - Pull down Spotlight and search for "Christmas".
   - Expect: the app appears with the same icon at small size, still recognizable.
6. **Smallest size.**
   - In Settings, find the app's row (Settings, scroll to the app).
   - Expect: the icon is legible at the small row size.
7. **Normal flows still work.**
   - Log in against the local backend as in earlier checks and open the lists screen.
   - Expect: login works and the lists screen loads as before.

Not part of this package: a Face ID or device pass, the web favicon, the tinted icon slot, Icon Composer, and any launch-screen title.

Checks run: `scripts/verify.sh` (app tests, TrackerAPI package tests, script tests) before and after each commit, `scripts/build.sh`, SHA-256 comparison of every copied asset, and both Gate 2 reviews for the asset story (both approved). Checks NOT PERFORMED: all seven steps above. The agents never saw the simulator, and Brian has not yet run the real-mode check.
