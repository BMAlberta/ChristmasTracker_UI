> Historical snapshot (2026-11-02), taken before the baseline fixes. Section 5 (contract comparison) has errors: the login response is the {success, data, meta} envelope, and /auth/forgot-password does not exist. Code and reports outrank this file.

# iOS State Audit
**Date:** 2026-11-02  
**Auditor:** Claude (read-only audit)  
**Branch audited:** `chore/ios-setup`  
**Xcode:** 26.6 (Build 17F113)

---

## Current State Summary

The app has a well-structured architecture (Repository → DataStore → Service → View) with Swift 6 strict concurrency correctly configured and a complete design-token layer. Auth, Lists, Items, and Purchases have working Network and Mock repository implementations. However **the build is currently broken** due to 39 stale documentation file references in `project.pbxproj`. Beyond the build blocker, three critical integration gaps must be closed before any real-backend testing is possible: the `NetworkAPIClient` never injects an Authorization header, the `AuthResponse` model shape is entirely wrong relative to the contract, and the `DEBUG` flag routes all builds to mock data regardless of configuration. Additional contract mismatches (PUT vs PATCH, missing enum cases, missing capability flags) would surface as runtime crashes or silent no-ops once the first three issues are fixed.

---

## Section 1 — Project Facts

| Property | Value |
|---|---|
| Xcode Version | 26.6 (Build 17F113) |
| Deployment Target | iOS 26.0 (main target); 26.2 appears for a second build config |
| Swift Version | 6.0 |
| Swift Language Mode | Swift 6 (`SWIFT_VERSION = 6.0`) |
| Strict Concurrency | `-strict-concurrency=complete` via `OTHER_SWIFT_FLAGS[arch=*]` |
| File-system Synchronized Groups | **YES** — `PBXFileSystemSynchronizedRootGroup` confirmed (3 entries); new `.swift` files need no project edits |
| Bundle ID (main) | `com.alberta.ChristmasTracker` (**note double "com"**) |
| Bundle ID (Debug override) | `com.christmastracker.ios.dev` (from `Config-Debug.xcconfig`) |
| Bundle ID (Tests) | `com.alberta.ChristmasTrackerTests` |

### Build Configurations

| Config | xcconfig | API Base URL Host |
|---|---|---|
| Debug | `Config-Debug.xcconfig` (includes `Config.xcconfig`) | **BROKEN** — `https:/ /api-dev.christmastracker.com` (literal space in URL) |
| QA | `Config-QA.xcconfig` | `api-qa.christmastracker.com` |
| Release | `Config.xcconfig` | `api.christmastracker.com` |

**Note:** The contract's production server is `https://api.bmalberta.com/tracker/v2`; the xcconfig hosts differ. Whether the xcconfig URLs are the live backend hosts or a planned custom domain is UNVERIFIED.

**Note:** Debug xcconfig has a literal space in the URL (`https:/ /api-dev...`). `URL(string:)` will return nil and the app will `fatalError` at launch in Debug.

### SPM Dependencies

| Package | Declared Minimum | Resolution |
|---|---|---|
| `newrelic-ios-agent-spm` | `upToNextMajorVersion(7.6.1)` | Resolved at build time |
| `sentry-cocoa` | `upToNextMajorVersion(9.4.0)` | Resolved at build time |
| `TrackerInstrumentation` | Local package (`LocalPackages/`) | **NOT linked to Xcode target** (not in `project.pbxproj`) |

### How to Create a Debug-Against-Real-Backend Scheme

Two changes are required:

1. **Fix (or add) an xcconfig** that sets `API_BASE_URL` to the real backend base URL without the space. Either fix `Config-Debug.xcconfig` or create `Config-RealBackend.xcconfig`.
2. **Change `AppDependencies.make()`** in `ChristmasTrackerApp.swift` — the `#if DEBUG` block unconditionally uses mock repositories. Either remove the `#if DEBUG` guard, add a new compiler flag (e.g., `REAL_BACKEND`), or use a different scheme with a non-DEBUG configuration (QA or Release already use network repositories).

---

## Section 2 — Build and Tests

### Build Command
```
xcodebuild -project "ChristmasTracker/ChristmasTracker.xcodeproj" \
  -scheme ChristmasTracker \
  -destination "platform=iOS Simulator,id=BDA94E1A-7F5D-4689-A195-7F293ECC57A6" \
  -derivedDataPath /tmp/ct-audit-build \
  build
```
Simulator used: **iPhone 16 Pro (26.4.1)** — id `BDA94E1A-7F5D-4689-A195-7F293ECC57A6`

