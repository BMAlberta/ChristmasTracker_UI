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
