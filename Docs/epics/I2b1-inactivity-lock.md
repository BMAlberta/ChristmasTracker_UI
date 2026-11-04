# I2b-1: Inactivity lock (local half of I2b)
Track: iOS. Depends on: I2a, I2c, I6a (merged). Blocks: I2b-2 (auth flows, token persistence, registration code; needs the CONFORMANT contract).
Contract state: PRE-CONFORMANCE (no networking, API model, or token-persistence changes).

Why: decision A8 replaces the session ping with a client-side inactivity lock. A gift list left open on a shared family device must not be readable after the owner walks away, and the audience is older, so the lock must be forgiving and accessible.

Scope
1. A lock policy: timeout in minutes. Compiled default from xcconfig key INACTIVITY_LOCK_MINUTES (10 in Debug, QA, and Release), exposed through Info.plist. An optional override read from UserDefaults key `inactivityLockMinutesOverride` (this is the seam for a future remote value; it is also set by an Xcode launch argument `-inactivityLockMinutesOverride 1` for manual testing). Everything is clamped to 1...30 minutes; missing, non-numeric, zero, negative, or out-of-range values are ignored (fall back to the next source). There is no way to disable the lock.
2. Inactivity tracking using a monotonic clock (ContinuousClock instants), never wall-clock Date, so changing the device clock cannot extend a session. Time spent in the background counts toward the timeout. Touch activity resets the timer.
3. A lock controller that locks when the timeout elapses (foreground idle, or after returning from the background), only while the user is authenticated, and unlocks only after a successful biometric check or after the user chooses "Use password".
4. A lock screen shown in its own interactive UIWindow above all app content (so sheets and in-progress forms are covered but their state is preserved) and BELOW the privacy cover window from I2c. Large text, VoiceOver, and 44-point tap targets.
5. Unlock: Face ID or Touch ID through LocalAuthentication (a thin protocol wrapper so tests use a fake). "Use password" ends the session through the existing teardown (a new TeardownReason case, `lockFallback`) and shows the login screen. If biometrics are unavailable, not enrolled, locked out by the system, or the user turned biometric unlock off, the lock offers only "Use password".
6. A biometric-unlock preference: offered once after the first successful login (reuse the existing BiometricSetupView if it is presented today; otherwise present it once), with a toggle in Profile. The preference is a local UserDefaults flag. It does not change what is stored in the Keychain (I2b-2).
7. The controller resets on teardown (register it as a SessionClearable through makeProductionClearables).
8. scripts/check-config.sh gains INACTIVITY_LOCK_MINUTES = 10 for all three configurations.

Decisions
- Default 10 minutes; clamp 1...30; no off switch.
- A remote or admin-configured value is NOT fetched in this package; only the override slot exists.
- No change to the privacy cover. Whether the cover flashes behind the system Face ID prompt is verified manually on a device; if it is disruptive, a follow-up adds suppression while the lock is showing.
- The old ping and session-duration code is not touched.

Non-goals: token persistence or the A7 Keychain redesign, silent session restore, registration code, any networking, remote configuration fetch, I2c cover changes.

Acceptance
- Timeout resolution, clamping, and the override are unit-tested; the lock decision logic is unit-tested with a fake clock (foreground idle, background return, boundary at exactly the timeout, activity resets, wall-clock change has no effect).
- The lock appears only while authenticated, over sheets, below the privacy cover; biometric success unlocks; failure, cancel, lockout, and unavailability leave it locked and offer "Use password"; "Use password" ends the session and shows login.
- The controller is registered in the production clearable set and the registry test is updated.
- verify.sh is green, including check-config with the new key, before and after each commit.

---

## Inventory

All findings read from code at the time of this inventory.

### recordActivity

- `SessionManager.swift:96` — actor method `func recordActivity()`, sets `lastActivityTime = Date()`. Not called anywhere outside of SessionManager and AuthenticationService.
- `AuthenticationService.swift:219` — `@MainActor` wrapper method `func recordActivity()`, wraps `Task { await sessionManager.recordActivity() }`. Not called by any view today (dead code path; the old recordActivity-on-every-event pattern was never wired to touch events).

### isSessionValid

- `SessionManager.swift:101` — actor method `func isSessionValid() -> Bool`, reads `sessionStartTime` and `lastActivityTime` and returns false if max (24h) or base (30 min) duration exceeded. **Not called anywhere in production code.** It is dead code, superseded by decision A8.

### startSession

- `SessionManager.swift:73` — actor method `func startSession()`, sets `sessionStartTime` and `lastActivityTime = Date()`, starts `pingTask` (a `Task.detached` loop that calls `performPing()` every 5 minutes).
- `AuthenticationService.swift:245` — called by `handleAuthSuccess(authData:rememberMe:)` after every successful login, register, or token-restore.

### ping / performPing

- `AuthenticationRespository.swift:43` — protocol `func ping() async throws`
- `NetworkAuthenticationRepository.swift:100-110` — network implementation, `POST /auth/ping`
- `MockAuthenticationRepository.swift:99` — no-op mock
- `SessionManager.swift:122` — private `func performPing()`, called by pingTask
- `SessionManager.swift:81` — called by `pingTask` every `pingInterval` (5 min) in a `Task.detached`

**Do not touch any of the above** (A8 says ping is replaced; it and the 30-min and 24-h duration code remain until I1).

### scenePhase

Not found anywhere in production code. Greenfield.

### LAContext

- `KeychainService.swift:103` — creates `LAContext` in `getWithBiometric(_:reason:)` to evaluate `.deviceOwnerAuthenticationWithBiometrics` before Keychain access.
- `AuthenticationService.swift:322` — creates `LAContext` in `checkBiometricAvailability()` to test `canEvaluatePolicy`.

### BiometricSetupView

- `BiometricSetupView.swift:9` — defined; exists as a full SwiftUI view.
- **Not presented anywhere in the production app.** No `.sheet(isPresented:) { BiometricSetupView() }` exists in LoginView, ContentView, ChristmasTrackerApp, or any other file. It has only a `#Preview` macro usage.
- **Conclusion for Story 3:** BiometricSetupView is NOT presented anywhere today. Story 3 must present it once after the first successful login.

### isBiometricAvailable

- `AuthenticationService.swift:26` — `private(set) var isBiometricAvailable: Bool = false` (Observable property)
- `AuthenticationService.swift:103` — guard in `loginWithBiometric()`
- `AuthenticationService.swift:184` — guard in `setupBiometrics(biometricToken:)`
- `AuthenticationService.swift:325` — set in `checkBiometricAvailability()`
- `ProfileView.swift:26` — passed as `isBiometricAvailable: authService.isBiometricAvailable` to `SettingsSectionView`
- `LoginView.swift:59` — conditional display of biometric option

### biometricType

- `AuthenticationService.swift:27` — `private(set) var biometricType: BiometricType = .none`
- `AuthenticationService.swift:326,330` — set in `checkBiometricAvailability()` based on `LAContext.biometryType`
- `ProfileView.swift:27` — passed to `SettingsSectionView` as a let
- `BiometricSetupView.swift` — used throughout for button labels and icon selection
- `LoginView.swift:61,224,225` — used in `BiometricOptionView` for "Sign in with [type]" text

### Where BiometricSetupView is presented today

