# I6a: Observability and configuration
Track: iOS. Depends on: I2a (merged), the chore branch linking TrackerInstrumentation and removing the New Relic package (merged). Blocks: I1.
Contract state: PRE-CONFORMANCE (no networking or API model changes).

Why: crash and performance reporting must exist before the networking work (I1 uses @Instrumented), without leaking surprises or personal data. The compile-time #if DEBUG mock switch stops a Debug build from ever talking to the local backend. Both are configuration problems that must be solved before I1.

Scope
1. Remove New Relic code: NewRelicDestination and its setup in Logger. (The package dependency is already gone.)
2. Configuration keys through xcconfig and Info.plist: API_MODE (mock or real), SENTRY_DSN, APP_ENVIRONMENT. Replace the #if DEBUG mock switch in ChristmasTrackerApp's AppDependencies.make() with the API_MODE value.
3. Initialize Sentry with scrubbing and a low traces sample rate. The DSN comes from configuration; with an empty DSN, Sentry does not start.
4. A configuration check script so effective values cannot drift.

Decisions
- Values by configuration: Debug API_MODE=mock, APP_ENVIRONMENT=development, SENTRY_DSN empty. QA API_MODE=mock, APP_ENVIRONMENT=qa, SENTRY_DSN empty. Release API_MODE=real, APP_ENVIRONMENT=production, SENTRY_DSN from a local untracked secrets file (empty if the file is absent). Debug and QA never send events to Sentry.
- API_MODE parsing: trim and case-insensitive; "mock" gives mock; "real" gives real; missing or unrecognized gives real, plus a warning log. A typo must never produce mock data.
- Mock mode is allowed only in Debug and QA. Release must resolve to real; the config check enforces it.
- The DSN source is option A: an untracked, gitignored Config-Secrets.xcconfig located OUTSIDE every file-synchronized folder (so it can never be copied into the app bundle), included optionally from the tracked xcconfigs. A tracked Config-Secrets.example.xcconfig documents the format with a placeholder. Because a DSN contains //, which xcconfig treats as a comment, the secrets file writes it as `https:/$()/key@host/project`.
- Sentry privacy: sendDefaultPii off; screenshots and view-hierarchy capture off (they could capture surprise gifts); network breadcrumbs off; failed-request capture off; user-interaction tracing off; traces sample rate 0.05; no user, no server name, no email ever attached. beforeSend and beforeBreadcrumb scrub strings with the existing PIIFilter.redact, including message, exception values, extras, tags, breadcrumb messages and data, and URL query strings. Sentry starts as the first statement of ChristmasTrackerApp.init, before FirstLaunchWipe.
- Release identifier for Sentry: com.alberta.ChristmasTracker@<marketing version>+<build>.

Non-goals: API_BASE_URL and any host (I1), a Logger-to-Sentry destination, @Instrumented rollout (I1 onward), networking, API models, removing the Sentry package or the TrackerInstrumentation link.

Acceptance
- No New Relic references remain in app sources; build and all tests pass.
- Effective API_MODE, APP_ENVIRONMENT, SENTRY_DSN per configuration match the Decisions (checked by scripts/check-config.sh, called from scripts/verify.sh).
- A Release-configuration simulator build compiles with the mock types present and with no #if DEBUG around the mock/real choice.
- Sentry options and scrubbers are covered by tests; the SDK does not start when the DSN is empty.
- No DSN, secrets file, or xcconfig ends up in the app bundle; effective bundle ids are unchanged from P5.

---

## Preconditions and inventory

### P1 — Git state
Branch: `master`. `git log --oneline -6` output:
```
614ff30 Merge pull request #12 from BMAlberta/chore/link-instrumentation
b7b59c9 Remove NewRelic and add TrackerInstrumentation to project.
f727446 Merge pull request #11 from BMAlberta/feat/i2a-session-hygiene
5b370d5 I2a: fix stale comment in logout
335ff0d I2a: correct reports and handoff after rework
be49ed0 I2a: register clearables deterministically and test the registry
```
Both expected PRs present. ✓

### P2 — pbxproj checks
- `grep -c "TrackerInstrumentation" project.pbxproj` → 8 matches ✓
- `grep -i "newrelic" project.pbxproj` → no output ✓

### P3 — Baseline verify.sh
```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: unit tests ===
--- tests: 65 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Baseline: 65 passed, 0 failed, 0 skipped. ✓

### P4 — Macro smoke test
@Instrumented macro signature in TrackerInstrumentation/Sources/TrackerInstrumentation/Instrumented.swift:
```swift
@attached(body)
public macro Instrumented() = #externalMacro(
    module: "TrackerInstrumentationMacros",
    type: "InstrumentedMacro")
