# I2b-2b C1 Report: Generated Auth Repository, Models, and Service

**Story:** C1 — Generated auth repository, models, and service  
**Package:** I2b-2b  
**Date:** 2026-11-06  
**Branch:** feat/i2b2b-generated-auth  
**Commit:** a90965e

---

## What Changed

### New files
- `GeneratedClientAuthenticationRepository.swift` — actor implementing `AuthenticationRepository` via the generated `TrackerAPI` client. Handles all 4 auth operations (login, register, refresh, logout) with full response mapping for every documented case. Includes a `JSONSerialization`-based fallback decoder for 2xx responses whose strict decode fails due to extended role values not in `RolePayload` (see Contract Issues).
- `GeneratedClientAuthRepositoryTests.swift` — 22 tests covering all documented login/register/refresh/logout response cases via a real factory-built client with an injected fake transport.
- `MockAuthenticationRepositoryC1Tests.swift` — 6 tests for updated mock (new protocol signatures, error cases, `AuthSession` return type).
- `AuthSessionTests.swift` — 4 tests for `AuthSession` struct and `AuthTokens.needsRefresh`.

### Modified files
- `AuthTypes.swift` — deleted `LoginRequest`, `RegisterRequest`, `BiometricLoginRequest`, `RefreshTokenRequest`, `ForgotPasswordRequest`, `AuthResponse`, `AuthData`, `ResponseMeta`; added `AuthSession` struct.
- `User.swift` — updated to match `Components.Schemas.User`: added `firstName`, `lastName`, `displayName`, `isActive`, `lastLoginAt`; removed `name`.
- `AuthenticationRespository.swift` — protocol redefined to 4 methods returning `AuthSession`: `login(email:password:)`, `register(email:password:firstName:lastName:registrationCode:)`, `refresh(refreshToken:)`, `logout()`. All old methods removed.
- `MockAuthenticationRepository.swift` — updated to new protocol; `AuthenticationError` expanded with new cases (`invalidResponse`, `accountDisabled`, `updateRequired`, `rateLimited`, `serverError`, `invalidRegistrationCode`, `validationFailed`, `credentialExpired`, `emailAlreadyExists`).
- `AuthenticationService.swift` — updated all callers to new protocol signatures; `forgotPassword` removed; `handleAuthSuccess` now takes `AuthSession`; `forceRefresh` uses `AuthSession`.
- `BiometricSignInState.swift` — added `.credentialExpired` to `isCredentialFailure` check.
- `SessionManager.swift` — removed ping-related dead code (no production callers).
- `ForgotPasswordView.swift` — removed `forgotPassword` service call; now navigates to close directly (no network call; full informational screen change deferred to C2).
- `ChristmasTrackerApp.swift` — composition root updated: real mode builds `GeneratedClientAuthenticationRepository(client: generatedClient)`.

### Deleted files
- `NetworkAuthenticationRepository.swift` — hand-written auth network stack removed.
- `ErrorResponseModels.swift` — wire-format decoding structs removed.
- `NetworkAuthRepositoryRequestTests.swift` — 5 tests for deleted repository removed.
- `MockAuthenticationRepositoryTests.swift` — 10 tests for old `AuthData`-returning interface removed (old interface deleted by this story).

### Test files updated (inline mock conformances only)
- `LogoutPathTests.swift`, `SignInWithBiometricTests.swift`, `ObservableSnapshotTests.swift` — inline `AuthenticationRepository` mock implementations updated to new 4-method protocol with `AuthSession` return types. Test assertions unchanged.
- `AuthenticationServiceTests.swift` — deleted `forgotPasswordResetsIsLoadingOnReturn` test (forgotPassword method removed).

---

## Commands and Raw Output

**Pre-commit verify.sh:**
```
=== verify: unit tests ===
--- tests: 565 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed
=== verify: OK ===
```

**Post-commit verify.sh:**
```
=== verify: unit tests ===
--- tests: 565 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed
=== verify: OK ===
```

**Test delta from master baseline (549 app):**
- Added: 22 (GeneratedClientAuthRepositoryTests) + 6 (MockAuthRepositoryC1Tests) + 4 (AuthSessionTests) = +32
- Deleted: 5 (NetworkAuthRepositoryRequestTests) + 10 (MockAuthRepositoryTests) + 1 (forgotPassword) = -16
- Net: 549 + 32 − 16 = 565 ✓

---

## Gate 2 Verdicts

**Convention-reviewer (second pass):** PASS  
Hard blocks from first pass resolved (removed `import HTTPTypes`, removed hand-written Codable structs). `import OpenAPIRuntime` accepted for `ClientError` access (public type, not `@_spi`). Surfaced warning: `AuthenticationRepository` protocol naming (pre-existing, not introduced by this story).

**Acceptance-reviewer (second pass):** PASS  
All 40 acceptance criteria met. Prior blockers resolved: `AuthData`/`ResponseMeta` deleted, old protocol methods stripped, `forgotPassword` removed from service.

---

## Deviations

- `ForgotPasswordView` was partially updated (service call removed, now navigates to close directly) rather than the full informational redesign specified in C2. The C2 story will complete the UI change.
- `AuthenticationService.register(email:password:name:)` convenience overload kept on the service (not the protocol) to maintain compilation of existing test files (`AuthenticationServiceTests.swift`, `EnrollMarkerRegistrationTests.swift`). This overload splits the name and passes an empty registrationCode. It will be removed in C2 when the registration UI provides the new fields.
- `Components.Schemas.User.RolePayload` is `@frozen` with only `USER`/`ADMIN` — a `JSONSerialization`-based fallback decoder handles extended role values. See contract-issues.md row 2.

---

## Contract Issues Found

| # | Endpoint | Issue |
|---|---|---|
| 1 | POST /auth/login | `Operations.Login.Output` has no `.forbidden` case; 403 ACCOUNT_DISABLED arrives as `.undocumented(403, …)`. Backend should add `403 ForbiddenError` to the login operation in openapi.json. |
| 2 | All auth endpoints returning User | `Components.Schemas.User.RolePayload` is `@frozen` with only `USER`/`ADMIN`. Backend returns extended role values (`viewer`, `member`, `owner`, `blind_viewer`). Backend should add all role enum values and regenerate. |

---

## Not Done or Partial

- `ForgotPasswordView` informational redesign: partially done (service call removed); full UI redesign (C2 scope).
- `AuthenticationService.register(email:password:name:)` overload: temporary compat shim, to be removed in C2.
- SessionManager dead code (baseSessionDuration, pingInterval, maxSessionDuration, isSessionValid, stopSession, etc.): deferred to C2 per story scope.