**Nowhere.** The view exists and has a preview. Neither LoginView, nor ContentView, nor ChristmasTrackerApp presents it. Story 3 must add the first-time presentation.

### ProfileView structure (where a toggle fits)

ProfileView is a `NavigationStack` → `ScrollView` → `VStack`:
1. `UserInfoCardView` — user avatar + name + email
2. `SettingsSectionView` — a `CardContainerView` containing `SettingsRowView` items:
   - Edit Profile (TODO)
   - Notifications (TODO)
   - Biometric row (shows biometric type displayName, calls TODO stub `onBiometric`)
3. `AboutSectionView` — Help, Privacy Policy, Version
4. `LogoutButtonView`

The existing biometric row in `SettingsSectionView` already exists as a `SettingsRowView` (line 149-163) gated on `isBiometricAvailable`. **Story 3 replaces this row with a `Toggle` for "Unlock with Face ID" (label from biometricType).**

### INACTIVITY_LOCK_MINUTES effective values after adding to xcconfig

Value added to Config.xcconfig (Release base), Config-Debug.xcconfig, and Config-QA.xcconfig as `INACTIVITY_LOCK_MINUTES = 10`. Since all three explicitly set the key to 10, the effective value is **10 for Debug, QA, and Release**. Verification via `-showBuildSettings` is performed in the Story 1 report after the xcconfig changes are committed.

### Touch-capture options evaluated (Story 2 input)

| Option | Verdict |
|---|---|
| `.gesture()` or `simultaneousGesture()` on ContentView's root | Rejected: SwiftUI gesture recognizers sit in the view tree and compete with scroll/drag gestures; `simultaneousGesture` would need to be applied recursively or at the window level |
| `UIApplicationDelegate application(_:sendEvent:)` | Rejected: requires `@UIApplicationDelegateAdaptor`, adds an application delegate to a @main SwiftUI app, and sendEvent is called for every event in the app which is heavyweight |
| `UIGestureRecognizer` on each scene's main window | **Chosen**: attaches once per scene, never recognizes (always fails), `cancelsTouchesInView = false`, `delaysTouchesBegan = false`, `delaysTouchesEnded = false`, allows simultaneous recognition with all children via `shouldRecognizeSimultaneouslyWith` returning true; lightweight; does not intercept gestures on the cover window (which is correct — touches on the locked screen should not reset the timer) |
| `UIWindow.sendEvent(_:)` subclass | Rejected: requires subclassing UIWindow, more invasive than a recognizer |

**Chosen mechanism:** `UIGestureRecognizer` subclass added to each scene's main window. Limitation: does not capture touches on the lock window itself (acceptable — the lock window should not reset the timer).

---

## Gate 1: Story 1 — Lock policy, inactivity tracker, controller

### New interface: Yes

### Type signatures

```swift
// MARK: SessionClearable.swift (modified — add case)
internal enum TeardownReason: Sendable {
    case userLogout
    case sessionExpired
    case forcedUpdate
    case lockFallback  // "Use password" on the inactivity lock screen
}

// MARK: Features/Authentication/Services/LockPolicy.swift (new)

/// Protocol seam so tests inject a fake; production uses LockPolicy.
internal protocol LockTimeoutProviding {
    var timeoutMinutes: Int { get }
}

/// Reads the inactivity timeout from Info.plist (xcconfig-sourced) with a UserDefaults override.
/// Resolution order:
///   1. UserDefaults key `inactivityLockMinutesOverride` (set by launch arg or future remote config)
///   2. Info.plist key INACTIVITY_LOCK_MINUTES (xcconfig value, compile-time)
///   3. Hardcoded fallback: 10
/// Every source is clamped to 1...30. Zero, negative, non-numeric, and out-of-range values skip
/// to the next source. There is no way to disable the lock.
internal struct LockPolicy: LockTimeoutProviding {
    /// `defaults` is injected so tests use an isolated suite.
    init(defaults: UserDefaults = .standard,
         infoDictionary: [String: Any]? = Bundle.main.infoDictionary)
    var timeoutMinutes: Int { get }
    nonisolated static func clamp(_ value: Int) -> Int  // pure; clamps to 1...30
    nonisolated static func parse(_ raw: String?) -> Int?  // nil if blank/non-numeric/zero/negative/out-of-range
}

// MARK: Features/Authentication/Services/InactivityTracker.swift (new)

/// Pure value type. No real clock — all instants are caller-supplied.
/// Tests inject any ContinuousClock.Instant without sleeping.
internal struct InactivityTracker {
    typealias Instant = ContinuousClock.Instant

    init(policy: any LockTimeoutProviding)

    /// Resets the inactivity deadline to `now + timeout`.
    mutating func recordActivity(at now: Instant)

    /// Records the background-entry instant so elapsed background time counts toward the timeout.
    mutating func enteredBackground(at now: Instant)

    /// Returns true if elapsed time since enteredBackground(at:) >= timeout.
    /// Resets the background instant (treat the return as a new activity baseline when false).
    mutating func becameActive(at now: Instant) -> Bool

    /// The ContinuousClock instant at which the foreground idle timer should fire.
    var deadline: Instant { get }

    /// Returns true if `now >= deadline` (user has been idle for >= timeout).
    func isTimedOut(at now: Instant) -> Bool
}

// MARK: Features/Authentication/Services/InactivityLockController.swift (new)

/// Protocol seam for scene events; tests inject a FakeSceneEventProvider.
internal protocol SceneEventProviding: AnyObject {
    var willResignActiveHandler: (() -> Void)? { get set }
    var didBecomeActiveHandler: (() -> Void)? { get set }
}

/// MainActor-isolated, Observable. Single source of truth for the lock state.
@MainActor
@Observable
internal final class InactivityLockController {

    enum LockState {
        case unlocked
        case locked
    }

    private(set) var lockState: LockState = .unlocked

    /// Set by production wiring; tests inject a FakeSceneEventProvider.
    var sceneEventProvider: (any SceneEventProviding)?

    /// Set by production wiring; used by usePasswordTeardown().
    weak var authService: AuthenticationService?

    init(policy: any LockTimeoutProviding)

    /// Starts the foreground idle timer. Only active after the user authenticates.
    /// Idempotent: a second call while the timer is running is a no-op.
    func start()

    /// Cancels the foreground idle timer. Called on logout/teardown.
    func stop()

    /// Records touch activity; resets the inactivity deadline.
    /// No-op when locked (the lock screen gestures should not reset the timer).
    func recordActivity()

    /// Scene will-resign-active: records background-entry instant.
    func sceneWillResignActive()

    /// Scene did-become-active: computes elapsed background time and locks if >= timeout.
    func sceneDidBecomeActive()

    /// Unlocks the screen after a successful biometric result.
    func unlock()

    /// Ends the session via authService.logout(reason: .lockFallback).
    func usePasswordTeardown()
}

extension InactivityLockController: SessionClearable {
    /// Stops the timer and resets lockState to .unlocked.
    func clearForSession() async throws
}
```

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LockPolicy.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityTracker.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LockPolicyTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityTrackerTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockControllerTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift` — add `TeardownReason.lockFallback`
- `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig` — add `INACTIVITY_LOCK_MINUTES = 10`
- `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig` — add `INACTIVITY_LOCK_MINUTES = 10`
- `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig` — add `INACTIVITY_LOCK_MINUTES = 10`
- `ChristmasTracker/ChristmasTracker/Info.plist` — add `INACTIVITY_LOCK_MINUTES` key
- `scripts/check-config.sh` — add INACTIVITY_LOCK_MINUTES = 10 check for Debug, QA, Release

### Decisions

- LockPolicy reads from Info.plist key `INACTIVITY_LOCK_MINUTES` (via injected `infoDictionary`), then checks `UserDefaults` key `inactivityLockMinutesOverride`.
- Both sources clamped to 1...30. Zero, negative, non-numeric, and out-of-range values fall through.
- Hardcoded fallback is 10 (never reached in production since Info.plist always supplies the xcconfig value; exists for test isolation with empty infoDictionary).
- InactivityTracker is a struct (value type); InactivityLockController holds one and updates it on each event.
- Foreground idle timer uses `Task.sleep(until: tracker.deadline, tolerance: .seconds(1), clock: ContinuousClock())`. On activity, cancel and reschedule; no GCD.
- SceneEventProviding seam: tests use a `FakeSceneEventProvider` and call the handlers directly; production wiring injects a concrete type that observes `UIScene.willDeactivateNotification` and `UIScene.didActivateNotification` using the same synchronous `addObserver(forName:queue:nil)` pattern as PrivacyCoverCoordinator.
- InactivityLockController does NOT observe notifications directly — it receives signals through the seam so it stays testable without UIKit.

---

## Gate 1: Story 2 — Lock screen, biometric gate, activity capture, wiring

### New interface: Yes

### Type signatures

```swift
// MARK: Features/Authentication/Services/BiometricAuthenticating.swift (new)

