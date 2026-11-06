# I1-a: Generated API client package and middleware
Track: iOS. Depends on: the contract sync at backend commit 35ff2bc (CONFORMANT). Blocks: I1-b (app integration), I2b-2b (auth mapping and registration code), I3, I4, I6b.
Contract state: CONFORMANT. API models come ONLY from the generator run on contract/openapi.json; nothing is hand-written.

Why: the app currently uses a hand-written network layer and API-shaped models that disagree with the server. This package creates a self-contained, fast-testable Swift package that holds the generated client, the cross-cutting client behavior (headers, auth, 401 refresh-once-and-replay, 426, 429), the URLSession configuration that keeps the Face ID design safe (no cookies), and the money conversion. The app integrates it in I1-b. Brian links the package into the Xcode project after this package (agents cannot edit the project file).

Server facts to honor (from the client guide and the API handoffs): the base URL is host-only (never append /tracker/v2; every path key already has it); the contract does not list the four client headers as parameters, so middleware sends X-Platform ios, X-Build, X-App-Version, and X-Client-Platform ios on EVERY request (X-Client-Platform ios is what makes login and refresh return the refresh token in the body); a fresh UUID in X-Request-Id on every request is optional but wanted (a callback exposes it so the app can tag Sentry events); POST /auth/logout revokes the chain of a refresh token sent in a cookie or a JSON body, so cookies must be disabled and no refresh token may be sent to logout; refresh rotates the token and the old one has a 45-second grace window (single-flight); 401 means refresh once, replay once, then sign in again; 426 means update prompt with no retry (it can occur on login and refresh); 429 carries error.details.retryAfter and Retry-After headers and means back off, never a tight retry loop; every error uses the Error envelope and every operation documents a 500; money in responses is a JSON number with at most two decimals; dates are ISO 8601 and the server's JavaScript timestamps usually include fractional seconds.

Scope
1. LocalPackages/TrackerAPI, a local Swift package (tools 6.3, Swift 6 mode, platforms iOS 26 and macOS 15 so `swift test` runs on the Mac), product TrackerAPI, containing: the swift-openapi-generator build-tool plugin run on contract/openapi.json (types and client, public access, idiomatic naming); the spec reached through a symlink to ../../../../contract/openapi.json (fallback in the Decisions); a date transcoder that accepts BOTH ISO 8601 with and without fractional seconds and encodes without; the URLSession configuration factory; the middleware; the error taxonomy; protocol seams the app implements; the money conversion helpers.
2. A package test target runnable with `swift test`, using fake transports only.
3. scripts/verify.sh runs the package tests too.

Decisions
- Generated code is not committed. If the plugin refuses the symlink, use a committed COPY of the spec inside the package plus a script check in verify.sh that the copy equals contract/openapi.json (cmp); report which you used.
- Middleware order, outermost first: headers, request id, refresh-on-401, rate limit, version outdated, bearer auth. A replay after refresh therefore passes through bearer auth again and picks up the new token.
- Public operations (no bearer token attached, and no refresh attempted on a 401): exactly the operations in the spec that declare no security requirement. Derive the list from the spec and pin it in a unit test that reads the spec file and compares, so a spec change that adds or removes a public operation fails the test. The four public operations are: checkAppVersion, register, login, refreshToken.
- 401 handling: only for non-public operations. Call the app's SessionRefreshing seam once (single-flight across concurrent 401s: they all await ONE refresh), then replay the request once with the new token. Replay only when the request body is re-iterable (HTTPBody iterationBehavior multiple) or absent. If the refresh fails with a credential failure, do not replay and surface the typed session-expired error; if the refresh fails for any other reason, surface that failure and do not replay. A second 401 after a replay is surfaced as session-expired without another refresh. A 401 from a public operation (for example login with a wrong password) is surfaced as is.
- 426: never retry. Decode the error.details (minimumBuild, minimumVersion, latestBuild, latestVersion, manifestUrl, ipaUrl) leniently into a Sendable struct, call the app's version-outdated handler once per response, and surface the typed error. The response body must remain readable by the caller (buffer and rebuild it).
- 429: for GET and HEAD, retry up to 2 times, waiting the server's retryAfter (from error.details.retryAfter or the Retry-After header; cap one wait at 10 seconds and the total at 20 seconds; an injected sleeper in tests); for every other method never retry automatically; always surface the typed rate-limited error carrying retryAfter.
- Never log or print tokens, URLs, or bodies. The package has no logging.
- The package has no Sentry dependency. The request id is exposed through an injected closure.
- Money helpers: a pure function from the generated Double to Decimal rounded to two decimals (go through a two-decimal string, not arithmetic on the Double), and a pure function from Decimal to the Double that JSON encodes as the same two-decimal value; both tested with 0.1, 0.07, 19.99, 1234.5, 999999.99, 0, and -5.25.