### Result: **BUILD FAILED**

| Category | Count |
|---|---|
| Errors | 39 |
| Warnings | 2 |

**All 39 errors** are identical in pattern:
```
error: The file "00_Implementation_Phases_Overview.md" couldn't be opened
       because there is no such file. (in target 'ChristmasTracker')
```
These are stale references to `.md` and `.pdf` documentation files (e.g., `00_Implementation_Phases_Overview`, `Backend_Requirements_Phase3_Authentication`, `11_Phase_6-5_Purchase_Management_Part3`, etc.) that were added to the Xcode project resource bundle during earlier development but have since been removed from the repo. The entries still exist in `project.pbxproj` and must be deleted.

**2 warnings** (cosmetic only):
```
warning: The "primaryColor" color asset name resolves to a conflicting Color symbol "primary".
```

**Unit tests: NOT RUN** (build failed before test phase).

**Swift 6 concurrency warnings: UNVERIFIED** (build blocked before Swift compilation).

### Fix Required Before Any Other Testing
Remove the ~39 stale file references from `project.pbxproj`. This is the sole blocker; no Swift code changes are required.

### scripts/ directory
`scripts/` exists but is empty. `scripts/build.sh`, `scripts/test.sh`, and `scripts/verify.sh` referenced in `CLAUDE.md` do not exist yet.

---

## Section 3 — Architecture Conformance

### Actual Structure

```
Core/
  Configuration/   AppConfiguration (xcconfig reader)
  Extensions/      EnvironmentValues (+Auth, +APIClient, +ListService, +ItemService)
  Logging/         Logger actor, destinations, PIIFilter
  Models/          GiftList, GiftItem, ListDetail, Purchase, User, AuthTypes
  Networking/      APIClient protocol, NetworkAPIClient, MockAPIClient, NetworkCache
  Security/        KeychainService, DeviceFingerprintService
Features/
  Authentication/  Repository protocol + Mock + Network, AuthenticationService, SessionManager, Views
  Dashboard/       DashboardViewModel_old (DEAD CODE), Views
  Items/           Repository protocol + Mock + Network, ItemDataStore, ItemService, Views
  Lists/           Repository protocol + Mock + Network, ListDataStore, ListService, Views
  Purchases/       Repository protocol + Mock + Network, Views (no PurchaseService)
  Statistics/      StatsView (stub only)
  Profile/         ProfileView
DesignSystem/
  Colors/          AppColors + xcassets with named tokens
  Typography/      AppTypography
  Spacing/         AppSpacing
  Icons/           AppIcons
  Components/      EmptyStateView, ErrorStateView, LoadingView, SkeletonView
Navigation/        TabBarView, TabSelection
```

### Conformance vs Intended Pattern

| Pattern | Status | Notes |
|---|---|---|
| Repository protocol with Mock + Network | ✓ Conforms | Auth, Lists, Items, Purchases all have both |
| Actor DataStore | ✓ Conforms | `ListDataStore`, `ItemDataStore` are actors |
| `@MainActor @Observable` Service | ✓ Conforms | Auth, List, Item services |
| Services via environment | ✓ Conforms | `@Environment(\.listService)` etc. |
| No per-screen view models | **PARTIAL** | `DashboardViewModel_old` still compiles; class name has `_old` suffix but is not deleted. `Dashboard/ViewModels/` folder exists with both the dead class and `DashboardListResponse.swift` |
| `@Instrumented` on async/throws in repo/service layer | **MISSING** | `TrackerInstrumentation` package exists in `LocalPackages/` but is not linked to the Xcode target; `@Instrumented` is never used anywhere in the app |

### Architecture Deviations

| File | Deviation |
|---|---|
| `Features/Dashboard/ViewModels/DashboardViewModel_old.swift` | Old view-model pattern, still compiles. Should be deleted. |
| `Features/Dashboard/ViewModels/DashboardListResponse.swift` | Defines `ListsData` at module scope; `NetworkListRepository` also defines `NetworkListRepository.ListsData` (nested). No compile conflict, but conceptual duplication. |
| `Features/Purchases/` | No `PurchaseService`. `RecordPurchaseView` has repository call commented out. Views need a service wrapper before the purchase flow works. |
| `Core/Networking/NetworkAPIClient.swift` | **Critical:** `appendCommonHeaders` never adds `Authorization: Bearer <token>`. Access token is held in `AuthenticationService` but there is no mechanism to inject it into `NetworkAPIClient`. Every authenticated endpoint will return 401. |
| `ChristmasTrackerApp.swift:27` | `#if DEBUG` unconditionally uses all-mock dependencies. QA scheme would use Network repositories (Release condition), but the build is gated on removing mock at compile time rather than at runtime configuration. |

