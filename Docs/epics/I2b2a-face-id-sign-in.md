# I2b-2a: Face ID / Touch ID sign-in
Track: iOS. Depends on: I2b-1 (merged). Blocks: I2b-2b (registration code and the generated-client mapping, after the contract sync).
Contract state: PRE-CONFORMANCE (no networking or API model changes; the existing refresh call is used as is, and the mock accepts it).

Why: users want a Face ID / Touch ID button on the login screen. Decision A7: biometric login is local only; the biometric releases a Keychain-stored refresh token (protected with .biometryCurrentSet), which the app sends to POST /auth/refresh instead of a password. No password is ever stored.

Server facts (from the API chat, verified in its code): POST /auth/logout revokes the chain of the refresh token it receives from a cookie or a JSON body field "refreshToken"; with neither it is a no-op that returns 200. iOS must therefore never send the refresh token in the logout request and must keep cookie handling disabled (I1 owns the URLSession configuration). Refresh: POST /auth/refresh with {refreshToken} in the body and X-Client-Platform: ios returns {user, accessToken, expiresIn: 900, refreshToken}; the new refresh token must be stored before use every time (rotation, A4); the old token stays valid for a 45-second grace window and replaying it afterwards revokes the whole chain, so refresh is single-flight. Any 401 from refresh (REFRESH_TOKEN_EXPIRED after 7 days idle or the 90-day cap, REFRESH_TOKEN_INVALID for an unknown or replayed token) means: show the password screen. 426 is also possible on refresh. The server session stays live after an iOS logout until the token expires.