Non-goals: any app code, repositories, domain models, the xcconfig hosts, AppConfiguration, API_MODE changes, auth flows, registration code, the version manager, linking the package into Xcode (Brian does it), the Sentry tagging itself.

Acceptance
- `swift test --package-path LocalPackages/TrackerAPI` passes; scripts/verify.sh is green including the new step and still reports the app's tests.
- The generator runs on the real contract/openapi.json with zero errors; every diagnostic it prints is listed in the findings report.
- Decoding tests prove the generated types accept the server's real formats: dates with and without fractional seconds, uuid, nullable fields, the allOf-based ListSummary and ListDetail, the anyOf-null coOwner, a Money value, the 426 details, and the Error envelope.
- Each middleware behavior in the Decisions has a passing test with a fake transport and no real time.
- No change to app code, the Xcode project, contract/, or the synced Docs files; the only edits to existing files are the ones named in SAFETY.

---

## Inventory

### Existing Network Layer

The existing hand-written network layer lives in `ChristmasTracker/ChristmasTracker/Core/Networking/`:

| File | Role |
|------|------|
| `APIClient.swift` | Protocol (`APIClient`) + `APIError` enum; generic `request<T>` method; no auth header, no X-Client-Platform, no cookie disabling, no 401 refresh |
| `NetworkAPIClient.swift` | Concrete implementation; appends X-App-Version, X-Platform, X-Device-Fingerprint; posts NotificationCenter on 401 (no refresh-and-replay); hand-decodes 426 into an old struct `VersionErrorResponse` with wrong field names (`updateUrl`, `currentVersion`); uses URLSession.shared (cookies enabled) |
| `MockAPIClient.swift` | In-memory stub for tests |
| `NetworkCache.swift` | Simple in-memory LRU cache keyed by path |

None of these files are touched by I1-a. The app integration is I1-b.

### Operations Table (from contract/openapi.json)

| operationId | Method | Path | Auth |
|-------------|--------|------|------|
| checkAppVersion | GET | /tracker/v2/app/version-check | **PUBLIC** |
| register | POST | /tracker/v2/auth/register | **PUBLIC** |
| login | POST | /tracker/v2/auth/login | **PUBLIC** |
| refreshToken | POST | /tracker/v2/auth/refresh | **PUBLIC** |
| getCurrentUser | GET | /tracker/v2/auth/me | bearerAuth |
| logout | POST | /tracker/v2/auth/logout | bearerAuth |
| createBudget | POST | /tracker/v2/budgets | bearerAuth |
| listBudgets | GET | /tracker/v2/budgets | bearerAuth |
| getBudget | GET | /tracker/v2/budgets/{year} | bearerAuth |
| updateBudget | PATCH | /tracker/v2/budgets/{year} | bearerAuth |
| deleteBudget | DELETE | /tracker/v2/budgets/{year} | bearerAuth |
| duplicateBudget | POST | /tracker/v2/budgets/{year}/duplicate | bearerAuth |
| createPurchase | POST | /tracker/v2/items/{itemId}/purchases | bearerAuth |
| getItem | GET | /tracker/v2/items/{id} | bearerAuth |
| updateItem | PATCH | /tracker/v2/items/{id} | bearerAuth |
| deleteItem | DELETE | /tracker/v2/items/{id} | bearerAuth |
| updateItemStatus | PATCH | /tracker/v2/items/{id}/status | bearerAuth |
| createItem | POST | /tracker/v2/lists/{listId}/items | bearerAuth |
| listItems | GET | /tracker/v2/lists/{listId}/items | bearerAuth |
| addMember | POST | /tracker/v2/lists/{id}/members | bearerAuth |
| listMembers | GET | /tracker/v2/lists/{id}/members | bearerAuth |
| removeMember | DELETE | /tracker/v2/lists/{id}/members/{userId} | bearerAuth |
| createList | POST | /tracker/v2/lists | bearerAuth |
| listLists | GET | /tracker/v2/lists | bearerAuth |
| getList | GET | /tracker/v2/lists/{id} | bearerAuth |
| updateList | PATCH | /tracker/v2/lists/{id} | bearerAuth |
| deleteList | DELETE | /tracker/v2/lists/{id} | bearerAuth |
| getPurchase | GET | /tracker/v2/purchases/{id} | bearerAuth |
| updatePurchase | PATCH | /tracker/v2/purchases/{id} | bearerAuth |
| listPurchases | GET | /tracker/v2/purchases | bearerAuth |
| updatePurchaseShipping | PATCH | /tracker/v2/purchases/{id}/shipping | bearerAuth |
| getStats | GET | /tracker/v2/stats | bearerAuth |
| getMe | GET | /tracker/v2/users/me | bearerAuth |
| updateMe | PATCH | /tracker/v2/users/me | bearerAuth |
| updatePassword | PATCH | /tracker/v2/users/me/password | bearerAuth |
| listChildren | GET | /tracker/v2/users/me/children | bearerAuth |
| createChild | POST | /tracker/v2/users/me/children | bearerAuth |
| deleteChild | DELETE | /tracker/v2/users/me/children/{id} | bearerAuth |
| getUser | GET | /tracker/v2/users/{id} | bearerAuth |

