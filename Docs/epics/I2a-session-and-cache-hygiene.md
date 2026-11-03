# I2a: Session and cache hygiene
Track: iOS. Depends on: nothing. Blocks: I2b (the auth token store registers with the teardown), I1.
Contract state at start: PRE-CONFORMANCE (no networking or API model changes).

Why: this is a gift-coordination app whose core promise is not leaking surprises. After a logout, a shared family device must hold no list, item, purchase, or credential data from the previous user. v2 replaces 4.4 in place: Keychain items and UserDefaults from 4.4 survive the update (Keychain items even survive uninstall), so 4.4's credentials, saved host, settings, and cached data must be wiped once on first launch.

Scope
1. One session teardown, the single entry point every session-ending path calls. It clears all user-scoped data: ListDataStore, ItemDataStore, the in-memory state held by ListService, ItemService, and AuthenticationService, NetworkCache, cookies and URLCache, on-disk caches, auth Keychain items, and user-scoped UserDefaults keys. It does not depend on the network.
2. Every existing session-ending path calls it, with a test per path. Ad hoc clearing in views and services is removed.
3. A first-launch wipe of 4.4's stored credentials, saved host, settings, and cached data, once, before any store reads or UI.

Decisions
- Device-level settings (appearance, and anything else the inventory classifies as device-level) are not session data. Teardown and the first-launch wipe both preserve them. Teardown removes explicit user-scoped keys, never the whole UserDefaults domain.
- Everything user-scoped is cleared on logout, including the refresh token and any biometric token.

Non-goals: new auth, Keychain with biometrics (I2b), API models or networking, the API base URL and xcconfig hosts (deferred to I1), app-switcher snapshot privacy (queued as I2c), removing New Relic or adding Sentry (I6a).

Design rules
- Reuse the existing SessionManager if it is the session coordinator. If you do not extend it, justify that in the Gate 1 spec.
- One async teardown entry point taking a reason (for example userLogout, sessionExpired). It is idempotent.
- Components register as clearable through a small -ing protocol, so I2b's token store adds itself without editing teardown logic. Clearables work across actors and @MainActor types, and datastores are actors.
- One failing clearable never stops the others. Failures are collected and logged through the existing Logger without values. The app always ends in the signed-out state.
- The first-launch wipe is gated by a versioned marker written only after every wipe step succeeds. A failed wipe retries on the next launch. Later launches never wipe, so v2 data is safe. Because Keychain items survive uninstall, a reinstall re-runs the wipe, which is correct.
- Swift 6 strict concurrency stays clean with no new warnings. Any @unchecked Sendable is justified in the report.
- Dependencies (keychain, defaults, file manager, stores) are injected through protocols, so tests use fakes, an isolated UserDefaults suite, and temporary directories. No test touches the real Keychain or UserDefaults.standard.

Acceptance
- Teardown empties every inventoried store (tests and inspection).
- Every session-ending path calls teardown (one test each).
- The wipe clears every inventoried 4.4 item, runs once, and is a no-op on a fresh install apart from the marker.
- scripts/verify.sh is green. No change under contract/, .claude/, the synced Docs files, API models, or networking behavior.

---

## Inventory

### User-scoped stores (current master)

All items were verified by reading the indicated files. "Cleared today" means the behaviour on the current master branch.

