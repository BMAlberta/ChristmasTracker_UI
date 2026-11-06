# Handoff — I1-a: Generated API Client Package (+ Fix Passes)
**Date:** 2026-11-05  
**Branch:** feat/i1a-api-client-package  
**From:** iOS (Claude)  
**To:** Brian

---

## What Changed

A new local Swift package `LocalPackages/TrackerAPI` now contains:

- **swift-openapi-generator** build-tool plugin (1.14.2) running on a committed derived spec at `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`; generates `Types.swift` and `Client.swift` at compile time — not committed
- **Derived spec** (`scripts/make-client-spec.sh`) — transforms `contract/openapi.json` to handle 5 nullable-field schemas the generator cannot process natively; `scripts/verify.sh` checks the derived spec is current before every build
- **`TrackerDateTranscoder`** — ISO 8601 date transcoder accepting both fractional-seconds and whole-seconds formats
- **`TrackerURLSessionConfiguration`** — cookies fully disabled, no credential storage, 30s/60s timeouts
- **`TrackerClientFactory.make`** — `throws TrackerAPIError.invalidServerURL` for bad URLs; assembles the full middleware stack and returns a configured `Client`
- **Seam protocols** — `AccessTokenProviding`, `SessionRefreshing`, `VersionOutdatedHandling`, `RequestIDObserving`, `RateLimitSleeping` — the app layer implements these
- **5 middleware types** (Headers, BearerAuth, RefreshOn401, RateLimit, VersionOutdated) in the correct order
- **`RefreshOn401Middleware`** — single-flight 401 refresh using NSLock + UUID nonce; every token expiry (not just the first) triggers a fresh refresh; stale-token detection skips refresh when a concurrent caller already rotated the token
- **`TrackerAPIError`** — typed error enum; `classifyErrorCode(errorCode:)` maps every ACTIVE error code to `.reLogin`, `.refreshAndReplay`, `.forceUpdate`, `.notFound`, `.backOff`, or `.showMessage`
- **`isCredentialFailure(errorCode:)`** — returns true for codes 1005, 1006, 1013 (NOT 1007, which is UNUSED)
- **`doubleToDecimal` / `decimalToDouble`** — string-intermediate money conversion helpers; `doubleToDecimal` returns `Decimal?` (nil for NaN/Infinity)
- **146 package tests** (Swift Testing), all passing on macOS via `swift test`
- **`scripts/verify.sh`** now runs `swift test --package-path "LocalPackages/TrackerAPI"` as a gate step

---

## Branch Commits (oldest → newest)

| Commit | Summary |
|--------|---------|
| `0ad658d` | Epic brief and inventory |
| `b49c760` | A1: package scaffold, generator, `TrackerDateTranscoder`, 11 decoding tests |
| `b0a3a54` | A2: URLSession config, middleware, error mapping, money helpers (74 tests) |
| `b88a4ff` | A3: package tests wired into `verify.sh` |
| `31a4a21` | Fix pass Gate 1 spec |
| `eed4b93` | G1: derived spec (`scripts/make-client-spec.sh`), `SpecConformanceTests` |
| `b92f546` | G2: factory `throws`, URL validation, `TrackerDateTranscoder` wired, `publicOperationIDs` consolidated |
| `95b7fe4` | G3: `doubleToDecimal` rewritten, `classifyErrorCode` added, stale-token replay |
| `3749f36` | G4: docs corrections |
| `9101e5c` | Second fix pass Gate 1 spec |
| `57a3122` | H1: `RefreshOn401Middleware` nonce fix — every expiry refreshes |
| `79c9474` | H2: fractional-second date decode tests through factory |

---

## Contract Issues Found

None. The package consumes the generated client only. No new endpoints were called against a live server.

**5 nullable fields** — resolved by the derived spec; these are now optional Swift properties:
- `ListSummary.value1.coOwner: Components.Schemas.PersonRef?`
- `Item.expectedUnitPrice: Components.Schemas.Money?` (= `Swift.Double?`)
- `YearStats.totalBudget: Components.Schemas.Money?`
- `StatsYearResponse.value1.budget: Components.Schemas.BudgetStats?`
- `PurchaseConfirmationRequiredData.purchase`: removed from spec (was bare null); no field exists

---

## What the API Team Must Do

Nothing.

---

## What Brian Must Do for I1-b

### Xcode setup (required before first build)

1. In Xcode: File → Add Package Dependencies → Add Local → select `LocalPackages/TrackerAPI`
2. Add `TrackerAPI` as a framework dependency on the `ChristmasTracker` app target
3. Build once (`Cmd+B`) — the generator plugin runs at build time and produces `Types.swift` and `Client.swift`; SourceKit may show "No such module 'TrackerAPI'" until after the first successful build
4. If the build-tool plugin asks for trust, grant it

### App integration

5. Implement `AccessTokenProviding` and `SessionRefreshing` on (or beside) `SessionManager`/`AuthStore`
6. Implement `VersionOutdatedHandling` — show a force-update sheet
7. Implement `RequestIDObserving` and `RateLimitSleeping` (can be trivial no-ops initially)
8. Call `TrackerClientFactory.make(serverURL:info:tokenProvider:sessionRefresher:versionOutdatedHandler:)` from the app's composition root; handle `throws TrackerAPIError.invalidServerURL`
9. Build the domain model mapping layer — `Components.Schemas.*` → app domain models. Key notes:
   - Money fields are `Swift.Double`; call `doubleToDecimal(_:)` at the boundary; handle `nil` return
   - Use `classifyErrorCode(errorCode:)` to decide what to do with server error codes
   - allOf schemas (e.g. `ListSummary`) expose payload via `.value1` / `.value2`
   - The 4 nullable fields above are `Optional` — map to domain `Optional` or provide defaults

### Open risks for I1-b

- `VersionOutdatedMiddleware` returns the 426 response without throwing — the repository layer calling the generated client must check `response.status.code == 426` and act (e.g. call `mapHTTPStatus`), or the outdated-version case is silently ignored
- `createPurchase` may return `200 { status: "confirmation_required" }` — the repository layer must inspect the response body's `status` field and show the budget confirmation flow
- `createItem` has NO `offList` field in the request body (it's server-derived from the caller's role); do not add it in domain mapping
- The generated client's `operationID` strings match the ones in `publicOperationIDs` in `BearerAuthMiddleware`; if new public operations are added to the contract in future, update that list

---

## Section 9 of PROGRAM.md (one line)

> I1-a complete: `LocalPackages/TrackerAPI` package with derived spec, 146 package tests, nonce-based refresh lifecycle fix, `classifyErrorCode`, stale-token replay, money helpers; I1-b wires into Xcode and builds domain mapping layer.
