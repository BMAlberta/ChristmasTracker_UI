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
- Notification observers for `.unauthorizedRequest` and `.versionUpdateRequired` added in
  Story 2 — **removed in Rework Story R1** (see below).
- `ProfileView` logout button no longer calls `listService.clearCache()` — teardown handles
  all store clearing.
- `ChristmasTrackerApp` registered clearables with `sessionManager` via fire-and-forget Task —
  **replaced with deterministic registration in Rework Story R2** (see below).

### Story 3 — First-launch wipe of 4.4 legacy data
- `FirstLaunchWipe` struct (in `Features/Authentication/Services/FirstLaunchWipe.swift`):
  synchronous, nonisolated, injected with `UserDefaults`, `FileManager`, and
  `KeychainWiping`. `performIfNeeded()` removes `"savedEmail"` from UserDefaults,
  class-wide deletes `kSecClassGenericPassword` and `kSecClassInternetPassword` via
  `SecItemDelete`, and writes a versioned marker to UserDefaults (key
  `"v2.firstLaunchWipeVersion"`, value 1) only when all steps succeed.
- `ChristmasTrackerApp.init()` calls `FirstLaunchWipe().performIfNeeded()` as its first
  statement.

### Rework Story R1 — Real teardown reasons, notification observers removed
- Removed from `AuthenticationService`: notification observers for `.unauthorizedRequest` and
  `.versionUpdateRequired`, `setupNotificationObservers()`, `notificationObservers` array,
  `deinit`, and `nonisolated(unsafe)` annotation. These observers violated client-guide §3.6
  (401 must refresh-and-replay; 426 must block and prompt — not silent logout).
- `logout()` → `logout(reason: TeardownReason = .userLogout)` with reason forwarded to `teardown`.
- `refreshTokenIfNeeded()` failure now calls `logout(reason: .sessionExpired)`.
- `SessionManager` gained `private(set) var lastTeardownReason: TeardownReason?` for test observability.
- `TeardownReason.forcedUpdate` remains in the enum as an I1 entry point.

### Rework Story R2 — Deterministic clearable registration
- `SessionClearable.swift` gained `makeProductionClearables(...)` free function (5 clearables:
  `ListDataStore`, `ItemDataStore`, `ListService`, `ItemService`, `NetworkCache`).
- `SessionManager.init` gained `initialClearables: [any SessionClearable] = []` parameter.
- `ChristmasTrackerApp.init` now calls `makeProductionClearables(...)` synchronously and passes
  the result to `SessionManager.init` — the fire-and-forget `Task` is removed.
- `AuthenticationService` is excluded from the factory (circular dependency); it continues to
  self-clear in `logout()`.

### Out-of-scope toolchain fixes (justified)
The project build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (enabled by
`SWIFT_APPROACHABLE_CONCURRENCY = YES`) infers `@MainActor` on all types that lack explicit
isolation. This made `ListRepository`, `ItemRepository`, and several domain model types
`@MainActor`, preventing actor-based test mock conformances from compiling. Fixed by adding
`nonisolated` to protocol declarations and struct declarations, and `@MainActor` to
`Color`-returning computed properties. The Story 1 report incorrectly attributed this to
`InferIsolatedConformances`; the actual cause is `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
All changes are safe, backwards-compatible isolation annotations.

**Isolation edits actually made (verified by diff):**
- `ListRespository.swift`: `nonisolated` added to `protocol ListRepository` — 1 changed declaration, remaining changes are trailing whitespace removal.
- `ItemRepository.swift`: `nonisolated` added to `protocol ItemRepository` — 1 changed declaration, remaining changes are trailing whitespace removal.
- `GiftItem.swift`: `nonisolated` added to `struct GiftItem` and `struct ItemPerson`; `@MainActor` added to `ItemStatus.color` — 3 changed declarations.
- `GiftList.swift`: `@MainActor` added to `ListRole.color` — 1 changed declaration.
- `Purchase.swift`: `@MainActor` added to `ShippingStatus.color` — 1 changed declaration.

**`CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, and `ItemResponse` were not changed.**

Nothing under `Core/Networking` changed.

---

## What the API team must do

None for this package.

**Note for I1 (not API team work):** The `.unauthorizedRequest` and `.versionUpdateRequired`
notifications exist in `NetworkAPIClient`. I1 must wire the full 401 refresh-replay loop and
the 426 block-and-prompt flow. The `TeardownReason.forcedUpdate` entry point is ready.

