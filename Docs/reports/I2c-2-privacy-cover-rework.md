# I2c-2: Privacy Cover Rework — Story Report

**Branch:** feat/i2c-privacy-cover  
**Date:** 2026-11-03

---

## Files Added and Changed

Modified production files:
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverCoordinator.swift` — synchronous `addObserver` observers, injectable NotificationCenter, `handleDidDisconnect`, deinit; `@preconcurrency import UIKit` to satisfy strict concurrency (see below)
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverWindowAdapter.swift` — explicit hide in `hideCover()`: `isHidden = true`, `rootViewController = nil`, then release

Modified test file:
- `ChristmasTracker/ChristmasTrackerTests/App/PrivacyCoverCoordinatorTests.swift` — updated `makeSUT` to accept `notificationCenter:` parameter (default `NotificationCenter()`); added `import UIKit`; added 6 new tests

Docs:
- `Docs/epics/I2c-privacy-cover.md` (Rework Gate 1 section, prior commit)

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
--- tests: 124 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793757548.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

Previous total (I2c-1): **118 passed**  
New tests added in this story: **6**  
Removed tests: **0**  
New total: **118 + 6 = 124 passed** ✓

New test names (all in `PrivacyCoverCoordinatorTests` — Rework R1 section):
1. `willDeactivateNotificationShowsCoverSynchronously` — synchronous delivery proof (see note below)
2. `didActivateNotificationHidesCoverForScene` — did-activate notification hides cover
3. `willDeactivateTwiceForSameSceneShowsOnce` — idempotency via notification path
4. `startTwicePostOnceShowsOnce` — start() twice + post once shows once
5. `didDisconnectHidesActiveCoverAndIsNoOpWhenNoCover` — disconnect hides active cover; no-op when none
6. `afterDisconnect_willDeactivateForDifferentSceneShowsCover` — after disconnect, different scene still shows

**Synchronous delivery proof**: Test 1 posts `UIScene.willDeactivateNotification` on a private `NotificationCenter()` instance and asserts `showCallCount == 1` on the very next line, with no `await` between `post()` and the assertion. The test is a synchronous `@MainActor` function (no `async throws`). If the observer were queued asynchronously (e.g. via `Task { }`, `DispatchQueue.main.async`, or `OperationQueue.main`), `showCallCount` would be 0 at the assertion point. The fact that it is 1 proves synchronous delivery.

---

## Strict Concurrency Shape

The rework uses `NotificationCenter.addObserver(forName:object:queue:using:)` with `queue: nil` for synchronous, same-thread delivery. Inside the callback, `MainActor.assumeIsolated` asserts runtime MainActor isolation and calls the coordinator's `@MainActor` handle methods.

**Swift 6 / NonisolatedNonsendingByDefault issue**: Under the `NonisolatedNonsendingByDefault` upcoming feature (enabled in this project), the `notification` parameter of the `@Sendable (Notification) -> Void` callback is non-sending and cannot be used inside the `@MainActor assumeIsolated` closure. Two approaches were tried and rejected:

1. `SendableScene(@unchecked Sendable)` wrapper: wrapping `notification.object as AnyObject` before entering `assumeIsolated`. Failed — the `AnyObject` extracted from the wrapper still triggered "sending value of non-Sendable type 'AnyObject'" when passed as an argument to the `@MainActor handleWillDeactivate(for:)` function.
2. `@MainActor` closure annotation on the block: failed — "converting function value of type '@MainActor @Sendable (Notification) -> Void' to '@Sendable (Notification) -> Void' loses global actor 'MainActor'".

**Chosen shape**: `@preconcurrency import UIKit`. This tells the Swift 6 compiler to treat UIKit APIs (including `NotificationCenter.addObserver`) with pre-Swift-6 concurrency rules, suppressing the region-isolation check on the callback's parameters. This is the established pattern for UIKit callback bridging in Swift 6, used when the developer can guarantee (and the runtime asserts) that the callback runs on the correct actor. `MainActor.assumeIsolated` is kept as the runtime assertion that we ARE on the MainActor when the callback fires.

**Justification**: UIKit guarantees that all `UIScene.*Notification` notifications are posted on the main thread. `assumeIsolated` asserts this invariant at runtime. The coordinator's state is `@MainActor`-isolated. No actual thread-safety is compromised; the `@preconcurrency` suppresses a region-isolation false positive that the Swift 6 checker produces for all synchronous UIKit callbacks, not just this one.

**`nonisolated(unsafe) private var observers`**: written once during `start()` on MainActor; subsequently only read in `deinit`, where the coordinator is exclusively owned. No concurrent access is possible. The `@unchecked` comment in the source explains this invariant.

**`@unchecked Sendable` in test file**: `FakePresenterCollection` is `@unchecked Sendable` with the comment "accessed only on MainActor in tests" — unchanged from I2c-1.

---

## Verification Claims

| Claim | Source |
|---|---|
| `hideCover()` sets `isHidden = true` before releasing | Code read (`PrivacyCoverWindowAdapter.swift:hideCover()`) |
| `hideCover()` sets `rootViewController = nil` before releasing | Code read |
| Observer block runs synchronously (no queue) | Code read: `queue: nil` in all three `addObserver` calls |
| `start()` idempotent | Code read: `guard observers.isEmpty else { return }` |
| `handleDidDisconnect` removes presenter from `activePresenters` | Code read + test 5 |
| `deinit` removes all observers | Code read |
| `notificationCenter` injectable | Code read: `init(notificationCenter:presenterFactory:)` |
| 124 tests pass | Running `scripts/test.sh` |
| verify.sh green | Running `scripts/verify.sh` |
| Synchronous delivery | Test 1 (`willDeactivateNotificationShowsCoverSynchronously`): synchronous assertion with no `await` — running `scripts/test.sh` |
| UIKit window behavior (level, isHidden, main window key) | **Not verified** — UIKit runtime behavior; requires simulator manual check |

---

## Gate 2 Results

Gate 2 reviewers launched after this report is committed.

---

## Stuck Detector Log

No stuck condition triggered. The strict concurrency shape required three attempts:
1. `assumeIsolated` with `notification` capture — failed: "sending 'notification' risks causing data races"
2. `SendableScene(@unchecked Sendable)` wrapper for `AnyObject` — failed: "sending value of non-Sendable type 'AnyObject'"
3. `@MainActor` closure annotation — failed: "loses global actor 'MainActor'"
4. `@preconcurrency import UIKit` — succeeded: build clean, all tests pass

No repeated identical error signature; each attempt was a distinct approach. No stuck detector threshold exceeded.

---

## Deviations from Prompt

The prompt specified `MainActor.assumeIsolated` as the mechanism. Due to Swift 6's strict concurrency rules under `NonisolatedNonsendingByDefault` (enabled in this project), `assumeIsolated` alone does not compile cleanly. `@preconcurrency import UIKit` was added as the smallest suppression to make the `assumeIsolated` pattern compile. The pattern — synchronous observer, `queue: nil`, `assumeIsolated` — is preserved; only the import-level annotation changed. This is explicitly within the brief's "if strict concurrency forces a different shape" allowance.

---

## Not Done or Partial

Manual verification checklist items (from I2c-1) remain not performed. They are unchanged:
- a. Simulator app switcher with list detail
- b. Simulator app switcher with Add Item sheet open
- c. Control Center and Notification Center
- d. Light and dark appearance
- e. Login screen
- f. Real device (a and b)

The rework adds no new manual checklist items. The UIKit adapter change (`isHidden = true`, `rootViewController = nil`) is code-verified but its runtime effect (whether the window visually disappears without flicker) requires simulator observation.
