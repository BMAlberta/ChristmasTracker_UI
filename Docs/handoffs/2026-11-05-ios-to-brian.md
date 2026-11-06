# Handoff — I1-a: Generated API Client Package
**Date:** 2026-11-05  
**Branch:** feat/i1a-api-client-package  
**From:** iOS (Claude)  
**To:** Brian

---

## What Changed

A new local Swift package `LocalPackages/TrackerAPI` now contains:

- **swift-openapi-generator** build-tool plugin (1.14.2) running on `contract/openapi.json` via a symlink; generates `Types.swift` and `Client.swift` at compile time — not committed
- **`TrackerDateTranscoder`** — ISO 8601 date transcoder accepting both fractional-seconds and whole-seconds formats
- **`TrackerURLSessionConfiguration`** — cookies fully disabled, no credential storage, 30s/60s timeouts
- **`TrackerClientFactory`** — assembles the full middleware stack and returns a configured `Client`
- **Seam protocols** — `AccessTokenProviding`, `SessionRefreshing`, `VersionOutdatedHandling`, `RequestIDObserving`, `RateLimitSleeping` — the app layer implements these
- **5 middleware types** (Headers, BearerAuth, RefreshOn401, RateLimit, VersionOutdated) in the correct order
- **`TrackerAPIError`** — typed error enum covering all client-visible HTTP status codes
- **`isCredentialFailure(errorCode:)`** — returns true for codes 1005, 1006, 1007
- **`mapHTTPStatus(_:retryAfter:versionDetails:)`** — HTTP status → typed error
- **`doubleToDecimal` / `decimalToDouble`** — string-intermediate money conversion helpers
- **85 package tests** (Swift Testing), all passing on macOS via `swift test`
- **`scripts/verify.sh`** now runs `swift test --package-path "LocalPackages/TrackerAPI"` as a gate step
- **`scripts/build.sh`** and **`scripts/test.sh`** have `-skipPackagePluginValidation` for when the package is wired into the Xcode project

Commits on this branch (since master):
- `0ad658d` — epic brief and Gate 1 specs
- `b49c760` — A1: package scaffold, generator, symlink, TrackerDateTranscoder, 11 decoding tests
- `b0a3a54` — A2: URLSession config, middleware, error mapping, money helpers (74 tests)
- *(A3 commit pending)*

---

## Contract Issues Found

None. The package consumes the generated client only; no new endpoints were called and no contract behavior was tested against a live server.

**Generator limitations recorded in `Docs/reports/I1a-1-generator-findings.md`:**

| Field | Schema | Generator behavior |
|---|---|---|
| `ListSummary.coOwner` | `anyOf: [$ref, null]` | Field dropped entirely (warning) |
| `Item.expectedUnitPrice` | `anyOf: [Money, null]` | Field dropped entirely (warning) |
| `PurchaseConfirmationRequiredData.purchase` | `anyOf: [$ref, null]` | Field dropped entirely (warning) |
| `YearStats.totalBudget` | `anyOf: [Money, null]` | Field dropped entirely (warning) |
| `StatsYearResponse.budget` | `anyOf: [Money, null]` | Field dropped entirely (warning) |

These fields will always be `nil` in the domain mapping layer (I1-b). The API team does not need to change anything; this is a generator limitation.

---

## What the API Team Must Do

Nothing. This package is entirely client-side. No server changes required.

---

## What Brian Must Do for I1-b

1. Wire `LocalPackages/TrackerAPI` into the Xcode project as a local package dependency
2. Implement `AccessTokenProviding`, `SessionRefreshing`, `VersionOutdatedHandling`, `RequestIDObserving` in the app (the existing `SessionManager`/`AuthStore` layer is the natural home)
3. Build the domain model mapping layer that maps `Components.Schemas.*` → app domain models; the 5 dropped fields above must be mapped as `nil` always
4. The `VersionOutdatedMiddleware` returns the 426 response without throwing — the repository layer calling the generated `Client` must inspect `response.status.code == 426` and throw `TrackerAPIError.versionOutdated` if needed; or call `mapHTTPStatus` after every response