internal enum BiometricResult {
    case success
    case userCancelled       // LAError.userCancel
    case systemCancelled     // LAError.systemCancel
    case userFallback        // LAError.userFallback ("Use Password" in system dialog)
    case lockedOut           // LAError.biometryLockout
    case unavailable         // LAError.biometryNotAvailable, LAError.biometryNotEnrolled, or similar
    case failed              // Any other LAError
}

internal protocol BiometricAuthenticating: Sendable {
    var biometryType: BiometricType { get }
    var isAvailable: Bool { get }
    func authenticate(reason: String) async -> BiometricResult
}

internal final class LocalAuthenticationService: BiometricAuthenticating {
    var biometryType: BiometricType { get }  // derived from LAContext.biometryType
    var isAvailable: Bool { get }             // LAContext.canEvaluatePolicy
    func authenticate(reason: String) async -> BiometricResult
    // Uses a single LAContext per attempt. Never logs result beyond the case name.
}

// Fake for tests — lives in the test target
internal final class FakeBiometricAuthenticator: BiometricAuthenticating {
    var stubbedBiometryType: BiometricType = .faceID
    var stubbedIsAvailable: Bool = true
    var stubbedResult: BiometricResult = .success
    var biometryType: BiometricType { stubbedBiometryType }
    var isAvailable: Bool { stubbedIsAvailable }
    func authenticate(reason: String) async -> BiometricResult { stubbedResult }
}

// MARK: App/AppWindowLevels.swift (new)

import UIKit

extension UIWindow.Level {
    /// Privacy cover window (I2c): above all alerts and sheets.
    /// Matches the hardcoded value in PrivacyCoverWindowAdapter (not modified).
    static let privacyCoverLevel: UIWindow.Level = .alert + 1
    /// Inactivity lock window: above all app content and sheets, below the privacy cover.
    static let inactivityLockLevel: UIWindow.Level = .alert + 0.5
}

// MARK: App/InactivityTouchRecognizer.swift (new)

import UIKit

/// A UIGestureRecognizer that records touch activity without interfering with the responder chain.
/// cancelsTouchesInView = false, delaysTouchesBegan = false, delaysTouchesEnded = false.
/// Always transitions to .failed; never consumes touches.
/// Allows simultaneous recognition with all other recognizers.
final class InactivityTouchRecognizer: UIGestureRecognizer {
    var activityHandler: (() -> Void)?
    // touchesBegan: calls activityHandler, state = .failed
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent)
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent)
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    // UIGestureRecognizerDelegate: shouldRecognizeSimultaneouslyWith always returns true
}

// MARK: App/LockWindowAdapter.swift (new)
// Manual adapter; verified manually. MainActor by default.

@preconcurrency import UIKit

final class LockWindowAdapter {
    private weak var scene: UIWindowScene?
    private var lockWindow: UIWindow?

    init(scene: UIWindowScene)

    func showLock(controller: InactivityLockController,
                  biometricAuthenticator: any BiometricAuthenticating)
    func hideLock()  // isHidden = true; rootViewController = nil; lockWindow = nil
}

// MARK: App/LockView.swift (new)

struct LockView: View {
    // All DesignSystem tokens (AppColors, AppTypography, AppSpacing). No app data.
    // Elements:
    //   - App name "Christmas Tracker" in Font.appTitle1 / Color.textPrimaryColor
    //   - Short plain message in Font.appBody / Color.textMutedColor
    //   - Primary button: "Unlock with Face ID" / "Unlock with Touch ID"
    //     (shown only when biometricAuthenticator.isAvailable AND preference.biometricUnlockEnabled)
    //   - Secondary button: "Use password" (always shown)
    //   - Minimum 44pt tap targets
    //   - Dynamic Type: no fixed heights; .minimumScaleFactor(0.8) if needed
    //   - VoiceOver: .accessibilityLabel on buttons; UIAccessibility.post(.screenChanged) on appear
    //   - Light/dark adaptive via AppColors
    let controller: InactivityLockController
    let biometricAuthenticator: any BiometricAuthenticating
    var body: some View
}

// MARK: SessionClearable.swift (modified — add lockController parameter)

internal func makeProductionClearables(
    listDataStore: ListDataStore,
    itemDataStore: ItemDataStore,
    listService: ListService,
    itemService: ItemService,
    networkCache: NetworkCache,
    lockController: InactivityLockController  // NEW
) -> [any SessionClearable]
// Returns 6 clearables:
// [listDataStore, itemDataStore, listService, itemService, networkCache, lockController]
```

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift`
- `ChristmasTracker/ChristmasTracker/App/AppWindowLevels.swift`
- `ChristmasTracker/ChristmasTracker/App/InactivityTouchRecognizer.swift`
- `ChristmasTracker/ChristmasTracker/App/LockWindowAdapter.swift`
- `ChristmasTracker/ChristmasTracker/App/LockView.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricAuthenticatingTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — add lock controller, scene observer, activity recognizer, lock window adapter, wiring for show/hide
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift` — add lockController parameter to makeProductionClearables
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift` — registry test: count 5 → 6, add `clearables[5] is InactivityLockController`

### Decisions

- Activity capture: `InactivityTouchRecognizer` subclass added to each scene's main window via `UIGestureRecognizer`. `cancelsTouchesInView = false`, `delaysTouchesBegan = false`, `delaysTouchesEnded = false`. Always transitions to `.failed`. Implements `UIGestureRecognizerDelegate` returning `true` from `shouldRecognizeSimultaneously`. Added once per scene; not removed unless the scene disconnects. Limitation: does not capture touches on additional UIWindows (acceptable — the lock window should not reset the timer while locked).
- Lock window level: `.inactivityLockLevel` (`.alert + 0.5`) defined in `AppWindowLevels.swift`; keeps the lock below the cover (`.alert + 1`) without modifying `PrivacyCoverWindowAdapter`.
- Lock window show/hide pattern reuses PrivacyCoverWindowAdapter conventions: `isHidden = false` to show (no makeKey, no animation); `isHidden = true` + `rootViewController = nil` before nil assignment to release.
- Biometric result mapping:
  - `.success` → `controller.unlock()`
  - `.userCancelled`, `.systemCancelled` → stay locked, "Try Again" available (no user message)
  - `.userFallback`, `.lockedOut`, `.unavailable`, `.failed` → stay locked, show only "Use password"
- LAContext: single instance per authentication attempt; never logged beyond the case name.
- Wiring observes `InactivityLockController.lockState` changes via `withObservationTracking` or a Task observation loop to show/hide the lock window.
- Scene event wiring: a lightweight adapter (can be in ChristmasTrackerApp) uses `NotificationCenter.addObserver(forName:object:queue:nil)` with `MainActor.assumeIsolated`, same pattern as PrivacyCoverCoordinator, and calls `lockController.sceneWillResignActive()` / `lockController.sceneDidBecomeActive()`.

---

## Gate 1: Story 3 — Biometric unlock preference

### New interface: Yes

### Type signatures

```swift
// MARK: Features/Authentication/Services/BiometricUnlockPreference.swift (new)