**Total: 39 operations. 4 public (no security requirement in spec), 35 authenticated.**

### Generator-Challenging Schema Constructs

| Schema / Location | Construct | Notes |
|-------------------|-----------|-------|
| `ListSummary` | `allOf` (2 refs: inline object + `CapabilityFlags`) | Generated type flattens both; access as direct properties |
| `ListDetail` | `allOf` (2 refs: `ListSummary` + inline `{members: [...]}`) | `ListDetail` extends `ListSummary`; `members` optional field |
| `ListSummary.coOwner` | `anyOf` with `PersonRef` or `null` | Generates as optional `PersonRef?` |
| `Item.expectedUnitPrice` | `anyOf` with `Money` or `null` | Generates as optional `Double?` (Money = number) |
| `StatsYearResponse.budget` | `anyOf` with `BudgetStats` or `null` | Generates as optional |
| `PurchaseResult` | `oneOf` with discriminator `status` (`created` / `confirmation_required`) | Generates as enum with associated values |
| `StatsResponse` | `oneOf` with discriminator `scope` (`year` / `all`) | Generates as enum with associated values |
| `getUser` 200 response | Inline `oneOf` (`User` / `ChildProfile` / `PersonSummary`) with no discriminator | May generate as `.undocumented` or as enum; mapping layer must handle |
| `ListRole` | Enum with hyphen: `co-owner` | Generator should use idiomatic naming; check generated Swift name (likely `coOwner`) |
| `Money` | `type: number, multipleOf: 0.01` | Generates as `Double`; `multipleOf` is a JSON Schema constraint only, not enforced by the generator at decode time |
| `MoneyAmount` | Same as `Money` | Separate schema used for request bodies |
| `PersonRef` / `PersonSummary` / `ChildProfile` | `additionalProperties: true` | Generator allows extra fields; decoded via struct with named properties |
| `PurchaseCreatedData.requiresConfirmation` | `enum: [false]` (boolean literal) | Unusual; generator may treat as a boolean constant |
| `PurchaseConfirmationRequiredData.requiresConfirmation` | `enum: [true]` (boolean literal) | Same |
| `Item.url`, `Item.imageUrl`, `Item.updatedAt` | `type: ["string", "null"]` | Standard nullable; generates as `String?` |
| `VersionOutdatedDetails` fields | Multiple `type: ["T", "null"]` | Standard nullables |
| Various date fields | `format: date-time` | Requires ISO 8601 transcoder supporting fractional seconds |

**Key risk:** `getUser` has an inline `oneOf` on the `200` response `data` field with no discriminator — the generator may not resolve this cleanly. The mapping layer (I1-b) will likely need to try-decode each variant.