| # | Component | File : line | What it holds | Cleared today | Classification |
|---|-----------|-------------|---------------|---------------|----------------|
| 1 | `ListDataStore` (actor) | `Features/Lists/DataStores/ListDataStore.swift:84` | `listSummaries [GiftList]`, `listDetails [String:ListDetail]`, `lastFetch` | `clear()` exists; called via `ListService.clearCache()` from `ProfileView` before logout | **user-scoped** |
| 2 | `ItemDataStore` (actor) | `Features/Items/DataStores/ItemDataStore.swift:66` | `itemsByList [String:[GiftItem]]`, `lastFetchByList` | `clearAll()` exists **but is never called at logout** | **user-scoped** |
| 3 | `NetworkCache` (actor) | `Core/Networking/NetworkCache.swift:96` | In-memory response dict keyed by path + session ID | `clear()` called in `AuthenticationService.logout()` line 149 | **user-scoped** |
| 4 | `AuthenticationService` in-memory state (`@MainActor`) | `Features/Authentication/Services/AuthenticationService.swift:303–308` | `currentUser`, `isAuthenticated`, `tokens`, `error` | `clearAuthState()` called via `defer` in `logout()` | **user-scoped** |
| 5 | `SessionManager` keep-alive state (actor) | `Features/Authentication/Services/SessionManager.swift:47–53` | `sessionStartTime`, `lastActivityTime`, `pingTask: Task` | `stopSession()` called in `AuthenticationService.logout()` line 148 | **user-scoped** |
| 6 | Auth Keychain items | `Features/Authentication/Services/AuthenticationService.swift:309–319` | `auth.tokens`, `auth.refresh_token`, `auth.user_id`, `auth.biometric_token` (all `kSecClassGenericPassword`, no explicit service/accessGroup) | `clearStoredTokens()` called in `logout()` line 158 | **user-scoped** |
| 7 | `ListService` in-memory state (`@MainActor`) | `Features/Lists/Services/ListService.swift:210–214` | `lists`, `currentListDetail`, `isLoading`, `error`, `lastUpdated` | `clearCache()` called from `ProfileView` line 70 (ad hoc, before logout) | **user-scoped** |
| 8 | `ItemService` in-memory state (`@MainActor`) | `Features/Items/Services/ItemService.swift:211–214` | `items`, `currentListId`, `currentItem`, filter flags | `clearItems()` exists line 211 **but is never called at logout** | **user-scoped** |
| 9 | `DeviceFingerprintService` Keychain | `Core/Security/DeviceFIngerprintService.swift:16` | UUID: key `com.christmastracker.deviceFingerprintUUID`, `kSecClassGenericPassword` | Never cleared (intentional) | **device-level** — identifies the device, not the user |
| 10 | `URLCache.shared` / `HTTPCookieStorage.shared` | (system) | HTTP response cache; cookies (none observed being written in v2) | Never explicitly cleared | **user-scoped** (cleared as precaution) |
| 11 | UserDefaults | n/a | No `UserDefaults` or `@AppStorage` usage found in master (grep returned empty) | n/a | n/a |

**Confirmed from code reading:**
- `ItemDataStore` is NOT cleared at logout (no call to `clearAll()` anywhere on the logout path).
- `ProfileView` line 70 calls `listService.clearCache()` before `authService.logout()` — this ad hoc clearing is what Story 2 removes.
- No on-disk user caches found in master.

### Session-ending paths (current master)

| Path | File : line | Current clearing | Notes |
|------|-------------|-----------------|-------|
| Profile logout button | `Features/Profile/Views/ProfileView.swift:68–73` | Calls `listService.clearCache()` (ad hoc) then `authService.logout()` | Ad hoc clearing removed in Story 2; reason: `userLogout` |
| Token refresh failure | `Features/Authentication/Services/AuthenticationService.swift:176–179` | Calls `logout()` | No ad hoc clearing; reason: `sessionExpired` |
| 401 Unauthorized (server response) | `Core/Networking/NetworkAPIClient.swift:146–150` | Posts `.unauthorizedRequest` notification | **No observer registered in master.** Entry point exists; full wiring deferred to I1. Reason: `sessionExpired` |
| 426 Force Update (server response) | `Core/Networking/NetworkAPIClient.swift:153–168` | Posts `.versionUpdateRequired` notification | **No observer registered in master.** Entry point exists; full wiring deferred to I1. Reason: `forcedUpdate` |
| Account deletion | Not found in master | — | Not present; not in scope |
| Mock/real switch | Not found in master (only DEBUG preprocessor in `ChristmasTrackerApp`) | — | No session-ending path |

**In-flight task handles:** `SessionManager.pingTask` (actor-isolated) is the only in-flight task handle found. There are no task handles in services or view models. Late-response risk for service loads (e.g. a `loadLists()` completing after teardown) is noted as a recommendation for I1.

### 4.4 legacy inventory (read-only via `legacy/4.4`, not checked out)

