# I1-b: App integration of the generated client
Track: iOS. Depends on: I1-a (merged: LocalPackages/TrackerAPI linked into the app), the contract at backend commit 35ff2bc (CONFORMANT). Blocks: I2b-2b (auth mapping and registration code), I3 (lists, items, members), I4 (purchases), I6b (version manager UI).
Contract state: CONFORMANT. API models come only from the generated client.

Why: the package exists but nothing in the app uses it and the app's base URL configuration is broken (the Release xcconfig resolves API_BASE_URL to "https:" because // starts an xcconfig comment; Debug and QA contain a literal space). This package makes the configuration correct and verifiable, builds the client at one composition root, adds a safe way to point Debug builds at the real backend, and proves the whole path with one real call (version-check) that needs no authentication.

Scope
1. Hosts. Effective API_BASE_URL: Debug http://localhost:3010, QA http://localhost:3010 (same as Debug; no QA stack exists), Release https://api.bmalberta.com. Written in the xcconfig files so that // survives (the https:/$()/host form, or equivalent). No /tracker/v2 in any base URL. A pure validator (scheme http or https, non-empty host, empty path or "/") used by AppConfiguration; per-configuration expectations checked by tests (the validator over the three expected strings) and by scripts/check-config.sh (the effective xcodebuild -showBuildSettings value for each configuration).
2. A launch argument `-apiModeOverride real|mock` that overrides API_MODE for Debug and QA builds only (ignored when APP_ENVIRONMENT is production), through a pure resolver.
3. A composition root that builds the generated client with TrackerClientFactory.make (the app info from the bundle, the base URL from AppConfiguration, the four seams implemented), used only when the effective API mode is real.
4. The first real call: GET /app/version-check through a repository (protocol, generated-client implementation, mock), a domain model, a service, and a launch-time check in real mode that only logs the result.
5. scripts/verify.sh builds the TrackerAPI package scheme with xcodebuild, so a missing dependency declaration in Package.swift fails verify (a declared-dependencies gap passed `swift test` but broke the Xcode build in I1-a).

Decisions
- App Transport Security: add NSAppTransportSecurity with only NSAllowsLocalNetworking set to true to Info.plist (it permits plain HTTP to localhost and local addresses only, not to internet hosts). check-config.sh fails if NSAllowsArbitraryLoads or NSAllowsArbitraryLoadsInWebContent is present or true.
- The override applies as: the launch argument (read from UserDefaults key apiModeOverride) wins over the Info.plist API_MODE only when APP_ENVIRONMENT is not production; an unrecognized value is ignored (the Info.plist value stands) with a warning log; Release builds (APP_ENVIRONMENT production) ignore the argument entirely.
- The generated client is built once at the composition root and injected; nothing else constructs it. Existing hand-written network repositories stay as they are until I2b-2b and I3 replace them; real mode therefore only exercises version-check through the new client in this package.
- Seam implementations: AccessTokenProviding reads the in-memory access token from the existing AuthenticationService (hop to the main actor); SessionRefreshing calls a new small AuthenticationService method that forces one refresh through the existing single-flight function and maps a credential failure (the existing isCredentialFailure classification) to SessionRefreshError.credentialFailure and any other failure to SessionRefreshError.other (mark it TODO(I2b-2b): the generated auth mapping replaces it); VersionOutdatedHandling publishes the details to a main-actor observable VersionGate (state only, no UI in this package); RequestIDObserving records the latest request id in memory and sets it as the Sentry scope tag request_id when Sentry is enabled (never anything else).
- The version-check domain model: VersionPolicy (state: ok, updateRecommended, forceUpdate; minimumVersion, recommendedVersion, latestVersion, minimumBuild, latestBuild; manifestURL and ipaURL as URL? parsed from the strings, nil when absent or unparsable; releaseNotes: String?; enabled: Bool; updatedAt: Date). The client sends platform "ios", version = CFBundleShortVersionString, build = CFBundleVersion as an Int.
- Response handling: 200 maps to VersionPolicy; 304 (notModified) returns the last in-memory policy if there is one, otherwise throws; 400, 429, and 500 and the undocumented fallback map to TrackerAPIError through the package's mapping; transport failures map to TrackerAPIError.network. The service keeps the last successful policy and the last error category (no messages with data) and never crashes the app on failure.