internal protocol BiometricUnlockPreferring {
    var biometricUnlockEnabled: Bool { get set }
    var biometricSetupOfferShown: Bool { get set }
}

internal struct BiometricUnlockPreference: BiometricUnlockPreferring {
    static let enabledKey = "biometricUnlock.enabled"
    static let offerShownKey = "biometricUnlock.offerShown"

    /// `defaults` is injected so tests use an isolated suite.
    init(defaults: UserDefaults = .standard)

    var biometricUnlockEnabled: Bool { get set }   // reads/writes UserDefaults
    var biometricSetupOfferShown: Bool { get set }  // reads/writes UserDefaults
}

// MARK: Fake for tests (test target only)
internal final class FakeBiometricUnlockPreference: BiometricUnlockPreferring {
    var biometricUnlockEnabled: Bool = false
    var biometricSetupOfferShown: Bool = false
}
```

**ProfileView.swift (modified):**
- `SettingsSectionView` gains a `preference: Binding<BiometricUnlockPreference>` parameter.
- The existing TODO biometric `SettingsRowView` (line 149-163) is replaced with a `Toggle`:
  - Label: "Unlock with [biometricType.displayName]"
  - Binding: `$preference.biometricUnlockEnabled`
  - Disabled with a note (`.disabled(!isBiometricAvailable)`) when biometrics are unavailable.

**ChristmasTrackerApp.swift (modified):**
- After successful login (observing `authService.isAuthenticated` changing to `true`): if `preference.biometricSetupOfferShown == false` and `authService.isBiometricAvailable`, present `BiometricSetupView` as a sheet.
- Pass a `onOfferComplete(enabled: Bool)` closure to `BiometricSetupView` so the app can record `preference.biometricSetupOfferShown = true` and `preference.biometricUnlockEnabled = enabled`.

**BiometricSetupView.swift (modified — minimally):**
- Add optional `var onComplete: ((Bool) -> Void)?` callback. "Enable" calls `onComplete(true)` after setup; "Not Now" calls `onComplete(false)`. Existing `setupBiometrics` Keychain behavior is unchanged.

**InactivityLockController.swift (modified):**
- Add `var preference: (any BiometricUnlockPreferring)?` (set by wiring).
- `start()` and the lock screen rendering read `preference?.biometricUnlockEnabled` to decide whether to offer biometric unlock. If `false` or `preference == nil`, the lock shows only "Use password".

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricUnlockPreference.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricUnlockPreferenceTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — add preference, present BiometricSetupView after login
- `ChristmasTracker/ChristmasTracker/Features/Profile/Views/ProfileView.swift` — replace TODO biometric row with Toggle
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — read preference to show/hide biometric button
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/BiometricSetupView.swift` — add `onComplete` callback
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift` — add preference property

### Decisions

- Preference is UserDefaults-backed; device-level, not session-level (survives teardown — it is a device preference).
- `biometricSetupOfferShown` is set to `true` on both "Enable" and "Not Now"; the offer is never shown again.
- If the user later enables biometric unlock in Profile (after declining the initial offer), the toggle sets `biometricUnlockEnabled = true` without re-showing the BiometricSetupView (it was already shown once; re-enabling via toggle goes straight to UserDefaults).
- The existing `setupBiometrics(biometricToken:)` Keychain behavior in AuthenticationService is unchanged (I2b-2).
- BiometricSetupView modification is minimal: only the `onComplete` callback is added. The view's existing behavior (prompt, Keychain setup, dismiss) is preserved.

---

## Rework Gate 1: Story R1 — Controller and Tracker Correctness

### Defects confirmed by code review

**D1 (unlock relock loop):** `InactivityLockController.unlock()` calls `scheduleTimer()` which uses `tracker.deadline`. After a foreground-idle lock the deadline is in the past, so the timer fires immediately, `checkTimeout` sees the deadline still passed, and locks again. Confirmed: `scheduleTimer()` does not reset the deadline; `recordActivity()` is a no-op while locked.

**D2 (scene events while not running):** `sceneDidBecomeActive()` calls `tracker.becameActive(at:)` unconditionally; there is no `isRunning` guard. A scene cycle on the login screen can lock the app while unauthenticated.

**D3 (tracker measures only background duration):** `InactivityTracker.becameActive()` computes `elapsed = now - backgroundEntryInstant` and returns `elapsed >= timeout`. Foreground idle time preceding the background does not contribute. After 9 idle foreground minutes and a 2-minute background, the check sees 2 minutes elapsed — does not lock. Deadline is also reset unconditionally in `becameActive`, so a brief Control Center dismissal extends the session by a full timeout.

### New semantics (required)

**InactivityTracker** (pure value type, no UIKit):
- Removes `enteredBackground(at:)` and `backgroundEntryInstant`.
- `becameActive(at: now)` → `return isTimedOut(at: now)`. No side effect; does not reset deadline.
- `recordActivity(at: now)` → `deadline = now + timeout`. Unchanged.
- `isTimedOut(at: now)` → `now >= deadline`. Unchanged.
- Inactivity is measured continuously from last activity; background time counts toward the timeout automatically because the deadline is not reset on backgrounding.

**InactivityLockController**:
- Adds `private(set) var isRunning: Bool = false`.
- Adds clock and sleeper seams for testability (see signatures below).
- `start()`: sets `isRunning = true`, resets tracker deadline to `clockNow() + timeout`, then schedules the timer.
- `stop()`: sets `isRunning = false`, cancels the timer. Does not change `lockState`.
- `sceneDidBecomeActive()`: no-op if `!isRunning`; calls `tracker.becameActive(at: clockNow())`; locks if true.
- `sceneWillResignActive()`: no-op (background-entry tracking removed).
- `recordActivity()`: no-op if `!isRunning` or if locked; calls `tracker.recordActivity(at: clockNow())`; reschedules timer.
- `unlock()`: calls `tracker.recordActivity(at: clockNow())` to reset the deadline, sets `lockState = .unlocked`, then reschedules the timer for the new deadline.
- Timer task calls `sleepUntil(tracker.deadline)`; on wakeup calls `checkTimeout()` which calls `clockNow()` for the timedout check.
- `clearForSession()`: cancels timer, sets `isRunning = false`, sets `lockState = .unlocked`.

### Type signatures (delta)

```swift
// InactivityTracker.swift — remove these:
//   mutating func enteredBackground(at now: Instant)
//   mutating func becameActive(at now: Instant) -> Bool  // old signature with side effects
// Add (simplified becameActive, no side effects):
internal mutating func becameActive(at now: Instant) -> Bool  // return isTimedOut(at: now)

