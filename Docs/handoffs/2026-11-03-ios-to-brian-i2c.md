# iOS Handoff — I2c: App-Switcher Privacy Cover
**Date:** 2026-11-03  
**From:** iOS agent (Orchestrator)  
**To:** Brian

---

## Contract Issues Found

None. This story makes no networking or API model changes. Contract status remains PRE-CONFORMANCE.

---

## What Changed

**New production files** (all in `ChristmasTracker/ChristmasTracker/App/`):
- `PrivacyCoverPresenting.swift` — protocol with `showCover()` and `hideCover()`
- `PrivacyCoverCoordinator.swift` — state machine; tracks one presenter per scene by ObjectIdentifier; observes `UIScene.willDeactivateNotification`, `UIScene.didActivateNotification`, and `UIScene.didDisconnectNotification` via synchronous `addObserver(forName:object:queue:using:)` with `queue: nil` (runs cover show/hide inside the notification post call, before it returns — guaranteeing the app-switcher snapshot captures the cover); injectable `NotificationCenter`; `deinit` removes all observer tokens; idempotent show/hide; disconnect handler removes stale entries
- `PrivacyCoverWindowAdapter.swift` — UIKit adapter; creates a `UIWindow(windowScene:)` at `UIWindow.Level.alert + 1`, shows with `isHidden = false` (no makeKey, no animation), releases on hide
- `PrivacyCoverView.swift` — SwiftUI cover; opaque `backgroundPrimaryColor` fill, app name in `appTitle1`/`textPrimaryColor`, `accessibilityHidden(true)`, no app data

**New test file** (`ChristmasTracker/ChristmasTrackerTests/App/`):
- `PrivacyCoverCoordinatorTests.swift` — 12 unit tests (6 original + 6 rework) with FakePrivacyCoverPresenter via FakePresenterCollection; tests show/hide idempotency, two-scene independence, show-hide-show sequence, synchronous delivery proof, didActivate via notification, disconnect handling

**Modified file:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — adds `private let privacyCoverCoordinator`; constructs and starts the coordinator in `init()` after `FirstLaunchWipe` before `AppDependencies.make()`

---

## Commit Hashes (master..HEAD)

```
39c7ab3 I2c: show cover synchronously, hide it explicitly, handle scene disconnect
fa43299 I2c: add rework Gate 1 spec
b325c4d I2c: add package handoff note
bbdb5e1 I2c: add Story 1 report with manual adapter checklist
43e4fb3 I2c: add app-switcher privacy cover
34f6a67 I2c: add epic brief, inventory, and Gate 1 spec
```

Note: six commits on the branch across two stories plus docs commits. Merge with a merge commit; do not squash — the rework history (async→synchronous observation shape) is worth preserving.

## git diff --stat master...HEAD

```
 ChristmasTracker/ChristmasTracker/App/PrivacyCoverCoordinator.swift    | 103 +++++++++
 ChristmasTracker/ChristmasTracker/App/PrivacyCoverPresenting.swift     |   9 +
 ChristmasTracker/ChristmasTracker/App/PrivacyCoverView.swift           |  19 ++
 ChristmasTracker/ChristmasTracker/App/PrivacyCoverWindowAdapter.swift  |  45 ++++
 ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift            |  11 +
 ChristmasTracker/ChristmasTrackerTests/App/PrivacyCoverCoordinatorTests.swift | 239 +++++++++++++++++++++
 Docs/epics/I2c-privacy-cover.md                                        | 189 ++++++++++++++++
 Docs/handoffs/2026-11-03-ios-to-brian-i2c.md                          |  64 ++++++
 Docs/reports/I2c-1-privacy-cover.md                                    | 158 ++++++++++++++
 Docs/reports/I2c-2-privacy-cover-rework.md                             | 138 ++++++++++++
 10 files changed, 975 insertions(+)
```

---

## What the API Team Must Do

Nothing. This story has no API dependencies.

---

## Open Risks

1. **Manual adapter checklist not performed** — All six simulator/device checklist items in `Docs/reports/I2c-1-privacy-cover.md` (app switcher cards, Control Center, light/dark, login screen, real device) were not performed by the agent. Brian must verify these before shipping.

2. **Face ID flash risk (I2b must handle)** — When the system Face ID prompt appears (e.g. during biometric authentication in I2b), it may make the scene inactive, triggering the privacy cover. This could cause a brief flash behind the Face ID dialog. I2b's inactivity lock and Face ID unlock work (decisions A7, A8) must check this interaction and add a suppression hook if the flash is visually disruptive.

3. **I2b may reuse this cover** — The `PrivacyCoverPresenting` protocol and `PrivacyCoverCoordinator` are designed so I2b's inactivity lock can reuse them (the coordinator can accept a second presenter factory keyed by scene). No code changes needed in I2c for this; noted for I2b's Gate 1.

4. **iPad multi-window — not simulator-verified** — `TARGETED_DEVICE_FAMILY = 1,2`; the coordinator tracks scenes by `ObjectIdentifier` and is designed for multi-window. The `twoScenesTrackedIndependently` test (one of six) unit-tests this, but it was not tested in the iPad simulator with multiple scenes side-by-side.

5. **iPad Stage Manager / side-by-side — open risk** — On iPad with Stage Manager or in split-screen, two scenes can be simultaneously visible and active. If the user switches focus between them rapidly, the coordinator may receive will-deactivate for scene A while scene B's cover is still active, leaving two simultaneous covers. The coordinator's per-scene tracking handles this correctly in isolation; however, the visual result (two covers visible at once on a split screen) has not been verified. If visually disruptive, I2b (or a later story) should handle multi-scene suppression.

5. **Screenshot and screen-recording prevention remain out of scope** — This story covers the app-switcher snapshot only. Screen mirroring, AirPlay, and `UIScreen.capturedDidChangeNotification` handling are not addressed.

---

## Section 9 of PROGRAM.md (one line)

I2c (app-switcher privacy cover): UIWindow at `.alert+1` per scene, synchronous `addObserver` observers (guarantees cover in snapshot), coordinator + fake-presenter tests (12 new, 124 total), no networking; manual simulator verification pending.