Searched using `git grep -n -E "UserDefaults|Keychain|SecItem|kSecClass|AppStorage|config.json|FileManager" legacy/4.4 -- "*.swift"`.

**UserDefaults keys (4.4):**

| Key | Where set | Where read | Classification |
|-----|-----------|------------|----------------|
| `"savedEmail"` | `MIddleware/AsyncHandlers/UserActionHandler.swift:30` | `Views/Login/LoginView.swift:15`, `Views/Profile/ProfileView.swift:105` (removes on logout) | **user-scoped** — saved email for login convenience |
| Dynamic education IDs (via `@AppStorage(educationModel.educationId)`) | `Views/Education/EducationViewModel.swift:21,26` | Same file | **user-scoped** — "have you seen this walkthrough" flags. Exact IDs are runtime values set by the server config; cannot enumerate specific keys. See note below. |

> Education IDs note: because the keys are runtime strings from a server-provided `EducationModel`, exact key names are unknown at wipe time. The first-launch wipe will remove only explicitly known keys (`savedEmail`). The education flags are low-risk stale data since the feature does not exist in v2.

**Keychain items (4.4):**

| Class | Service | Accounts | Classification |
|-------|---------|----------|----------------|
| `kSecClassGenericPassword` | `com.alberta.ChristmasTracker` | `biometricUserId`, `biometricCredentials` | **user-scoped** — biometric credentials |

> No explicit `kSecAttrAccessGroup` was found, so items are app-bundle-scoped.
> The v2 `KeychainService` does not use a `kSecAttrService` attribute (stores by `kSecAttrAccount` key only), which means 4.4's service-keyed items will persist separately. The first-launch wipe must do a class-wide `kSecClassGenericPassword` delete to catch them.

**File paths (4.4):**

| Path | Type | Classification |
|------|------|----------------|
| None | — | No local file storage found. `config.json` is a remote fetch URL (not a local file path). |

**Device-level settings (4.4):**

`darkModeEnabled` in `Views/Profile/ProfileView.swift:12` is a transient `@State`, not persisted to UserDefaults or Keychain. No other device-level preferences were found in 4.4.

---

## Gate 1 Spec

### Decision: extend SessionManager

`SessionManager` is the existing session coordinator. `AuthenticationService` already calls `sessionManager.stopSession()` and `startSession()`. Extending `SessionManager` with `teardown(reason:)` and `register(_:)` keeps the session lifecycle in one actor and satisfies I2b extensibility without coupling stores to auth. **Decision: extend SessionManager.**

### Protocol and type signatures

```swift
// NEW: Features/Authentication/Services/SessionClearable.swift

/// Implemented by any component that holds user-scoped state.
/// Registered with SessionManager; called on every teardown regardless of others' failures.
protocol SessionClearable: AnyObject, Sendable {
    func clearForSession() async throws
}

enum TeardownReason: Sendable {
    case userLogout
    case sessionExpired
    case forcedUpdate
}
```

```swift
// MODIFIED: Features/Authentication/Services/SessionManager.swift
// (new methods added to the actor body)

actor SessionManager {
    // existing state + new:
    private var clearables: [any SessionClearable] = []

    /// Register a component to be cleared on every teardown.
    func register(_ clearable: any SessionClearable)

    /// Single entry point for all session-ending paths.
    /// Idempotent: safe to call twice.
    /// Order: cancel pingTask → clear all clearables (never aborts early) → clear URLCache + cookies.
    func teardown(reason: TeardownReason) async
}
```

```swift
// MODIFIED: each conforming type adds SessionClearable in an extension

// ListDataStore (actor) – calls existing clear()
extension ListDataStore: SessionClearable {
    func clearForSession() async throws
}

// ItemDataStore (actor) – calls existing clearAll()
extension ItemDataStore: SessionClearable {
    func clearForSession() async throws
}

// ListService (@MainActor) – clears lists, currentListDetail; public clearCache() removed
extension ListService: SessionClearable {
    func clearForSession() async throws
}

// ItemService (@MainActor) – clears items, currentListId, currentItem, filter flags
extension ItemService: SessionClearable {
    func clearForSession() async throws
}

// AuthenticationService (@MainActor) – clears in-memory tokens+state + Keychain items
extension AuthenticationService: SessionClearable {
    func clearForSession() async throws
}

// NEW: Core/Extensions/NetworkCache+SessionClearable.swift
// (extension outside Core/Networking per brief)
extension NetworkCache: SessionClearable {
    func clearForSession() async throws
}
```

