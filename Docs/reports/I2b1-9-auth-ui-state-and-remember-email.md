# I2b-1 R7 Report: Loading State, Error Alert, Legacy Face ID, Remember Email, No Token Persistence

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R7 — Auth UI state fixes, remember email, stop persisting sessions
**Branch:** feat/i2b1-inactivity-lock
**Commit:** 7e4a90c — I2b-1: reset loading state, make the error alert dismissible, hide legacy Face ID sign-in, remember the email, and stop persisting sessions

---

## Defects Fixed

- **B5** — `login()`, `loginWithBiometric()`, `forgotPassword()` never reset `isLoading` on failure. Fixed by adding `defer { isLoading = false }` to all three (and `register()`).
- **B6** — Error alert in `LoginView` used `.constant(true)` — OK tap never cleared error. Fixed: `@State private var showError`, `.onChange(of: authService.error)`, `authService.clearError()` on dismiss.
- **B7** — `BiometricOptionView` in `LoginView` body used legacy Keychain-backed biometric sign-in. Removed from view body.
- **B8** — "Remember me" checkbox persisted tokens and silently restored sessions. Changed to remember-email-only via `RememberedEmailStore` (UserDefaults). `loadStoredSession()` replaced by `performLegacyKeychainCleanup()` (synchronous, deletes the two old Keychain keys from `init()`). Repository always receives `rememberMe: true` (required by contract; email/password login is always durable server-side).

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/RememberedEmailStoring.swift` — `RememberedEmailStoring` protocol + `RememberedEmailStore` struct; UserDefaults key `"login.rememberedEmail"`; `nonisolated(unsafe)` for Swift 6.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/RememberedEmailStoreTests.swift` — 4 tests.

## Files Changed

- `AuthenticationService.swift` — `defer { isLoading = false }` in `login()`, `loginWithBiometric()`, `forgotPassword()`, `register()`; `clearError()` added; `handleAuthSuccess(authData:)` — `rememberMe: Bool` parameter removed; `storeTokens(_:)` removed; `loadStoredSession()` replaced by `performLegacyKeychainCleanup()`.
- `LoginView.swift` — `@State private var showError: Bool`; `.onChange(of: authService.error)`; `authService.clearError()` on alert dismiss; `BiometricOptionView` removed from view body; `rememberMe` → `rememberEmail`; `.onAppear` seeds email and toggle from `emailStore`; on login saves/clears email.
- `ContentView.swift`, `ProfileView.swift`, `LogoutPathTests.swift`, `InactivityLockControllerTests.swift`, `SessionTeardownTests.swift` — `rememberMe:` → `rememberEmail:` call site updates.
- `AuthenticationServiceTests.swift` — 4 new tests (R7 group: `loginResetsIsLoadingOnFailure`, `loginResetsIsLoadingOnSuccess`, `forgotPasswordResetsIsLoadingOnReturn`, `clearErrorClearsServiceError`); existing `rememberMe:` → `rememberEmail:` label updates.

---

## verify.sh Output (post-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 257 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Results

**Convention reviewer:** PASS (13 hard blocks pass)

**Acceptance reviewer:** GATE 2 REJECT → Rework applied inline:
1. `storeTokens(_:)` method body still present (spec requires removal) — removed.
2. `handleAuthSuccess` retained unused `rememberMe: Bool` parameter — removed with all call sites updated.

**Convention reviewer (after rework):** Covered by prior PASS; both rework changes are strictly deletions.
**Acceptance reviewer (after rework):** Rework corrects both deviations; all 11 criteria substantively met.

---

## Deviations

None after the Gate 2 rework. However, the following defects were present in the R7 implementation and identified in Rework 3:

- **C1a** — `LoginView.handleLogin()` wrote to `RememberedEmailStore` BEFORE calling `authService.login()`, persisting a typo even on a failed login attempt. Corrected in Rework 3 R9.
- **C1b** — `AuthenticationService.login()`'s `rememberEmail` parameter was accepted but unused in the service; the email store writes were performed in `LoginView` instead. Corrected in Rework 3 R9 by moving email-store writes inside the service after successful login.
- **C1c** — `LoginView.onAppear` overwrote any in-progress typed text on every scene appearance, not just on first display. Corrected in Rework 3 R9 by seeding the email field once at init time via `loginInitialState(remembered:)`.

---

## Not Done or Partial

None. All R7 acceptance criteria were met at the time of this story; defects C1a, C1b, C1c were identified and corrected in Rework 3 R9.
