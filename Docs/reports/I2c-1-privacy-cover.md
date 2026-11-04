# I2c-1: Privacy Cover — Story Report

> **Superseded in part by I2c-2.** The rework (commit `39c7ab3`) replaced async-sequence notification observation with synchronous `addObserver` observers, made `hideCover()` explicitly hide before releasing, and added disconnect handling. The two claims corrected below are marked with *(corrected by I2c-2)*.

**Branch:** feat/i2c-privacy-cover  
**Date:** 2026-11-03

---

## Files Added and Changed

New files:
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverPresenting.swift` — protocol (`showCover()`, `hideCover()`)
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverCoordinator.swift` — state machine; tracks one presenter per scene by ObjectIdentifier
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverWindowAdapter.swift` — UIKit adapter; creates UIWindow above `.alert + 1` level
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverView.swift` — SwiftUI cover; DesignSystem tokens only, no app data
- `ChristmasTracker/ChristmasTrackerTests/App/PrivacyCoverCoordinatorTests.swift` — 6 unit tests with fake presenter

Modified files:
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — adds `private let privacyCoverCoordinator`; constructs and starts coordinator in `init()` after `FirstLaunchWipe` before `AppDependencies.make()`

Docs:
- `Docs/epics/I2c-privacy-cover.md` (Gate 1 commit)

---

## scripts/verify.sh Raw Output

