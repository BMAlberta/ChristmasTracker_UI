# BA1 Story A1: Assets and configuration

Branch `feat/ba1-brand-assets`. Path: solo. The orchestrator copied the assets and edited the JSON and Info.plist (see Deviations); the solo implementer wrote the tests. Then the convention-reviewer and the acceptance-reviewer ran, and both approved with no rejection routing.

## What changed

Files added (all under `ChristmasTracker/ChristmasTracker/Assets.xcassets/`):

- `AppIcon.appiconset/app-icon-1024.png` (default appearance)
- `AppIcon.appiconset/app-icon-dark-1024.png` (dark appearance)
- `LaunchGlyph.imageset/Contents.json`
- `LaunchGlyph.imageset/launch-glyph-light-120.png`, `-240.png`, `-360.png`
- `LaunchGlyph.imageset/launch-glyph-dark-120.png`, `-240.png`, `-360.png`
- `LaunchBackground.colorset/Contents.json`

Files changed:

- `Assets.xcassets/AppIcon.appiconset/Contents.json`: added `filename` to the default and dark slots only. Idiom, platform, size and appearances are unchanged. The tinted slot has no filename.
- `ChristmasTracker/ChristmasTracker/Info.plist`: one new key, `UILaunchScreen`, a dictionary with `UIColorName` = `LaunchBackground` and `UIImageName` = `LaunchGlyph`. No `UILaunchStoryboardName`, no other key.

Tests:

- New `ChristmasTrackerTests/DesignSystem/BrandAssetsTests.swift`, 9 tests: `appIconSlots`, `appIconPNGHeaders`, `launchGlyphEntries`, `launchGlyphWidths`, `launchGlyphHasNoTemplateRendering`, `launchBackgroundComponents`, `infoPlistLaunchScreen`, `launchNamesResolveToAssets`, `projectFileDoesNotGenerateLaunchScreen`. Pure file reads (JSON, plist, PNG header bytes, project file text). The source tree is found with `ItemSourceTree.load(from: #filePath)`.
- `ChristmasTrackerTests/DesignSystem/ThemeAssetCatalogTests.swift`: `noExtraColorsets` only. See Deviations.

Not touched: `.claude/`, any `.pbxproj` (apart from Brian's own commit ecd7992 earlier on this branch), `contract/`, `LocalPackages/`, synced Docs files, any Swift outside the test target.

## P3 stop condition (evidence)

- First run: `INFOPLIST_KEY_UILaunchScreen_Generation = YES` at project file lines 460, 497, 683. The package stopped there.
- Brian removed it in ecd7992 `BA1: stop generating the launch screen from a build setting`.
- Re-check on resume (`grep -n "LaunchScreen"` on the project file): `INFOPLIST_KEY_UILaunchScreen_Generation = NO;` at lines 460, 497, 683, and no other launch-screen key. `grep -n -i "launch"` on Info.plist printed nothing before this story.
- New guard: `projectFileDoesNotGenerateLaunchScreen`.

## Hash comparison (P4)

`shasum -a 256` of each source file in the unzipped brand package against its line in `validation/SHA256SUMS.txt`: all 9 match (two icons, six glyph PNGs, the LaunchBackground `Contents.json`). After the copies, the repo files were hashed again and carry the same nine values, so the copies are byte-identical. The acceptance-reviewer also matched the LaunchGlyph `Contents.json` to its package line (byte-identical).

## Test arithmetic

Baseline (scripts/verify.sh on ecd7992, and again after the brief commit e32c2d9): 4638 passed. New: 9. 4638 + 9 = 4647. The run shows 4647 passed, 0 failed, 0 skipped. TrackerAPI: 212 tests in 16 suites before and after, unchanged. `noExtraColorsets` was edited, not added, so it does not change the count.

## Commands and raw output

Before the story commit (`scripts/verify.sh`, filtered to the summary lines, run by the orchestrator):

```
=== verify: build ===
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 4647 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.022 seconds.
=== verify: OK ===
```

`scripts/build.sh` once (orchestrator), tail:

```
note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/PlugIns'

** BUILD SUCCEEDED **
```

So the app target builds with the new asset catalog entries and the Info.plist key. Raw verify output after the commit is in the Gate 2 section below.

## Run versus read

- From running a command: build succeeded; 4647 passed and TrackerAPI 212 (verify); all hashes (shasum).
- From reading: the JSON and plist contents (read by me and by the acceptance-reviewer); that the test files follow the conventions (convention-reviewer, read-only); the claim that `file` reports 1024 x 1024, 8-bit/color RGB for both icons (acceptance-reviewer). The tests also assert the same facts from the PNG header bytes, and they passed.

## Deviations

- **Process.** CLAUDE.md says the orchestrator does not write production code or tests during a story. I copied the assets and wrote the JSON and plist edits myself, before delegating the tests to the implementer. The tests were therefore written against finished assets: there was no red-before-green run for them. They pass, check exact values, and would fail on a wrong value, a missing file or a wrong size, but nobody watched them fail.
- **Existing test changed.** `ThemeAssetCatalogTests.noExtraColorsets` required exactly the 18 token colorsets plus `AccentColor` (19) and rejected any other. `LaunchBackground` is a deliberate new colorset that is not a theme token, so the expected set now also contains `LaunchBackground` and the count is 20. No token, token value or palette changed. Both reviewers judged this a legitimate consequence of the package.
- A malformed Edit call of mine (a `PLACEHOLDER` replacement) failed to apply and changed nothing; the real edits followed.

## Gate 2

- convention-reviewer: APPROVE. No hard blocks, no warnings. Observation only: `glyphScales` is declared partway down `BrandAssetsTests.swift` (style).
- acceptance-reviewer: APPROVE, no rejection routing. It read the JSON, the plist and the tests and covered focus items 1 to 6 and 8; item 7 (the handoff) did not exist yet. It ran no build or tests and no simulator.
- Raw `scripts/verify.sh` output after the story commit: see the verify output recorded in the handoff report (BA1-2), since this report is committed in the same commit.

## Not done or partial

- No simulator run was possible, so the app icon and the launch screen were never seen running. Nothing here shows how either renders, that iOS picks up the dark icon or the adaptive launch background, or that the glyph is centered. Brian's real-mode check in the handoff covers that.
- The tinted icon slot stays empty (no image supplied).
- The web favicon, Icon Composer layers, a Face ID or device pass, and any launch title are not part of this package.
- The acceptance-reviewer did not itself run the catalog compile or the tests; the build and test results above are the orchestrator's own runs.