### Existing Mock Types

| Type | Location |
|---|---|
| `MockAPIClient` | `Core/Networking/MockAPIClient.swift` |
| `MockAuthenticationRepository` | `Features/Authentication/Repositories/MockAuthenticationRepository.swift` |
| `MockListRepository` | `Features/Lists/Repositories/MockListRepository.swift` |
| `MockItemRepository` | `Features/Items/Repositories/MockItemRepository.swift` |
| `MockPurchaseRepository` | `Features/Purchases/Repositories/MockPurchaseRepository.swift` |
| `MockData` (preview data) | `PreviewContent/MockData.swift` |

### Theme / Design Token Layer

**EXISTS.** `DesignSystem/` folder with `AppColors`, `AppTypography`, `AppSpacing`, `AppIcons`, and a full xcassets color catalog (Primary, Accent, Background, Surface, Text, Border, Status, Budget). Token usage is consistent in views reviewed. One naming conflict (`primaryColor` → conflicts with SwiftUI `Color.primary`) produces a build warning.

---

## Section 4 — Feature Inventory

| Screen / Flow | Status | Backend? |
|---|---|---|
| Login | BUILT | Mock only (Debug); Network impl exists for QA/Release |
| Register | PARTIAL | Mock only; request body missing `firstName`, `lastName`, `registrationCode` |
| Session restore (token refresh on launch) | BUILT | Mock only |
| Biometric setup + login | BUILT | Mock only; `/auth/biometric` endpoint NOT in contract |
| Forgot password | BUILT | Mock only |
| Dashboard / Lists | BUILT | Mock only |
| List detail | BUILT | Mock only |
| Create list | BUILT | Mock only; `recipientId` sent as snake_case (`recipient_id`) — contract is camelCase |
| Edit list | BUILT | Mock only; uses PUT, contract requires PATCH |
| Delete list | BUILT | Mock only |
| Items list | BUILT | Mock only |
| Item detail | BUILT | Mock only |
| Add item | BUILT | Mock only; `offList` field stripped server-side per P21 |
| Edit item | BUILT | Mock only; uses PUT, contract requires PATCH |
| Delete item | BUILT | Mock only |
| Record purchase | PARTIAL | Stub: actual repository call is commented out (`// let response = try await purchaseRepository...`) |
| Purchase history | PARTIAL | View exists (`PurchaseHistoryView`); no service or data source wired |
| Purchase detail | PARTIAL | View exists; no data wiring |
| Budget confirmation (overage) | PARTIAL | `PurchaseWarning` model exists, `RecordPurchaseView` has alert UI, but no actual call to trigger it |
| Statistics | MISSING | Stub view only (`"Statistics coming soon"`) |
| Budgets | MISSING | No views; models/repos in `backup/phase-7-1-models` branch only |
| Profile | BUILT | Mock only; logout works |
| Edit profile | MISSING | `ProfileView` has TODO comment |
| Members / invite flow | MISSING | No views; `GET /lists/{id}/members` never called |
| Children management | MISSING | No views |
| Settings (notifications, biometric toggle) | MISSING | `ProfileView` rows present but tap handlers are print statements |
| Version-check proactive call | MISSING | 426 response handled in `NetworkAPIClient`; no proactive `GET /app/version-check` call |
| Share extension | MISSING | Not present in project |

---

## Section 5 — Contract Comparison

### API Calls Made by the App