---

## Gate 1: Story A1 — The Package, the Generator, and the Findings

**Interface introduced:** `TrackerAPI` package product; `TrackerDateTranscoder`; generated `Client` type and all generated schema types.

**Contract slice:** The generator consumes `contract/openapi.json`. No app code changes. New files only under `LocalPackages/TrackerAPI/`.

**Acceptance criteria:**
1. `swift build --package-path "LocalPackages/TrackerAPI"` exits 0.
2. The generator plugin runs on `contract/openapi.json` with zero build errors (warnings are recorded in the findings report; they are not a failure criterion).
3. `TrackerDateTranscoder` decodes ISO 8601 strings with and without fractional seconds into `Foundation.Date` and encodes to the without-fractional-seconds form.
4. Decoding tests (Swift Testing, `swift test`) cover every item in the Acceptance decoding bullet: dates ±fractional, uuid, nullable fields, `ListSummary` allOf (capability flags + base fields), `ListDetail` allOf, `coOwner` anyOf-null, `Money` number field, `VersionOutdatedDetails` 426 fields, the `Error` envelope.
5. No production Swift files hand-write any API model type.

**New interface:** `TrackerDateTranscoder` (struct, `DateTranscoder` from swift-openapi-runtime), the generated `Client` and all generated schema types.

**Scoped files/folders:**
- Create: `LocalPackages/TrackerAPI/` (new package)
- Create: `LocalPackages/TrackerAPI/Package.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerDateTranscoder.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi-generator-config.yaml`
- Create symlink: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml` → `../../../../contract/openapi.json`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/DecodingTests.swift`
- Create: `Docs/reports/I1a-1-generator-findings.md`
- Create: `Docs/reports/I1a-2-package-and-decoding.md`

---

## Gate 1: Story A2 — URLSession, Seams, Middleware, Errors, Money

**Interface introduced:** `TrackerURLSessionConfiguration`, `TrackerClientFactory`, seam protocols (`AccessTokenProviding`, `SessionRefreshing`, `VersionOutdatedHandling`, `RequestIDObserving`), `AppClientInfo`, middleware types, `TrackerAPIError` enum, money helpers.

**Contract slice:** No app code, no networking changes in the app. New files only under `LocalPackages/TrackerAPI/Sources/TrackerAPI/`.

**Acceptance criteria:**
1. `swift test --package-path "LocalPackages/TrackerAPI"` exits 0 with all middleware tests passing.
2. `TrackerURLSessionConfiguration` returns a `URLSessionConfiguration` with cookies fully disabled and correct timeouts; every setting is asserted by a test.
3. Each middleware (headers, request id, bearer, 401-refresh, 426, 429) has unit tests with a fake `ClientTransport`.
4. Concurrent 401s cause exactly one refresh call (single-flight test).
5. A non-re-iterable body is not replayed; a second 401 after replay gives session-expired without another refresh.
6. The public-operation set matches what the spec declares (test reads `contract/openapi.json`).
7. 429 retries GET up to 2 times with capped wait; never retries POST/DELETE; typed error carries retryAfter.
8. 426 calls handler once, leaves body readable, never retries.
9. Money helpers tested with all 7 required values; go through string conversion, not arithmetic.
10. `TrackerAPIError` covers every error code in `Docs/error-codes.md` that the client must act on.

**New interface:** All types listed above.

