# I2b-1 R9 Report: Remember-Email Correctness and Legacy-Cleanup Seam

**Package:** I2b-1 — Inactivity lock (local half of I2b)
**Story:** R9 — Remember-email correctness and legacy-cleanup seam (Rework 3)
**Branch:** feat/i2b1-inactivity-lock
**Commit:** 3a69e57 — I2b-1: remember the email only after a successful login and seed the login screen once

---

## Defects Fixed

- **C1a** — `LoginView.handleLogin()` wrote to the email store BEFORE calling `authService.login()`, persisting a typo even on a failed login attempt.
- **C1b** — `AuthenticationService.login()`'s `rememberEmail` parameter was accepted but unused; the store write in `handleLogin()` bypassed it entirely.
- **C1c** — `LoginView.onAppear` overwrote any in-progress typed text on every scene appearance, not just on first display.

---

## Files Added

- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/LegacyTokenCleaning.swift` — `LegacyTokenCleaning` protocol (`-ing` suffix) and `LegacyTokenCleanup` struct; body extracted from the now-deleted `performLegacyKeychainCleanup()` method in `AuthenticationService`.

## Files Changed

- `AuthenticationService.swift` — Added `private var emailStore: any RememberedEmailStoring` and `private let legacyCleanup: any LegacyTokenCleaning` stored properties; expanded `init` to accept both with concrete defaults (`RememberedEmailStore()` and `LegacyTokenCleanup()`) so existing callers are unaffected; replaced `performLegacyKeychainCleanup()` call in `init` with `legacyCleanup.cleanUpLegacyTokens()`; removed `performLegacyKeychainCleanup()` method; added email-store writes inside the `do` block of `login()` AFTER `await handleAuthSuccess(authData:)` — `emailStore.rememberedEmail = email` when `rememberEmail == true`, `emailStore.rememberedEmail = nil` when `rememberEmail == false`; catch branches unchanged (no store writes on failure).
- `LoginView.swift` — Added `internal nonisolated func loginInitialState(remembered: String?) -> (email: String, rememberEmail: Bool)` pure free function at module scope; replaced inline `@State` defaults with a custom `init()` that seeds `_email` and `_rememberEmail` via `State(wrappedValue:)` using `loginInitialState(remembered: RememberedEmailStore().rememberedEmail)` — called once at init, never again; removed `@State private var emailStore = RememberedEmailStore()`; removed `.onAppear` block; removed email-store writes from `handleLogin()`.
- `AuthenticationServiceTests.swift` — Added `import Foundation` (required for `UUID`/`UserDefaults` visibility under `MemberImportVisibility`; test-writer omission); added `FakeLegacyTokenCleanup` class and `MockAuthenticationRepository.setFail(_:)` extension before the suite; added `makeSUTWithEmailStore()` factory inside the suite; added 12 new tests in `MARK: - R9`.
- `RememberedEmailStoreTests.swift` — Added 2 new tests in `MARK: - R9` for `loginInitialState(remembered:)`.

---

## verify.sh Output (pre-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 271 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## verify.sh Output (post-commit)

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 271 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Results

**Convention reviewer:** PASS (all 13 hard blocks). Pre-existing warning surfaced: commented-out `EnvironmentKey` block at `AuthenticationService.swift:328–341`, not introduced by R9.

**Acceptance reviewer:** PASS. All nine acceptance criteria explicitly verified. Structural note: AC5 tests pre-seed the email store via a local `mutableStore` copy (struct sharing the same `UserDefaults` backing as the service's injected instance); this is architecturally correct.

---

## Deviations

- `import Foundation` added to `AuthenticationServiceTests.swift` — omitted by the test-writer; required for `UUID`/`UserDefaults` visibility under the project's `MemberImportVisibility` compiler setting. One-line test-only addition; does not affect production code.

---

## Not Done or Partial

None. All R9 acceptance criteria met.