| Method | App Path | Contract Path | Status | Issue |
|---|---|---|---|---|
| POST | `/auth/login` | `/tracker/v2/auth/login` | **Mismatch** | Response shape wrong (see below) |
| POST | `/auth/register` | `/tracker/v2/auth/register` | **Mismatch** | Request body missing `firstName`, `lastName`, `registrationCode`; response shape wrong |
| POST | `/auth/refresh` | `/tracker/v2/auth/refresh` | **Mismatch** | Response shape wrong |
| POST | `/auth/logout` | `/tracker/v2/auth/logout` | OK (path) | `refreshToken` not sent in body (app passes `.none` body) |
| POST | `/auth/forgot-password` | `/tracker/v2/auth/forgot-password` | OK | |
| POST | `/auth/biometric` | — | **NOT IN CONTRACT** | Endpoint does not exist in `openapi.json` |
| POST | `/auth/ping` | — | **NOT IN CONTRACT** | Endpoint does not exist in `openapi.json` |
| GET | `/lists` | `/tracker/v2/lists` | OK | |
| GET | `/lists/{id}` | `/tracker/v2/lists/{id}` | OK | |
| POST | `/lists` | `/tracker/v2/lists` | **Mismatch** | `recipientId` encoded as `recipient_id` (snake_case CodingKey); contract is camelCase |
| **PUT** | `/lists/{id}` | PATCH `/tracker/v2/lists/{id}` | **Wrong method** | Contract says PATCH |
| DELETE | `/lists/{id}` | `/tracker/v2/lists/{id}` | OK | |
| GET | `/lists/{listId}/items` | `/tracker/v2/lists/{listId}/items` | OK | |
| POST | `/lists/{listId}/items` | `/tracker/v2/lists/{listId}/items` | OK | `offList` field silently ignored by server per P21 |
| GET | `/items/{id}` | `/tracker/v2/items/{id}` | OK | |
| **PUT** | `items/{id}` (missing `/`) | PATCH `/tracker/v2/items/{id}` | **Wrong method + bad path** | Missing leading `/`; contract says PATCH |
| DELETE | `/items/{id}` | `/tracker/v2/items/{id}` | OK | |
| **GET** | `/items/{itemId}/purchases` | — | **NOT IN CONTRACT** | Contract only has POST for this path; to list purchases by item use `GET /purchases?itemId=` |
| POST | `/items/{itemId}/purchases` | `/tracker/v2/items/{itemId}/purchases` | OK (commented out) | Actual call is TODO |
| **PUT** | `/purchases/{id}` | PATCH `/tracker/v2/purchases/{id}` | **Wrong method** | Contract says PATCH |
| DELETE | `/purchases/{id}` | `/tracker/v2/purchases/{id}` | OK | |

### Auth Response Shape Mismatch (critical)

The contract `POST /auth/login` response:
```json
{ "accessToken": "...", "refreshToken": "..." }
```

The app's `AuthResponse` struct:
```swift
struct AuthResponse: Codable {
    let success: Bool
    let data: AuthData  // { user, accessToken, refreshToken, expiresIn }
}
```

These are completely incompatible. Login will throw a `decodingError` at runtime. The `User` model is also incompatible: the contract has `firstName`, `lastName`, `displayName`; the app has a single `name` field with snake_case CodingKeys (`created_at`).

### Domain Model Mismatches

| Model | App | Contract | Impact |
|---|---|---|---|
| `User` | `name`, snake_case `created_at`/`updated_at` CodingKeys | `firstName`, `lastName`, `displayName`, camelCase dates | Decode failure at login |
| `AuthResponse` | Wrapped `{success, data: {user, accessToken, refreshToken, expiresIn}}` | Flat `{accessToken, refreshToken}` | Decode failure at login |
| `ListVisibility` | Missing `FRIENDS_ONLY` case | `PRIVATE`, `INVITE_ONLY`, `FRIENDS_ONLY`, `PUBLIC` | **Crash** on any list with `FRIENDS_ONLY` |
| `ShippingStatus` | Missing `NOT_TRACKED` case | `NOT_TRACKED`, `NOT_SHIPPED`, `SHIPPED`, `DELIVERED` | **Crash** on any purchase with `NOT_TRACKED` |
| `GiftList` / `ListDetail` | No `capabilities: CapabilityFlags` | `ListSummary` allOf includes `CapabilityFlags` | Capability-driven UI impossible; app uses `myRole` as proxy (violates CLAUDE.md contract rule) |
| `ListMember` | Placeholder in `MockData.swift`; snake_case CodingKeys (`user_id`, `joined_at`) | `MemberSummary` with `userId`, `displayName`, `role`, `status`, `invitedAt`, `acceptedAt`, `expiresAt` (camelCase) | Decode failure |
| `CreateListRequest` | snake_case CodingKeys (`recipient_id`, `co_owner_id`) | camelCase | Server will reject or silently ignore |

