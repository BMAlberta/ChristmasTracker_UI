# I2c: App-switcher privacy cover
Track: iOS. Depends on: I6a (merged). Blocks: nothing. Related: I2b adds the client-side inactivity lock (decision A8) and Face ID unlock (A7); it may reuse this cover.
Contract state: PRE-CONFORMANCE (no networking or API model changes).

Why: this is a gift-coordination app whose core promise is not leaking surprises. iOS takes a screenshot of the app when it leaves the foreground and shows it in the app switcher. That snapshot could show a surprise gift on a list or detail screen, including inside a sheet such as Add Item, to anyone who sees the phone.

Scope
1. When a window scene is about to become inactive, show a full-screen opaque cover above ALL content, including presented sheets, full-screen covers, and alerts. Remove it when the scene becomes active again.
2. The cover shows no app data, no session state, and uses DesignSystem tokens: an opaque adaptive background color and the app name as text.
3. The cover appears regardless of authentication state.

Decisions
- Mechanism: a dedicated UIWindow per UIWindowScene at a window level above everything, shown from the scene will-deactivate notification (the equivalent of sceneWillResignActive, Apple's recommended place to hide sensitive content) and hidden on the scene did-activate notification. A SwiftUI overlay on the root view is NOT acceptable: sheets and alerts present above it and would stay visible in the snapshot.
- Show with no animation (the snapshot must contain the cover). Never call makeKey or makeKeyAndVisible on the cover window; the app's main window must remain the key window after the cover is removed. Keep a strong reference to each cover window while shown and release it on removal.
- Notifications are consumed with async sequences (NotificationCenter notifications(named:)), no Combine.
- Testable core: a small coordinator holds the show/hide logic and talks to the UIKit window through a protocol (-ing suffix) so the logic is unit-tested with a fake. The thin UIKit adapter is the only untested piece and is verified manually.
- Idempotent: repeated will-deactivate for the same scene shows one cover; did-activate with no cover is a no-op; scenes are tracked independently (iPad multi-window safe).

Non-goals: screenshot or screen-recording prevention, AirPlay or screen-capture detection, the inactivity lock and Face ID (I2b), any change to SessionManager or teardown, any networking.

Acceptance
- Will-deactivate shows exactly one opaque cover window above all other windows for that scene; did-activate removes it and releases it; the main window is key afterwards.
- The cover contains no app data and uses only DesignSystem tokens; it adapts to light and dark.
- Coordinator logic is covered by unit tests with a fake presenter; the SDK/UIKit adapter is manually verified (report includes the checklist and its status).
- scripts/verify.sh is green; nothing outside the scoped files changes.

---

## Inventory

### Existing scene/window API usage
Grep result for `scenePhase`, `willResignActive`, `didEnterBackground`, `UIScene`, `UIWindowScene`, `UIWindow`, `UIApplication.shared` across `ChristmasTracker/ChristmasTracker/` (all `.swift` files):
**None found.** This is greenfield; no existing scene lifecycle handling exists.

### Scene configuration
- `ChristmasTrackerApp.swift` uses SwiftUI's `@main` with a single `WindowGroup` — no manual scene delegate or `UIApplicationDelegate`. Xcode generates the scene manifest from `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` in the build settings.
- `TARGETED_DEVICE_FAMILY = 1,2` → iPhone and iPad supported. iPad supports multi-window via `UIApplicationSupportsMultipleScenes` (auto-generated manifest may include it; each scene gets its own `UIWindowScene`). The coordinator must track each scene independently by `ObjectIdentifier`.

### Available DesignSystem tokens for the cover
AppColors (Color extension):
- `.backgroundPrimaryColor` — adaptive opaque background (Light: `#FAF9F7`, Dark: `#0F1A17`)
- `.textPrimaryColor` — primary text (Light: `#1F2933`, Dark: `#E6ECEA`)

AppTypography (Font extension, used as modifiers):
- `.appTitle1` — 28pt semibold (chosen for the app name; prominent but not oversized)

AppSpacing: tokens available but the cover fills the full screen; spacing not needed.

---

## Gate 1

### New interface: yes (new coordinator + protocol)

### Protocol and type signatures

```swift
// ChristmasTracker/ChristmasTracker/App/PrivacyCoverPresenting.swift
protocol PrivacyCoverPresenting: AnyObject {
    func showCover()
    func hideCover()
}

// ChristmasTracker/ChristmasTracker/App/PrivacyCoverCoordinator.swift
// @MainActor by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor)
final class PrivacyCoverCoordinator {
    // Receives notification.object (AnyObject); returns nil if not a supported scene type.
    // In production: casts to UIWindowScene and returns PrivacyCoverWindowAdapter.
    // In tests: returns a FakePrivacyCoverPresenter for any supplied object.
    typealias PresenterFactory = @MainActor (AnyObject) -> (any PrivacyCoverPresenting)?

    // Exposed internal for unit tests (not public API)
    private(set) var activePresenters: [ObjectIdentifier: any PrivacyCoverPresenting]

    init(presenterFactory: @escaping PresenterFactory)

    // Starts two async Tasks observing willDeactivateNotification and didActivateNotification.
    // Idempotent: second call is a no-op.
    func start()

    // Called by the notification tasks; also called directly in unit tests.
    // Idempotent: repeated calls for the same object show one cover.
    func handleWillDeactivate(for object: AnyObject)

    // Called by the notification tasks; also called directly in unit tests.
    // No-op if no cover is active for the object.
    func handleDidActivate(for object: AnyObject)
}

// ChristmasTracker/ChristmasTracker/App/PrivacyCoverWindowAdapter.swift
// UIKit adapter; the only untested piece (verified manually).
final class PrivacyCoverWindowAdapter: PrivacyCoverPresenting {
    init(scene: UIWindowScene)
    func showCover()   // creates UIWindow at .alert+1 level, sets rootVC hosting PrivacyCoverView, isHidden = false, no makeKey
    func hideCover()   // sets coverWindow = nil, releases strong reference
}

// ChristmasTracker/ChristmasTracker/App/PrivacyCoverView.swift
struct PrivacyCoverView: View {
    // backgroundPrimaryColor fill (ignoresSafeArea), app name "Christmas Tracker" in
    // Font.appTitle1 with Color.textPrimaryColor, centered.
    // accessibilityHidden(true) — cover must not appear in the accessibility tree.
    var body: some View
}
```

### Scoped file list
New files:
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverPresenting.swift`
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverCoordinator.swift`
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverWindowAdapter.swift`
- `ChristmasTracker/ChristmasTracker/App/PrivacyCoverView.swift`
- `ChristmasTracker/ChristmasTrackerTests/App/PrivacyCoverCoordinatorTests.swift`

Modified files:
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — add `private let privacyCoverCoordinator: PrivacyCoverCoordinator`; in `init()` construct and start the coordinator after `FirstLaunchWipe` and before `AppDependencies.make()`.

No other files change. `.pbxproj` is NOT touched — both `ChristmasTracker/ChristmasTracker/` and `ChristmasTracker/ChristmasTrackerTests/` are `fileSystemSynchronizedGroups`, so new `.swift` files are auto-included.

### Where the coordinator is started
In `ChristmasTrackerApp.init()`, after `SentryBootstrap.startIfConfigured()` and `FirstLaunchWipe().performIfNeeded()`, before `AppDependencies.make()`. Justification:
- Must exist before any scene events; starting it early is safe because the first `willDeactivateNotification` cannot arrive until after the app run loop starts (after `init()` returns).
- Must not read session state, services, or environment — this placement precedes all of that.
- Must not be started from a view (brief requirement) — placing it in `init()` satisfies this.
- Stored as `private let` on `ChristmasTrackerApp`, which lives for the app's lifetime, keeping the coordinator and its observation tasks alive.

### Strict concurrency: how notifications are observed
`PrivacyCoverCoordinator` is `@MainActor` (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor). Its `start()` creates `Task` blocks; a `Task` inherits the actor context of its creation site, so the tasks are MainActor-isolated.

Inside each task's `for await notification in NotificationCenter.default.notifications(named:)` loop:
- `notification` is `Notification` (a struct).
- In Swift 6 / Foundation, `Notification` is marked `@unchecked Sendable` (see `Foundation/NSNotification.swift` overlay), so crossing into the MainActor-isolated task is permitted.
- `notification.object` is cast to `AnyObject` immediately in the MainActor body; only the `ObjectIdentifier` and the resulting presenter are retained beyond the loop iteration.
- No `Notification` value is ever stored or passed across isolation boundaries; it is consumed entirely within the `@MainActor` task body.

### Test seam justification
`UIWindowScene` cannot be instantiated in unit tests (requires a running UIKit application). The coordinator's `presenterFactory` takes `AnyObject` (the notification's `object`), not `UIWindowScene` directly. Tests supply plain `NSObject()` instances as scene proxies; the factory returns a `FakePrivacyCoverPresenter` for each. The `handleWillDeactivate(for:)` and `handleDidActivate(for:)` methods are called directly (synchronously, on MainActor) from tests, bypassing the notification observation tasks entirely. This is the smallest seam: it tests all coordinator state machine logic without requiring async notification delivery or real UIKit scenes.

---

## Rework Gate 1 (I2c-2)

**Amendment to original brief:** The original brief required consuming notifications with async sequences (`NotificationCenter.notifications(named:)`). This is replaced by synchronous `NotificationCenter.addObserver(forName:object:queue:using:)` observers with `queue: nil`. **Reason:** With the async-sequence approach the cover handler runs on a future MainActor turn — after the notification has been delivered and the method has returned. iOS takes the app-switcher snapshot at or just after the `sceneWillDeactivate` callback. If the cover is shown one run-loop turn later, the snapshot may not include it and the privacy guarantee is lost. The synchronous observer with `queue: nil` runs the handler inside the notification post call, before it returns, so the cover window is visible when the snapshot is taken.

### R1 Change 1 — Explicit hide in PrivacyCoverWindowAdapter

**Problem:** `hideCover()` only sets `coverWindow = nil`. Relying on ARC deallocation to remove a visible UIWindow is fragile; under some retain conditions the window may outlive the expected release point.

**Fix:** Before releasing, set `coverWindow?.isHidden = true` and `coverWindow?.rootViewController = nil`, then set `coverWindow = nil`. This ensures the window is hidden and its view hierarchy is dismantled synchronously, regardless of when ARC releases it.

### R1 Change 2 — Synchronous observation in PrivacyCoverCoordinator

Replace the two `Task`-based async-sequence observers (and `observationTasks: [Task<Void, Never>]`) with `NotificationCenter.addObserver(forName:object:queue:using:)` registered with `queue: nil`. With `queue: nil` the handler runs synchronously on the posting thread (the main thread for UIKit scene notifications). Inside the handler, use `MainActor.assumeIsolated` to call the coordinator's MainActor-isolated handle methods without an async hop.

**Injectable NotificationCenter:** Change `init` to `init(notificationCenter: NotificationCenter = .default, presenterFactory:)`. The `notificationCenter` let property is `nonisolated` (it is a stable reference) and usable from `deinit`.

**Observer lifetime:** Store the returned `any NSObjectProtocol` tokens in a `nonisolated(unsafe) private var observers: [any NSObjectProtocol]`. Mark `nonisolated(unsafe)` with the justification that `observers` is written exactly once during `start()` on MainActor and then only read in `deinit` where the coordinator is exclusively owned — no concurrent access is possible. Remove all observers in `deinit` using `notificationCenter.removeObserver(_:)`. Keep `start()` idempotent: guard on `observers.isEmpty`.

**Strict concurrency shape:** The outer `@Sendable (Notification) -> Void` closure captures `[weak self]`. `PrivacyCoverCoordinator` is `@MainActor`-isolated and therefore `Sendable`; `Notification` is `@unchecked Sendable`. Both captures are permissible in a `@Sendable` closure. The `@MainActor`-annotated `assumeIsolated` closure then calls `handleWillDeactivate`, `handleDidActivate`, or `handleDidDisconnect` with full MainActor isolation.

### R1 Change 3 — Disconnect handling

Observe `UIScene.didDisconnectNotification` with the same synchronous observer pattern. Add `handleDidDisconnect(for object: AnyObject)`: if an active presenter exists for the scene, call `hideCover()` on it and remove it from `activePresenters`; otherwise no-op. This prevents a stale entry from suppressing a future will-deactivate for a recycled scene slot or a different scene.

### Rework Gate 1 — Type signatures (delta)

```swift
// PrivacyCoverWindowAdapter (modified)
func hideCover() {
    // explicit: hide → nil rootVC → release
    coverWindow?.isHidden = true
    coverWindow?.rootViewController = nil
    coverWindow = nil
}

// PrivacyCoverCoordinator (modified init; new property; new method)
init(notificationCenter: NotificationCenter = .default, presenterFactory: @escaping PresenterFactory)

nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []
// (replaces observationTasks: [Task<Void, Never>])

func handleDidDisconnect(for object: AnyObject)

deinit // removes all observer tokens
```

### Rework test seam

The coordinator is now injectable with a `NotificationCenter`. Tests inject a private `NotificationCenter()` instance, call `start()`, and post notifications directly — proving synchronous delivery because there is no `await` between `post()` and the assertion. `NSObject()` instances serve as scene stand-ins (notification `object`). Existing 6 tests (which call `handleWillDeactivate`/`handleDidActivate` directly) remain unchanged.
