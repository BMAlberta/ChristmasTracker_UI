# Handoff: Package I2a — Session and Cache Hygiene
**Date:** 2026-11-03  
**Branch:** `feat/i2a-session-hygiene`  
**From:** iOS  
**To:** Brian (for PROGRAM.md and merge decision)

---

## Contract issues found

None. This package has no networking work. The contract is PRE-CONFORMANCE; no API models
were created or modified.

---

## What changed

### Story 1 — Session teardown and clearable stores
- `SessionClearable` protocol (`AnyObject, Sendable`, one method `clearForSession() async throws`)
  and `TeardownReason` enum added to `Features/Authentication/Services/SessionClearable.swift`.
- `SessionManager` actor gained `clearables: [any SessionClearable]`, `register(_:)`, and
  `teardown(reason:)`. Teardown cancels the ping task, iterates all clearables with per-item
  do-catch (one failure never blocks others), and clears `URLCache` and `HTTPCookieStorage`.
- `SessionClearable` conformances added to: `ListDataStore`, `ItemDataStore`, `ListService`,
  `ItemService`, `AuthenticationService` (in same file, for `private` method access), and
  `NetworkCache` (in a new `Core/Extensions/NetworkCache+SessionClearable.swift`).

### Story 2 — Route all session-ending paths through teardown
- `AuthenticationService.logout()` rewritten: network call first, then
  `await sessionManager.teardown(reason: .userLogout)`, then `clearAuthState()` +
  `clearStoredTokens()`.
- Notification observers for `.unauthorizedRequest` and `.versionUpdateRequired` wired
  into `AuthenticationService.init()` (not `ContentView`). Each observer dispatches
  `Task { @MainActor [weak self] in await self?.logout() }`. Observers removed in `deinit`
  via `nonisolated(unsafe) var notificationObservers`.
- `ProfileView` logout button no longer calls `listService.clearCache()` — teardown handles
  all store clearing.
- `ChristmasTrackerApp` registers all six clearables with `sessionManager` at init time.

### Story 3 — First-launch wipe of 4.4 legacy data
- `FirstLaunchWipe` struct (in `Features/Authentication/Services/FirstLaunchWipe.swift`):
  synchronous, nonisolated, injected with `UserDefaults`, `FileManager`, and
  `KeychainWiping`. `performIfNeeded()` removes `"savedEmail"` from UserDefaults,
  class-wide deletes `kSecClassGenericPassword` and `kSecClassInternetPassword` via
  `SecItemDelete`, and writes a versioned marker to UserDefaults (key
  `"v2.firstLaunchWipeVersion"`, value 1) only when all steps succeed.
- `ChristmasTrackerApp.init()` calls `FirstLaunchWipe().performIfNeeded()` as its first
  statement.

### Out-of-scope toolchain fixes (justified)
Swift 6.3.3 / iOS 26 SDK `InferIsolatedConformances` was inferring `ListRepository`,
`ItemRepository`, and several model types as `@MainActor`, making test mock conformances
impossible. Fixed by adding `nonisolated` to the protocol declarations and model struct
declarations. These are safe, backwards-compatible isolation annotations.

---

## What the API team must do

None for this package.

**Note for I1 (not API team work):** The `.unauthorizedRequest` and `.versionUpdateRequired`
observers are wired in `AuthenticationService`. The `NetworkAPIClient` must post these
notifications at the right moments (401-after-refresh, 426 response). That wiring belongs
to I1's network client work. The current I2a changes are a clean prerequisite.

---

## Test count

| Package end | Tests |
|---|---|
| Before I2a | 40 |
| After I2a-1 | 50 |
| After I2a-2 | 55 |
| After I2a-3 | **64** |

---

## Diff stat

24 files changed, 1810 insertions(+), 44 deletions(−).

No `.pbxproj` touched. No `contract/`, `.claude/`, or synced Docs files touched.

---

## One line for PROGRAM.md section 9

> I2a (2026-11-03): session teardown with clearable registry (all stores cleared on every
> logout/session-end path), first-launch 4.4 Keychain + UserDefaults wipe with versioned
> marker, notification observers for unauthorized and forced-update paths; 64 tests, 0
> failures.