// InactivityLockController.swift — new init signature:
internal init(
    policy: any LockTimeoutProviding,
    clockNow: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now },
    sleepUntil: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
        deadline in try await ContinuousClock().sleep(until: deadline)
    }
)

// New property:
private(set) var isRunning: Bool = false

// sceneWillResignActive becomes a no-op:
internal func sceneWillResignActive()  // no-op; kept for wiring compatibility

// tracker visibility: keep internal (the rework must NOT use tracker.enteredBackground
// any longer in tests; instead use fake clock + scene events)
```

### Fake infrastructure (test target only)

```swift
// FakeClock.swift — test target
@MainActor
final class FakeClock {
    var now: ContinuousClock.Instant
    init(startingAt instant: ContinuousClock.Instant = ContinuousClock().now) { self.now = instant }
    func advance(by duration: Duration) { now = now + duration }
}

// FakeSleeper.swift — test target
// nonisolated(unsafe) on pending: accessed from both @MainActor release() and the
// nonisolated withTaskCancellationHandler.onCancel block. Safe because onCancel runs
// only when the Task is being cancelled (exclusive access to pending at that point).
@MainActor
final class FakeSleeper {
    private(set) var requestedDeadline: ContinuousClock.Instant?
    nonisolated(unsafe) private var pending: CheckedContinuation<Void, Error>?

    func sleep(until deadline: ContinuousClock.Instant) async throws {
        requestedDeadline = deadline
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [self] c in self.pending = c }
        } onCancel: {
            self.pending?.resume(throwing: CancellationError())
            self.pending = nil
        }
        pending = nil
    }

    func release() {
        pending?.resume(returning: ())
        pending = nil
    }
}

// Helper: make controller with injected seams
func makeController(
    timeoutMinutes: Int = 10,
    clock: FakeClock,
    sleeper: FakeSleeper
) -> InactivityLockController {
    InactivityLockController(
        policy: FakePolicy(timeoutMinutes: timeoutMinutes),
        clockNow: { clock.now },
        sleepUntil: { deadline in try await sleeper.sleep(until: deadline) }
    )
}
```

### Test yield pattern

After `start()` or any method that creates/reschedules the timer Task, the test must yield once so the Task runs to its first suspension point:

```swift
// Let the new timer task start and hit sleeper.sleep():
await Task.yield()
// Now sleeper.requestedDeadline is set.
```

After `sleeper.release()`, yield again to let the timer task wake and run `checkTimeout()`:

```swift
sleeper.release()
await Task.yield()
// Now lockState reflects the timeout check.
```

### Tests to delete (prompt-specified)

Delete from `InactivityLockControllerTests.swift` with reason:

| Test name | Reason |
|---|---|
| `sceneCycleExceedingTimeoutCausesLock` | Vacuous: only asserts `.unlocked` after `stop()`; never actually locked. |
| `unlockAfterLockRestoresUnlockedState` | Vacuous: calls `unlock()` on an already-unlocked controller. |
| `recordActivityWhenLockedIsNoOp` (first, line 138) | Vacuous: only calls `recordActivity()` on an *unlocked* controller; asserts `.unlocked`. |
| `sceneHandlersAttachedAfterStart` | Redundant: R1 test 7 (scene events before start never lock) covers the same guard. |
| `controllerDoesNotLockWhenNotStarted` | Redundant: R1 test 7 covers this directly. |

Delete from `InactivityTrackerTests.swift` with reason:

| Test name | Reason |
|---|---|
| `backgroundReturnAfterTimeoutLocks` | Tests `enteredBackground`/`becameActive` old semantics; both removed. |
| `backgroundReturnBeforeTimeoutDoesNotLock` | Same. |
| `enteredBackgroundThenRecordActivityDoesNotAffectBecameActive` | Same. |

Rewrite (keep name or give new name) with reason:

| Old test | New test name | Reason |
|---|---|---|
| `trackerUsesOnlyInstant` | `trackerUsesOnlyInstant` | Remove `enteredBackground`/`becameActive` calls; replace with `becameActive(at:)` new API. |
| Controller locked-state tests using `tracker.enteredBackground` (5 tests) | Same names, new body | Remove `tracker.enteredBackground`; use fake clock + `sceneDidBecomeActive()`. |
| `makeLockedController()` in `BiometricAuthenticatingTests` | Helper rewritten | Use fake clock; advance past deadline; call `sceneDidBecomeActive()`. |
| `lockControllerConformsToSessionClearable` in `InactivityLockIntegrationTests` | Same name | Use fake clock to reach locked state. |

### New tests (R1) — 11 controller tests + 2 tracker tests

Tracker additions (2 new):
- T-new-1: `becameActiveAtExactDeadlineLocks` — `becameActive(at: deadline)` returns `true`.
- T-new-2: `becameActiveOneNanosecondBeforeDeadlineDoesNotLock` — `becameActive(at: deadline - .nanoseconds(1))` returns `false`. Deadline is unchanged after the call.

Controller additions (11 new, with fake clock + fake sleeper):
1. `foregroundIdleFiresTimerAtDeadline` — after `start()` and sleeper released at deadline, `lockState == .locked`.
2. `timerReleasedOneSecondEarlyReschedulesForSameDeadline` — sleeper released at deadline - 1s: state stays `.unlocked`; `sleeper.requestedDeadline` is unchanged (same deadline).
3. `unlockAfterIdleLock_freshDeadlineAndNoRelockOnNewDeadlineMinusOne` — after idle lock, `unlock()` resets deadline to `now + timeout`; releasing sleeper 1s before that new deadline does not relock.
4. `cumulativeInactivity_9minIdle_2minBackground_locks` — advance clock 9m, call `sceneWillResignActive`, advance 2 more minutes, call `sceneDidBecomeActive`: `lockState == .locked`.
5. `cumulativeInactivity_5minIdle_3minBackground_doesNotLock_deadlineUnchanged` — advance 5m, background, advance 3m, foreground: not locked; `tracker.deadline` equals original deadline.
6. `becameActiveBoundary_exactDeadlineLocks_oneNanosecondBeforeDoesNot` — two controller subtests using fake clock at exactly deadline and at deadline - 1ns.
7. `sceneEventsBeforeStartAndAfterStopNeverLock` — advance fake clock far past deadline; call scene events before `start()` and after `stop()`; never locked.
8. `startResetsDeadline_priorFakeClockAdvanceDoesNotCauseLock` — advance fake clock 15m, then call `start()`; immediate `sceneDidBecomeActive()` does not lock.
9. `recordActivityWhileRunningPushesDeadlineAndReschedules` — while running and unlocked: `recordActivity()` advances deadline by timeout; sleeper reschedules for new deadline. While locked: `recordActivity()` changes nothing.
10. `clearForSession_resetsLockedRunningControllerToUnlockedAndNotRunning` — drive to locked+running state; `clearForSession()`: `lockState == .unlocked`, `isRunning == false`.
11. `trackerAlone_activityDeadline_isTimedOutBoundary_becameActiveSemantics` (tracker test): `recordActivity` sets deadline; `isTimedOut` at boundary; `becameActive` returns `now >= deadline` without changing deadline.

### Scoped file list

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityTracker.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityTrackerTests.swift` (delete 3, rewrite 1, add 2)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockControllerTests.swift` (delete 5, rewrite 5, add 11)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricAuthenticatingTests.swift` (rewrite `makeLockedController` helper)
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift` (rewrite `lockControllerConformsToSessionClearable`)

**New (test target):**
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FakeClock.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FakeSleeper.swift`