```
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestBundleInject.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestSwiftSupport.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/PlugIns'

** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 118 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793739416.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

Previous total (I6a baseline): **112 passed**  
New tests added in this story: **6**  
Removed tests: **0**  
New total: **112 + 6 = 118 passed** ✓ (matches verify.sh output)

New test names (all in `PrivacyCoverCoordinatorTests`):
1. `willDeactivateShowsOneCoverForScene` — will-deactivate calls showCover once for a scene
2. `repeatedWillDeactivateForSameSceneIsIdempotent` — repeated will-deactivate for the same scene does not show a second cover
3. `didActivateHidesCoverForScene` — did-activate calls hideCover for the scene that was deactivated
4. `didActivateWithNoCoverIsNoOp` — did-activate with no active cover is a no-op and does not crash
5. `twoScenesTrackedIndependently` — two scenes are tracked independently — deactivating A does not affect B
6. `showHideShowSequencePresentsTwiceAndLeavesOneCoverActive` — show, hide, show sequence presents twice in total and leaves one cover active

---

## UIKit Adapter Manual Verification Checklist

The `PrivacyCoverWindowAdapter` is the only untested piece; it bridges the testable coordinator to UIKit. The following claims are code-verified (reading the source); simulator/device items are marked explicitly.

### Code-verified claims

**Window level above all content (including alerts and sheets):**  
`PrivacyCoverWindowAdapter.swift` line 23: `window.windowLevel = UIWindow.Level.alert + 1`  
UIKit's `.alert` window level is 2000.0; the cover is at 2001.0, above every standard window including system alerts and action sheets. Source: code read.

**Cover shown without animation:**  
`PrivacyCoverWindowAdapter.showCover()` sets `window.isHidden = false` directly with no `UIView.animate` or `.withAnimation` wrapper. Source: code read.

**Cover window never made key:**  
`makeKey()` and `makeKeyAndVisible()` are absent from all new files (confirmed by convention reviewer grep). The cover window is shown via `isHidden = false` only. Source: code read + convention reviewer finding 9.

**Main window remains key after cover is removed** *(corrected by I2c-2)*:  
In I2c-1, `hideCover()` only sets `coverWindow = nil`. Since the cover window was never made key, the main window was never displaced. The claim that the main window remains key is accurate. However, I2c-2 strengthens this: by calling `coverWindow?.isHidden = true` before release, the window is explicitly hidden before it may be deallocated by UIKit; UIKit does not reassign the key window when a non-key window is hidden or deallocated, so the guarantee is the same either way. Source (I2c-1): code read; source (correction): I2c-2 rework commit `39c7ab3`.

**Cover released on removal** *(corrected by I2c-2)*:  
`PrivacyCoverWindowAdapter` holds the cover window in `private var coverWindow: UIWindow?`. In I2c-1, `hideCover()` only sets `coverWindow = nil`; the original claim that "the window's reference count drops to zero and it is deallocated" is overstated — UIKit may hold additional retain counts on visible windows, so ARC timing is not guaranteed. I2c-2 corrects this by calling `coverWindow?.isHidden = true` and `coverWindow?.rootViewController = nil` before `coverWindow = nil`, ensuring the window is hidden and its view hierarchy is dismantled synchronously regardless of ARC timing. Source (I2c-1): code read; source (correction): I2c-2 rework commit `39c7ab3`.

**Cover contains no app data:**  
`PrivacyCoverView.swift` has no stored properties, `@Environment`, `@State`, or service injection. The only content is `Text("Christmas Tracker")` (the app name, not app data) and DesignSystem color/font tokens. Source: code read.

**Coordinator does not read session or auth state:**  
`PrivacyCoverCoordinator.swift` imports only `UIKit`. Its `presenterFactory` closure in production captures only `UIWindowScene`. No auth, session, or config types are referenced. Source: code read.

### Simulator / device verification (manual — not performed by agent)

a. **Simulator — app switcher with list detail open:** Open a list detail with items. Press Shift+Cmd+H twice. Confirm the app switcher card shows the opaque cover (app name on background) and not the list content. **Not performed.**

b. **Simulator — app switcher with Add Item sheet open:** With a list detail open, open the Add Item sheet and type a name. Press Shift+Cmd+H twice. Confirm the cover, not the sheet content, appears in the app switcher card. **Not performed.**

c. **Simulator — Control Center and Notification Center:** Pull down Control Center (or Notification Center). Confirm the cover appears and disappears cleanly on return. Confirm typing focus and the keyboard still work afterwards (main window still key). **Not performed.**

d. **Light and dark appearance:** Toggle between light and dark in the simulator. Confirm the cover uses the adaptive DesignSystem background token and readable text in both modes. **Not performed.**

e. **Login screen:** Cover shows on the login screen, not only when authenticated. The coordinator is started before any auth state is established; `PrivacyCoverView` has no auth dependency. Code-verified as described above; simulator confirmation **not performed.**

f. **Real device — repeat a and b:** Repeat checklist items a and b on a physical device. **Not performed.**

---

## Verification Source Key

| Claim | Source |
|---|---|
| Window level above .alert | Code read (`PrivacyCoverWindowAdapter.swift:23`) |
| No makeKey / makeKeyAndVisible | Code read + convention reviewer grep finding |
| hideCover releases window | Code read (`PrivacyCoverWindowAdapter.swift:hideCover()`) |
| Cover has no app data | Code read (`PrivacyCoverView.swift`) |
| Coordinator stateless | Code read (`PrivacyCoverCoordinator.swift`) |
| 6 tests pass | Running `scripts/test.sh` (118 passed) |
| verify.sh green | Running `scripts/verify.sh` |

---

## Gate 2 Results

### Convention Reviewer — PASS (two surfaced warnings, no hard blocks)

Finding 1 (WARNING): Two commits on the branch (Gate 1 docs commit + story commit). The Orchestrator prompt explicitly prescribed both commits separately ("STEP 1: docs commit, no code" and "STORY commit"). This is consistent with the prompt's intent; not squashed.

Finding 9 (WARNING): Top-level type declarations lack explicit `internal` keyword. This is consistent with the entire codebase convention (all existing production files follow the same omission-as-implicit-internal pattern). No change made.

### Acceptance Reviewer — initial GATE 2 REJECT; resolved

The initial rejection was narrow: the story report file (`Docs/reports/I2c-1-privacy-cover.md`) was absent from the commit. All implementation criteria passed. This report resolves the rejection.

Acceptance reviewer confirmed all criteria passed: window level, no makeKey, cover released on hide, no app data, 6 tests with fake presenter, coordinator started before `AppDependencies.make()`, cover stateless, UIWindow approach (not SwiftUI overlay), two-scene independence, no networking, async sequence notification observation, strict concurrency clean.

---

## Stuck Detector Log

No stuck condition was triggered. Build succeeded on first attempt. Tests failed once (missing `import Foundation` for `NSObject` in test file) and passed on the next attempt. No repeated error signature.

---

## Deviations from Prompt

None. All scoped files were written as specified. No out-of-scope files were touched.

---

## Not Done or Partial

Manual verification checklist items a–f were not performed (agent cannot operate the simulator UI). These items are listed in the checklist above with status "not performed."

The cover-may-flash risk (when the system Face ID prompt makes the scene inactive) is noted in the open risks section of the handoff; I2b must check and handle it if needed.