```swift
// NEW: Features/Authentication/Services/FirstLaunchWipe.swift  (Story 3)

/// Protocols for injection in tests.
protocol KeychainWiping: Sendable {
    func deleteAllGenericPasswords() throws
    func deleteAllInternetPasswords() throws
}

struct FirstLaunchWipe {
    static let markerVersion: Int = 1
    static let markerKey: String = "v2.firstLaunchWipeVersion"

    // injected for testability
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let keychainWiper: any KeychainWiping

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        keychainWiper: any KeychainWiping = LiveKeychainWiper()
    )

    /// Runs synchronously at app entry before any store reads or UI.
    /// No-op if marker == markerVersion. Writes marker only after all steps succeed.
    func performIfNeeded()
}

struct LiveKeychainWiper: KeychainWiping {
    func deleteAllGenericPasswords() throws
    func deleteAllInternetPasswords() throws
}
```

### @Instrumented note

The `@Instrumented` macro and Sentry SDK are not yet present in the codebase (deferred to I6a). New `async`/`throws` functions in this package must NOT use `@Instrumented` because the macro does not compile. This is a known deviation from coding-standards; each story report notes it. The convention reviewer must not block on its absence.

### Story split

#### Story 1 — Session teardown and clearable stores (new interface: **yes**)

Failing tests first, then implementation.

Scoped files:
- NEW: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionManager.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Lists/DataStores/ListDataStore.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Items/DataStores/ItemDataStore.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Lists/Services/ListService.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Items/Services/ItemService.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`
- NEW: `ChristmasTracker/ChristmasTracker/Core/Extensions/NetworkCache+SessionClearable.swift`
- NEW: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift`
- NEW: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/MockSessionClearable.swift`

Core/Networking files touched: **none** (NetworkCache conformance lives in `Core/Extensions/`).

Acceptance tests:
1. After teardown: `ListDataStore` is empty (no lists, no details).
2. After teardown: `ItemDataStore` is empty (no items).
3. After teardown: `ListService.lists` is empty and `currentListDetail` is nil.
4. After teardown: `ItemService.items` is empty and `currentListId` is nil.
5. After teardown: `AuthenticationService.isAuthenticated` is false and `currentUser` is nil.
6. After teardown: `NetworkCache` returns nil for a previously set key.
7. One failing clearable does not stop subsequent clearables (all run).
8. Calling teardown twice is safe (idempotent).
9. The app reaches the signed-out state (`isAuthenticated == false`) even when a clearable throws.
10. Device-level settings (simulated via a test-injected defaults suite) survive teardown.

#### Story 2 — Route every session-ending path (new interface: **no**)

Scoped files:
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (update `logout()` to call `sessionManager.teardown(reason: .userLogout)`; remove direct `NetworkCache.shared.clear()`, `stopSession()`, `clearAuthState()`, `clearStoredTokens()` calls — these are now handled by clearables)
- MOD: `ChristmasTracker/ChristmasTracker/Features/Profile/Views/ProfileView.swift` (remove `listService.clearCache()` call — teardown handles it)
- MOD: `ChristmasTracker/ChristmasTracker/ContentView.swift` (add `.task` or `onReceive` observer for `.unauthorizedRequest` and `.versionUpdateRequired` notifications that call `authService.logout()`)
- MOD: `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (register all clearables with sessionManager in a `Task` at init)
- NEW: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LogoutPathTests.swift`

Acceptance tests (one per path, using a spy teardown):
1. Profile logout button calls `sessionManager.teardown(reason: .userLogout)`.
2. `AuthenticationService.refreshTokenIfNeeded()` failure calls `sessionManager.teardown(reason: .sessionExpired)`.
3. `.unauthorizedRequest` notification causes `sessionManager.teardown(reason: .sessionExpired)` to be called.
4. `.versionUpdateRequired` notification causes `sessionManager.teardown(reason: .forcedUpdate)` to be called.
5. Network logout call failure (server 500) does not prevent teardown.

Paths 3 and 4 are wired as entry points; full behaviour is completed in I1. Both are listed in the Story 2 report as "wired in I1".

#### Story 3 — First-launch wipe of 4.4 data (new interface: **yes**)

Scoped files:
- NEW: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/FirstLaunchWipe.swift`
- MOD: `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (call `FirstLaunchWipe().performIfNeeded()` synchronously in `init()` before stores are used)
- NEW: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/FirstLaunchWipeTests.swift`