---

## Rework Gate 1: Story R2 — Synchronous Lock Presentation and Biometric Outcome Mapping

### Defects confirmed by code review

**D4 (async lock presentation):** `ChristmasTrackerApp.body` has `.onChange(of: lockController.lockState)` which calls `lockCoordinator.handleLockStateChange(lockState)`. `.onChange` is delivered asynchronously on the next SwiftUI render cycle, not synchronously within the scene notification handler. On return from background, the privacy cover hides synchronously (PrivacyCoverCoordinator uses synchronous `addObserver(queue: nil)`) but the lock window appears on the next frame — a gap of app content is visible.

**D5 (failed biometric hides the button):** `LockView.attemptBiometricUnlock()` maps `.failed` to `showPasswordOnly = true`. A transient failure (non-matching face, lighting, slightly wet finger) permanently hides the biometric button for the rest of that lock event, forcing the user to log in entirely. The correct behavior: `.failed` keeps the biometric button visible and shows a short "try again" hint. Only `.userFallback`, `.lockedOut`, and `.unavailable` warrant password-only mode.

### New semantics (required)

**InactivityLockPresenting protocol** (new, `App/InactivityLockPresenting.swift`):
```swift
internal protocol InactivityLockPresenting: AnyObject {
    func presentLock()
    func dismissLock()
}
```

`InactivityLockController` gains:
```swift
var lockPresenter: (any InactivityLockPresenting)?
```

The controller calls `lockPresenter?.presentLock()` SYNCHRONOUSLY (before the method returns) inside:
- `sceneDidBecomeActive()` — if `becameActive` returns true
- `checkTimeout()` — if `isTimedOut` returns true
- It does NOT call `presentLock` if already locked (guard `lockState == .unlocked`).

The controller calls `lockPresenter?.dismissLock()` synchronously inside:
- `unlock()` — before rescheduling the timer
- `clearForSession()` — only if `lockState == .locked` at the time of the call

`LockCoordinator` in `ChristmasTrackerApp.swift` conforms to `InactivityLockPresenting`. The `handleLockStateChange(_:)` method and the `.onChange(of: lockController.lockState)` path in `body` are **removed**. Instead, `lockController.lockPresenter` is set to the `lockCoordinator` after construction.

**Biometric outcome mapping** (extracted from `LockView` for testability):

```swift
// Pure nonisolated function (new file or added to LockView.swift):
internal func biometricOutcome(
    for result: BiometricResult,
    biometryTypeName: String
) -> BiometricOutcome

internal enum BiometricOutcome: Equatable {
    case unlock               // success
    case keepBiometricButton  // userCancelled, systemCancelled, failed
    case showHint(String)     // failed only — includes biometryTypeName for the message
    case passwordOnly         // userFallback, lockedOut, unavailable
}
```

Wait — simplify the enum. The prompt says `.failed` keeps the biometric button visible AND shows a hint. So:

```swift
internal enum BiometricOutcome: Equatable {
    case unlock
    case keepBiometric(hint: String?)  // hint is non-nil for .failed only
    case passwordOnly
}

internal nonisolated func biometricOutcome(
    for result: BiometricResult,
    biometryTypeName: String
) -> BiometricOutcome {
    switch result {
    case .success:
        return .unlock
    case .userCancelled, .systemCancelled:
        return .keepBiometric(hint: nil)
    case .failed:
        let hint = "\(biometryTypeName) didn't recognize you. Try again or use your password."
        return .keepBiometric(hint: hint)
    case .userFallback, .lockedOut, .unavailable:
        return .passwordOnly
    }
}
```

**Button visibility rule** (extracted for testing):

```swift
internal nonisolated func showBiometricButton(
    isAvailable: Bool,
    preferenceEnabled: Bool,
    isPasswordOnly: Bool
) -> Bool {
    isAvailable && preferenceEnabled && !isPasswordOnly
}
```

`LockView` calls these two functions instead of inline logic. `attemptBiometricUnlock` applies the `BiometricOutcome`:
- `.unlock` → `controller.unlock()`
- `.keepBiometric(hint:)` → set `hintText = hint` (new `@State`); biometric button stays visible
- `.passwordOnly` → `showPasswordOnly = true`

### New Gate 1 type signatures

```swift
// App/InactivityLockPresenting.swift (new)
internal protocol InactivityLockPresenting: AnyObject {
    func presentLock()
    func dismissLock()
}

// InactivityLockController.swift (modified)
var lockPresenter: (any InactivityLockPresenting)?
// Called synchronously on lock (before returning from sceneDidBecomeActive/checkTimeout)
// Called synchronously on unlock (before rescheduling timer in unlock())
// Called synchronously on clearForSession (if was locked)

// LockView.swift (modified) — added @State:
@State private var hintText: String? = nil
// biometricButton shows hintText below button when non-nil

// New pure functions (can live in LockView.swift or a new file):
internal nonisolated func biometricOutcome(
    for result: BiometricResult,
    biometryTypeName: String
) -> BiometricOutcome

internal nonisolated func showBiometricButton(
    isAvailable: Bool,
    preferenceEnabled: Bool,
    isPasswordOnly: Bool
) -> Bool
```

### Tests (R2, Swift Testing, `@MainActor`)

```swift
// FakeLockPresenter (test target, alongside FakeClock/FakeSleeper)
@MainActor
final class FakeLockPresenter: InactivityLockPresenting {
    private(set) var presentCallCount = 0
    private(set) var dismissCallCount = 0
    func presentLock() { presentCallCount += 1 }
    func dismissLock() { dismissCallCount += 1 }
}
```

Required tests (new file `InactivityLockPresenterTests.swift`):
1. `presentLockCalledBeforeSceneDidBecomeActiveReturns` — after advance-past-deadline + `sceneDidBecomeActive()`: `presentCallCount == 1` and `lockState == .locked` before yielding.
2. `dismissLockCalledBeforeUnlockReturns` — after lock then `unlock()`: `dismissCallCount == 1`.
3. `presentLockNotCalledTwiceForRepeatedLockTriggers` — `sceneDidBecomeActive()` twice when already locked: `presentCallCount` stays 1.
4. `clearForSessionCallsDismissWhenLocked` — drive to locked, `clearForSession()`: `dismissCallCount == 1`.
5. `clearForSessionDoesNotCallDismissWhenUnlocked` — `clearForSession()` without locking first: `dismissCallCount == 0`.

