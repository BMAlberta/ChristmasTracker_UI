# I2b-2b: Authentication on the generated client
Track: iOS. Depends on: I1-a and I1-b (merged), I2b-2a (merged). Blocks: I3 (lists, items, members), I4 (purchases).
Contract state: CONFORMANT at 35ff2bc.

Why: login, registration, refresh, and logout still run on the hand-written network stack, whose models disagree with the server (no envelope, no user object, wrong expiry, a removed biometric endpoint, a ping endpoint that no longer exists, a forgot-password endpoint that was never built). This package moves them onto the generated client, adds the registration code, deletes the dead pieces, and closes the Face ID gaps recorded in the I2b-2a handoff.

Server facts (client guide, error codes, decisions): login and register return {user, accessToken, refreshToken} in the standard envelope, with refreshToken present only because X-Client-Platform: ios is sent (the middleware sends it); neither returns expiresIn, so the client uses the documented 15-minute access token lifetime (900 seconds); refresh (POST /auth/refresh, body {refreshToken}, JSON only; the cookie parameter is skipped by the generator and unused) returns {user, accessToken, expiresIn, refreshToken}, rotates the token (store the new one before using the new access token; decisions A4 and A7); user = {id, email (nullable), firstName, lastName, displayName, role, isActive, createdAt, updatedAt, lastLoginAt (nullable)}; registration needs email, password, firstName, lastName, an optional displayName, and the shared registrationCode; logout is POST /auth/logout with only the Authorization header, never a body or a refresh token (decision A15); there is no biometric endpoint, no ping endpoint, and no self-service password reset (the client says to contact the administrator); 401 on a public operation is returned as is (for example wrong password); 426 can occur on login and refresh (the package's middleware calls the version handler and returns the response); 429 carries retryAfter.

Scope
1. A generated-client AuthenticationRepository (login, register, refresh, logout, and the current user if the app needs it), mapping generated payloads to domain models; typed, user-meaningful errors for every documented response of those operations; the hand-written auth wire models and NetworkAuthenticationRepository deleted.
2. AuthenticationService on the new repository: login without the rememberMe parameter, register with firstName, lastName, and registrationCode, expiresIn defaults, the SessionRefreshing adapter using the new refresh, local-first logout kept (its server call sends no body and no refresh token).
3. UI: the registration screen gains first name, last name, and registration code fields (no more single Full Name); server and client validation messages; the forgot-password flow becomes an informational screen (contact the administrator) with no network call; error presentation for 401, 403 account disabled, 409 email in use, invalid registration code, 426, 429, and 5xx.
4. Remove the dead session code: the old ping loop, isSessionValid, and the 30-minute and 24-hour session durations in SessionManager (only what has no remaining caller), the biometricLogin and ping members of the repository protocol and every implementation, and BiometricLoginRequest.
5. The Face ID gaps from the I2b-2a handoff.

Decisions
- Real mode (APIMode.real) builds the auth repository from the generated client through the composition root; mock mode keeps MockAuthenticationRepository, updated to the new protocol. The hand-written list and item repositories stay until I3.
- Domain mapping: the app's User from the generated User (name from displayName; email must be present for any user returned by login, register, or refresh: a nil email on those responses is a typed invalid-response error); AuthSession (user, accessToken, refreshToken, expiresIn in seconds) as the repository's result; AuthTokens(expiresAt) computed from expiresIn at receipt, with 900 when absent.
- Error mapping uses the package's classification and the codes in Docs/error-codes.md: wrong credentials and invalid or expired refresh tokens are credential failures (the existing isCredentialFailure rule, extended with the real codes), account disabled shows the administrator message, email in use shows an inline message, an invalid registration code shows an inline message on the code field, 426 shows an update-required message (and the existing VersionGate seam publishes the details), 429 shows a wait message with the seconds, 5xx and transport failures show the neutral retry message. No message includes data from the server beyond the documented message text.
- Registration validation on the client mirrors the server's documented rules (read the client guide), and the server's validation errors are shown when the server rejects.
- The Forgot Password screen keeps its entry point and presentation but has no email field and no request: it explains that password resets are handled by the administrator and offers Close.
- SessionManager keeps teardown and the registered clearables; everything else in it is deleted unless a live caller remains (inventory first, and justify each remaining member).

Non-goals: lists, items, members, purchases, stats, the version manager screen (the 426 message and VersionGate state are enough), remote lock timeout, changing the TrackerAPI package, the dedicated biometric credential (A9).

Acceptance
- Through the REAL factory-built client with a fake transport, every documented response of login, register, refresh, and logout maps as specified (success, each error status and code, 426, 429 with retryAfter, 500, undocumented, transport failure), the requests carry the four client headers, the login and register and refresh requests carry no Authorization header, the logout request carries Authorization and NO body, and no request sends a cookie or a refresh token to logout.
- AuthenticationService login, register, refresh, forceRefresh (for the middleware seam), and logout behave as specified with the generated repository fake: tokens stored in memory with the right expiry, the new refresh token stored for the enrolled user before use, local-first logout, isLoading reset on every path.
- The registration screen has the new fields and the code, the forgot-password screen makes no request, and the error messages render for each mapped case (tested through view-state functions or models, with the screens read by the reviewer).
- No reference remains to the removed endpoints, models, or members (grep evidence), and the app builds, links, and passes verify.
- The Face ID gaps are fixed with tests.
- No change under contract/, .claude/, any .pbxproj, LocalPackages/TrackerAPI, or the lists and items code.

---

## Inventory

### AuthenticationRepository protocol
**File:** `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/AuthenticationRespository.swift` lines 11–52

Current method signatures:
- `login(email: String, password: String, rememberMe: Bool) async throws -> AuthData` (line 19)
- `register(email: String, password: String, name: String) async throws -> AuthData` (line 28)
- `biometricLogin(userId: String, biometricToken: String) async throws -> AuthData` (line 35) — **DELETE** (no server endpoint, A9)
- `refreshToken(_ refreshToken: String) async throws -> AuthData` (line 41)
- `ping() async throws` (line 44) — **DELETE** (endpoint removed, A8)
- `logout(refreshToken: String) async throws` (line 47)
- `forgotPassword(email: String) async throws` (line 50) — **DELETE** (endpoint never built, A10)

### NetworkAuthenticationRepository
**File:** `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/NetworkAuthenticationRepository.swift`
- Used by: `AppDependencies.make()` in `ChristmasTrackerApp.swift` line 112 (`.real` branch)
- Also passed as `authRepository` to `SessionManager` init at `ChristmasTrackerApp.swift` line 241 — **DELETE** entire file; delete tests in `NetworkAuthRepositoryRequestTests.swift` (4 tests: `logoutSendsPostToLogoutPath`, `logoutSendsNilBody`, `refreshTokenSendsPostToRefreshPath`, `refreshTokenBodyContainsOnlyRefreshTokenField`, `refreshTokenBodyValueMatchesArgument`; note: 5 tests actually in the file, name each in report)

### MockAuthenticationRepository
**File:** `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/MockAuthenticationRepository.swift`
- Used by: `AppDependencies.make()` mock branch (`ChristmasTrackerApp.swift` line 101), all test files that construct an `AuthenticationService`, `SessionManager` tests, Previews in LoginView, RegisterView, ForgotPasswordView
- Must be updated to the new protocol (C1 task)
- **Also contains:** `AuthenticationError` enum (lines 178–207) — this stays (updated with new cases)

### Hand-written auth wire models (`Core/Models/AuthTypes.swift`)
**DELETE these types** (after C1 moves AuthTokens):
- `LoginRequest` (line 10): only used in `NetworkAuthenticationRepository.login` (line 22)
- `RegisterRequest` (line 16): only used in `NetworkAuthenticationRepository.register` (line 44)
- `BiometricLoginRequest` (line 22): only used in `NetworkAuthenticationRepository.biometricLogin` (line 66)
- `RefreshTokenRequest` (line 27): only used in `NetworkAuthenticationRepository.refreshToken` (line 85)
  - Note: contains a nested `ForgotPasswordRequest` struct at line 29 (dead code)
- `ForgotPasswordRequest` (line 34): only used in `NetworkAuthenticationRepository.forgotPassword` (line 136)
- `AuthResponse` (line 39): only used in `NetworkAuthenticationRepository` for all calls
- `AuthData` (line 45): used in `AuthenticationRepository` protocol (all methods), `AuthenticationService` (all calls), `MockAuthenticationRepository` (all methods), `NetworkAuthenticationRepository` (all calls), `AuthenticationServiceTests.swift`
- `ResponseMeta` (line 52): only used inside `AuthResponse`

**KEEP:**
- `AuthTokens` (line 59): used in `AuthenticationService.tokens` property (line 51), `handleAuthSuccess`, `updateTokens`, `forceRefresh`, `refreshTokenIfNeeded`, `clearStoredTokens`

### App User model (`Core/Models/User.swift`)
Current: `User(id, email?, name, role, createdAt, updatedAt)` — no `firstName`, `lastName`, `displayName`, no `isActive`, no `lastLoginAt`
**Must be updated** to match `Components.Schemas.User`:
- `id: String`, `email: String?`, `firstName: String`, `lastName: String`, `displayName: String`, `role`, `isActive: Bool`, `createdAt: Date`, `updatedAt: Date`, `lastLoginAt: Date?`
- Current `name` field mapped from `displayName` going forward
- `UserRole` enum stays; `Components.Schemas.User.RolePayload` is the generated enum

### AuthenticationService callers of deleted methods
- `forgotPassword(email:)` — `AuthenticationService.swift` line 410–425: `authService.forgotPassword(email:)` called from `ForgotPasswordView.handleSendReset()`. Both deleted in C2.
- `authRepository.login(email:password:rememberMe:true)` — `AuthenticationService.swift` line 149: will become `authRepository.login(email:password:)` in C1
- `authRepository.register(email:password:name:)` — `AuthenticationService.swift` line 278: will become `authRepository.register(email:password:firstName:lastName:registrationCode:)` in C1
- `authRepository.refreshToken(token)` — `AuthenticationService.swift` via `singleFlightRefresh` line 458: will become `authRepository.refresh(refreshToken:)` in C1
- `repo.logout(refreshToken: "")` — `AuthenticationService.swift` line 336: will become `authRepository.logout()` (no parameter) in C1

### SessionManager members — verdict for each
**File:** `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionManager.swift`

Properties:
- `baseSessionDuration: TimeInterval` (line 13) — read only by `isSessionValid()` → **DELETE**
- `pingInterval: TimeInterval` (line 14) — read only by ping loop in `startSession()` → **DELETE**
- `maxSessionDuration: TimeInterval` (line 15) — read only by `isSessionValid()` → **DELETE**
- `authRepository: AuthenticationRepository` (line 19) — read only by `performPing()` → **DELETE** (also remove from `init`)
- `sessionStartTime: Date?` (line 21) — set by `startSession()`/`teardown()`, read only by `isSessionValid()` → **DELETE**
- `lastActivityTime: Date?` (line 22) — set by `startSession()`/`recordActivity()`/`teardown()`, read only by `isSessionValid()` → **DELETE**
- `pingTask: Task<Void, Never>?` (line 23) — only used for the ping loop → **DELETE**
- `clearables: [any SessionClearable]` (line 24) — used by `teardown()` and `register()` → **KEEP**
- `lastTeardownReason: TeardownReason?` (line 25) — set in `teardown()`, readable externally → **KEEP**

Methods:
- `init(authRepository:initialClearables:)` (line 29) — `authRepository` parameter has no remaining live caller (only `performPing()` used it) → remove `authRepository` parameter, keep `initialClearables`
- `register(_ clearable:)` (line 37) — called from `makeProductionClearables` / `AppDependencies` → **KEEP**
- `teardown(reason:)` (line 44) — called from `AuthenticationService.logout()` → **KEEP** (simplify: remove pingTask cancel lines, sessionStartTime/lastActivityTime nil assignments)
- `startSession()` (line 73) — called from `AuthenticationService.handleAuthSuccess()` line 493 → **KEEP** (simplify: remove ping loop and timestamp assignments; body becomes only the log call)
- `stopSession()` (line 88) — no live production caller (only `SessionManagerTests.swift` tests call it) → **DELETE**
- `recordActivity()` (line 96) — called from `AuthenticationService.recordActivity()` line 428 → **KEEP** (simplify: remove `lastActivityTime = Date()` assignment; body becomes only the timestamp line... actually nothing remains)

  Wait: `AuthenticationService.recordActivity()` calls `Task { await sessionManager.recordActivity() }`. That `recordActivity()` only sets `lastActivityTime`. With `lastActivityTime` deleted, the method body is empty. It has a live caller, so keep it as a no-op (or remove the call in `AuthenticationService.recordActivity()` since it does nothing).
  
  Decision: keep `recordActivity()` as a no-op (the live caller is harmless); simplify body to empty.

- `isSessionValid() -> Bool` (line 101) — called only from `SessionManagerTests.swift` (3 tests) and from nowhere in production → **DELETE**
- `performPing()` (line 122) — called only from the ping loop in `startSession()` → **DELETE**

**Tests that exclusively cover deleted SessionManager members (all 3 tests in `SessionManagerTests.swift`):**
1. `testSessionValid` ("Session is valid after start") — calls `startSession()` + `isSessionValid()`
2. `testRecordActivity` ("Session records activity") — calls `startSession()` + `recordActivity()` + `isSessionValid()`
3. `testSessionInvalidAfterStop` ("Session becomes invalid after stop") — calls `startSession()` + `stopSession()` + `isSessionValid()`
→ All 3 deleted. No teardown or registry tests exist in this file.

**Updated `SessionManager.init` callers:**
- `ChristmasTrackerApp.swift` line 241: `SessionManager(authRepository: dependencies.authRepository, initialClearables: clearables)` → update to `SessionManager(initialClearables: clearables)` in C2
- `AuthenticationService.swift` line 36 (in tests): `SessionManager(authRepository: mockRepo)` → update in C2

### Generated signatures

**Operations.Login.Input:**
```swift
Operations.Login.Input(
    headers: .init(),
    body: .json(.init(email: String, password: String, rememberMe: Bool? = nil))
)
```
Login omits `rememberMe` per brief.

**Operations.Login.Output:**
- `.ok(Operations.Login.Output.Ok)` — `body.json.data: { user: Components.Schemas.User, accessToken: String, refreshToken: String? }`
- `.badRequest(Components.Responses.ValidationError)` — 400
- `.unauthorized(Components.Responses.UnauthorizedError)` — 401 (INVALID_CREDENTIALS=1001, also ACCOUNT_DISABLED=1008 403 arrives here as undocumented)
- `.upgradeRequired(Components.Responses.UpgradeRequiredError)` — 426 VERSION_OUTDATED
- `.tooManyRequests(Components.Responses.RateLimitError)` — 429
- `.internalServerError(Components.Responses.InternalError)` — 500
- `.undocumented(statusCode: Int, OpenAPIRuntime.UndocumentedPayload)` — catch-all; **note: 403 ACCOUNT_DISABLED arrives here because Login.Output has no `.forbidden` case**

**Operations.Register.Input:**
```swift
Operations.Register.Input(
    headers: .init(),
    body: .json(.init(email: String, password: String, firstName: String, lastName: String, displayName: String? = nil, registrationCode: String))
)
```
displayName omitted unless provided per brief.

**Operations.Register.Output:**
- `.created(Operations.Register.Output.Created)` — 201 `body.json.data: { user, accessToken, refreshToken? }`
- `.badRequest(Components.Responses.ValidationError)` — 400
- `.forbidden(Components.Responses.ForbiddenError)` — 403 REGISTRATION_CODE_INVALID (1017)
- `.conflict(Components.Responses.ConflictError)` — 409 EMAIL_ALREADY_EXISTS (1009)
- `.tooManyRequests(Components.Responses.RateLimitError)` — 429
- `.internalServerError(Components.Responses.InternalError)` — 500
- `.undocumented`

**Operations.RefreshToken.Input:**
```swift
Operations.RefreshToken.Input(
    headers: .init(),
    body: .json(.init(refreshToken: String?, deviceFingerprint: String? = nil))
)
```
Send refreshToken in JSON body only; body is optional in the generated type but we always send it.

**Operations.RefreshToken.Output:**
- `.ok(Operations.RefreshToken.Output.Ok)` — `body.json.data: { user, accessToken, expiresIn: Int, refreshToken? }`
- `.unauthorized(Components.Responses.UnauthorizedError)` — 401 (REFRESH_TOKEN_EXPIRED=1005, REFRESH_TOKEN_INVALID=1006, REFRESH_TOKEN_MISSING=1013)
- `.upgradeRequired(Components.Responses.UpgradeRequiredError)` — 426
- `.internalServerError(Components.Responses.InternalError)` — 500
- `.undocumented`

**Operations.Logout.Input:**
```swift
Operations.Logout.Input(headers: .init())
```
No body. Authorization header added by the middleware seam.

**Operations.Logout.Output:**
- `.ok(Operations.Logout.Output.Ok)` — 200
- `.unauthorized(Components.Responses.UnauthorizedError)` — 401
- `.internalServerError(Components.Responses.InternalError)` — 500
- `.undocumented`

**Error body structure (`Components.Schemas._Error`):**
```swift
_Error.error: _ErrorPayload { code: Int, errorCode: String, message: String?, details: DetailsPayload? }
```
Access via `try body.json.error.code` and `body.json.error.errorCode` to classify.

**VersionOutdatedError body structure (`Components.Schemas.VersionOutdatedError`):**
Used for the `.upgradeRequired` response body; contains `error.details` with `minimumVersion`, `minimumBuild`, `latestVersion`, `latestBuild`, `manifestUrl`, `ipaUrl`.

### User model and places it is built
Current `User(id:email:name:role:createdAt:updatedAt:)`:
- `MockAuthenticationRepository` (all stableUser / mockUser instances): `AuthenticationService.swift` via authData
- `AuthenticationService.currentUser` — set from `handleAuthSuccess(authData:)`
- `MockData.swift` (PreviewContent)
- Tests (various)

After C1, `User` changes to `User(id:email:firstName:lastName:displayName:role:isActive:createdAt:updatedAt:lastLoginAt:)`. The `name` property is removed; callers that read `user.name` will need to use `user.displayName` or `"\(user.firstName) \(user.lastName)"`. The `AuthenticationService` currently uses `user.name.components(separatedBy: " ").first` for firstName — this is replaced with `user.firstName`.

**AuthTokens** (`AuthTypes.swift` line 59): stays. Built in `handleAuthSuccess(authData:)` and `updateTokens(authData:)`. After C1, `AuthSession.expiresIn` replaces `AuthData.expiresIn`.

**AuthSession (new domain type introduced in C1):**
```swift
struct AuthSession: Sendable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int   // seconds; 900 for login/register (not in response), from response for refresh
}
```
Replaces `AuthData` as the repository return type.

### Password and registration rules (from client guide §3.1 and §3.2)
**Password rules** (server-enforced, client mirrors):
- Minimum 8 characters
- Must contain at least one uppercase letter
- Must contain at least one lowercase letter
- Must contain at least one digit
- Must contain at least one special character

**Registration code:** non-empty string; server compares via SHA-256 constant-time comparison. Invalid code → 403 REGISTRATION_CODE_INVALID.

**Registration required fields:** email (valid format), password (rules above), firstName, lastName, registrationCode. displayName is optional.

---

## Gate 1: Story C1 — The Generated Auth Repository, Models, and Service

**Contract slice:** `AuthenticationRepository` protocol redefinition; `GeneratedClientAuthenticationRepository`; delete `NetworkAuthenticationRepository`, hand-written wire models (LoginRequest, RegisterRequest, BiometricLoginRequest, RefreshTokenRequest, ForgotPasswordRequest, AuthResponse, AuthData, ResponseMeta); update `AuthenticationService`; update `MockAuthenticationRepository`; update composition root.

**New interface introduced:** yes — new `AuthenticationRepository` protocol signatures, `GeneratedClientAuthenticationRepository`, `AuthSession` domain type, new `AuthenticationError` cases.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/AuthenticationRespository.swift` (redefine protocol)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/GeneratedClientAuthenticationRepository.swift` (new)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/NetworkAuthenticationRepository.swift` (delete)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/MockAuthenticationRepository.swift` (update protocol, add registration code path)
- `ChristmasTracker/ChristmasTracker/Core/Models/AuthTypes.swift` (delete wire models, keep AuthTokens; also add AuthSession here or in AuthenticationRespository.swift)
- `ChristmasTracker/ChristmasTracker/Core/Models/User.swift` (update to full generated schema shape)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (update callers)
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (composition root update: real mode → GeneratedClientAuthenticationRepository, mock mode → updated Mock)
- `ChristmasTrackerTests/Features/Authentication/GeneratedClientAuthRepositoryTests.swift` (new)
- `ChristmasTrackerTests/Features/Authentication/NetworkAuthRepositoryRequestTests.swift` (delete; 5 tests: logoutSendsPostToLogoutPath, logoutSendsNilBody, refreshTokenSendsPostToRefreshPath, refreshTokenBodyContainsOnlyRefreshTokenField, refreshTokenBodyValueMatchesArgument)

**Acceptance criteria:**
1. Through the REAL factory-built client with a fake ClientTransport, all documented Login/Register/Refresh/Logout output cases map as specified (see test list in STORY C1 above).
2. Login input body omits rememberMe; Register input body omits displayName when nil; Refresh sends refreshToken in JSON body; Logout sends no body.
3. Nil email on a login/register/refresh user response → `AuthenticationError.invalidResponse`.
4. expiresIn defaults to 900 for login and register.
5. AuthenticationService uses the new protocol with no AuthData references remaining.
6. MockAuthenticationRepository matches new protocol and returns `AuthenticationError.invalidRegistrationCode` for code "bad-code".
7. No reference to biometricLogin, ping, forgotPassword, NetworkAuthenticationRepository, AuthResponse, AuthData, ResponseMeta, LoginRequest, RegisterRequest, BiometricLoginRequest, RefreshTokenRequest, ForgotPasswordRequest anywhere in production code.
8. Composition root wires GeneratedClientAuthenticationRepository in real mode; MockAuthenticationRepository in mock mode.
9. No retain cycle between client seams and AuthenticationService.

---

## Gate 1: Story C2 — Screens and the Dead Code

**Contract slice:** RegistrationView new fields; error message mapping; ForgotPasswordView informational screen; SessionManager dead code removal; grep verification.

**New interface introduced:** yes — `AuthenticationError` message-mapping function (pure); registration form validity pure function.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/RegistrationView.swift` (add firstName, lastName, registrationCode fields; inline error messages)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/ForgotPasswordView.swift` (remove email field, remove network call, informational screen)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginView.swift` (remove forgotPassword call)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (remove forgotPassword method)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionManager.swift` (delete dead members per inventory)
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (update SessionManager init — remove authRepository parameter)
- `ChristmasTrackerTests/Features/Authentication/AuthErrorMappingTests.swift` (new — message mapping)
- `ChristmasTrackerTests/Features/Authentication/RegistrationValidationTests.swift` (new — form validity)
- `ChristmasTrackerTests/Features/Authentication/SessionManagerTests.swift` (delete 3 tests covering deleted code: testSessionValid, testRecordActivity, testSessionInvalidAfterStop)

**Acceptance criteria:**
1. RegistrationView has firstName, lastName, email, password, confirmPassword, registrationCode fields with correct autocapitalization/autocorrection settings.
2. Client-side validation: firstName non-empty, lastName non-empty, email valid, password meets all 5 rules, confirmPassword matches, registrationCode non-empty.
3. Server error messages (invalidRegistrationCode, emailInUse, validation, accountDisabled, updateRequired, rateLimited, server, network) map to correct field (none, email, code) or alert.
4. ForgotPasswordView body has no email field, makes no repository or service call; it shows "Contact your administrator" message and a Close button.
5. No reference to `ping`, `biometricLogin`, `forgotPassword`, `BiometricLoginRequest`, `AuthResponse`, `AuthData`, `ResponseMeta`, `NetworkAuthenticationRepository`, `baseSessionDuration`, `maxSessionDuration` in any source or test file.
6. SessionManager: `startSession`, `recordActivity`, `register`, `teardown` remain; `stopSession`, `isSessionValid`, `performPing` are gone; `authRepository` property and init parameter removed.
7. The registry and teardown tests keep passing unchanged in meaning (note: none exist currently; this criterion applies if new tests are written for them).

---

## Gate 1: Story C3 — The Face ID Gaps

**Contract slice:** Swipe-down dismissal; KeychainBiometricCredentialStore LAError mapping with evaluation seam; LoginBiometricModel auto-prompt app-active guard; shared offer logic.

**New interface introduced:** yes — injectable seam on `KeychainBiometricCredentialStore`; injectable `appIsActive` closure on `LoginBiometricModel.autoAttemptIfNeeded`.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (sheet binding setter calls clearBiometricOfferAction)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Views/LoginBiometricModel.swift` (appIsActive closure; auto-prompt change)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/BiometricCredentialStoring.swift` (add evaluation seam if needed)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/KeychainBiometricCredentialStore.swift` (or BiometricCredentialStoring.swift) — richer LAError mapping
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (extract shared offer logic into private method)
- `ChristmasTrackerTests/Features/Authentication/BiometricFaceIDGapTests.swift` (new — gap fixes)

**Acceptance criteria:**
1. Swipe-down dismissal of the enablement sheet calls `clearBiometricOfferAction()` exactly once; sheet binding setter and both explicit paths (Enable success, Not Now) each trigger exactly one call.
2. LAError.authenticationFailed → `.biometricFailed`; LAError.systemCancel and LAError.appCancel → `.userCancelled`; LAError.userCancel and lockout → `.lockedOut`. Keychain read is never attempted when evaluatePolicy fails.
3. `autoAttemptIfNeeded` skips the attempt (and does NOT consume the flag) when `appIsActive` returns false; first appearance in an active app always consumes the flag.
4. The offer logic is in one private method called by both `login()` and `register()`.

---

## Gate 1: Story C4 — Real-Mode Check and Handoff (docs only)

**Contract slice:** Handoff document per CLAUDE.md spec; `Docs/reports/I2b2b-4-handoff.md`.

**New interface introduced:** no.

**Scoped files:**
- `Docs/handoffs/<run-date>-ios-to-brian-i2b2b.md` (new)
- `Docs/reports/I2b2b-4-handoff.md` (new)

**Acceptance criteria:**
1. Handoff contains "Brian's real-mode check" section with all 9 steps from the prompt.
2. Lists what still uses the hand-written stack (lists, items, purchases until I3/I4).
3. Lists open risks including the 900-second expiresIn assumption, nil-email rejection, removed protocol members.
4. `git diff --stat master...HEAD` shows no changes under contract/, .claude/, any .pbxproj, LocalPackages/TrackerAPI, or lists/items code.