**Scoped files/folders:**
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerURLSessionConfiguration.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerClientFactory.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Seams.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/HeadersMiddleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RequestIDMiddleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/BearerAuthMiddleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RateLimitMiddleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/VersionOutdatedMiddleware.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerAPIError.swift`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/MoneyHelpers.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/URLSessionConfigurationTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/HeadersMiddlewareTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RateLimitMiddlewareTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/VersionOutdatedMiddlewareTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerAPIErrorTests.swift`
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/MoneyHelpersTests.swift`
- Create: `Docs/reports/I1a-3-middleware-errors-money.md`

---

## Gate 1: Story A3 — Verify Script, Build Flags, and Handoff

**Interface introduced:** None (script changes only).

**Contract slice:** `scripts/verify.sh` gains a `swift test` step for the package. `scripts/build.sh` and `scripts/test.sh` gain `-skipPackagePluginValidation`. `Docs/handoffs/` gains the handoff note.

**Acceptance criteria:**
1. `scripts/verify.sh` exits 0 and its output includes the `swift test` summary for `TrackerAPI`.
2. The app suite still reports 486 passed.
3. `scripts/build.sh` and `scripts/test.sh` include `-skipPackagePluginValidation` on the xcodebuild invocations.
4. The handoff note contains the "Brian's Xcode steps" section and all items from the prompt's open-risks list.
5. If the spec is copied instead of symlinked, verify.sh includes a `cmp` step.

**New interface:** None.

**Scoped files/folders:**
- Modify: `scripts/verify.sh`
- Modify: `scripts/build.sh`
- Modify: `scripts/test.sh`
- Create: `Docs/handoffs/2026-11-05-ios-to-brian-i1a.md`
- Create: `Docs/reports/I1a-4-verify-and-handoff.md`

---

## Fix Pass Gate 1

**Why:** Brian's review found defects H1–H7: the generator drops 5 nullable-field properties (ListSummary.coOwner, Item.expectedUnitPrice, YearStats.totalBudget, StatsYearResponse.budget, PurchaseConfirmationRequiredData.purchase); the factory omits the date transcoder; publicOperationIDs is duplicated and untested; doubleToDecimal manipulates private Decimal fields; isCredentialFailure omits 1013 and includes the unused 1007; RefreshOn401Middleware starts a second refresh for stale-token 401s; reports contain inaccuracies.

---

### Fix Pass Story G1: The Derived Client Spec

**Interface introduced:** `scripts/make-client-spec.sh`, committed derived spec `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` (replaces symlink), `SpecConformanceTests` suite.

**Contract slice:** No app code. Script and spec file only. The generator now produces optional Swift properties for the five previously-dropped fields; decoding tests are updated to assert nil/value on each field.

**Acceptance criteria:**
1. `scripts/make-client-spec.sh` runs without error, prints the transform count (must equal 5), exits non-zero if count ≠ 5; `--check` mode regenerates to a temp file, compares, exits non-zero on difference.
2. `scripts/verify.sh` gains a `make-client-spec.sh --check` step (placed before the app build).
3. The derived `openapi.json` differs from `contract/openapi.json` only by: 4 anyOf-null properties replaced with the non-null schema (coOwner, expectedUnitPrice, totalBudget, budget) and the 1 bare-null property removed (purchase); each removed from its object's `required` array.
4. The Swift package test `SpecConformanceTests` reads both files, applies the same transform in Swift, asserts the transformed-contract matches the derived file (via JSON re-serialization with sortedKeys), and asserts count == 5.
5. Decoding tests prove: coOwner null → `nil`; coOwner present → `PersonRef`; expectedUnitPrice 349.99 → `Double`; expectedUnitPrice null → `nil`; PurchaseConfirmationRequiredData with absent purchase field decodes; YearStats.totalBudget null → `nil` and present → `Double`; StatsYearResponse.budget null → `nil` and present (a `BudgetStats` value). Print the generated Swift property types of all 5 fields in the report.
6. After the transform the generator emits ONLY the refreshToken cookie-parameter warning (zero null-schema warnings).
7. All 85 existing tests still pass.

**Scoped files:**
- Create: `scripts/make-client-spec.sh`
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` (derived file)
- Delete: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml` (symlink)
- Modify: `scripts/verify.sh` (add --check step before build)
- Modify: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/DecodingTests.swift` (strengthen tests 5a, 5b, 6; add nullable-field tests for the other 3 fields)
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SpecConformanceTests.swift`
- Create: `Docs/reports/I1a-5-derived-spec.md`

---

### Fix Pass Story G2: Factory, Date Transcoder, Spec Pins

**Interface introduced:** `TrackerClientFactory.make` becomes `throws`; `publicOperationIDs` moves to a single shared constant in `Sources/TrackerAPI/PublicOperations.swift`; `TrackerClientFactoryTests` suite.

**Contract slice:** No app code, no new endpoints. Factory and middleware only.

**Acceptance criteria:**
1. `TrackerClientFactory.make` throws `TrackerAPIError.invalidServerURL` when the URL has: a non-http/https scheme, an empty host, or a non-empty non-"/" path; accepts `http://localhost:3010` and `https://api.bmalberta.com` and `https://api.bmalberta.com/`; proven by factory tests.
2. `TrackerClientFactory.make` passes `Configuration(dateTranscoder: TrackerDateTranscoder())` to `Client`; a factory-level test with a fake transport decodes a JSON body with ISO 8601 dates WITH fractional seconds and without; both pass.
3. All four required headers (`X-Platform`, `X-Build`, `X-App-Version`, `X-Client-Platform`) and a UUID `X-Request-Id` are present on every request; proven by a factory-level test.
4. Bearer token is on non-public requests and absent on public ones; proven by factory-level tests.
5. `publicOperationIDs` is defined ONCE in `PublicOperations.swift`; `BearerAuthMiddleware` and `RefreshOn401Middleware` both import the same constant; a test reads the derived spec and asserts the set of operationIds with no `security` requirement equals `publicOperationIDs`, and that every string in `publicOperationIDs` appears as an operationId in the spec.