### Endpoints in Contract Not Called by App

`GET /app/version-check`, `GET /auth/me`, `GET /stats`, `GET /purchases` (paginated history), all `/budgets` CRUD, all `/members` CRUD, `PATCH /items/{id}/status`, `GET /purchases/{id}/shipping`, `PATCH /purchases/{id}/shipping`, `GET /users/me`, `PATCH /users/me`, `PATCH /users/me/password`, `/users/me/children` CRUD, `GET /users/{id}`.

---

## Section 6 — Security and Operations

| Topic | Finding |
|---|---|
| Access token storage | In-memory only (`tokens` var on `AuthenticationService`). Lost on app terminate. |
| Refresh token storage | Keychain key `auth.tokens` (full JSON) and `auth.refresh_token` (raw). `kSecAttrAccessibleAfterFirstUnlock`. |
| Biometric token storage | Keychain key `auth.biometric_token` with `SecAccessControlCreateWithFlags(.biometryCurrentSet)`. Gate: `LocalAuthentication` Face ID / Touch ID. |
| Authorization header | **CRITICAL: MISSING.** `NetworkAPIClient.appendCommonHeaders` sends `X-App-Version`, `X-Platform`, `X-Device-Fingerprint`, `Content-Type` — never `Authorization: Bearer`. All authenticated API calls will return 401. |
| Hardcoded secrets | None found. Keys come from environment variables (`NEW_RELIC_LICENSE_KEY`) or xcconfig. |
| Hardcoded URLs | None in Swift code. Base URL loaded from xcconfig via `Info.plist`. |
| Sentry | `@_exported import Sentry` in `TrackerInstrumentation/Sources/ClearanceInstrumentation/Instrumented.swift`. That package is **NOT linked** to the Xcode target. No `SentrySDK.start()` anywhere. **Crash reporting is entirely dark.** |
| New Relic | SPM dependency declared and resolves. `NewRelicDestination` exists. License key read from `ProcessInfo.processInfo.environment["NEW_RELIC_LICENSE_KEY"]` — requires env var injection at runtime. **All SDK method calls are commented-out TODO stubs.** Logging falls through to `print` statements. New Relic is non-functional. |
| PII filter | `PIIFilter` redacts Bearer tokens, email patterns, etc. Integrated into `Logger`. |
| Logging | `Logger` actor with `OSLog` (always), `Console` (Debug), `NewRelic` (stub). Fire-and-forget via `Task.detached`. Signposts implemented. Flush on error/critical. |
| Ad hoc device build | No `ExportOptions.plist`, no export scripts, no provisioning profile in `Distribution/`. The `Distribution/` folder contains numbered directories (30–44) and icons — likely old IPA artifacts. A full provisioning + export workflow must be set up. |
| Version enforcement | 426 response triggers `versionUpdateRequired` notification in `NetworkAPIClient`. No proactive `GET /app/version-check` call on launch. |
| Debug URL | `Config-Debug.xcconfig` has a space in the URL (`https:/ /api-dev.christmastracker.com`) — will cause `fatalError("API_BASE_URL not configured")` at launch in any Debug scheme that uses Network repositories. |

---

## Section 7 — Docs and Agent Files

| Path | Exists | Notes |
|---|---|---|
| `Docs/DECISIONS.md` | ✓ | Revision 17, dated 2026-11-02 — current |
| `Docs/PRD.md` | ✓ | Not reviewed in detail |
| `Docs/process/coding-standards.md` | ✓ | |
| `Docs/process/testing-conventions.md` | ✓ | |
| `Docs/client-guide.md` | **MISSING** | Referenced in `CLAUDE.md` "Read from disk every session" — does not exist |
| `Docs/error-codes.md` | **MISSING** | Referenced in `CLAUDE.md` — does not exist |
| `Docs/epics/` | ✓ (empty) | No current epic file |
| `Docs/reports/` | ✓ (empty) | No story reports yet |
| `Docs/ios-state-audit.md` | Created by this audit | |
| `scripts/build.sh` | **MISSING** | Referenced in `CLAUDE.md` |
| `scripts/test.sh` | **MISSING** | Referenced in `CLAUDE.md` |
| `scripts/verify.sh` | **MISSING** | Referenced in `CLAUDE.md` |
| `ChristmasTracker/AGENTS.md` | ✓ | |
| `Docs/AGENTS.md` | ✓ | |