```
Temp file placed at `Core/SmokeTestTemp.swift` applying `@Instrumented` to a trivial `nonisolated func _smokeTestInstrumented() async throws -> String`. Result: **BUILD SUCCEEDED**. SourceKit shows a "No such module 'TrackerInstrumentation'" diagnostic in the IDE index but the compiler accepted the macro without `--enable-experimental-feature` or `-skipMacroValidation` flags. Temp file deleted; `git status` clean. ✓

### P5 — BEFORE build settings (by -showBuildSettings, not file text)

**App target — ChristmasTracker scheme**

| Configuration | PRODUCT_BUNDLE_IDENTIFIER | MARKETING_VERSION | CURRENT_PROJECT_VERSION | API_BASE_URL (effective) |
|---|---|---|---|---|
| Debug | com.alberta.ChristmasTracker | 5.0 | 500 | https:/ /api-dev.christmastracker.com |
| QA | com.alberta.ChristmasTracker | 5.0 | 500 | https:/ /api-qa.christmastracker.com |
| Release | com.alberta.ChristmasTracker | 5.0 | 500 | https: (truncated — `//` parsed as xcconfig comment; pre-existing, deferred to I1) |

**ChristmasTrackerTests target**

| Configuration | PRODUCT_BUNDLE_IDENTIFIER | MARKETING_VERSION | CURRENT_PROJECT_VERSION | API_BASE_URL (effective) |
|---|---|---|---|---|
| Debug | com.alberta.ChristmasTrackerTests | 5.0 | 500 | https:/ /api-dev.christmastracker.com |
| QA | com.alberta.ChristmasTrackerTests | 5.0 | 500 | https:/ /api-qa.christmastracker.com |

**ChristmasTrackerUITests target**

| Configuration | PRODUCT_BUNDLE_IDENTIFIER | MARKETING_VERSION | CURRENT_PROJECT_VERSION | API_BASE_URL (effective) |
|---|---|---|---|---|
| Debug | com.alberta.ChristmasTrackerUITests | 5.0 | 500 | https:/ /api-dev.christmastracker.com |
| QA | com.alberta.ChristmasTrackerUITests | 5.0 | 500 | https:/ /api-qa.christmastracker.com |

Note: `PRODUCT_BUNDLE_IDENTIFIER = com.alberta.ChristmasTracker` is the effective target-level override for the app; the stale xcconfig values `com.christmastracker.ios` and `com.christmastracker.ios.dev` are present in Config.xcconfig and Config-Debug.xcconfig but are overridden by the target's own setting.

### Grep inventory

**NewRelic / NEW_RELIC references (app + test sources):**
```
ChristmasTracker/Core/Logging/NewRelicDestination.swift:2:  //  NewRelicDestination.swift
ChristmasTracker/Core/Logging/NewRelicDestination.swift:10: nonisolated final class NewRelicDestination: LogDestination {
ChristmasTracker/Core/Logging/NewRelicDestination.swift:47: // NewRelic.recordError(
ChristmasTracker/Core/Logging/NewRelicDestination.swift:56: // NewRelic.recordCustomEvent(
ChristmasTracker/Core/Logging/Logger.swift:35:           if let licenseKey = ProcessInfo.processInfo.environment["NEW_RELIC_LICENSE_KEY"] {
ChristmasTracker/Core/Logging/Logger.swift:36:               if let newRelic = NewRelicDestination(licenseKey: licenseKey) {
```

**API_MODE references:** None

**SENTRY references:** None (TrackerInstrumentation imports Sentry but app source has no direct SENTRY_ references)

**#if DEBUG references (app + test sources):**
```
ChristmasTracker/ChristmasTrackerApp.swift:26:#if DEBUG
ChristmasTracker/Core/Configuration/AppConfiguration.swift:70:#if DEBUG
ChristmasTracker/Core/Configuration/AppConfiguration.swift:78:#if DEBUG
ChristmasTracker/Core/Logging/Logger.swift:30:#if DEBUG
ChristmasTracker/Core/Logging/ConsoleLogDestination.swift:12:#if DEBUG
ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift:18:#if DEBUG
ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift:28:#if DEBUG
ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift:37:#if DEBUG
```

---

## Gate 1

### Story 1 — Remove New Relic code

**Contract slice:** None (no networking, no API models).

**Acceptance criteria:**
1. `NewRelicDestination.swift` is deleted.
2. Logger.setupDestinations has no New Relic block and no NEW_RELIC_LICENSE_KEY lookup.
3. `LogEvent.toAttributes()` is deleted with the file (grep confirms no other callers).
4. `grep -rn "NewRelic\|NEW_RELIC" --include="*.swift"` over app and test sources returns nothing (ignoring Docs/).
5. `scripts/verify.sh` passes; test count unchanged from P3 baseline (65).

