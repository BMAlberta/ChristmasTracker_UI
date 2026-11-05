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

*(to be written before S3 work begins)*

---

## Gate 1: Story S4 — Report and Handoff

*(docs only; no Gate 1 spec needed)*