Acceptance tests (all with injected fakes):
1. `savedEmail` is removed after wipe.
2. All `kSecClassGenericPassword` items are deleted after wipe (class-wide delete).
3. All `kSecClassInternetPassword` items are deleted after wipe (class-wide delete, in case 4.4 wrote any).
4. Marker is written after all steps succeed.
5. A second call is a no-op: newly written v2 data is preserved.
6. When one step fails, the marker is NOT written.
7. A retry after failure completes successfully.
8. Device-level defaults (simulated with an isolated suite) survive the wipe.

---

## Rework Gate 1

### Story R1 — Real Teardown Reasons, No Notification Observers

**Problem:** Story 2 wired notification observers for `.unauthorizedRequest` and `.versionUpdateRequired`
into `AuthenticationService.init()`. Both are wrong:
- `.unauthorizedRequest` fires on every 401, including failed logins and the logout call itself.
  Client-guide §3.6 says 401 must trigger a refresh-then-replay, not an immediate logout.
- `.versionUpdateRequired` should block the app and prompt for an update (§3.6); silent logout
  is incorrect. Wiring the full response behaviors is I1 work.

**New interface introduced:** Yes — `logout(reason:)` signature and `SessionManager.lastTeardownReason`.

**Scoped files:**
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionManager.swift`
- MOD: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/LogoutPathTests.swift`

No files under `Core/Networking`, `Core/Models`, or repository protocols are touched.

**Seam choice:** Add `private(set) var lastTeardownReason: TeardownReason?` to `SessionManager`
(set inside `teardown(reason:)` before the log line). Tests that hold a reference to the same
`SessionManager` instance read it via `await sessionManager.lastTeardownReason`. No new protocol is
needed — the existing actor reference is sufficient.

Rationale: an observable value on SessionManager is the smallest surface that lets all four tests
assert the reason without sleeps, global notification posting, or a new protocol type. A `-ing`
protocol would require changing `AuthenticationService`'s stored property type, which is wider scope.

**Interface signatures (delta):**

```swift
// SessionManager — add one stored property; update teardown body
actor SessionManager {
    private(set) var lastTeardownReason: TeardownReason?

    func teardown(reason: TeardownReason) async {
        self.lastTeardownReason = reason
        // ... existing body unchanged ...
    }
}

// AuthenticationService — remove observers; add reason parameter
final class AuthenticationService {
    // REMOVED: nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol]
    // REMOVED: setupNotificationObservers()
    // REMOVED: deinit

    func logout(reason: TeardownReason = .userLogout) async {
        // ... network call unchanged ...
        await sessionManager.teardown(reason: reason)
        clearAuthState()
        clearStoredTokens()
    }

    func refreshTokenIfNeeded() async {
        // ... on catch, call: await logout(reason: .sessionExpired)
    }
}
```

**Tests (5 total, replacing all 5 current LogoutPathTests; no notification posting; no sleeps):**

1. `profileLogoutPathSendsTeardownWithUserLogoutReason`
   — Call `authService.logout()` (default reason). Assert `lastTeardownReason == .userLogout` and a
     registered `ListDataStore` is empty.

2. `refreshFailureCallsLogoutWithSessionExpiredReason`
   — Login via `ThrowingLogoutRepository` with `expiresIn: 0` (so `AuthTokens.needsRefresh` is
     immediately true). Arm `shouldFailRefresh = true`. Call `refreshTokenIfNeeded()` directly.
     Assert `isAuthenticated == false`, registered `ListDataStore` is empty, and
     `lastTeardownReason == .sessionExpired`.