Requirements
1. The login screen shows a biometric button when the device has biometric hardware (Face ID or Touch ID).
2. If the hardware is present but not usable (no device passcode, no face or finger enrolled in iOS, Face ID turned off for this app, or the system has locked biometrics out), tapping it explains the problem and offers "Open Settings" (the app's settings page; the message also says to check Face ID & Passcode in Settings).
3. If it is usable but nobody is enrolled for this app on this device, tapping it says to sign in with the password first and that Face ID can then be turned on; the next successful password login presents the biometric enablement screen even if the offer was declined before.
4. If it is usable and a user is enrolled, tapping it prompts for the face or finger once and signs that user in with the stored refresh token. On a cold launch with an enrolled user, the prompt starts once by itself (once per app launch), with the button for retries.
5. Enablement (the enablement screen after a login, or the Profile toggle) stores the current session's refresh token behind the biometric.

Decisions
- Password login is always available and unchanged. No password is stored.
- One enrollment per device, belonging to the user who enabled it. The Keychain item holds the refresh token (access control: biometryCurrentSet, accessible only when a passcode is set, this device only) and carries the enrolled user's id and first name as non-secret attributes on the same item. Reading those attributes, and testing whether an enrollment exists, must NEVER prompt (attributes-only query, no data returned, no authentication UI).
- The enabler keeps Face ID. Another user's password login never replaces or removes the enrollment, receives no enablement offer, has a disabled Profile toggle with the text "Face ID is set up for another account on this device.", and has a lock screen that offers only "Use password".
- The enrollment is kept across explicit logout, the lock's "Use password", teardown for every reason, and other users signing in.
- The enrollment is deleted only when: the enabler turns Face ID off in Profile while signed in as themselves; a refresh with the stored token fails with a CREDENTIAL failure (see below) for the enrolled user's own session or sign-in (then the password screen appears with no error text, per A7); iOS invalidates the item (biometric set changed). Never delete another user's enrollment. Network errors, 429, 5xx, and 426 are NOT credential failures: the enrollment and the session are kept and a neutral message is shown.
- Credential failure classification: one pure, nonisolated function over AuthenticationError returning true for invalidRefreshToken, sessionExpired, and invalidCredentials (the existing hand-written mapping turns a 401 into invalidCredentials; I2b-2b and I1 replace the mapping with the real error codes), false for everything else.
- After a password login by the SAME user who is enrolled, the stored token is replaced silently with the new session's token. After a password login by the user who previously enrolled on this device but whose token was lost, re-enroll silently (no screen) when the device is ready and they had turned Face ID on. Otherwise the enablement screen is offered once per user (and again when they tap the login button as in requirement 3).
- Token rotation: after EVERY successful refresh for the enrolled user, store the new refresh token in the Keychain item before it is used again (delete and add; this never prompts).
- Single-flight refresh: refreshTokenIfNeeded and the Face ID sign-in share one coalescing mechanism, so concurrent refreshes with the same token share one repository call.
- Logout: local teardown FIRST (the user is signed out immediately, and logout works offline), then a best-effort, non-awaited call to the repository's logout. The server call must never delay or block the local sign-out. The request carries no body (verified by a test, see S2). The enrollment is not touched by logout.
- The login button shows the enrolled user's first name under it ("Signs in <first name>") when an enrollment exists.
- Button style: icon plus text below the Sign In button ("Sign in with Face ID" or "Sign in with Touch ID"). A trailing icon in the field is a later theme task.

Non-goals: registration code and the generated-client mapping (I2b-2b), any networking or API model change, cookie configuration (I1), a dedicated server biometric credential (decision A9, after build 1), removing the dead biometricLogin repository method, remote configuration, the privacy cover.

Acceptance
- The state table in the Requirements section is implemented and unit-tested through pure functions and fakes.
- A Face ID sign-in costs exactly one system prompt (no separate LAContext evaluation followed by a Keychain read).
- Enrollment rules, rotation sync, single-flight, failure classification, and deletion rules are unit-tested with fakes.
- Logout signs out locally without waiting for the server call; the logout request has no body.
- The lock offers biometric unlock only to the enrolled user; the Profile toggle follows the same rule and is never stale.
- scripts/verify.sh is green before and after each commit. No change under contract/, .claude/, the synced Docs files, any .pbxproj, Core/Networking, the repository protocol, or API models.

---

## Inventory

All file references read from master code (HEAD before the first story commit). Line numbers are approximate and reflect the state of the code at the time of the inventory.

### KeychainService — `Core/Security/KeychainService.swift`

| Key or method | Location | Notes |
|---|---|---|
| `KeychainService.set(_:for:accessControl:)` | Line 40 | Synchronous; supports `.afterFirstUnlock` and `.biometry` (uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `.biometryCurrentSet`) |
| `KeychainService.get(_:)` | Line 77 | Synchronous, no prompt |
| `KeychainService.getWithBiometric(_:reason:)` | Line 102 | async; calls `canEvaluatePolicy` then `evaluatePolicy` THEN `get` — **two prompts**. This is the method deleted by S1. |
| `KeychainService.delete(_:)` | Line 122 | Synchronous |
| `KeychainService.clear()` | Line 137 | Clears all generic-password items |

**Key names used in production code:**

| Key string | Constant | File/line | Used for |
|---|---|---|---|
| `"auth.biometric_token"` | `keychainBiometricTokenKey` | AuthenticationService.swift:34 | Legacy: biometric-gated refresh token |
| `"auth.user_id"` | `keychainBiometricUserIdKey` | AuthenticationService.swift:35 | Legacy: enrolled user id (no access control) |
| `"auth.tokens"` | `keychainAuthTokensKey` | AuthenticationService.swift:37 | Legacy: tokens object (unused in current code, cleaned up by LegacyTokenCleanup) |
| `"auth.refresh_token"` | `keychainAuthRefreshTokenKey` | AuthenticationService.swift:38 | Legacy: refresh token (unused, cleaned up by LegacyTokenCleanup) |

**Note:** `LegacyTokenCleanup` (LegacyTokenCleaning.swift:11-14) currently deletes only `"auth.tokens"` and `"auth.refresh_token"`. It does NOT yet delete `"auth.biometric_token"` or `"auth.user_id"`. S1 extends this.

### BiometricUnlockPreference readers/writers

| File/line | What it does |
|---|---|
| `BiometricUnlockPreference.swift` | Protocol `BiometricUnlockPreferring` + struct; keys `"biometricUnlock.enabled"` and `"biometricUnlock.offerShown"` |
| `ChristmasTrackerApp.swift:95` | `@State private var preference = BiometricUnlockPreference()` — app-level instance |
| `ChristmasTrackerApp.swift:150` | `lc.preference = BiometricUnlockPreference()` — lock controller gets its own instance |
| `ChristmasTrackerApp.swift:249` | `!preference.biometricSetupOfferShown && authService.isBiometricAvailable` — first-login offer guard (single global flag; S3 replaces with per-user markers) |
| `ChristmasTrackerApp.swift:263–265` | `preference.biometricSetupOfferShown = true; preference.biometricUnlockEnabled = enabled; lockController.preference = preference` — written after offer |
| `LockView.swift:96` | `controller.preference?.biometricUnlockEnabled ?? false` — auto-attempt guard |
| `LockView.swift:131` | `controller.preference?.biometricUnlockEnabled ?? true` — button visibility guard (note: different default than line 96) |
| `ProfileView.swift:17–22` | `@State private var toggleModel = ProfileBiometricToggleModel(preference: BiometricUnlockPreference(), enablementModel: ...)` — created once at view init; known bug: stale after first-login offer |
| `ProfileBiometricToggleModel.swift:28` | `self.isEnabled = preference.biometricUnlockEnabled` — read once at init |
| `ProfileBiometricToggleModel.swift:43,52` | Writes `preference.biometricUnlockEnabled` on toggle OFF/ON |
| `BiometricEnablementModel.swift:42` | Writes `preference.biometricUnlockEnabled = true` on success |

**S3 bug to fix:** `ProfileView` creates `toggleModel` once at `@State` declaration — the enablement state from the first-login offer sheet never updates the already-created toggle model, so the toggle shows OFF after the offer succeeds.

### LockView and InactivityLockController use of preference

- `InactivityLockController.swift:43` — `var preference: (any BiometricUnlockPreferring)?` — optional property set from outside
- `LockView.swift:96, 131` — reads `controller.preference?.biometricUnlockEnabled`; note inconsistent defaults (false vs true)
- S3 replaces the device-level preference with a closure-backed eligibility rule (enrolled user id == signed-in user id)

### AuthenticationService token handling

| Method | Line | Notes |
|---|---|---|
| `tokens` | 32 | `private var tokens: AuthTokens?` — in-memory only |
| `handleAuthSuccess(authData:)` | 247 | Sets `currentUser`, `isAuthenticated`, builds `AuthTokens`, calls `sessionManager.startSession()` |
| `updateTokens(authData:)` | 265 | Rebuilds `AuthTokens` from `AuthData`; called by `refreshTokenIfNeeded` |
| `refreshTokenIfNeeded()` | 180 | Checks `tokens.needsRefresh`; calls `authRepository.refreshToken`; on failure calls `logout(.sessionExpired)` — no enrollment cleanup |
| `logout(reason:)` | 159 | **Wrong order**: calls repository logout FIRST (awaits), THEN `sessionManager.teardown` + `clearAuthState()`. S2 fixes to local-first. |
| `clearStoredTokens()` | 280 | Deletes all four legacy Keychain keys — **incorrectly deletes** `keychainBiometricTokenKey` and `keychainBiometricUserIdKey`; S1 fixes |
| `setupBiometrics(biometricToken:)` | 202 | Dead (S1 deletes) |
| `loginWithBiometric()` | 121 | Dead: calls `KeychainService.getWithBiometric` (two prompts) + `authRepository.biometricLogin` (server endpoint). S1 deletes. |

### BiometricSetupView and BiometricEnablementModel

- `BiometricEnablementModel.swift` — `@MainActor @Observable`; `enable()` calls `authenticator.authenticate(reason:)` only (no Keychain); sets `preference.biometricUnlockEnabled = true` on success. S1 reuses for the LAContext evaluation; S2/S3 add token storage.
- `BiometricSetupView.swift` — accepts `BiometricEnablementModel`, calls `model.enable()`; `onComplete: ((Bool) -> Void)?`. S3 adds token storage to `enable()`.

### ProfileBiometricToggleModel and ProfileView

- `ProfileBiometricToggleModel.swift` — `isEnabled` initialized from `preference.biometricUnlockEnabled` at init (line 28); `toggle(to:)` calls `enablementModel.enable()` on ON. Known bug: stale initial state if enrollment changes while view is live.
- `ProfileView.swift:16–22` — `@State private var toggleModel` created once at declaration; this is the root of the stale-toggle bug.
- `ProfileView.swift:67` — `.task { authService.refreshBiometricAvailability() }` — refreshes availability on appear.

### First-login enablement screen (ChristmasTrackerApp.swift)

- `ChristmasTrackerApp.swift:245–268` — `.onChange(of: authService.isAuthenticated)`: on `true`, starts the lock controller and shows `BiometricSetupView` if `!preference.biometricSetupOfferShown && authService.isBiometricAvailable`. Single global offer flag — S3 replaces with per-user markers.

### MockAuthenticationRepository

- `MockAuthenticationRepository.swift:10–120` — actor; uses a single hardcoded `mockUser` ("mock-user-123", "test@example.com", "Test User") for all emails; `refreshToken` always returns the same `mockRefreshToken` (no rotation). `fail@example.com` throws `invalidCredentials`. S1 replaces with per-email stable users and rotating tokens.

### NetworkAuthenticationRepository

- `NetworkAuthenticationRepository.swift:117–136` — `logout(refreshToken:)` sends POST `/auth/logout` with `.none` body (correct). Has a dead private `LogoutRequest` struct (lines 120–122) that is defined but never used. S2 deletes it.
- `NetworkAuthenticationRepository.swift:82–98` — `refreshToken` sends POST `/auth/refresh` with `RefreshTokenRequest(refreshToken:)` body (correct).

### User model — name field

- `User.swift:14` — `let name: String` (full name). There is no `firstName` field. First name is derived at enrollment time as `name.components(separatedBy: " ").first ?? name`.

---

## Gate 1: Story S1 — Credential Store, Readiness, and the Mock

### Contract slice
No network or API model changes. Keychain operations only (new key, new protocol). Mock behavior change is test-only.

### New interfaces introduced
- `BiometricReadiness` enum + `nonisolated` mapping functions (`biometricReadiness(for:biometryPresent:)` and `biometricReadinessMessage(for:biometryTypeName:)`)
- `BiometricAuthenticating` protocol extension: `var readiness: BiometricReadiness { get }` added to the protocol; `LocalAuthenticationService` implements it; `FakeBiometricAuthenticator` gains `var stubbedReadiness: BiometricReadiness`
- `BiometricCredentialStoring` protocol with `enrolledUser() -> (userId: String, firstName: String)?`, `enroll(refreshToken:userId:firstName:) throws`, `readRefreshToken(reason:) async throws -> String`, `updateRefreshToken(_:) throws`, `delete() throws`; associated error enum `BiometricCredentialError`
- `KeychainBiometricCredentialStore: BiometricCredentialStoring` — thin real implementation over Security framework; new Keychain key `"biometric.credential.v1"` (distinct from all legacy keys)
- `InMemoryBiometricCredentialStore: BiometricCredentialStoring` — in-memory fake for tests
- `MockAuthenticationRepository` updated: stable per-email user and rotating tokens (no new protocol surface)

### Acceptance criteria
1. `biometricReadiness(for:biometryPresent:)` correctly maps every `LAError` code and `biometryType == .none` to the enum cases.
2. `biometricReadinessMessage(for:biometryTypeName:)` returns the correct user-facing message and `opensSettings` flag for each case.
3. `enrolledUser()` on the in-memory store returns `nil` before enroll and `(userId, firstName)` after.
4. `enroll` replaces any existing enrollment.
5. `updateRefreshToken` preserves the user attributes and updates the token.
6. `delete()` leaves the store empty.
7. `clearStoredTokens`-equivalent logic (deleting the legacy keys) leaves the new enrollment key untouched.
8. The mock produces a stable user per email, issues a fresh refresh token on every `refreshToken` call, rejects malformed tokens and tokens for `expired@example.com`, and accepts tokens from a "previous mock instance" (parse-not-state-based).
9. All tests pass with fakes only — no real LAContext, no real Keychain.

### Scoped file and folder list
**New:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricReadiness.swift`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricCredentialStoring.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricReadinessTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/BiometricCredentialStoreTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/MockAuthenticationRepositoryTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricAuthenticating.swift` — add `readiness` to protocol + `LocalAuthenticationService` impl
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FakeBiometricAuthenticator.swift` — add `stubbedReadiness`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LegacyTokenCleaning.swift` — extend cleanup to also delete `"auth.biometric_token"` and `"auth.user_id"`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` — delete `setupBiometrics` and `loginWithBiometric`; fix `clearStoredTokens` to not delete the new enrollment key; keep `keychainBiometricTokenKey` and `keychainBiometricUserIdKey` constants for legacy cleanup only
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/MockAuthenticationRepository.swift` — per-email stable user, rotating tokens
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/AuthenticationServiceTests.swift` — update tests that relied on `loginWithBiometric` or `setupBiometrics` (if any)

**New interface: Yes** → full pipeline (test-writer → implementer → both reviewers)

---

## Gate 1: Story S2 — Sign-In Flow, Single-Flight Refresh, and Logout Order

### Contract slice
No network or API model changes. `AuthenticationService` changes only (new methods, modified logout and refresh). `NetworkAuthenticationRepository` dead-struct deletion. `LoginView` new biometric button (UI only, not unit-tested). `LockView` unchanged.

### New interfaces introduced
- `AuthenticationService.signInWithBiometric() async` — new async method
- `AuthenticationService` gains `BiometricCredentialStoring` dependency (injected, default `KeychainBiometricCredentialStore()`)
- Internal coalescing function for single-flight refresh (private to `AuthenticationService`)
- `LoginView` biometric button: pure function `loginBiometricButtonState(readiness:enrolledUser:) -> LoginBiometricButtonState` (nonisolated) where `LoginBiometricButtonState` is an enum (`hidden`, `showNotEnrolled`, `showNeedsSetup(message:opensSettings:)`, `showEnrolled(firstName:)`)
- `LoginView` auto-prompt: pure function `shouldAutoAttemptBiometricLogin(readiness:hasEnrolledUser:alreadyAttemptedThisLaunch:appIsActive:) -> Bool` (nonisolated)
- Credential failure classification: `isCredentialFailure(_ error: AuthenticationError) -> Bool` (nonisolated free function)
- Pending enablement request flag: stored on `AuthenticationService` (in-memory, consumed by next successful login)

### Acceptance criteria
1. `signInWithBiometric()` reads the token with `readRefreshToken`, calls the single-flight refresh, runs `handleAuthSuccess`, and immediately calls `updateRefreshToken` with the new token before returning.
2. Each failure outcome (success, userCancelled, biometricFailed, lockedOut, itemNotFound/invalidated, credentialFailure, networkError) is mapped to the correct UI state; `isLoading` resets on every path.
3. A credential failure during biometric sign-in deletes the enrollment and shows the password screen with no error text.
4. Network errors, 429, 5xx, and 426-style errors keep both the enrollment and the session.
5. `logout(reason:)` performs local teardown FIRST (clears state, calls `sessionManager.teardown`) before starting a non-awaited Task for the repository logout call.
6. The logout request carries no body — a test using a spy `APIClient` pins this.
7. `refreshToken` sends only the `refreshToken` field in the body — same spy test.
8. After a successful refresh for the enrolled user, `updateRefreshToken` is called before the tokens are used.
9. A credential failure in `refreshTokenIfNeeded` for the enrolled user ends the session and deletes only that user's enrollment.
10. Network failures in `refreshTokenIfNeeded` leave the session and enrollment in place.
11. Single-flight: two concurrent callers with the same refresh token share one repository call.
12. `isCredentialFailure` returns true for `invalidRefreshToken`, `sessionExpired`, `invalidCredentials`; false for all others.
13. The button-state function covers all readiness + enrolled combinations.
14. The auto-prompt truth table (all combinations of readiness, hasEnrolledUser, alreadyAttempted, appIsActive).
15. A pending enablement request is consumed by the next successful password login.

### Scoped file and folder list
**New:**
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SignInWithBiometricTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/NetworkAuthRepositoryRequestTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LoginBiometricButtonTests.swift`

**Modified:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` — `signInWithBiometric`, single-flight coalescing, `logout` order fix, `refreshTokenIfNeeded` enrollment sync, inject `BiometricCredentialStoring`
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginView.swift` — biometric button, auto-prompt, pending enablement
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/NetworkAuthenticationRepository.swift` — delete dead `LogoutRequest` struct only
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/AuthenticationServiceTests.swift` — update logout test for new order

**New interface: Yes** → full pipeline

---

## Gate 1: Story S3 — Enrollment Rules, Profile Toggle, and Lock Eligibility

### Contract slice
No network or API model changes. `AuthenticationService` gains enrollment methods. `BiometricEnablementModel`, `ProfileBiometricToggleModel`, `InactivityLockController`, and `LockView` are updated for credential-store-based eligibility. `ChristmasTrackerApp` offer logic is simplified.

### New interfaces introduced
- `AuthenticationService.enrollCurrentSession() async throws` — calls `biometricAuthenticator.authenticate(reason:)`, then on success calls `credentialStore.enroll(refreshToken:userId:firstName:)` with the current session token and user. Actor-isolated; manual SentrySDK span required.
- `AuthenticationService.revokeEnrollment() throws` — calls `credentialStore.delete()`. (Explicit method so the toggle and tests can call it cleanly.)
- `AuthenticationService.enrolledUser: (userId: String, firstName: String)?` — computed, forwarded from `credentialStore.enrolledUser()`. Nonisolated; no prompt. `@MainActor` read is safe.
- `AuthenticationService.enrolledUserMatchesSession: Bool` — computed: `enrolledUser?.userId == currentUser?.id`.
- `InactivityLockController` — replace `var preference: (any BiometricUnlockPreferring)?` with `var biometricEligibility: (() -> Bool)?`; `LockView` reads this closure instead of the preference. `ChristmasTrackerApp` wires it as `{ authService.enrolledUserMatchesSession }`.
- `BiometricEnablementModel.enable()` — updated signature: inject `enrollAction: () async throws -> Void` (called after LA succeeds) so the model stays testable without a real `AuthenticationService`. The existing LAContext authentication call (`authenticator.authenticate`) moves to `AuthenticationService.enrollCurrentSession` (it already has the authenticator); the model's `enable()` becomes: guard enrolled ≠ self, then call `enrollAction()`. Alternatively simpler: inject `authService: AuthenticationService` directly and call `authService.enrollCurrentSession()` after the existing authenticate step — pick the simpler approach that keeps the model testable with fakes.

### Acceptance criteria
1. `enrollCurrentSession()` calls `biometricAuthenticator.authenticate(reason:)` before storing the token; throws if authentication fails.
2. `enrollCurrentSession()` stores the current `tokens.refreshToken` with `credentialStore.enroll(refreshToken:userId:firstName:)` where `firstName` is `currentUser?.name.components(separatedBy:" ").first ?? ""`.
3. `enrollCurrentSession()` does nothing (no-op, no throw) when `tokens` is nil or `currentUser` is nil.
4. `revokeEnrollment()` calls `credentialStore.delete()`.
5. `enrolledUser` returns nil when no enrollment; returns the credential store pair when enrolled.
6. `enrolledUserMatchesSession` returns `true` when enrolled userId == `currentUser?.id`, `false` otherwise, and `false` when either is nil.
7. After a successful password login where the enrolled user matches the session user, `updateRefreshToken` is called with the new token (silent rotation — no offer shown to that user, `shouldShowBiometricEnablementAfterLogin` stays false for a session where enrollment already exists).
8. After a password login by a user who is NOT enrolled and no pending enablement request was set, `shouldShowBiometricEnablementAfterLogin` stays false.
9. `InactivityLockController.biometricEligibility` closure drives the lock screen biometric option: LockView shows the biometric button only when the closure returns `true`.
10. `ProfileBiometricToggleModel` reads `enrolledUserMatchesSession` from `AuthenticationService` (not from `BiometricUnlockPreference`) to set initial `isEnabled` state; the model is not stale after the first-login offer sheet closes.
11. When `enrolledUser != nil` and `enrolledUser?.userId != currentUser?.id`, the Profile toggle is disabled and shows "Face ID is set up for another account on this device."
12. `BiometricEnablementModel.enable()` calls `enrollCurrentSession()` (or the injected `enrollAction`) after user confirmation; on success sets `isComplete = true`; on failure sets the error.
13. First-login offer in `ChristmasTrackerApp` uses `authService.shouldShowBiometricEnablementAfterLogin` as the trigger; the `preference.biometricSetupOfferShown` flag is removed from this guard.
14. All tests pass with fakes; no real Keychain, no real LAContext.

### Scoped file and folder list
**New:**
- `ChristmasTrackerTests/Features/Authentication/EnrollCurrentSessionTests.swift`
- `ChristmasTrackerTests/Features/Authentication/LockEligibilityTests.swift`
- `ChristmasTrackerTests/Features/Authentication/ProfileToggleEnrollmentTests.swift`

**Modified:**
- `ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` — add `enrollCurrentSession()`, `revokeEnrollment()`, `enrolledUser`, `enrolledUserMatchesSession`; fix `handleAuthSuccess` for silent token rotation when enrolled user matches
- `ChristmasTracker/Features/Authentication/Services/BiometricEnablementModel.swift` — call `enrollCurrentSession()` (or injected action) after LA success; remove preference write
- `ChristmasTracker/Features/Authentication/ViewModels/ProfileBiometricToggleModel.swift` — read enrollment state from `AuthenticationService`; fix stale initial state
- `ChristmasTracker/Features/Authentication/Views/ProfileView.swift` — pass `authService` to `ProfileBiometricToggleModel` (or observe it); fix stale `@State` init
- `ChristmasTracker/Features/Lock/InactivityLockController.swift` — replace `preference` with `biometricEligibility: (() -> Bool)?`
- `ChristmasTracker/Features/Lock/LockView.swift` — replace `controller.preference?.biometricUnlockEnabled` with `controller.biometricEligibility?() ?? false`
- `ChristmasTracker/ChristmasTrackerApp.swift` — wire `biometricEligibility` closure; use `authService.shouldShowBiometricEnablementAfterLogin` for the offer guard; remove `preference.biometricSetupOfferShown` from the offer condition

**New interface: Yes** → full pipeline (touches biometrics, auth, UI eligibility)

---

## Gate 1: Story S4 — Report and Handoff

*(docs only; no Gate 1 spec needed)*

---

## Rework Gate 1: Story R1 — Observable Enrollment State, Store Hardening, and Sign-in Outcomes

### Contract slice
No network or API model changes. Changes are entirely within `AuthenticationService`, `BiometricCredentialStoring.swift`, and the sign-in test suite. `LoginView.swift` loses the misplaced `isCredentialFailure` free function (moved to services).

### New interfaces introduced

**`BiometricSignInState` enum** (new file `Authentication/Services/BiometricSignInState.swift`):
```swift
internal enum BiometricSignInState: Equatable {
    case idle
    case retryHint(String)
    case passwordOnly(String)
    case passwordRequired
    case neutralError(String)
}
```

**`biometricSignInOutcome(for:biometryTypeName:)` pure nonisolated function** (same file):
Maps a `BiometricCredentialError` to `(state: BiometricSignInState, deleteEnrollment: Bool, refreshSnapshot: Bool)`.
Maps an `AuthenticationError` to the same tuple (via `isCredentialFailure`).
Two separate overloads, or one with an enum discriminant — pick what tests naturally.

Mapping table:
- `BiometricCredentialError.userCancelled` → `.idle`, delete=false, refresh=false
- `BiometricCredentialError.biometricFailed` → `.retryHint("{biometryTypeName} didn't recognize you. Try again or use your password.")`, delete=false, refresh=false
- `BiometricCredentialError.lockedOut` → `.passwordOnly("Biometrics are locked. Use your password to continue.")`, delete=false, refresh=false
- `BiometricCredentialError.itemNotFound` or `.itemInvalidated` → `.idle`, delete=true, refresh=true
- `BiometricCredentialError.other` → `.neutralError("Couldn't sign in. Try again or use your password.")`, delete=false, refresh=false
- `AuthenticationError` with `isCredentialFailure == true` → `.passwordRequired`, delete=true, refresh=true
- `AuthenticationError` with `isCredentialFailure == false` → `.neutralError("Couldn't sign in. Try again or use your password.")`, delete=false, refresh=false

**`isCredentialFailure` moved** from `LoginView.swift` to `Authentication/Services/` (same file as `BiometricSignInState` or standalone). Declaration stays `internal nonisolated func isCredentialFailure`.

**`AuthenticationService` additions**:
- `private(set) var enrolledUserSnapshot: (userId: String, firstName: String)?` — stored observable (SwiftUI can observe changes).
- `func refreshBiometricState()` — replaces `refreshBiometricAvailability()` body: also sets `enrolledUserSnapshot = credentialStore.enrolledUser()`. Keep `refreshBiometricAvailability()` as a thin alias that calls `refreshBiometricState()` (for all existing call sites — no rename cascade needed).
- `private(set) var biometricSignInState: BiometricSignInState = .idle`
- `func clearBiometricSignInState()` — sets `biometricSignInState = .idle`
- `enrolledUser` computed property: returns `enrolledUserSnapshot` (observable read; justification: snapshot is refreshed immediately after every mutation, so views are never stale and no Keychain hit is needed in the view path).
- `enrolledUserMatchesSession` computed property: compares `enrolledUserSnapshot?.userId == currentUser?.id` (snapshot is reliable here because `refreshBiometricState()` is called at the top of `handleAuthSuccess` before `currentUser` is set, so both are updated atomically within the same `@MainActor` turn).

**`signInWithBiometric()` rewrite** (same file):
- Clear `biometricSignInState` at the start of each attempt.
- Apply the mapping to every error case; execute the side effects (delete, refresh) in the service.
- Set `biometricSignInState` on every failure path.
- After success: `biometricSignInState` stays `.idle`.
- `isLoading` defer unchanged.

**Store hardening** (`KeychainBiometricCredentialStore.enrolledUser()`):
- Create a local `LAContext`, set `context.interactionNotAllowed = true`, pass as `kSecUseAuthenticationContext`.
- Treat `errSecInteractionNotAllowed` as "not enrolled" for this call (return `nil`); do NOT delete the item.
- Verified by reading code only (Keychain behavior cannot be verified in a unit test without a real device).

### Acceptance criteria
1. `biometricSignInOutcome` mapping covers all `BiometricCredentialError` cases and both `AuthenticationError` credential/non-credential paths — pure, tested without a service instance.
2. `itemNotFound` and `itemInvalidated` produce `.idle`, `deleteEnrollment=true`, `refreshSnapshot=true`.
3. A credential `AuthenticationError` produces `.passwordRequired`, `deleteEnrollment=true`, `refreshSnapshot=true`, with no error message in the state.
4. A network `AuthenticationError` produces `.neutralError(...)`, `deleteEnrollment=false`, `refreshSnapshot=false`.
5. `userCancelled` produces `.idle` with no delete and no snapshot refresh.
6. `biometricFailed` produces `.retryHint(...)` containing the biometry type name.
7. `enrolledUserSnapshot` updates after `enrollCurrentSession`, `revokeEnrollment`, stale-item cleanup, and token rotation — without recreating the service instance.
8. `refreshBiometricAvailability()` still exists and behaves identically to before (alias).
9. `isCredentialFailure` is gone from `LoginView.swift` and present in the services folder.
10. `KeychainBiometricCredentialStore.enrolledUser()` query includes an `LAContext` with `interactionNotAllowed = true` — verified by reading code.
11. `enrolledUser` on `AuthenticationService` returns the snapshot value, not a fresh Keychain read.
12. All 388 existing tests continue to pass.

### Scoped file and folder list
**New:**
- `ChristmasTracker/Features/Authentication/Services/BiometricSignInState.swift` — enum, mapping, `isCredentialFailure`
- `ChristmasTrackerTests/Features/Authentication/BiometricSignInStateTests.swift`
- `ChristmasTrackerTests/Features/Authentication/ObservableSnapshotTests.swift`

**Modified:**
- `ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` — snapshot, `refreshBiometricState`, `biometricSignInState`, rewritten `signInWithBiometric`
- `ChristmasTracker/Features/Authentication/Services/BiometricCredentialStoring.swift` — hardened `enrolledUser()`
- `ChristmasTracker/Features/Authentication/Views/LoginView.swift` — delete `isCredentialFailure`

**New interface: Yes** → full pipeline

---

## Rework Gate 1: Story R2 — Enrollment Offer Rules

### Contract slice
No network or API model changes. `AuthenticationService` gains offer logic. `EnrollmentHistoryStoring` protocol + `UserDefaultsEnrollmentHistory` added. `ProfileBiometricToggleModel` clears previously-enrolled user on revoke. `ChristmasTrackerApp` observes `biometricOfferAction`. `BiometricUnlockPreference` and `BiometricUnlockPreferring` deleted.

### New interfaces introduced

**`BiometricOfferAction` enum** (new file `Authentication/Services/BiometricOfferAction.swift`):
```swift
internal enum BiometricOfferAction: Equatable {
    case none
    case silentlyReplaceToken
    case silentlyReenroll
    case showEnablementScreen
}
```

**`biometricOfferAction(readiness:enrolledUserId:signedInUserId:previouslyEnrolledUserId:offerShownForUser:pendingRequest:)` pure nonisolated function** (same file):
Mapping (in order of precedence):
1. `readiness != .ready` → `.none`
2. `enrolledUserId == signedInUserId` (same user is enrolled) → `.silentlyReplaceToken`
3. `enrolledUserId != nil && enrolledUserId != signedInUserId` (another user enrolled) → `.none`
4. No enrollment, `pendingRequest == true` → `.showEnablementScreen`
5. No enrollment, `previouslyEnrolledUserId == signedInUserId` → `.silentlyReenroll`
6. No enrollment, `offerShownForUser == false` → `.showEnablementScreen`
7. Otherwise → `.none`

**`EnrollmentHistoryStoring` protocol** (same file or companion):
```swift
internal protocol EnrollmentHistoryStoring: Sendable {
    var previouslyEnrolledUserId: String? { get }
    func setPreviouslyEnrolledUserId(_ userId: String?)
    func hasSeenOffer(for userId: String) -> Bool
    func markOfferShown(for userId: String)
}
```

**`UserDefaultsEnrollmentHistory`** — struct, backed by injected `UserDefaults` suite. Keys: `"enrollment.previousUserId"` and `"enrollment.offerShown.<userId>"`. Thread-safe by value semantics + main-actor callers.

**`AuthenticationService` additions**:
- Dependency: `enrollmentHistory: any EnrollmentHistoryStoring` (default: `UserDefaultsEnrollmentHistory(defaults: .standard)`)
- `private(set) var biometricOfferAction: BiometricOfferAction = .none` — observable
- In `login()` and `register()`: before calling `handleAuthSuccess`, compute the action with `biometricOfferAction(...)` using the new user from `authData` and current readiness/snapshot; set `self.biometricOfferAction`; execute silent actions immediately; always consume `pendingBiometricEnablement`. After `handleAuthSuccess` sets `isAuthenticated = true`, the action is already published.
- Remove `shouldShowBiometricEnablementAfterLogin` (or keep as `var shouldShowBiometricEnablementAfterLogin: Bool { biometricOfferAction == .showEnablementScreen }` derived property — avoids breaking ChristmasTrackerApp if it still reads it; remove usages in ChristmasTrackerApp).
- Silent re-enroll uses current `tokens.refreshToken` and `authData.user.name.components(separatedBy:" ").first`.

**`ProfileBiometricToggleModel.toggle(to: false)`**: after `revokeEnrollment()`, call `enrollmentHistory.setPreviouslyEnrolledUserId(nil)` to clear the previously-enrolled marker. The `ProfileBiometricToggleModel` needs access to `enrollmentHistory`; inject via `authService` (add `enrollmentHistoryForTesting` or expose through the service) or pass separately.

**`BiometricEnablementModel.onComplete(enabled: true)`** / success path: call `enrollmentHistory.markOfferShown(for: userId)` and `enrollmentHistory.setPreviouslyEnrolledUserId(userId)`. Pass `enrollmentHistory` to the enablement model or handle in the `onComplete` closure in `ChristmasTrackerApp`.

**`ChristmasTrackerApp`**: replace `.onChange(of: authService.isAuthenticated)` offer guard with `.onChange(of: authService.biometricOfferAction)` → `{ if newValue == .showEnablementScreen { showBiometricSetup = true } }`; in `onComplete` closure, mark offer shown and set previously enrolled user. Clear `biometricOfferAction` to `.none` after dismissal (add `clearBiometricOfferAction()` or directly set via a method).

**Delete**: `BiometricUnlockPreference.swift`, `BiometricUnlockPreferring` protocol, and `BiometricUnlockPreferenceTests.swift` (5 tests: list by name in report).

### Acceptance criteria
1. `biometricOfferAction` truth table: all 7 input combinations (R1=not ready, R2=same user enrolled, R3=other user enrolled, R4=no enroll+pending, R5=no enroll+prev user, R6=no enroll+no offer shown, R7=no enroll+offer shown+no pending) produce the right action — parameterized test.
2. Silent replace updates `credentialStore` token (no `enrollCurrentSession` prompt).
3. Silent re-enroll uses the previously-enrolled user id; a user whose credential failed is re-enrolled at next login (via the `previouslyEnrolledUserId` marker NOT being cleared by credential deletion).
4. Turning Face ID off in Profile (via `revokeEnrollment`) clears `previouslyEnrolledUserId`; that user is NOT silently re-enrolled at next login.
5. Another user's login leaves the enrollment untouched and returns `.none`.
6. The action is published BEFORE `isAuthenticated` becomes `true` — tested with a suspending repository that records publication order.
7. Offer markers survive creating a new `AuthenticationService` instance (UserDefaults persistence).
8. `showEnablementScreen` shown once per user; second login returns `.none`; a pending request overrides to `showEnablementScreen` regardless.
9. All `BiometricUnlockPreference` tests removed; `BiometricUnlockPreference.swift` deleted.
10. All 388 (minus 5 preference tests + any new tests) pass.

### Scoped file and folder list
**New:**
- `ChristmasTracker/Features/Authentication/Services/BiometricOfferAction.swift` — enum, pure function, `EnrollmentHistoryStoring`, `UserDefaultsEnrollmentHistory`
- `ChristmasTrackerTests/Features/Authentication/BiometricOfferActionTests.swift`
- `ChristmasTrackerTests/Features/Authentication/EnrollmentHistoryTests.swift`

**Modified:**
- `AuthenticationService.swift` — offer logic, `biometricOfferAction`, enrollment history dependency
- `ProfileBiometricToggleModel.swift` — clear previously-enrolled marker on revoke
- `BiometricEnablementModel.swift` — mark offer shown + set previously-enrolled in `enrollAction` closure or on success
- `ChristmasTrackerApp.swift` — observe `biometricOfferAction`, not `isAuthenticated` for offer sheet

**Deleted:**
- `BiometricUnlockPreference.swift`
- `BiometricUnlockPreferenceTests.swift`

**New interface: Yes** → full pipeline

---

## Rework Gate 1: Story R3 — The Login Screen

### Contract slice
No network or API model changes. `LoginView.swift` gains `LoginBiometricModel` view model and the biometric button, alerts, and auto-prompt. `BiometricOptionView` deleted.

### New interfaces introduced

**`LoginBiometricModel`** — `@MainActor @Observable final class` (new file or at top of `LoginView.swift`):
```swift
@MainActor @Observable internal final class LoginBiometricModel {
    // Reads from authService
    var buttonState: LoginBiometricButtonState  // derived from readiness + snapshot
    var biometricSignInState: BiometricSignInState  // from authService
    var isLoading: Bool  // from authService

    // Per-process once flag (nonisolated(unsafe) static var or a nonisolated singleton)
    // Set on first autoAttemptIfNeeded call regardless of whether the attempt runs.
    func autoAttemptIfNeeded() async  // triggers signInWithBiometric if conditions met
    func tap()  // executes action for current buttonState; records pending request if not enrolled
    // Convenience: pendingSetupMessage and opensSettings for showNeedsSetup
    var setupMessage: String?
    var setupOpensSettings: Bool
    var showSetupAlert: Bool
    var showNotEnrolledAlert: Bool
}
```

The process-once flag is `nonisolated(unsafe) private static var hasAutoAttempted: Bool = false` or a dedicated `LoginBiometricModel.shared` — pick the approach that lets the auto-attempt test reset it cleanly. Per the prompt: "not reset by logout, the lock, or teardown".

**`LoginBiometricTapAction`** (private or internal):
No separate enum needed if `tap()` directly manipulates `showSetupAlert`/`showNotEnrolledAlert` state on the model.

**`LoginView.body`** (modified):
- Below `LoginActionSection`: `BiometricButtonSection` or inline view that reads from a `@State private var biometricModel: LoginBiometricModel`.
- Biometric button: SF Symbol (`faceid` or `touchid`), text "Sign in with Face ID/Touch ID", DesignSystem tokens, min 44pt height, accessibility label and hint, hidden when `buttonState == .hidden`.
- Caption "Signs in <first name>" when `.showEnrolled(firstName:)`.
- `.disabled(authService.isLoading)`.
- Two `.alert` modifiers for setup (with "Open Settings" / "Cancel") and not-enrolled (with "OK").
- Outcome text: show `retryHint`/`passwordOnly`/`neutralError` message near the button; `passwordRequired` shows nothing.
- `.task { ... }` for appear: re-reads readiness + snapshot via `authService.refreshBiometricState()`, then calls `biometricModel.autoAttemptIfNeeded()`.
- `.onReceive` or `.onChange` on scene activation: re-reads readiness + snapshot.
- Delete `BiometricOptionView` and `DividerRow` (if DividerRow is only used by BiometricOptionView).

### Acceptance criteria
1. `LoginBiometricModel.tap()` for `.hidden` → no-op.
2. For `.showNeedsSetup(message:opensSettings:)` → sets `showSetupAlert = true`, correct message.
3. For `.showNotEnrolled` → sets `showNotEnrolledAlert = true`, calls `authService.pendBiometricEnablementRequest()`.
4. For `.showEnrolled(firstName:)` → calls `authService.signInWithBiometric()`.
5. After tapping when not enrolled + login succeeds → `biometricOfferAction == .showEnablementScreen` (end-to-end with fakes).
6. `autoAttemptIfNeeded` triggers `signInWithBiometric` exactly once per process when conditions met.
7. `autoAttemptIfNeeded` does NOT trigger when `readiness != .ready`, no enrolled user, already attempted, or inactive.
8. `biometricSignInState` changes from service are observable in the model.
9. `buttonState` updates when `enrolledUserSnapshot` changes without recreating the model.
10. `BiometricOptionView` is deleted from `LoginView.swift`.

### Scoped file and folder list
**New:**
- (Possibly) `ChristmasTrackerTests/Features/Authentication/LoginBiometricModelTests.swift`

**Modified:**
- `ChristmasTracker/Features/Authentication/Views/LoginView.swift` — `LoginBiometricModel`, body changes, delete `BiometricOptionView`

**New interface: Yes** → full pipeline

---

## Fix pass Gate 1

Eight defects (E1–E8) found during manual testing and code review after the rework. Four stories:
F1 (marker + registration + single enroll prompt), F2 (single sign-in prompt), F3 (cold-launch auto-prompt, offer presentation, display names), F4 (docs corrections). Full pipeline for F1–F3 per CLAUDE.md.

Superseded brief text — overrides everything below for the two items it covers:
- `readRefreshToken` (F2): ONE LAContext, `evaluatePolicy` once (`.deviceOwnerAuthenticationWithBiometrics`, reason string, `localizedFallbackTitle = ""`), then pass that SAME authenticated context as `kSecUseAuthenticationContext` to the Keychain query. The system then prompts exactly once (the evaluation), on the simulator and on a device.
- Auto-prompt flag (F3): the FIRST appearance of the login screen in a process consumes `hasAutoAttempted` whatever the state (not ready, not enrolled, enrolled). Logout, the lock, and teardown never re-arm it.

---

### F1 — Previously-enrolled marker, registration offer, single enroll prompt

**Defects fixed:** E1 (`enrollCurrentSession()` and silent paths never call `setPreviouslyEnrolledUserId`), E2 (`register()` has no offer logic), E4 (double biometric prompt: `BiometricEnablementModel.enable()` calls `authenticator.authenticate()` and `enrollCurrentSession()` also calls `biometricAuthenticator.authenticate()`).

**Contract slice:** Pure local changes. No networking. No new types in production code.

**Interface changes:**
- `AuthenticationService.enrollCurrentSession()`: removes the `biometricAuthenticator.authenticate()` call (authentication is now the caller's responsibility); adds `enrollmentHistory.setPreviouslyEnrolledUserId(user.id)` after `credentialStore.enroll(...)`.
- `AuthenticationService.login()` silent paths (`silentlyReplaceToken`, `silentlyReenroll`): each gains `enrollmentHistory.setPreviouslyEnrolledUserId(authData.user.id)` after `credentialStore.enroll(...)`.
- `AuthenticationService.register(email:password:name:)`: gains offer logic identical to `login()` — compute `computeOfferAction(readiness:signedInUserId:pendingRequest:)` before `handleAuthSuccess`, execute silent paths if applicable, set `biometricOfferAction`, call `handleAuthSuccess`. Consumes `pendingBiometricEnablement` flag.
- `ProfileBiometricToggleModel.toggle(to: true)`: authenticates with `authService.biometricAuthenticator.authenticate(reason: "Enable Face ID for Christmas Tracker")` before calling `enrollCurrentSession()`. If authentication fails or is cancelled, sets `errorMessage` and returns without calling `enrollCurrentSession()`.
- `FakeBiometricAuthenticator`: gains `var evaluationCount: Int = 0` incremented on every `authenticate(_:)` call, and `func resetEvaluationCount()`.

**Acceptance criteria:**
1. After `enrollCurrentSession()`, `enrollmentHistory.previouslyEnrolledUserId` equals the enrolled user's id.
2. After `enrollCurrentSession()`, `FakeBiometricAuthenticator.evaluationCount` is 0 (no auth inside `enrollCurrentSession()`).
3. After `login()` with the `silentlyReplaceToken` path, `enrollmentHistory.previouslyEnrolledUserId` equals the signed-in user's id.
4. After `login()` with the `silentlyReenroll` path, `enrollmentHistory.previouslyEnrolledUserId` equals the signed-in user's id.
5. After `register()` for a first-time user on a device with no prior enrollment and `isBiometricAvailable == true`, `biometricOfferAction == .showEnablementScreen`.
6. After `register()` with `pendingBiometricEnablement = true`, `biometricOfferAction == .showEnablementScreen`.
7. After `register()` for a user who was previously enrolled and whose credential was lost (silentlyReenroll case), enrollment completes silently and `biometricOfferAction != .showEnablementScreen`.
8. `ProfileBiometricToggleModel.toggle(to: true)` with a succeeding fake authenticator calls `enrollCurrentSession()` exactly once and results in `isEnabled == true`.
9. `ProfileBiometricToggleModel.toggle(to: true)` with a failing fake authenticator never calls `enrollCurrentSession()` (evaluationCount == 1, `isEnabled == false`, `errorMessage != nil`).
10. Full enable-in-Profile flow: `FakeBiometricAuthenticator.evaluationCount == 1` after the toggle turns on (exactly one prompt across toggle model + enrollCurrentSession).

**Scoped file list:**
- Modified: `ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`
- Modified: `ChristmasTracker/Features/Profile/Services/ProfileBiometricToggleModel.swift`
- Modified: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FakeBiometricAuthenticator.swift`
- Modified (possible): `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/EnrollCurrentSessionTests.swift`
- Modified (possible): `ChristmasTracker/ChristmasTrackerTests/Features/Profile/ProfileToggleEnrollmentTests.swift`
- New: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/EnrollMarkerRegistrationTests.swift`

**New interface: Yes** → full pipeline (F1)

---

### F2 — Single sign-in prompt via evaluatePolicy-then-reuse-context

**Defect fixed:** E5 (`KeychainBiometricCredentialStore.readRefreshToken` creates an LAContext and passes it to the Keychain query, but never calls `evaluatePolicy` — the iOS Simulator does not enforce biometric Keychain access control, so sign-in shows no prompt on device either).

**Contract slice:** Pure local change to `BiometricCredentialStoring.swift`. No new types.

**Interface changes:**
- `KeychainBiometricCredentialStore.readRefreshToken(reason:)`:
  1. Create `LAContext`, set `localizedFallbackTitle = ""` (no passcode fallback button in the prompt).
  2. Call `try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)`. If this throws, map the `LAError` to `BiometricCredentialError` using the same mapping already in the file (`.userCancel` → `.cancelled`, `.biometryLockout` → `.lockedOut`, any other → `.unavailable`).
  3. Remove `kSecUseAuthenticationUI: kSecUseAuthenticationUIAllow` from the Keychain query.
  4. Pass the already-evaluated context as `kSecUseAuthenticationContext` in the query.

**Acceptance criteria:**
1. `readRefreshToken` on a credential that has no stored token throws `BiometricCredentialError.notEnrolled` (no regression via `InMemoryBiometricCredentialStore`).
2. `readRefreshToken` on a successfully enrolled `InMemoryBiometricCredentialStore` returns the token (no regression).
3. `KeychainBiometricCredentialStore.readRefreshToken` calls `context.evaluatePolicy` before the Keychain query (verified by code inspection at Gate 2).
4. The same LAContext instance is passed to both `evaluatePolicy` and the Keychain query (code inspection).
5. `localizedFallbackTitle` is set to `""` before `evaluatePolicy` is called (code inspection).

**Scoped file list:**
- Modified: `ChristmasTracker/Features/Authentication/Services/BiometricCredentialStoring.swift`

**New interface: Yes (behavior change)** → full pipeline (F2)

---

### F3 — Cold-launch auto-prompt, offer presentation, display names

**Defects fixed:** E3 (sheet presented from `.onChange(of: authService.isAuthenticated)` checking `shouldShowBiometricEnablementAfterLogin` instead of from `biometricOfferAction`), E6 (`LoginBiometricModel.hasAutoAttempted` only consumed when enrolled, so logout→re-login auto-signs-in again), E7 (`BiometricType.none.displayName` returns `"None"` causing "Sign in with None" in the UI).

**Contract slice:** Pure local changes. No new types.

**Interface changes:**
- `AuthenticationService.BiometricType.none.displayName`: return `"Face ID or Touch ID"` (was `"None"`).
- `LoginBiometricModel.autoAttemptIfNeeded()`: consume `hasAutoAttempted = true` BEFORE the enrolled guard, so the first appearance of the login screen always arms the flag regardless of biometric state:
  ```
  guard !LoginBiometricModel.hasAutoAttempted else { return }
  LoginBiometricModel.hasAutoAttempted = true
  syncFromService()
  guard case .showEnrolled = buttonState else { return }
  await authService.signInWithBiometric()
  ```
- `ChristmasTrackerApp.body`:
  - Remove the `shouldShowBiometricEnablementAfterLogin` check from the `.onChange(of: authService.isAuthenticated)` block.
  - Add `.onChange(of: authService.biometricOfferAction) { _, action in if case .showEnablementScreen = action { showBiometricSetup = true } }`.
  - In the sheet's `onComplete` closure: also call `authService.clearBiometricOfferAction()` after `showBiometricSetup = false`.

**Acceptance criteria:**
1. `autoAttemptIfNeeded()` when `buttonState == .hidden`: `hasAutoAttempted` becomes true, `signInWithBiometric()` is NOT called.
2. `autoAttemptIfNeeded()` when `buttonState == .showNotEnrolled`: `hasAutoAttempted` becomes true, `signInWithBiometric()` is NOT called.
3. `autoAttemptIfNeeded()` when `buttonState == .showEnrolled`: `hasAutoAttempted` becomes true, `signInWithBiometric()` IS called.
4. A second call to `autoAttemptIfNeeded()` (any state) after the first call: no-op regardless of state.
5. `BiometricType.none.displayName` returns `"Face ID or Touch ID"`.
6. `BiometricType.touchID.displayName` returns `"Touch ID"` (no regression).
7. `BiometricType.faceID.displayName` returns `"Face ID"` (no regression).
8. `shouldShowBiometricEnablementAfterLogin` is NOT used in `ChristmasTrackerApp.body` after F3 (code inspection at Gate 2).
9. `biometricOfferAction == .showEnablementScreen` triggers `showBiometricSetup = true` (code inspection at Gate 2).
10. `clearBiometricOfferAction()` is called in the `onComplete` closure (code inspection at Gate 2).

**Scoped file list:**
- Modified: `ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (BiometricType.none.displayName)
- Modified: `ChristmasTracker/Features/Authentication/Views/LoginBiometricModel.swift`
- Modified: `ChristmasTracker/ChristmasTrackerApp.swift`
- Modified: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LoginBiometricModelTests.swift`

**New interface: Yes (behavior change)** → full pipeline (F3)

---

### F4 — Correct reports and handoff

**Defect fixed:** E8 (reports and handoff contain inaccurate claims made before defects E1–E7 were known).

**Contract slice:** Docs only. No code changes.

**Changes:**
- `Docs/reports/I2b2a-2-sign-in-flow.md`: add Not-done entry for E5 (single prompt requirement not met; `readRefreshToken` lacked `evaluatePolicy` call; corrected in F2).
- `Docs/reports/I2b2a-3-enrollment-toggle-lock.md`: add Not-done entry for E1 (previously-enrolled marker not set; corrected in F1); add Not-done entry for E4 (double biometric prompt; corrected in F1).
- `Docs/handoffs/2026-11-05-ios-to-brian-i2b2a.md`: add fix-pass stories F1–F3, update verify count to post-F3 actual, correct Open Risks to reflect E6 resolution (flag now consumed on first appearance regardless of state).

**New interface: No** → docs-only, no pipeline