**Stale:** `project.pbxproj` references ~39 old `.md`/`.pdf` implementation guide files that no longer exist in the repository. These were bundled as resources at some earlier phase and break the build.

---

## Section 8 — Local Commit Review: `backup/phase-7-1-models` (d9188a6)

Commit message: "Phase 7.1 - Budget and Stats Initial Data Models"

Files added or modified: `Budget.swift`, `Statistics.swift`, `BudgetRepository.swift` (protocol), `StatisticsRepository.swift` (protocol), `MockBudgetRepository.swift`, `MockStatisticsRepository.swift`, `NetworkBudgetRepository.swift`, `NetworkStatisticsRepository.swift`, `project.pbxproj` (doc references).

### Per-File Classification

| File | Verdict | Reason |
|---|---|---|
| `Core/Models/Budget.swift` | **REWORK** | `Budget` model fields match contract schema ✓. `BudgetsResponse` wraps `data: BudgetData { items: [Budget] }` — **wrong**: contract `GET /budgets` returns `data` as a direct array `[Budget]`, not `{ items: [] }`. Decode will fail. `BudgetResponse { data: Budget }` is correct. |
| `Core/Models/Statistics.swift` | **REWORK** | `StatisticsData` is a valid client view model for display. However there are no Codable types for decoding the `/stats` endpoint (`StatsYearResponse`, `StatsAllResponse` with `scope` discriminator). These must be added. |
| `Features/Statistics/Repositories/BudgetRepository.swift` | **KEEP** | Protocol only; correct signatures. |
| `Features/Statistics/Repositories/StatisticsRepository.swift` | **KEEP** | Protocol only; correct signatures. |
| `Features/Statistics/Repositories/MockBudgetRepository.swift` | **KEEP** | Mock data; update once `BudgetData` response wrapper is fixed. |
| `Features/Statistics/Repositories/MockStatisticsRepository.swift` | **KEEP** | Mock assembly logic is sound. |
| `Features/Statistics/Repositories/NetworkBudgetRepository.swift` | **REWORK** | (1) `updateBudget` uses `.put` — contract says PATCH. (2) `duplicateBudget` uses `.get` with a request body — contract says POST to `/budgets/{year}/duplicate`. (3) Inconsistent leading `/` on paths. All three are blocking bugs. |
| `Features/Statistics/Repositories/NetworkStatisticsRepository.swift` | **REWORK** | Does not call `GET /stats` at all. Assembles statistics client-side by fetching `/budgets` + `/purchases` and merging them. This is architecturally wrong: the contract provides a single `/stats?year=` endpoint that returns pre-computed `StatsYearResponse` or `StatsAllResponse` with a `scope` discriminator. Additionally: (a) `GET /purchases` returns a paginated cursor response, not the simple `PurchasesResponse { data: { purchases: [] } }` the code expects; (b) path `"budgets"` is missing the leading `/`. The correct approach is to call `GET /tracker/v2/stats?year={year}` and decode the discriminated union. |
| `project.pbxproj` (doc references only) | **DISCARD** | Adds more stale documentation file references. Do not cherry-pick this portion. |

### Budget/Stats Contract Summary

`GET /tracker/v2/stats?year=2026` → `StatsYearResponse { scope: "year", year, totalSpent, itemsPurchased, purchaseCount, spendByRecipient, budget?, availableYears[] }`  
`GET /tracker/v2/stats` (or `?year=all`) → `StatsAllResponse { scope: "all", totalSpent, itemsPurchased, purchaseCount, byYear[], availableYears[] }`

`GET /tracker/v2/purchases` → paginated: `{ success, data: { purchases: PurchaseHistoryRow[], filteredCount, filteredTotal, nextCursor? } }`

`GET /tracker/v2/budgets` → `{ success, data: Budget[], meta }` (array, not wrapped object)

---

## Section 9 — Top 10 Risks to Ad Hoc Build (~Nov 15)

