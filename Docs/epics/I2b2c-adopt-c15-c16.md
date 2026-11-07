# I2b-2c: Adopt contract C15 and C16
Track: iOS. Depends on: I2b-2b (merged). Blocks: I3 (lists, items, members), I4 (purchases).
Branch: chore/contract-sync-f1d4f57 (the existing chore branch with Brian's sync commit e3ae527; new commits only).
Contract state: contract content of C16 (backend f1d4f57), synced at backend commit 5c86cc3 (one docs-only commit later), spec sha256 55f570342c69. STATUS.md reads CONFORMANT; decisions revision 24.

Precondition note: contract/VERSION shows backend_commit=5c86cc3d86d98c0bd864f0dc54f459a58fd1bf07, not f1d4f57. Brian confirmed (2026-11-06) that 5c86cc3 is a fast-forward of f1d4f57 by one commit ("docs: add the C16 handoff note", not a synced file) and that spec_sha256 55f570342c69... equals the checksum the API chat published for f1d4f57. P2 is therefore treated as passed when backend_commit starts with 5c86cc3, spec_sha256 starts with 55f570342c69, and STATUS.md reads CONFORMANT.

Why: the backend now documents every middleware status on every operation (C15) and makes User.email non-null and expiresIn required on login, register, and refresh (C16). The derived client spec is stale, the regenerated client adds Output cases that break exhaustive switches, and the app still carries the I2b-2b workarounds (900-second default, nil-email rejection, the `.undocumented(403)` login special case). A disabled or deleted account on an authenticated call must end the session.

## Contract facts (confirmed against the synced files)
- C15 (backend 99e15fb, DECISIONS revision 23): every operation documents 429 and 500; every bearerAuth operation also documents 401, 403 (ACCOUNT_DISABLED), and 404 (USER_NOT_FOUND); every operation with a request body documents 400. No operationId, path, parameter, or request body changed. Client guide section 4: "Clients must handle all five on every call to a bearerAuth endpoint."
- C16 (backend f1d4f57, DECISIONS revision 24): `User.email` is required and a plain string; `expiresIn` (integer seconds, example 900, derived from JWT_EXPIRY, equal to exp minus iat) is a required field of `data` on login, register, and refresh.
- Client guide 3.2 (login errors): 400 VALIDATION_ERROR, 401, 403 ACCOUNT_DISABLED ("redirect to the login screen and discard stored tokens"), 426, 429 (respect Retry-After).
- Client guide 3.3 (refresh errors): 400 VALIDATION_ERROR, 401 (expired, invalid, missing, revoked), 403 ACCOUNT_DISABLED ("redirect to the login screen and discard stored tokens"), 426, 429.
- Client guide section 4 table: 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND on an authenticated endpoint mean "redirect to login".

## Decisions taken in this package (Brian, 2026-11-06)
- D-a. Pre-existing composition-root bug (see Inventory 6) is fixed in U2 and reported under "Real bugs found". It was introduced in I2b-2b C1 (a90965e) and stayed latent because no screen makes an authenticated generated call yet. Two composition tests are required (see U2). No other pre-existing fixes in this package; anything else found is recorded in the handoff for a later pass.
- D-b. forceRefresh (the RefreshOn401Middleware path) and refreshTokenIfNeeded BOTH end the session on a refresh-context credential failure: delete the enrollment when it belongs to the current session user, log out with `.sessionExpired`, and (forceRefresh only) rethrow. This applies to every refresh credential failure (401 and the new 403), per the guide's "401: refresh once, then re-login".
- D-c. A login 403 ACCOUNT_DISABLED shows the administrator message only; it does not delete the stored Face ID token. The next Face ID attempt receives a refresh 403 and deletes the token itself (U3). The guide's "discard stored tokens" wording is recorded in the handoff.

## Scope
- U1. Regenerate the derived spec and client; fix every exhaustive switch with deliberate mappings; update package fixtures; add typed-response decoding tests for the new statuses.
- U2. Package `SessionEnding` seam and `SessionEndingMiddleware` (403 ACCOUNT_DISABLED, 404 USER_NOT_FOUND, non-public operations only), wired into `TrackerClientFactory.make` with a defaulted parameter; the app adapter in Core/API; the composition-root fix (D-a) with an extracted, testable composition function.
- U3. Use expiresIn from login and register; delete the nil-email path; a pure, nonisolated refresh-context classification used by forceRefresh, refreshTokenIfNeeded, and signInWithBiometric; Docs/contract-issues.md row 1 resolved.
- U4. Handoff and real-mode steps (docs only).

Allowed package changes: the new seam and middleware, the factory parameter and order comment, the regenerated derived spec (`LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`), updated fixtures and tests. Anything else in the package: stop and report.

Non-goals: lists, items, members, purchases, stats; any authenticated screen (I3); deleting the Face ID token on login 403 (D-c); other pre-existing fixes (D-a).

---

## Inventory (taken 2026-11-06, before U1)

### 1. Sync commit diff
`git diff HEAD~1 --stat -- contract Docs`:
```
 Docs/DECISIONS.md     |  20 ++++-
 Docs/client-guide.md  |  45 +++++++++-
 contract/STATUS.md    |   2 +-
 contract/VERSION      |   8 +-
 contract/openapi.json | 242 ++++++++++++++++++++++++++++++++++++++++++++++++--
 5 files changed, 300 insertions(+), 17 deletions(-)
```
Docs/error-codes.md did not change in the sync.

### 2. Contract hunks (from jq over the old and new contract/openapi.json)
Documented response codes, old -> new:

| operationId | Path | Old | New |
|---|---|---|---|
| login | POST /tracker/v2/auth/login | 200 400 401 426 429 500 | 200 400 401 **403** 426 429 500 |
| register | POST /tracker/v2/auth/register | 201 400 403 409 429 500 | unchanged |
| refreshToken | POST /tracker/v2/auth/refresh | 200 401 426 500 | 200 **400** 401 **403** 426 **429** 500 |
| getCurrentUser | GET /tracker/v2/auth/me | 200 401 500 | 200 401 **403 404 429** 500 |
| logout | POST /tracker/v2/auth/logout | 200 401 500 | 200 401 **403 404 429** 500 |
| checkAppVersion | GET /tracker/v2/app/version-check | 200 304 400 429 500 | unchanged |

Every other (bearerAuth) operation gained 403, 404 (where missing), and 429; updateList and duplicateBudget also gained 400. All new statuses use the shared components ForbiddenError, NotFoundError, RateLimitError, ValidationError, each `$ref: #/components/schemas/Error`.

User schema:
- Old: `required` = id, firstName, lastName, displayName, role, isActive, createdAt, updatedAt; `email` = `{"type": ["string","null"], "format": "email"}`.
- New: `required` adds `email`; `email` = `{"type": "string", "format": "email"}`.

Auth success `data`:
- login and register, old: required user, accessToken; properties accessToken, refreshToken, user (no expiresIn).
- login and register, new: required user, accessToken, **expiresIn**; `expiresIn` = `{"type": "integer", "example": 900}`.
- refreshToken: required user, accessToken, expiresIn in both old and new.

### 3. Exhaustive switches over a generated Output
App (`ChristmasTracker/ChristmasTracker`):
- `Features/Authentication/Repositories/GeneratedClientAuthenticationRepository.swift:35` login: ok, badRequest, unauthorized, upgradeRequired, tooManyRequests, internalServerError, undocumented (with the `status == 403` special case at lines 61–65). Gains `.forbidden`.
- `...GeneratedClientAuthenticationRepository.swift:93` register: no new cases expected (register's codes did not change).
- `...GeneratedClientAuthenticationRepository.swift:141` refreshToken: ok, unauthorized, upgradeRequired, internalServerError, undocumented. Gains `.badRequest`, `.forbidden`, `.tooManyRequests`.
- `...GeneratedClientAuthenticationRepository.swift:181` logout: ok, unauthorized, internalServerError, undocumented. Gains `.forbidden`, `.notFound`, `.tooManyRequests`.
- `Features/Version/GeneratedClientAppVersionRepository.swift:33` checkAppVersion: codes unchanged; no new cases expected.
- The app makes no getCurrentUser call. The generated client's getCurrentUser is used only in package tests (`LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift:199, 249, 299, 381`); none of them switches exhaustively over its Output (to be confirmed after regeneration in U1).
Package (`LocalPackages/TrackerAPI/Sources`): no switch over an `Operations.*.Output`.

Note: RateLimitMiddleware (`LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RateLimitMiddleware.swift:62-74`) throws `TrackerAPIError.rateLimited(retryAfter:)` for every 429 it cannot retry (all POSTs), so a `.tooManyRequests` case on the POST auth operations is reached only if that middleware is absent. The case is still mapped deliberately.

### 4. Places that default expiresIn to 900
- `GeneratedClientAuthenticationRepository.swift:44` (login) `expiresIn: 900`.
- `GeneratedClientAuthenticationRepository.swift:102` (register) `expiresIn: 900`.
- `Core/Models/AuthTypes.swift:17` doc comment: "900 for login/register (not in those responses)".
- `MockAuthenticationRepository.swift:58, 94, 121`: mock sessions with 900 (mock mode only; not a default for a real response; stays).
- Test fixtures using 900 as a value (not a default): `GeneratedClientAuthRepositoryTests.swift:66, 92, 118, 143` (fixtures already carry expiresIn) and the assertions at `:235` (login), `:414` (register), `:526` (refresh); other AuthSession builders in tests use 900 as a value.
- Unrelated 900s (cache and background refresh durations): `AppConfiguration.swift:116, 118`, `Config.xcconfig:24, 26`, `AppConfigurationTests.swift:22`. Out of scope.

### 5. Places that treat a nil email as invalid
- `GeneratedClientAuthenticationRepository.swift:203-208` `mapUser`: `guard let email = schema.email else { throw AuthenticationError.invalidResponse }`.
- `MockAuthenticationRepository.swift:180` comment on `AuthenticationError.invalidResponse`: "nil email on user returned by login/register/refresh" (the case stays for undecodable responses; the comment is updated in U3).
- Tests that assert the nil-email path are named in the U3 report.

### 6. Composition root (D-a)
`ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift:253-320`: `let authBox = AuthServiceBox()` is a local; the AccessTokenSeam and SessionRefreshSeam closures capture it with `[weak authBox]`; nothing else retains it after `init` returns, so the box is freed and the token seam returns nil and the refresh seam throws `invalidRefreshToken` forever. Introduced in a90965e (I2b-2b C1), which replaced the earlier `[weak auth]` captures; latent because no screen makes an authenticated generated call yet.

### 7. Other existing classification
- `Features/Authentication/Services/BiometricSignInState.swift:23` `isCredentialFailure`: invalidRefreshToken, sessionExpired, invalidCredentials, credentialExpired. Used by `AuthenticationService.refreshTokenIfNeeded` (`AuthenticationService.swift:332`), `biometricSignInOutcome` (`BiometricSignInState.swift:64`), and `SessionRefreshSeam` (`Core/API/SessionRefreshSeam.swift:18`).
- `AuthenticationService.forceRefresh` (`AuthenticationService.swift:355-366`) throws without ending the session today.

### 8. Docs/contract-issues.md (current contents)
```
| # | Filed | Endpoint | Contract says | Server did | Status |
|---|---|---|---|---|---|
| 1 | 2026-11-06 | POST /auth/login | `Operations.Login.Output` has no `.forbidden` case; spec does not document 403 | `Docs/error-codes.md` and `Docs/client-guide.md` document that 1008 ACCOUNT_DISABLED is returned as 403 on login; server sends 403 JSON error body. Arrives as `.undocumented(403,…)` in the generated client. iOS handles via undocumented path per client-guide. | Spec gap — docs authoritative; not blocking I2b-2b (epic brief accounts for it). Backend to add `403 ForbiddenError` to the login operation in openapi.json. Client: ios |
```
The file has no convention for resolved rows (only one row exists); U3 keeps the row and updates its Status to resolved.

### 9. Baseline (P3, before any change)
- `scripts/verify.sh`: `Transformed 5 null-schema properties.` / `ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate.` / `=== verify: DERIVED SPEC OUT OF DATE — run scripts/make-client-spec.sh ===`. Stops before build and tests.
- `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 146 tests in 11 suites failed after 0.124 seconds with 1 issue.` The single failure is SpecConformance "Derived spec file matches the Swift-transform applied to contract/openapi.json" (stale derived spec).
- App suite baseline: 612 tests (from the prompt; re-confirmed when verify first runs green in U1).

---

## Gate 1 specs (short; full pipeline for every story)

### U1: regenerate the client
- Contract slice: every operation's documented responses (table 2), User.email, auth data.expiresIn.
- Acceptance: derived spec regenerated with `scripts/make-client-spec.sh`; count guard still 5 (else stop and justify); app and package compile; every switch in Inventory 3 maps each new case explicitly (no `default`): login `.forbidden` -> `accountDisabled` and the `.undocumented(403)` special case removed; refresh `.badRequest` -> `validation(message:)`, `.forbidden` -> `accountDisabled`, `.tooManyRequests` -> `rateLimited(retryAfter:)`; logout `.forbidden` and `.notFound` -> `sessionExpired`, `.tooManyRequests` -> `rateLimited(retryAfter:)`; 429 retryAfter from the typed Retry-After header or `error.details.retryAfter` if the generated payload exposes them, else 0. Package fixtures gain expiresIn and non-null emails; typed decoding tests through the factory-built client with fake transports for login 403, refresh 400, refresh 403, refresh 429, getCurrentUser 403 and 404, logout 403 and 404, envelopes from the guide with full meta. Public-operation pin test unchanged. verify.sh green after the commit.
- Files: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`, `LocalPackages/TrackerAPI/Tests/TrackerAPITests/*`, `GeneratedClientAuthenticationRepository.swift`, `GeneratedClientAppVersionRepository.swift` (only if it no longer compiles), app tests for the repository.
- New interface: no.

### U2: end the session on a disabled or missing account
- Contract slice: client guide section 4 middleware table (403 ACCOUNT_DISABLED, 404 USER_NOT_FOUND on bearerAuth operations).
- New interface: yes.
  - Package `Seams.swift`: `public enum SessionEndReason: Sendable, Equatable { case accountDisabled, userNotFound }`; `public protocol SessionEnding: Sendable { func sessionEnded(reason: SessionEndReason) async }`.
  - Package `Middleware/SessionEndingMiddleware.swift`: `public struct SessionEndingMiddleware: ClientMiddleware { public init(handler: any SessionEnding) }`.
  - `TrackerClientFactory.make(..., sessionEndingHandler: (any SessionEnding)? = nil, transport: ...)`; order Headers, RefreshOn401, RateLimit, VersionOutdated, SessionEnding, BearerAuth, documented in the factory.
  - App `Core/API/SessionEndingSeam.swift`: `final class SessionEndingSeam: SessionEnding` with a closure-injected `@Sendable (SessionEndReason) async -> Void` sign-out action (production: hop to MainActor, call `AuthenticationService.logout(reason: .sessionExpired)` only when signed in).
  - App composition function (extracted from `ChristmasTrackerApp.init`, testable): builds the box and the three seams with the box held strongly by the closures and the service held weakly by the box.
- Exact signatures (fixed at Gate 1 for U2):
  - Package `Seams.swift`: `public enum SessionEndReason: Sendable, Equatable { case accountDisabled, userNotFound }`; `public protocol SessionEnding: Sendable { func sessionEnded(reason: SessionEndReason) async }`.
  - Package `Middleware/SessionEndingMiddleware.swift`: `public struct SessionEndingMiddleware: ClientMiddleware { public init(handler: any SessionEnding) }`. Public operations are those in `publicOperationIDs`. Only a 403 or 404 response body is buffered; it is peeked with a small private Decodable (`error.errorCode`, all fields optional, any other content tolerated), and the response is returned with a rebuilt readable body. The handler is called at most once per response.
  - `TrackerClientFactory.make(serverURL:info:tokenProvider:sessionRefresher:versionOutdatedHandler:requestIDObserver:sessionEndingHandler: (any SessionEnding)? = nil, transport:)`. When the handler is nil the middleware is omitted. The order is Headers, RefreshOn401, RateLimit, VersionOutdated, SessionEnding, BearerAuth, documented in a comment in the factory.
  - App `buildGeneratedClient(...)` gains `sessionEndingHandler: (any SessionEnding)? = nil` and passes it through.
  - App `Core/API/SessionEndingSeam.swift`: `final class SessionEndingSeam: SessionEnding { init(onSessionEnded: @escaping @Sendable (SessionEndReason) async -> Void) }`.
  - App `Core/API/ClientSeams.swift`: the box moves here from `ChristmasTrackerApp.swift` as `final class AuthServiceBox: @unchecked Sendable` with a WEAK `value: AuthenticationService?`. `struct ClientSeams { let box: AuthServiceBox; let tokenProvider: AccessTokenSeam; let sessionRefresher: SessionRefreshSeam; let sessionEnding: SessionEndingSeam }`, and `func makeClientSeams() -> ClientSeams`. All three seam closures capture the box STRONGLY. The session-ending closure hops to the main actor and calls `logout(reason: .sessionExpired)` only when `isAuthenticated` is true; it never touches the credential store. With no service, the refresh closure throws `AuthenticationError.invalidRefreshToken`, which SessionRefreshSeam maps to `SessionRefreshError.credentialFailure`. `ChristmasTrackerApp.init` uses `makeClientSeams()` and sets `seams.box.value = auth`.
- Acceptance: middleware fires once per response, only for non-public operations, only for 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND, with the body still readable; never for FORBIDDEN, LIST_NOT_FOUND, other codes, public operations, or 2xx. Adapter signs out a signed-in session, is a no-op when signed out, is idempotent, leaves the enrollment. Composition test 1: build the dependencies, drop every local reference, and after the composition function has returned prove the token provider returns the signed-in token, the refresher reaches the service, and the session-ending adapter reaches the service. Composition test 2: with the service released, the token provider returns nil and the refresher fails with a typed error, with no crash and no retain cycle.

### U3: expiresIn, non-null email, refresh 403
- Contract slice: C16; client guide 3.2 and 3.3 error lists.
- New interface: yes: an explicit, pure, nonisolated classification of an `AuthenticationError` in a context (login or refresh) used by forceRefresh, refreshTokenIfNeeded, signInWithBiometric (through biometricSignInOutcome), and SessionRefreshSeam; signatures fixed in the U3 Gate 1 brief.
- Acceptance: login and register use `data.expiresIn` (tests with 900 and a non-default value); mapUser uses the non-optional email; nil-email tests deleted and named; `invalidResponse` remains for undecodable bodies; refresh 403 deletes the enrollment and ends the session (forceRefresh and refreshTokenIfNeeded, D-b); Face ID with refresh 403 deletes the enrollment and shows no error text; login 403 still shows the administrator message; truth-table test over every AuthenticationError case in both contexts; contract-issues row 1 resolved ("fixed in 99e15fb (C15), synced at 5c86cc3").

### U4: handoff (docs only)
- Handoff `Docs/handoffs/2026-11-06-ios-to-brian-i2b2c.md` with the real-mode steps from the package prompt verbatim in substance.