3. `sessionExpiredTeardownClearsRegisteredClearable`
   — Call `sessionManager.teardown(reason: .sessionExpired)` directly with a registered
     `MockSessionClearable`. Assert clearable was called and `lastTeardownReason == .sessionExpired`.

4. `forcedUpdateTeardownClearsRegisteredClearable`
   — Same as test 3 but with `.forcedUpdate`. Assert clearable was called and
     `lastTeardownReason == .forcedUpdate`.

5. `networkLogoutFailureDoesNotPreventSignOut`
   — Kept from Story 2 (regression guard). Renamed to describe what it exercises. No change in
     behavior.

**Wired in I1 (out of R1 scope):**
- 401 path: full refresh-once, replay, then `.sessionExpired` teardown.
- 426 path: block app, prompt for update. Whether 426 clears the session is an **OPEN QUESTION** for I1;
  `.forcedUpdate` is available as an entry point but the UX decision (clear vs. leave) is not made here.

---

### Story R2 — Deterministic Registration

**Problem:** `ChristmasTrackerApp.init` uses a fire-and-forget `Task { await sm.register(...) }`.
Teardown could theoretically run before every clearable is registered. While the practical race does
not exist today (logout requires user interaction after full app load), the code offers no structural
guarantee.

**New interface introduced:** Yes — `SessionManager.init(authRepository:initialClearables:)` and
`makeProductionClearables(...)`.

**Scoped files:**
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionManager.swift`
- MOD: `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift`
  (add `makeProductionClearables` free function)
- MOD: `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`
- MOD: `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift`

**Mechanism:** Extend `SessionManager` with a new `init` that accepts `initialClearables`. A free
function `makeProductionClearables(...)` at `internal` visibility lives in `SessionClearable.swift`
so tests can call it directly. `App.init` calls the factory synchronously and passes the result to
`SessionManager.init` — the fire-and-forget `Task` is removed.

**Why `AuthenticationService` is excluded from the factory:** `AuthenticationService` requires a
fully constructed `SessionManager` in its own `init`. Passing authService to `SessionManager.init`
would require constructing it before the session manager exists — a circular dependency. Therefore
authService is not registered; it self-clears via the explicit `clearAuthState()` /
`clearStoredTokens()` calls in `logout()`. These calls are kept and documented with a code comment.

**Interface signatures:**

```swift
// SessionManager — new init
actor SessionManager {
    init(authRepository: AuthenticationRepository,
         initialClearables: [any SessionClearable] = []) {
        self.authRepository = authRepository
        self.clearables = initialClearables
    }
    // existing init removed (replaced by this one with default)
}

// SessionClearable.swift — new free function
/// Returns the production clearable list for the session manager.
/// AuthenticationService is excluded — it self-clears in AuthenticationService.logout()
/// because constructing it requires an already-initialised SessionManager (circular dependency).
internal func makeProductionClearables(
    listDataStore: ListDataStore,
    itemDataStore: ItemDataStore,
    listService: ListService,
    itemService: ItemService,
    networkCache: NetworkCache
) -> [any SessionClearable]

// ChristmasTrackerApp.init — replace Task block
let clearables = makeProductionClearables(
    listDataStore: listDataStore,
    itemDataStore: itemDataStore,
    listService: listService,
    itemService: itemService,
    networkCache: NetworkCache.shared
)
let sm = SessionManager(authRepository: dependencies.authRepository, initialClearables: clearables)
// Task { await sm.register(...) } — REMOVED
```

**Test (1 new test added to `SessionTeardownTests`):**

`productionClearableSetContainsExpectedClearables`
— Call `makeProductionClearables(...)` with real store/service instances. Assert `count == 5` and
  that the array contains exactly one each of `ListDataStore`, `ItemDataStore`, `ListService`,
  `ItemService`, and `NetworkCache` (in that order). The test must fail if any clearable is omitted
  from the factory. AuthenticationService's self-clear is documented by a code comment in
  `AuthenticationService.logout()`, not by this test.