---

## Accepted Deviations

1. **`RequestIDMiddleware.swift` merged into `HeadersMiddleware.swift`** — the Gate 1 spec listed a separate file; the X-Request-Id generation and observer callback are both present in `HeadersMiddleware`, making a separate file a 2-line pass-through. Accepted.

2. **`VersionOutdatedMiddleware` returns rather than throws** — the Gate 1 spec said "surface the typed error"; the test-writer's test contract required the response to be returned with a readable body. The middleware calls `handleVersionOutdated` and returns the buffered 426 response; it does not throw. The I1-b layer must decide whether to throw based on the status code. Accepted; recorded in `Docs/reports/I1a-3-middleware-errors-money.md`.

---

## Section 9 of PROGRAM.md (one line)

> I1-a complete: `LocalPackages/TrackerAPI` package with generated client, 5 middleware types, error taxonomy, money helpers, and 85 passing tests; app layer wiring deferred to I1-b.

---

## ERRATA — Fix Pass G1–G3 (2026-11-05)

The original I1-a package had defects H1–H7 found during review. A fix pass on the same branch corrected them. The following items in this handoff are **superseded**:

### 1. Spec delivery (H1)

~~"swift-openapi-generator build-tool plugin running on `contract/openapi.json` via a symlink"~~

The generator now runs on a **committed derived spec** at `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`. The derived spec is produced by `scripts/make-client-spec.sh`, which replaces 4 anyOf-null schemas and removes 1 bare-null property that the generator cannot handle. `scripts/verify.sh` checks this file is current before building. The symlink no longer exists.

### 2. The 5 nullable fields (H1)

The table in "Contract Issues Found" listing `ListSummary.coOwner`, `Item.expectedUnitPrice`, `PurchaseConfirmationRequiredData.purchase`, `YearStats.totalBudget`, `StatsYearResponse.budget` as "field dropped entirely" is **no longer accurate**. The derived spec causes the generator to emit these as optional Swift properties:
- `ListSummary.value1.coOwner: Components.Schemas.PersonRef?`
- `Item.expectedUnitPrice: Double?`
- `StatsYearResponse.budget: Components.Schemas.BudgetStats?` (via `value1`)
- `YearStats.totalBudget: Double?`
- `PurchaseConfirmationRequiredData.purchase`: property removed from spec (was bare null)

**Updated I1-b instruction** (replaces item 3 under "What Brian Must Do"):  
Map the 4 optional fields to their domain model equivalents — nil when absent, the typed value when present. The `purchase` field is not in the generated schema; ignore it.

### 3. `isCredentialFailure` (H4)

~~"returns true for codes 1005, 1006, 1007"~~

Now returns true for **1005, 1006, 1013** (`REFRESH_TOKEN_MISSING`). Code 1007 is UNUSED per `Docs/error-codes.md` and returns false.

New: `classifyErrorCode(errorCode: Int) -> ErrorCodeClassification` added to `TrackerAPIError.swift` — maps every ACTIVE error code to one of `.reLogin`, `.refreshAndReplay`, `.forceUpdate`, `.notFound`, `.backOff`, `.showMessage`.

### 4. `doubleToDecimal` implementation (H5)

~~"MoneyHelpers uses internal Decimal fields (_exponent, _length, etc.)"~~

Rewritten. Now uses `String(format: "%.2f", value)` + `Decimal(string:locale:)` only. Returns `Decimal?` (nil for NaN/Infinity). No private Decimal fields.

### 5. Single-flight stale-token detection (H6/H7)

`RefreshOn401Middleware` now captures the access token before each request. If a 401 arrives and the current token already differs from the request token (rotated by a concurrent caller), it replays once without a second refresh call.

### 6. Test count

~~"85 package tests"~~ → **141 package tests** after the fix pass.

### Section 9 correction

> I1-a + fix pass complete: `LocalPackages/TrackerAPI` package with generated client (derived spec), 5 middleware types, `classifyErrorCode`, stale-token replay, money helpers, and 141 passing tests; app layer wiring deferred to I1-b.