| # | Risk | Severity | Affected Flow |
|---|---|---|---|
| 1 | **Build blocked by 39 stale doc references** in `project.pbxproj`. Cannot produce any binary. | P0 | All |
| 2 | **No Authorization header** in `NetworkAPIClient`. Every authenticated API call returns 401. The token exists in `AuthenticationService` but is never injected into the HTTP client. | P0 | All authenticated endpoints |
| 3 | **Auth response shape entirely wrong.** `AuthResponse` cannot decode the contract's flat `{accessToken, refreshToken}`. Login will throw a decode error every time. | P0 | Login, register, refresh |
| 4 | **`#if DEBUG` forces all-mock dependencies.** Any Debug-configuration build never touches the network. A QA or Release scheme is required to test real-backend integration. | P1 | All network flows |
| 5 | **Missing `FRIENDS_ONLY` / `NOT_TRACKED` enum cases.** Any server response containing these values will crash with a `DecodingError`. These are live values in the production schema. | P1 | Lists (visibility), Purchases (shipping) |
| 6 | **Register request missing required fields** (`firstName`, `lastName`, `registrationCode`). New user creation will fail with a 400 validation error. | P1 | Register |
| 7 | **`CapabilityFlags` absent from `GiftList` and `ListDetail`.** All permission-gated UI (purchase button, off-list items, activity feed) is driven by `myRole` instead of server-computed capability flags, violating the core contract rule in `CLAUDE.md`. Blind viewers will see items they should not. | P1 | List detail, Item detail, Purchase |
| 8 | **Purchase recording is a TODO.** `RecordPurchaseView.recordPurchase()` has the repository call commented out. Tapping "Record" shows a success state without making any network request. | P1 | Record purchase (Build 1 requirement) |
| 9 | **Sentry not initialized.** SPM dependency linked but `SentrySDK.start()` never called (and `TrackerInstrumentation` package is not linked to the target). Crashes produce no observability signal. | P2 | Operations / post-launch |
| 10 | **Debug `API_BASE_URL` has a literal space** (`https:/ /api-dev...`). Any Debug scheme using Network repositories will `fatalError` at launch before displaying a single view. | P2 | Debug-against-real-backend |

---

## Effort Estimates

### Build 1 — Sign in, session restore, lists, items, members, purchases + budget confirmation

| Work Item | Agent-Hours | Pipeline |
|---|---|---|
| Remove stale doc references from `project.pbxproj` (fix build) | 1 | Solo |
| Fix Debug xcconfig URL (space removal) | 0.5 | Solo |
| Add `Authorization: Bearer` header injection to `NetworkAPIClient` | 1 | Full (auth layer) |
| Fix `AuthResponse` / `User` model to match contract response shape | 3 | Full (auth layer) |
| Fix `RegisterRequest` (`firstName`, `lastName`, `registrationCode`) | 1 | Full (auth layer) |
| Add `CapabilityFlags` to `GiftList` / `ListDetail` and wire to views | 3 | Full (capability-flag UI) |
| Fix missing `FRIENDS_ONLY` and `NOT_TRACKED` enum cases | 0.5 | Solo |
| Fix PUT → PATCH for lists, items, purchases | 1 | Solo |
| Fix `GET /items/{itemId}/purchases` → `GET /purchases?itemId=` | 1 | Solo |
| Fix `CreateListRequest` camelCase CodingKeys | 0.5 | Solo |
| Create `PurchaseService`; wire `PurchaseRepository` to environment | 2 | Full |
| Implement `RecordPurchaseView` actual repository call + budget confirmation | 3 | Full (purchase) |
| Members screen: `GET /lists/{id}/members`, invite, remove | 4 | Full |
| QA scheme that uses Network repositories (for device testing) | 1 | Solo |
| Wire `SentrySDK.start()` and link `TrackerInstrumentation` package | 1 | Solo |
| Create `scripts/build.sh`, `scripts/test.sh`, `scripts/verify.sh` | 1 | Solo |
| **Build 1 Total** | **~24** | |

### Build 2 — Stats, budgets, purchase history

| Work Item | Agent-Hours | Pipeline |
|---|---|---|
| Add `StatsYearResponse` / `StatsAllResponse` Codable types + decoder | 2 | Solo |
| `NetworkStatisticsRepository` calling `GET /stats` with discriminator decode | 3 | Full |
| Statistics view wired to real data | 2 | Full |
| `BudgetResponse` wrapper fix (`data` is array not `{items:[]}`) | 0.5 | Solo |
| `NetworkBudgetRepository` fix (PATCH, POST duplicate, leading `/`) | 1 | Solo |
| Budget CRUD views | 5 | Full |
| Purchase history: `GET /purchases` with cursor pagination | 3 | Full |
| Budget duplicate flow | 1 | Solo |
| **Build 2 Total** | **~17.5** | |
