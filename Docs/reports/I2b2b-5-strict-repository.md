# I2b-2b F1 Report: Strict Repository (Fix Pass)

**Story:** F1 — Strict repository  
**Package:** I2b-2b (fix pass)  
**Date:** 2026-11-06  
**Branch:** feat/i2b2b-generated-auth  
**Commit:** (see below)

---

## What Changed

### Modified production files

- `GeneratedClientAuthenticationRepository.swift` — deleted all JSONSerialization-based fallback helpers (~250 lines): `collectResponseBody`, `extractErrorFields`, `lenientRoleMap`, `LenientDecodeResult`, `lenientDecodeAuthSession`, `reclassifyOrFallbackLogin`, `reclassifyOrFallbackRegister`, `reclassifyOrFallbackRefresh`, `reclassifyLogoutError`, `mapNumericErrorCode`. Rewrote error classification in all four methods: outer catch now has four clauses (`AuthenticationError` rethrow → `TrackerAPIError.rateLimited` → `ClientError` via `classifyClientError` → bare catch). Added `private nonisolated func classifyClientError` with three branches: `TrackerAPIError.rateLimited` underlyingError → `.rateLimited(retryAfter:)`; `URLError` underlyingError → `.networkError` (the OpenAPI runtime wraps transport errors in `ClientError`); anything else → `.invalidResponse`. Updated `.badRequest` arm in login and register to decode `r.body.json.error.message` and throw `.validation(message:)`. Updated `.tooManyRequests` arm to throw `.rateLimited(retryAfter: 0)` (unreachable due to RateLimitMiddleware for POST operations, kept for exhaustiveness). Note: `GeneratedClientAuthenticationRepository` is confirmed `final class`, not actor (C1 report incorrectly called it an actor).

- `MockAuthenticationRepository.swift` — updated `AuthenticationError` enum: `case validationFailed` → `case validation(message: String)`; `case rateLimited` → `case rateLimited(retryAfter: TimeInterval)`. Added `Equatable` conformance (synthesized; valid because all associated value types conform to `Equatable`). Updated `errorDescription` switch: `validation` returns message directly; `rateLimited` returns canned message regardless of `retryAfter`.

- `AuthErrorMessages.swift` — updated exhaustive switch: `case .validationFailed: return "..."` → `case .validation(let message): return message`; `case .rateLimited:` updated to compile with new associated-value form.

- `Docs/contract-issues.md` — deleted row 2 (RolePayload extended values). Row 1 (login 403 undocumented) kept verbatim. Row 2 was filed on a false premise: the `viewer`, `member`, `owner`, `blind_viewer` values are list membership roles, not user roles. `Components.Schemas.User.RolePayload` correctly has only `USER` and `ADMIN`.

### Modified test files

- `GeneratedClientAuthRepositoryTests.swift` — deleted 5 tests that exclusively asserted fallback behavior:
  - `loginSuccessMapsFields` — fixture used `role: "viewer"` which forces the JSONSerialization fallback path
  - `register400ThrowsValidationFailed` — asserted the renamed `.validationFailed` case
  - `login429ThrowsRateLimited` — asserted `.rateLimited` with no associated value
  - `refreshSuccessReturnsNewSession` — fixture used `role: "viewer"`
  - `registerSuccessReturnsSessionWithExpiresIn900` — fixture used `role: "viewer"`
  
  Added 8 tests (5 net after deletes):
  - `loginSuccessDecodesThroughGeneratedClient` — `role: "USER"`, full meta, asserts email/accessToken/refreshToken/expiresIn
  - `loginNilEmailThrowsInvalidResponse` — rebuilt fixture with `role: "USER"` and full meta
  - `login400ValidationThrowsWithMessage` — asserts `.validation(message: "Validation error")` from server body
  - `loginTransportFailureThrowsNetworkError` — transport throws `URLError`; expects `.networkError`
  - `login429ThrowsRateLimitedWithRetryAfter` — 3×429; asserts `.rateLimited(retryAfter: X)` where X > 0
  - `registerSuccessDecodesThroughGeneratedClient` — `role: "USER"`, full meta
  - `register400PasswordTooWeakThrowsValidationWithMessage` — asserts message carried verbatim
  - `register400PasswordMismatchThrowsValidationWithMessage` — asserts message carried verbatim
  - `refreshSuccessDecodesThroughGeneratedClient` — `role: "USER"`, full meta
  
  All kept error fixtures rebuilt to include full `meta` block with fractional-seconds timestamp (`"2026-11-02T00:00:00.000Z"`), `requestId`, `sessionId`.

- `AuthErrorMappingTests.swift` — test A5 (`validationFailedMapsToExpectedMessage`) replaced by `validationMessageReturnsServerMessage` which calls `.validation(message: "Password does not meet requirements")` and asserts verbatim pass-through. Test A9 (`rateLimitedMapsToExpectedMessage`) updated to call `.rateLimited(retryAfter: 60)`.

---

## Commands and Raw Output

**verify.sh:**
```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: unit tests ===
--- tests: 612 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed
=== verify: OK ===
```

**Test delta from C3/C4 baseline (609 app):**
- Deleted: 5 (fallback-behavior tests)
- Added (net new): 8 (loginSuccessDecodesThroughGeneratedClient + 7 others; loginNilEmailThrowsInvalidResponse was rebuilt in-place)
- Net: 609 − 5 + 8 = 612 ✓

---

## Gate 2 Verdicts

**Convention-reviewer (second pass after AC3 fix):** PASS  
`classifyClientError` confirmed `private nonisolated func`. No force unwraps in new branch. All four `@Instrumented` attributes intact. No `import HTTPTypes`, no Combine, no GCD.

**Acceptance-reviewer (second pass after AC3 fix):** PASS  
All 10 criteria met. AC3 fix confirmed: `classifyClientError` has three branches (rateLimited / URLError / other-ClientError→invalidResponse). `loginTransportFailureThrowsNetworkError` correctly routes URLError through branch 2. verify.sh 612/0/0.

**Key implementation detail discovered:** The OpenAPI runtime wraps ALL transport errors (including `URLError`) in `ClientError` before they reach the repository catch clauses. The bare `catch` after `ClientError` is therefore unreachable for transport failures. `classifyClientError` must inspect `underlyingError` to distinguish URLErrors from decoding errors.

---

## Deviations

- First acceptance pass FAILED on AC3: `classifyClientError` returned `.networkError` for all non-rate-limit `ClientError`s. Correct mapping is `ClientError` → `.invalidResponse` (with the URLError-in-underlyingError carve-out). Fixed in a second implementer pass.
- C1 report incorrectly described `GeneratedClientAuthenticationRepository` as an "actor" — it is a `final class`. Corrected here and will be corrected in the F2 docs corrections pass.

---

## Not Done or Partial

None. F1 is complete. F2 (handoff and report corrections) is next.