---

## Test count

| Package end | Tests |
|---|---|
| Before I2a | 40 |
| After I2a-1 | 50 |
| After I2a-2 | 55 |
| After I2a-3 | 64 |
| After I2a-R1 | 64 (net 0: 2 removed, 2 added) |
| After I2a-R2 | **65** |

---

## Diff stat (master..HEAD, post-rework)

```
27 files changed, 2249 insertions(+), 54 deletions(-)
```

Full verbatim stat:

```
 .../ChristmasTracker/ChristmasTrackerApp.swift     |  29 +-
 .../Extensions/NetworkCache+SessionClearable.swift |  11 +
 .../ChristmasTracker/Core/Models/GiftItem.swift    |   8 +-
 .../ChristmasTracker/Core/Models/GiftList.swift    |   2 +-
 .../ChristmasTracker/Core/Models/Purchase.swift    |   2 +-
 .../Services/AuthenticationService.swift           |  40 +-
 .../Authentication/Services/FirstLaunchWipe.swift  | 100 +++++
 .../Authentication/Services/SessionClearable.swift |  31 ++
 .../Authentication/Services/SessionManager.swift   |  48 ++-
 .../Features/Items/DataStores/ItemDataStore.swift  |   8 +
 .../Items/Repositories/ItemRepository.swift        |  10 +-
 .../Features/Items/Services/ItemService.swift      |  21 +-
 .../Features/Lists/DataStores/ListDataStore.swift  |  10 +-
 .../Lists/Repositories/ListRespository.swift       |  12 +-
 .../Features/Lists/Services/ListService.swift      |  18 +-
 .../Features/Profile/Views/ProfileView.swift       |   2 -
 .../Authentication/FirstLaunchWipeTests.swift      | 305 ++++++++++++++
 .../Features/Authentication/LogoutPathTests.swift  | 262 ++++++++++++
 .../Authentication/MockSessionClearable.swift      |  50 +++
 .../Authentication/SessionTeardownTests.swift      | 332 +++++++++++++++
 Docs/epics/I2a-session-and-cache-hygiene.md        | 456 +++++++++++++++++++++
 Docs/handoffs/2026-11-03-ios-to-brian.md           |  93 +++++
 Docs/reports/I2a-1-teardown.md                     |  99 +++++
 Docs/reports/I2a-2-logout-paths.md                 |  86 ++++
 Docs/reports/I2a-3-first-launch-wipe.md            |  86 ++++
 Docs/reports/I2a-4-reasons-and-observer-removal.md |  98 +++++
 Docs/reports/I2a-5-registration.md                 |  84 ++++
 27 files changed, 2249 insertions(+), 54 deletions(-)
```

No `.pbxproj` touched. No `contract/`, `.claude/`, or synced Docs files touched.
**Nothing under `Core/Networking` changed.**

---

## Open risks

1. **Late-response risk**: Services (`ListService`, `ItemService`) have no in-flight task
   cancellation. A `loadLists()` task started before teardown can complete after stores are
   cleared and repopulate them. I1 should add task handles and cancel them at teardown start.

2. **Logout ordering risk**: `AuthenticationService.logout()` calls the server before local
   teardown. The server call can time out or fail; the teardown still runs (called after the
   network call regardless), but there is a window where the server sees the token as valid.

3. **On-device wipe test pending**: The first-launch wipe against a real Keychain has not been
   tested on device. A distribution certificate is required. This must be run before the first
   TestFlight or App Store build.

4. **426 session-clear question**: Whether a 426 (forced update) response should clear the
   session is an open question for I1. `TeardownReason.forcedUpdate` is available; the UX
   decision (clear vs. leave state for when the user updates) has not been made.

5. **TrackerInstrumentation package not linked**: `grep -n "TrackerInstrumentation"
   project.pbxproj` returns no matches. The `@Instrumented` macro package exists in the local
   package list but is NOT linked to the app target. Agents cannot edit `.pbxproj`. Brian must
   link the package in Xcode before I1. **I1 is blocked on this until it is done.**

---

## One line for PROGRAM.md section 9

> I2a (2026-11-03): session teardown with clearable registry (all stores cleared on every
> logout/session-end path), deterministic registration via factory init, real teardown reasons
> passed (no notification observers), first-launch 4.4 Keychain + UserDefaults wipe with
> versioned marker; 65 tests, 0 failures.