Non-goals: any UI, the version manager screen, auth or login through the generated client, lists, items, members, purchases, removing the hand-written network stack, the Face ID code, the inactivity-lock remote timeout (data.inactivityLockMinutes is not in the spec yet), registration code.

Acceptance
- The effective API_BASE_URL is exactly http://localhost:3010 (Debug, QA) and https://api.bmalberta.com (Release), proven by check-config.sh running xcodebuild -showBuildSettings, and the validator is unit-tested over those strings plus rejects (a path such as /tracker/v2, an empty host, a non-http scheme, "https:", a literal space).
- The override resolver is a pure function with a full truth table in tests, and a production environment ignores the argument.
- With a fake transport, a version-check response decoded through the REAL factory-built client maps to VersionPolicy for every state and for absent optional fields; 304, 400, 429, 500, undocumented, and a transport failure each map as specified; the request carries platform=ios, the version, and the build as query items and the four client headers.
- A launch-time check runs only in real mode and never in mock mode, and a failure is logged without crashing.
- scripts/verify.sh includes the package-scheme xcodebuild step; a mutation check (temporarily removing the HTTPTypes dependency from LocalPackages/TrackerAPI/Package.swift) makes it fail, and the report shows the failing output before the revert.
- No change under contract/, .claude/, any .pbxproj, Core/Networking, or auth and Face ID files other than the one new AuthenticationService method.

---

## Inventory

### Where API_BASE_URL is defined and read

**Defined in xcconfig files:**
- `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig` line 22: `API_BASE_URL = https://api.christmastracker.com`
- `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig` line 16: `API_BASE_URL = https:/ /api-dev.christmastracker.com` (broken — literal space; `//` without the space would be a comment)
- `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig` line 16: `API_BASE_URL = https:/ /api-qa.christmastracker.com` (broken — same)

**Read via Info.plist:**
- `ChristmasTracker/ChristmasTracker/Info.plist` line 6: `<key>API_BASE_URL</key><string>$(API_BASE_URL)</string>`

**Read in Swift:**
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift` line 55: `apiBaseURL: string("API_BASE_URL").flatMap { URL(string: $0) }` in `readConfiguration`
- `AppConfiguration.apiBaseURL` (static let, line 74): uses `fatalError` if nil
- `ChristmasTracker/ChristmasTracker/Core/Networking/NetworkAPIClient.swift` line 24: `baseURL: URL = AppConfiguration.apiBaseURL` (default parameter)

**Effective values today (from `xcodebuild -showBuildSettings`):**

| Configuration | Effective API_BASE_URL |
|---|---|
| Debug | `https:/ /api-dev.christmastracker.com` (broken — literal space) |
| QA | `https:/ /api-qa.christmastracker.com` (broken — literal space) |
| Release | `https:` (the `// api.christmastracker.com` part is treated as an xcconfig comment) |

### How AppDependencies.make() chooses mock vs real

`ChristmasTrackerApp.swift` lines 107–125: switches on `AppConfiguration.apiMode`:
- `.mock` → `MockAPIClient.withMockData()`, `MockAuthenticationRepository`, `MockListRepository`, `MockItemRepository`
- `.real` → `NetworkAPIClient()`, `NetworkAuthenticationRepository`, `NetworkListRepository`, `NetworkItemRepository`

No generated client is built or used anywhere yet.

### Version-check: existing references

None. No `version-check`, `VersionCheck`, `versionCheck`, or `checkAppVersion` symbol exists anywhere in the app target.

### Seam protocols (LocalPackages/TrackerAPI/Sources/TrackerAPI/Seams.swift)