Required tests (new file `BiometricOutcomeTests.swift`):
6. `.success` → `.unlock`
7. `.userCancelled` → `.keepBiometric(hint: nil)`
8. `.systemCancelled` → `.keepBiometric(hint: nil)`
9. `.failed` → `.keepBiometric(hint:)` with non-nil hint containing "try again"
10. `.userFallback` → `.passwordOnly`
11. `.lockedOut` → `.passwordOnly`
12. `.unavailable` → `.passwordOnly`
13. `showBiometricButton(isAvailable: true, preferenceEnabled: true, isPasswordOnly: false)` → true
14. `showBiometricButton(isAvailable: false, ...)` → false
15. `showBiometricButton(isAvailable: true, preferenceEnabled: false, ...)` → false
16. `showBiometricButton(isAvailable: true, preferenceEnabled: true, isPasswordOnly: true)` → false

### Scoped file list (R2)

**New:**
- `ChristmasTracker/ChristmasTracker/App/InactivityLockPresenting.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/InactivityLockPresenterTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricOutcomeTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/InactivityLockController.swift` — add `lockPresenter`; call synchronously
- `ChristmasTracker/ChristmasTracker/App/LockView.swift` — extract outcome mapping; fix `.failed` behavior; add `hintText` state
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — remove `.onChange(of: lockController.lockState)`; set `lockController.lockPresenter = lockCoordinator`; `LockCoordinator` conforms to `InactivityLockPresenting`

**No new test file for the BiometricAuthenticatingTests mapping tests:** those tests test via the LockView mock-caller pattern and remain valid; only the production `attemptBiometricUnlock` path changes.

---

## Rework 2 Gate 1: Story R5 — Enablement model and live biometric availability

### Defects addressed

**B1 (`BiometricSetupView` silently returns):** `enableBiometric()` reads `KeychainService.get("auth.refresh_token")`, returns without notifying `onComplete` when nil (normal login without "Remember me"). Fix: introduce `BiometricEnablementModel` that evaluates biometrics directly and writes the preference; `BiometricSetupView` uses the model. No Keychain read; `setupBiometrics` not called from this path.

**B2 (stale biometric availability):** `AuthenticationService.isBiometricAvailable` and `biometricType` are set once at launch via `checkBiometricAvailability()` which creates `LAContext` directly. Permissions or enrollment changes later in the session are never reflected. Fix: inject `any BiometricAuthenticating` into `AuthenticationService`; replace `checkBiometricAvailability()` with `refreshBiometricAvailability()` that reads from the authenticator; call it from `init()` and `handleAuthSuccess`.

### New interface: Yes

### Type signatures

```swift
// MARK: Features/Authentication/Services/BiometricEnablementModel.swift (new)

@MainActor
@Observable
internal final class BiometricEnablementModel {

    enum EnablementState: Equatable {
        case idle
        case inProgress
        case succeeded
        case failed(String)   // localised message; not logged
    }

    private(set) var state: EnablementState = .idle

    init(authenticator: any BiometricAuthenticating, preference: any BiometricUnlockPreferring)

    // Calls authenticator.authenticate(reason:).
    // .success        → preference.biometricUnlockEnabled = true; state = .succeeded
    // .userCancelled / .systemCancelled → state = .idle (silent)
    // .failed / .lockedOut / .unavailable / .userFallback → state = .failed(message)
    // Sets state = .inProgress before the await; always leaves a terminal state on return.
    func enable() async

    func reset()   // state = .idle
}

// MARK: Features/Authentication/Services/AuthenticationService.swift (modified)

// Existing init gains a third parameter (default keeps existing behaviour):
init(
    repository: any AuthenticationRepository,
    sessionManager: SessionManager,
    biometricAuthenticator: any BiometricAuthenticating = LocalAuthenticationService()
)

// Replaces checkBiometricAvailability(); reads from biometricAuthenticator:
internal func refreshBiometricAvailability()
// Sets isBiometricAvailable = biometricAuthenticator.isAvailable
// Sets biometricType derived from biometricAuthenticator.biometryType
// Called from init() Task and handleAuthSuccess (all existing call sites of checkBiometricAvailability).

// MARK: Features/Authentication/Services/FakeBiometricAuthenticator.swift (modified)

// Add (previously biometryTypeName was hardcoded "Face ID"):
var stubbedBiometryTypeName: String    // default = stubbedBiometryType.displayName
var biometryTypeName: String { stubbedBiometryTypeName }

// MARK: Features/Authentication/Views/BiometricSetupView.swift (modified)

// Accept model as a parameter (caller creates it):
init(model: BiometricEnablementModel, onComplete: ((Bool) -> Void)? = nil)
// enableBiometric() path: await model.enable(); call onComplete(model.state == .succeeded); dismiss if terminal
// onComplete(false) on skip — unchanged
// Must not read Keychain; must not call authService.setupBiometrics

// MARK: ChristmasTrackerApp.swift (modified)

// AuthenticationService init gains biometricAuthenticator (share LocalAuthenticationService() already created for LockCoordinator):
let localAuth = LocalAuthenticationService()
let lkCoord = LockCoordinator(lockController: lc, biometricAuthenticator: localAuth)
let auth = AuthenticationService(repository: ..., sessionManager: sm, biometricAuthenticator: localAuth)

// Sheet presentation creates the model:
BiometricSetupView(
    model: BiometricEnablementModel(
        authenticator: localAuth,
        preference: preference
    ),
    onComplete: { enabled in
        preference.biometricSetupOfferShown = true
        preference.biometricUnlockEnabled = enabled
        lockController.preference = preference
    }
)
```

### Acceptance criteria

1. After `model.enable()` with a fake returning `.success`, `model.state == .succeeded` and `preference.biometricUnlockEnabled == true`.
2. After `model.enable()` with `.userCancelled` or `.systemCancelled`, `model.state == .idle` and preference is unchanged.
3. After `model.enable()` with `.failed`, `.lockedOut`, `.unavailable`, or `.userFallback`, `model.state` is `.failed(...)` and preference is unchanged.
4. `model.reset()` sets `state = .idle` from any terminal state.
5. `AuthenticationService` constructed with a fake authenticator where `stubbedIsAvailable = false` → `service.isBiometricAvailable == false` after init.
6. `AuthenticationService.refreshBiometricAvailability()` with a fake returning `.touchID` → `service.biometricType == .touchID`.
7. `FakeBiometricAuthenticator` with `stubbedBiometryTypeName = "Touch ID"` → `biometryTypeName == "Touch ID"`.
8. `BiometricSetupView.enableBiometric()` calls `model.enable()` and does not read the Keychain or call `setupBiometrics` — verified by code review.

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricEnablementModel.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricEnablementModelTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/BiometricSetupView.swift`
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/AuthenticationServiceTests.swift`

---

## Rework 2 Gate 1: Story R6 — Automatic biometric prompt and Face ID usage key

### Defects addressed

**B3 (no auto-prompt):** The lock screen appears but never automatically requests Face ID/Touch ID. The user must tap the button. Fix: on `LockView.onAppear`, if conditions allow, attempt biometrics automatically — once per lock event.

**B4 (missing usage key):** `NSFaceIDUsageDescription` is likely absent from Info.plist; the system may kill the app when it first requests Face ID without the key. Fix: add the key; extend `scripts/check-config.sh` to verify it.

### New interface: No new protocol; new pure function only

