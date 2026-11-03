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
- `PrivacyCoverCoordinator.swift` — state machine; tracks one presenter per scene by ObjectIdentifier; observes `UIScene.willDeactivateNotification` and `UIScene.didActivateNotification` via async sequences; idempotent show/hide
- `PrivacyCoverWindowAdapter.swift` — UIKit adapter; creates a `UIWindow(windowScene:)` at `UIWindow.Level.alert + 1`, shows with `isHidden = false` (no makeKey, no animation), releases on hide
- `PrivacyCoverView.swift` — SwiftUI cover; opaque `backgroundPrimaryColor` fill, app name in `appTitle1`/`textPrimaryColor`, `accessibilityHidden(true)`, no app data

**New test file** (`ChristmasTracker/ChristmasTrackerTests/App/`):
- `PrivacyCoverCoordinatorTests.swift` — 6 unit tests with FakePrivacyCoverPresenter via FakePresenterCollection; tests show/hide idempotency, two-scene independence, show-hide-show sequence

**Modified file:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — adds `private let privacyCoverCoordinator`; constructs and starts the coordinator in `init()` after `FirstLaunchWipe` before `AppDependencies.make()`

---

## Commit Hashes (master..HEAD)

```
34f6a67 I2c: add epic brief, inventory, and Gate 1 spec
43e4fb3 I2c: add app-switcher privacy cover
bbdb5e1 I2c: add Story 1 report with manual adapter checklist
```

Note: three commits on the branch. The first is the Gate 1 docs commit (explicitly prescribed by the Orchestrator prompt); the second is the story implementation; the third adds the story report (separated to satisfy the Gate 2 acceptance reviewer). The convention reviewer flagged this against the "one commit per story" rule as a warning (no hard block). Brian can squash before merge if desired.

---

## What the API Team Must Do

Nothing. This story has no API dependencies.

---

## Open Risks

1. **Manual adapter checklist not performed** — All six simulator/device checklist items in `Docs/reports/I2c-1-privacy-cover.md` (app switcher cards, Control Center, light/dark, login screen, real device) were not performed by the agent. Brian must verify these before shipping.

2. **Face ID flash risk (I2b must handle)** — When the system Face ID prompt appears (e.g. during biometric authentication in I2b), it may make the scene inactive, triggering the privacy cover. This could cause a brief flash behind the Face ID dialog. I2b's inactivity lock and Face ID unlock work (decisions A7, A8) must check this interaction and add a suppression hook if the flash is visually disruptive.

3. **I2b may reuse this cover** — The `PrivacyCoverPresenting` protocol and `PrivacyCoverCoordinator` are designed so I2b's inactivity lock can reuse them (the coordinator can accept a second presenter factory keyed by scene). No code changes needed in I2c for this; noted for I2b's Gate 1.

4. **iPad multi-window — not simulator-verified** — `TARGETED_DEVICE_FAMILY = 1,2`; the coordinator tracks scenes by `ObjectIdentifier` and is designed for multi-window. The five-test `twoScenesTrackedIndependently` case unit-tests this, but it was not tested in the iPad simulator with multiple scenes side-by-side.

5. **Screenshot and screen-recording prevention remain out of scope** — This story covers the app-switcher snapshot only. Screen mirroring, AirPlay, and `UIScreen.capturedDidChangeNotification` handling are not addressed.

---

## Section 9 of PROGRAM.md (one line)

I2c (app-switcher privacy cover): UIWindow at `.alert+1` per scene, coordinator + fake-presenter tests (6 new, 118 total), no networking; manual simulator verification pending.