**Scoped files:**
- Create: `LocalPackages/TrackerAPI/Sources/TrackerAPI/PublicOperations.swift`
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerAPIError.swift` (add `invalidServerURL` case)
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerClientFactory.swift` (make throwing, pass date transcoder, add transport seam)
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/BearerAuthMiddleware.swift` (use shared constant)
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift` (use shared constant)
- Create: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift`
- Modify: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SpecConformanceTests.swift` (add public-ops pin test)
- Create: `Docs/reports/I1a-6-factory-and-spec-pins.md`

---

### Fix Pass Story G3: Money, Error Codes, Single-Flight

**Interface introduced:** rewritten `doubleToDecimal` (no private Decimal fields); `classifyErrorCode(errorCode:) -> ErrorCodeClassification`; updated `isCredentialFailure`; stale-token replay in `RefreshOn401Middleware`.

**Contract slice:** No contract changes.

**Acceptance criteria:**
1. `doubleToDecimal` uses `String(format: "%.2f", value)` and `Decimal(string:locale:)` with `Locale(identifier: "en_US_POSIX")`; no private `_exponent`, `_length`, `_mantissa`, `_isNegative`, `_isCompact`, `_reserved` fields; `decimalToDouble` uses `NSDecimalNumberHandler` and `.doubleValue`.
2. Money tests assert Decimal VALUE equality (not `.description` strings) and that `JSONEncoder` output for the Double contains the two-decimal representation; covers 0.1, 0.07, 19.99, 1234.5, 999999.99, 0, -5.25, 0.1+0.2→0.3; NaN and positive/negative infinity each return nil from `doubleToDecimal`.
3. `isCredentialFailure(errorCode:)` returns true for 1005, 1006, 1013 and false for all others including 1007; every ACTIVE re-login code from `Docs/error-codes.md` is explicitly tested.
4. `classifyErrorCode(errorCode:) -> ErrorCodeClassification` returns `.reLogin` for 1005/1006/1013, `.refreshAndReplay` for 1002/1003/1004, `.forceUpdate` for 1014, `.notFound` for 404-range active codes, `.backOff` for 429/503/500 active codes, `.showMessage` for all others and unknown codes; tested for every ACTIVE code in the table.
5. `RefreshOn401Middleware` stores the bearer token of the failed request; when a 401 arrives and the current token from `AccessTokenProviding.accessToken()` DIFFERS from the failed-request token, it replays ONCE with the new token WITHOUT calling refresh (zero refresh calls); when they are equal (token not yet rotated by another caller), it proceeds with the existing single-flight refresh. Tests: stale-token 401 → zero refresh calls, one replay; concurrent fresh 401s → one refresh; both pass.

**Scoped files:**
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/MoneyHelpers.swift`
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerAPIError.swift` (add `ErrorCodeClassification` enum and `classifyErrorCode`)
- Modify: `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift`
- Modify: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/MoneyHelpersTests.swift`
- Modify: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerAPIErrorTests.swift`
- Modify: `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift`
- Create: `Docs/reports/I1a-7-money-codes-singleflight.md`