### Type signatures

```swift
// Pure function (can live in LockView.swift):
internal nonisolated func shouldAutoAttemptBiometrics(
    isAvailable: Bool,
    preferenceEnabled: Bool,
    isPasswordOnly: Bool,
    alreadyAttempted: Bool,
    appIsActive: Bool
) -> Bool
// Returns true iff all five conditions are satisfied (isAvailable && preferenceEnabled
// && !isPasswordOnly && !alreadyAttempted && appIsActive).

// LockView.swift (modified):
// Add: @State private var hasAutoAttempted: Bool = false
// Add: @Environment(\.scenePhase) private var scenePhase
// In .onAppear:
//   guard shouldAutoAttemptBiometrics(
//       isAvailable: biometricAuthenticator.isAvailable,
//       preferenceEnabled: controller.preference?.biometricUnlockEnabled ?? false,
//       isPasswordOnly: showPasswordOnly,
//       alreadyAttempted: hasAutoAttempted,
//       appIsActive: scenePhase == .active
//   ) else { return }
//   hasAutoAttempted = true
//   Task { await attemptBiometricUnlock() }

// Info.plist (modified):
// Add: <key>NSFaceIDUsageDescription</key>
//      <string>Use Face ID to unlock Christmas Tracker.</string>

// scripts/check-config.sh (modified):
// After the existing checks, add a grep-based check that NSFaceIDUsageDescription
// exists in ChristmasTracker/ChristmasTracker/Info.plist; fail if missing.
```

### Acceptance criteria (truth table for `shouldAutoAttemptBiometrics`)

| isAvailable | preferenceEnabled | isPasswordOnly | alreadyAttempted | appIsActive | result |
|---|---|---|---|---|---|
| true | true | false | false | true | true |
| false | true | false | false | true | false |
| true | false | false | false | true | false |
| true | true | true | false | true | false |
| true | true | false | true | true | false |
| true | true | false | false | false | false |

7. `NSFaceIDUsageDescription` present in Info.plist — verified by code review and `check-config.sh`.
8. `scripts/verify.sh` passes with the new check in place.

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LockAutoAttemptTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/App/LockView.swift`
- `ChristmasTracker/ChristmasTracker/Info.plist`
- `scripts/check-config.sh`

---

## Rework 2 Gate 1: Story R7 — Loading state, error alert, biometric login removal, remember-email, no token persistence

### Defects addressed

**B5 (`isLoading` never reset on failure):** `login()`, `loginWithBiometric()`, and `forgotPassword()` set `isLoading = true` and have no `defer`; on the error paths the flag stays `true` permanently. Fix: `defer { isLoading = false }` in all four mutating methods.

**B6 (error alert never clears):** `LoginView` uses `.alert("Error", isPresented: .constant(authService.error != nil))`; the OK tap does nothing because `.constant` is read-only. Fix: add `clearError()` to `AuthenticationService`; use a proper `@State var showError` binding that calls `clearError()` on dismiss.

**B7 (legacy Face ID sign-in button):** `BiometricOptionView` ("Sign in with Face ID") in `LoginView.contentView` uses the legacy Keychain token flow that I2b-2 is redesigning. Fix: remove it from the view body. I2b-2 reinstates it via the new flow.

**B8 ("Remember me" persists tokens):** "Remember me" means persist `auth.tokens` and `auth.refresh_token` to the Keychain and silently restore on next launch. This is I2b-2's concern (token persistence, Keychain redesign). Fix: "Remember me" becomes remember-email-only; `storeTokens` is never called; `loadStoredSession` is replaced with a one-time legacy key cleanup; repository always receives `rememberMe: true` (the one permitted networking change).

### New interface: Yes (`RememberedEmailStoring`)

### Type signatures

```swift
// MARK: Features/Authentication/Services/RememberedEmailStoring.swift (new)

internal protocol RememberedEmailStoring {
    var rememberedEmail: String? { get set }
}

internal struct RememberedEmailStore: RememberedEmailStoring {
    static let key = "login.rememberedEmail"

    init(defaults: UserDefaults = .standard)

    // Reads and writes UserDefaults key "login.rememberedEmail".
    // Setting nil removes the key.
    var rememberedEmail: String? { get set }
}

// MARK: Features/Authentication/Services/AuthenticationService.swift (modified)

// login() signature: rename rememberMe → rememberEmail (default false)
func login(email: String, password: String, rememberEmail: Bool = false) async
// - defer { isLoading = false }
// - passes rememberMe: true to authRepository.login (always, regardless of rememberEmail)
// - does NOT log the email string anywhere in the method body

// loginWithBiometric()
// - defer { isLoading = false }

// forgotPassword()
// - defer { isLoading = false }

// register()
// - add defer { isLoading = false }; remove the existing explicit isLoading = false at end

// handleAuthSuccess(authData:rememberMe:) — remove rememberMe param:
private func handleAuthSuccess(authData: AuthData) async
// - remove the `if rememberMe { storeTokens(newTokens) }` block entirely

// Add new public method:
func clearError()   // sets self.error = nil

// Replace loadStoredSession() with:
private func performLegacyKeychainCleanup()
// - Attempts to delete "auth.tokens" (keychainAuthTokensKey); ignores KeychainError.itemNotFound
// - Attempts to delete "auth.refresh_token" (keychainAuthRefreshTokenKey); ignores KeychainError.itemNotFound
// - Called once from init() Task in place of loadStoredSession()
// - storeTokens() is removed; updateTokens() no longer calls storeTokens()

// MARK: Features/Authentication/Views/LoginView.swift (modified)

// Add @State private var showError: Bool = false
// Replace .alert("Error", isPresented: .constant(authService.error != nil)) { ... }
// with    .alert("Error", isPresented: $showError) { Button("OK") { authService.clearError() } }
//         .onChange(of: authService.error) { _, e in showError = e != nil }

// Remove BiometricOptionView from contentView body (B7)

// Add @State private var rememberEmail: Bool
// Add @State private var emailStore = RememberedEmailStore()
// On appear: email = emailStore.rememberedEmail ?? ""; rememberEmail = emailStore.rememberedEmail != nil
// On successful login attempt: if rememberEmail { emailStore.rememberedEmail = email }
//                              else             { emailStore.rememberedEmail = nil }
// Rename `rememberMe` state variable → `rememberEmail`
// Call authService.login(email:password:rememberEmail:rememberEmail)
```

### Acceptance criteria

1. `service.isLoading == false` after `login()` with invalid credentials (fail path).
2. `service.isLoading == false` after `login()` with valid credentials (success path).
3. `service.isLoading == false` after `forgotPassword()` (any outcome).
4. `service.clearError()` sets `service.error` to `nil`.
5. `RememberedEmailStore` returns `nil` before any write.
6. `RememberedEmailStore` returns a stored email after a write.
7. `RememberedEmailStore` returns `nil` after the email is set to `nil`.
8. `AuthenticationService.login()` does not log the email string — verified by code and convention review.
9. `BiometricOptionView` absent from `LoginView` body — verified by code review.
10. `storeTokens` is absent from production code — verified by code review.
11. `authRepository.login(rememberMe:)` is always called with `true` — verified by code review.

### Scoped file list

**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/RememberedEmailStoring.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/RememberedEmailStoreTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginView.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/AuthenticationServiceTests.swift`