```swift
public protocol AccessTokenProviding: Sendable {
    func accessToken() async -> String?
}

public enum SessionRefreshError: Error, Sendable {
    case credentialFailure
    case other(Error)
}

public protocol SessionRefreshing: Sendable {
    func refresh() async throws
}

public struct VersionOutdatedDetails: Sendable {
    public let minimumVersion: String
    public let minimumBuild: Int?
    public let latestVersion: String?
    public let latestBuild: Int?
    public let manifestUrl: String?
    public let ipaUrl: String?
}

public protocol VersionOutdatedHandling: Sendable {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async
}

public protocol RequestIDObserving: Sendable {
    func observe(requestID: String) async
}

public protocol RateLimitSleeping: Sendable {
    func sleep(seconds: TimeInterval) async
}
```

### AppClientInfo (LocalPackages/TrackerAPI/Sources/TrackerAPI/AppClientInfo.swift)

```swift
public struct AppClientInfo: Sendable {
    public let platform: String
    public let clientPlatform: String
    public let build: String
    public let version: String
}
```

### Generated CheckAppVersion Input and Output

**Input** (`Types+Operations.swift`):
```swift
Operations.CheckAppVersion.Input(
    query: Operations.CheckAppVersion.Input.Query(
        platform: String,  // "ios"
        version: String,   // CFBundleShortVersionString
        build: Int?        // CFBundleVersion as Int
    ),
    headers: Operations.CheckAppVersion.Input.Headers = .init()
)
```

**Output cases** (`Types+Operations.swift`):
- `.ok(Operations.CheckAppVersion.Output.Ok)` — body `.json(JsonPayload)` with `DataPayload`:
  - `state`: `.ok` | `.updateRecommended` | `.forceUpdate`
  - `platform: String`, `minimumVersion: String`, `recommendedVersion: String`, `latestVersion: String`
  - `minimumBuild: Int`, `latestBuild: Int`
  - `manifestUrl: String?`, `ipaUrl: String?`, `releaseNotes: String?`
  - `enabled: Bool`, `updatedAt: Date`
- `.notModified(Operations.CheckAppVersion.Output.NotModified)` — empty struct
- `.badRequest(Components.Responses.ValidationError)` — 400
- `.tooManyRequests(Components.Responses.RateLimitError)` — 429
- `.internalServerError(Components.Responses.InternalError)` — 500
- `.undocumented(statusCode: Int, OpenAPIRuntime.UndocumentedPayload)` — catch-all

---

## Gate 1: Story B1 — Hosts and Configuration

**Contract slice:** xcconfig `API_BASE_URL` for Debug/QA/Release; `AppConfiguration` validator; `Info.plist` ATS; `scripts/check-config.sh` ATS and effective URL checks.

**Acceptance criteria:**
1. Debug and QA effective `API_BASE_URL` = `http://localhost:3010`; Release = `https://api.bmalberta.com` (verified by `check-config.sh` using `xcodebuild -showBuildSettings`).
2. The xcconfig `//` problem is solved with a form that survives (e.g. `https:/$()/localhost:3010`).
3. `AppConfiguration` has a pure, nonisolated validator; invalid/missing URL in real mode is a clear failure; mock mode never touches `apiBaseURL`.
4. `Info.plist` has `NSAppTransportSecurity` → `NSAllowsLocalNetworking: true` only.
5. `check-config.sh` checks the effective `API_BASE_URL` for all three configs and forbids arbitrary loads.
6. Validator unit tests: accepts `http://localhost:3010`, `https://api.bmalberta.com`, `https://api.bmalberta.com/`; rejects `https://api.bmalberta.com/tracker/v2`, `https:`, empty string, `https:/ /api.bmalberta.com`, `ftp://x`, nil, URL with query.

**New interface introduced:** yes — `validateBaseURL(_:) -> Result<URL, ConfigurationError>` (or equivalent pure validator) on `AppConfiguration`.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig`
- `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig`
- `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig`
- `ChristmasTracker/ChristmasTracker/Info.plist`
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift`
- `scripts/check-config.sh`
- `ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift` (new)

