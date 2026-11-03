# Handoff: Package I6a — Observability and Configuration
**Date:** 2026-11-03
**Branch:** `feat/i6a-observability-config`
**From:** iOS
**To:** Brian (for PROGRAM.md and merge decision)

---

## Contract issues found

None. This package has no networking work. The contract is PRE-CONFORMANCE; no API models were created or modified.

---

## What changed

### Story 1 — Remove New Relic code
- `Core/Logging/NewRelicDestination.swift` deleted, including the `LogEvent.toAttributes()` extension (no other callers).
- `Logger.setupDestinations()` had the `NEW_RELIC_LICENSE_KEY` environment-variable lookup and `NewRelicDestination` init removed.

### Story 2 — API_MODE and observability configuration
- `Info.plist` gained `API_MODE`, `SENTRY_DSN`, `APP_ENVIRONMENT` as `$(...)` substitutions.
- `Config.xcconfig` (Release): stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `SENTRY_DSN_RELEASE =` fallback (before `#include?`), optional `#include? "../../Config-Secrets.xcconfig"`, `API_MODE = real`, `APP_ENVIRONMENT = production`, `SENTRY_DSN = $(SENTRY_DSN_RELEASE)`.
- `Config-Debug.xcconfig`: stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `API_MODE = mock`, `APP_ENVIRONMENT = development`, `SENTRY_DSN =` (after include).
- `Config-QA.xcconfig`: stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `API_MODE = mock`, `APP_ENVIRONMENT = qa`, `SENTRY_DSN =` (after include).
- `AppConfiguration.swift`: added `APIMode` enum with `nonisolated parse(_:)`, `readConfiguration(from:)` pure function, `apiMode`/`sentryDSN`/`appEnvironment` static properties; retained `environment`/`isDebug` compile-time helpers for existing tests.
- `ChristmasTrackerApp.AppDependencies.make()`: `#if DEBUG` mock switch replaced by `switch AppConfiguration.apiMode`. Both branches compile in every configuration.
- `scripts/build.sh`: added optional `CONFIGURATION` env variable (default `Debug`).
- `scripts/check-config.sh` added: checks `API_MODE`, `APP_ENVIRONMENT`, `SENTRY_DSN`-is-empty, and `PRODUCT_BUNDLE_IDENTIFIER` for Debug, QA, and Release; exits non-zero on mismatch; never prints DSN.
- `scripts/verify.sh`: calls `check-config.sh` after the build step.
- `ChristmasTracker/Config-Secrets.example.xcconfig` added (tracked, outside synchronized folder): template for Brian to copy as `Config-Secrets.xcconfig` and fill in a real DSN.
- `.gitignore`: added `ChristmasTracker/Config-Secrets.xcconfig`.

### Story 3 — Sentry initialization with scrubbing
- `Core/Observability/SentryBootstrap.swift` added: `nonisolated makeOptions(dsn:environment:release:)`, `nonisolated scrubEvent(_:)`, `nonisolated scrubBreadcrumb(_:)`, `startIfConfigured()`. Sentry import is direct (`import Sentry`).
- `ChristmasTrackerApp.init`: `SentryBootstrap.startIfConfigured()` added as first statement, before `FirstLaunchWipe`.

---

## What the API team must do

None for this package.

---

## Test count

| Story | Tests |
|---|---|
| Before I6a | 65 |
| After Story 1 | 65 (no change) |
| After Story 2 | 80 (+15) |
| After Story 3 | **99** (+19) |

---

## Diff stat (master..HEAD, taken after final commit)

```
20 files changed, 1194 insertions(+), 169 deletions(-)
```

No `.pbxproj` touched. No `contract/`, `.claude/`, synced Docs files, or `Core/Networking` touched. No `API_BASE_URL` line changed.

---

## Open risks

1. **Sentry is off until Brian creates Config-Secrets.xcconfig.** Copy `ChristmasTracker/Config-Secrets.example.xcconfig` → `ChristmasTracker/Config-Secrets.xcconfig` and fill in the real DSN. The file is gitignored; it must never be committed. Until it exists, Release also has `SENTRY_DSN` empty and Sentry does not start.

2. **Release resolves API_MODE=real with a base URL that still cannot reach a server until I1.** `API_BASE_URL` in Config.xcconfig is `https://api.christmastracker.com` which the xcconfig `//` parser truncates to `https:`. I1 must fix the URL escaping (same as Debug/QA's `https:/ /...` workaround, or move to a different mechanism).

3. **AppConfiguration's comments still mention the old `api-dev.christmastracker.com` and `api-qa.christmastracker.com` hosts.** These will be updated in I1 when the real host is finalized.

4. **P4 result (macro validation):** `@Instrumented` macro compiled without `-skipMacroValidation` — no flag needed. SourceKit shows "No such module 'TrackerInstrumentation'" in the IDE index but the compiler accepts it. This IDE-only issue pre-dates I6a.

5. **Pre-existing findings from I2a handoff** (carried forward):
   - `SessionClearable` naming: the protocol name uses a gerund adjective rather than the `-ing` suffix convention. Not blocking but worth a future rename.
   - Late-response risk: services have no in-flight task cancellation at teardown.
   - On-device wipe test pending (first TestFlight build).
   - 426 session-clear UX decision pending for I1.

6. **Pre-existing finding — xcconfig files in app bundle:** `Config-Debug.xcconfig`, `Config-QA.xcconfig`, and `Config.xcconfig` are copied into the Debug app bundle because they live inside the file-synchronized folder. They contain no secrets (DSN empty in Debug/QA; Release values are non-secret). `Config-Secrets.xcconfig` is correctly outside the synchronized folder and absent from the bundle.

---

## One line for PROGRAM.md section 9

> I6a (2026-11-03): removed New Relic code; xcconfig-driven API_MODE/APP_ENVIRONMENT/SENTRY_DSN with gitignored secrets file; Sentry initialized with PII scrubbing, privacy-first options, and 0.05 trace rate (disabled until Brian adds Config-Secrets.xcconfig); 99 tests, 0 failures.