**New interface introduced:** No.

**Scoped files:**
- Delete: `ChristmasTracker/ChristmasTracker/Core/Logging/NewRelicDestination.swift`
- Modify: `ChristmasTracker/ChristmasTracker/Core/Logging/Logger.swift` (remove New Relic block in setupDestinations)

**Weight:** Solo (no new interface).

---

### Story 2 — API_MODE and configuration

**Contract slice:** None (xcconfig + Info.plist + AppConfiguration + AppDependencies, no networking).

**Acceptance criteria:**
1. Info.plist gains `API_MODE`, `SENTRY_DSN`, `APP_ENVIRONMENT` keys as `$(...)` substitutions.
2. Debug xcconfig: `API_MODE = mock`, `APP_ENVIRONMENT = development`, `SENTRY_DSN =` (empty), set after include.
3. QA xcconfig: `API_MODE = mock`, `APP_ENVIRONMENT = qa`, `SENTRY_DSN =` (empty), set after include.
4. Release xcconfig: `API_MODE = real`, `APP_ENVIRONMENT = production`, `SENTRY_DSN = $(SENTRY_DSN_RELEASE)`, and an optional include of Config-Secrets.xcconfig.
5. `Config-Secrets.xcconfig` is in `.gitignore`; `Config-Secrets.example.xcconfig` is tracked with a placeholder and comment.
6. `AppConfiguration` has `apiMode: APIMode`, `sentryDSN: String?`, `appEnvironment: String` computed from infoDictionary via a pure, injectable function.
7. `APIMode.parse(_:)` is `nonisolated`, handles "mock"/"real"/nil/"" and unknown values as documented.
8. `AppDependencies.make()` uses `AppConfiguration.apiMode` — no `#if DEBUG`.
9. Mock types have no `#if DEBUG` wrapper (they do not — confirmed in P5 inventory).
10. `scripts/check-config.sh` exists, checks all three configurations, exits non-zero on mismatch, never prints DSN.
11. `scripts/verify.sh` calls `check-config.sh`.
12. After-state bundle ids match P5 BEFORE state exactly for all targets/configurations.
13. `scripts/verify.sh` passes.

**New interface introduced:** Yes (`APIMode` enum and `AppConfiguration` additions, pure `parse(_:)` and config-reading function under test).

**Scoped files:**
- Modify: `ChristmasTracker/ChristmasTracker/Info.plist`
- Modify: `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig`
- Modify: `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig`
- Modify: `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig`
- Modify: `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift`
- Modify: `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`
- Add: `ChristmasTracker/Config-Secrets.example.xcconfig` (tracked, outside synchronized folder)
- Add: `.gitignore` entry for `Config-Secrets.xcconfig`
- Add: `scripts/check-config.sh`
- Modify: `scripts/verify.sh`
- Add tests: `ChristmasTrackerTests/Core/Configuration/APIConfigurationTests.swift` (or extend existing)

**Weight:** Solo.

---

### Story 3 — Sentry initialization with scrubbing

**Contract slice:** None (local bootstrap only, no networking).

**Acceptance criteria:**
1. A `SentryBootstrap` type (or namespace) in `Core/Observability/` (or nearby) exposes:
   - `nonisolated makeOptions(dsn:environment:release:) -> SentrySDKOptions?` — returns nil when DSN is empty.
   - Pure scrubber functions for events and breadcrumbs using `PIIFilter.redact`.
   - `startIfConfigured()` — calls `SentrySDK.start` only when options exist; logs (not DSN) via Logger.
2. `ChristmasTrackerApp.init` calls `SentryBootstrap.startIfConfigured()` as its first statement, before `FirstLaunchWipe`.
3. Tests cover: nil return for empty DSN; for fake DSN, required privacy flags are set; scrubbers redact email/token/UUID from message, exception value, extras, tags, breadcrumb message/data, URL query string; user and server name are cleared; clean event is unchanged apart from clearing.
4. Tests must not start the SDK or send anything.
5. `scripts/verify.sh` passes; test count increases by the number of new tests.

**New interface introduced:** Yes (`SentryBootstrap` and its pure functions under test).

**Scoped files:**
- Add: `ChristmasTracker/ChristmasTracker/Core/Observability/SentryBootstrap.swift`
- Modify: `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`
- Add tests: `ChristmasTrackerTests/Core/Observability/SentryBootstrapTests.swift`

**Weight:** Solo.