---

## Gate 1: Story B2 — API Mode Override and Composition Root

**Contract slice:** pure resolver for `apiModeOverride` launch argument; `AppClientInfo` builder; four seam implementations; one new `AuthenticationService` method; composition root in `AppDependencies.make()`.

**Acceptance criteria:**
1. `resolveAPIMode(infoValue:override:environment:)` is pure and nonisolated; production environment ignores override; unrecognized override logs warning and falls back to info value.
2. No `#if DEBUG` in the resolver.
3. The generated client is built exactly once in `AppDependencies.make()` when mode is real, via `TrackerClientFactory.make`; never in mock mode.
4. Four seams implemented as specified in Decisions: `AccessTokenSeam`, `SessionRefreshSeam`, `VersionGate`, `RequestIDSeam`.
5. New `AuthenticationService.forceRefresh() async throws` method calls the existing `singleFlightRefresh` with the current token and maps errors correctly.
6. Resolver truth table tested; client-info builder tested; seam behaviors tested; composition root tested (mock mode builds no client).

**New interface introduced:** yes — resolver function, four seam types, `VersionGate`, new `AuthenticationService` method.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift` (resolver)
- `ChristmasTracker/ChristmasTracker/Core/API/AccessTokenSeam.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/SessionRefreshSeam.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/VersionGate.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/RequestIDSeam.swift` (new)
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (composition root)
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/AuthenticationService.swift` (one new method)
- `ChristmasTrackerTests/Core/API/APIModeResolverTests.swift` (new)
- `ChristmasTrackerTests/Core/API/SeamTests.swift` (new)

---

## Gate 1: Story B3 — Version-Check Slice

**Contract slice:** `VersionPolicy` domain model; `AppVersionChecking` repository protocol; `GeneratedClientAppVersionRepository`; `MockAppVersionRepository`; `VersionService`; launch check in `ChristmasTrackerApp`.

**Acceptance criteria:**
1. All five `CheckAppVersion` output cases map correctly, tested through the real factory-built client with a fake transport.
2. Fractional-second dates decode correctly.
3. 304 returns last cached policy if available, throws if not.
4. Request carries `platform=ios`, `version`, `build` query items and four client headers; no Authorization header.
5. Launch check runs only in real mode and logs only state and build numbers.
6. Service keeps last policy after a later failure.

**New interface introduced:** yes — `AppVersionChecking` protocol, `VersionPolicy`, `VersionService`, `GeneratedClientAppVersionRepository`, `MockAppVersionRepository`.

**Scoped files:**
- `ChristmasTracker/ChristmasTracker/Core/API/VersionPolicy.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/AppVersionChecking.swift` (new, protocol)
- `ChristmasTracker/ChristmasTracker/Core/API/GeneratedClientAppVersionRepository.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/MockAppVersionRepository.swift` (new)
- `ChristmasTracker/ChristmasTracker/Core/API/VersionService.swift` (new)
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` (launch check)
- `ChristmasTrackerTests/Core/API/VersionCheckTests.swift` (new)

---

## Gate 1: Story B4 — Verify Hardening and Handoff

**Contract slice:** `scripts/verify.sh` xcodebuild package-scheme step; handoff doc; mutation check proof.

**Acceptance criteria:**
1. New verify step builds the `TrackerAPI` scheme with xcodebuild for the simulator; script fails on non-zero exit.
2. Mutation check (remove `HTTPTypes` from `Package.swift`, run verify, restore) produces failing output pasted in the report.
3. Handoff doc contains "Brian's real-mode check" section and all required open risks.
4. No existing verify step or output format changed.

**New interface introduced:** no.

**Scoped files:**
- `scripts/verify.sh`
- `Docs/handoffs/<date>-ios-to-brian-i1b.md` (new)
- `Docs/reports/I1b-4-verify-and-handoff.md` (new)
